"""Devirtualize Prometheus' register VM (`Vmify`).

Output of Vmify::

    local function rebuild(shards, count, root) ... end
    return (function(prototypes, ...)
        <interpreter: pack, loop(P, U, Env, R, V), start, make>
    end)(rebuild({{...records...}}, N, ROOT), ...)

Everything that is randomised per file is recovered without running the
program:

* prototype tables: `rebuild(...)` only shuffles static records -> emulated;
* prototype field keys (code / constants / captures / params / children ...):
  inferred from the shape of the data;
* operand slot permutation: inferred from which slots each instruction uses;
* opcode numbers: every handler of the interpreter's dispatch tree is
  normalised and matched against the 56 handler templates of Prometheus.

The bytecode is then lifted into the register IR (ir.py) which rebuilds
structured Lua.
"""

import difflib
import re

from .luaast import (Symbol, Nil, Bool, Number, String, Vararg, Name, Index, Call, Method, Func, Table, TItem, Bin,
                     Un, Paren, Local, Assign, CallStat, Do, While, Repeat, If, NumFor, GenFor, LocalFunc, FuncStat,
                     Return, Break, Chunk, Node, Expr, transform, walk)
from .parser import parse
from .printer import Printer
from .emulator import Emulator, EmuAbort, LuaTable, Scope, Closure
from .luavalue import LuaError
from . import ir
from .ir import TupleE, Spread, CellRef, AllocCell, ClosureE, UpvalRef, IRFunc, Block, StructError


class VMError(Exception):
    pass


EXPAND = Symbol("__expand")  # pseudo function: t[n], t[n+1], ... = values


# ------------------------------------------------------------- templates
HANDLERS = {
    "LOAD": "R[a] = K[b]",
    "NIL": "R[a] = nil",
    "MOVE": "R[a] = R[b]",
    "CLEAR": "R[a] = nil",
    "CELL": "x = R[b]; R[a] = { x }",
    "GETCELL": "R[a] = R[b][1]",
    "SETCELL": "R[a][1] = R[b]",
    "GETUP": "R[a] = U[b][1]",
    "SETUP": "U[a][1] = R[b]",
    "GLOBAL": "R[a] = Env[K[b]]",
    "SETGLOBAL": "Env[K[a]] = R[b]",
    "GETTABLE": "R[a] = R[b][R[c]]",
    "SETTABLE": "R[a][R[b]] = R[c]",
    "TABLE": "R[a] = {}",
    "EXPAND": """x = R[c]
        for y = 1, x[COUNT] do
            R[a][b + y - 1] = x[y]
        end""",
    "ARGS": """x = { [COUNT] = 0 }
        for _, y in nativeIpairs(b) do
            x[COUNT] = x[COUNT] + 1
            x[x[COUNT]] = R[y]
        end
        if c ~= 0 then
            y = R[c]
            for d = 1, y[COUNT] do
                x[COUNT] = x[COUNT] + 1
                x[x[COUNT]] = y[d]
            end
        end
        R[a] = x""",
    "TAKE": "R[a] = R[b][c]",
    "VARARG": "R[a] = V",
    "RETURN": """x = R[a]
        return nativeUnpack(x, 1, x[COUNT])""",
    "CLOSURE": """x = P[F_children][b]
        y = {}
        for d = 1, #x[F_captures] do
            local capture = x[F_captures][d]
            if capture[1] == 0 then
                y[d] = R[capture[2]]
            else
                y[d] = U[capture[2]]
            end
        end
        R[a] = make(x, y, Env)""",
    "JMP": "pc = a",
    "JFALSE": "x = R[a]; R[a] = nil; if not x then pc = b end",
    "JTRUE": "x = R[a]; R[a] = nil; if x then pc = b end",
    "ADD": "R[a] = R[b] + R[c]",
    "SUB": "R[a] = R[b] - R[c]",
    "MUL": "R[a] = R[b] * R[c]",
    "DIV": "R[a] = R[b] / R[c]",
    "MOD": "R[a] = R[b] % R[c]",
    "POW": "R[a] = R[b] ^ R[c]",
    "CONCAT": "R[a] = R[b] .. R[c]",
    "LT": "R[a] = R[b] < R[c]",
    "LE": "R[a] = R[b] <= R[c]",
    "GT": "R[a] = R[b] > R[c]",
    "GE": "R[a] = R[b] >= R[c]",
    "EQ": "R[a] = R[b] == R[c]",
    "NE": "R[a] = R[b] ~= R[c]",
    "NOT": "R[a] = not R[b]",
    "NEG": "R[a] = -R[b]",
    "LEN": "R[a] = #R[b]",
    "FORPREP": """x = nativeTonumber(R[a])
        if x == nil then nativeError("'for' initial value must be a number", 0) end
        R[a] = x
        x = nativeTonumber(R[b])
        if x == nil then nativeError("'for' limit must be a number", 0) end
        R[b] = x
        x = nativeTonumber(R[c])
        if x == nil then nativeError("'for' step must be a number", 0) end
        R[c] = x""",
    "FORCHECK": """if R[d] ~= R[d] then
            R[a] = false
        elseif R[d] > 0 then
            R[a] = R[b] <= R[c]
        else
            R[a] = R[b] >= R[c]
        end""",
    "CALL": """x, y = R[b], R[c]
        if nativeGetfenv and x == nativeGetfenv and (y[COUNT] == 0 or y[1] == nil or y[1] == 1) then
            if d == -1 then
                R[a] = { [COUNT] = 1, Env }
            elseif d == 1 then
                R[a] = Env
            end
        elseif d == -1 then
            R[a] = pack(x(nativeUnpack(y, 1, y[COUNT])))
        elseif d == 1 then
            R[a] = x(nativeUnpack(y, 1, y[COUNT]))
        else
            x(nativeUnpack(y, 1, y[COUNT]))
        end""",
    "TAILCALL": """x, y = R[a], R[b]
        if nativeGetfenv and x == nativeGetfenv and (y[COUNT] == 0 or y[1] == nil or y[1] == 1) then
            return Env
        end
        return x(nativeUnpack(y, 1, y[COUNT]))""",
    "CLEARS": """for x = 1, #a do
            R[a[x]] = nil
        end""",
    "RETURN0": "return",
    "RETURN1": "return R[a]",
    "RETURN2": "return R[a], R[b]",
    "RETURN3": "return R[a], R[b], R[c]",
}


def _call_body(arity):
    args = ", ".join("R[c[%d]]" % i for i in range(1, arity + 1))
    inv = "x(%s)" % args
    icpt = "nativeGetfenv and x == nativeGetfenv" if arity == 0 else \
        "nativeGetfenv and x == nativeGetfenv and (R[c[1]] == nil or R[c[1]] == 1)"
    return ("x = R[b]\nif %s then\n if d == -1 then R[a] = { [COUNT] = 1, Env } elseif d == 1 then R[a] = Env end\n"
            "elseif d == -1 then R[a] = pack(%s) elseif d == 1 then R[a] = %s else %s end") % (icpt, inv, inv, inv)


def _tail_body(arity):
    args = ", ".join("R[b[%d]]" % i for i in range(1, arity + 1))
    icpt = "nativeGetfenv and x == nativeGetfenv" if arity == 0 else \
        "nativeGetfenv and x == nativeGetfenv and (R[b[1]] == nil or R[b[1]] == 1)"
    return "x = R[a]\nif %s then return Env end\nreturn x(%s)" % (icpt, args)


for _n in range(4):
    HANDLERS["CALL%d" % _n] = _call_body(_n)
    HANDLERS["TAILCALL%d" % _n] = _tail_body(_n)

ROLE_NAMES = ["P", "U", "Env", "R", "V", "K", "pc", "a", "b", "c", "d", "code", "I", "opcode"]
TOKEN_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*|\d+(?:\.\d+)?|\.\.|==|~=|<=|>=|\S")


def _tokens(text):
    return TOKEN_RE.findall(text)


def _normalize(stmts, role_of, numbers):
    """Print statements with role names; other locals become `_`."""
    syms = {}
    for n in walk(Chunk(stmts)):
        if isinstance(n, Name) and n.sym is not None:
            syms[n.sym] = n.sym.name
        elif isinstance(n, Local):
            for s in n.syms:
                syms[s] = s.name
        elif isinstance(n, NumFor):
            syms[n.sym] = n.sym.name
        elif isinstance(n, GenFor):
            for s in n.syms:
                syms[s] = s.name
        elif isinstance(n, Func):
            for s in n.params:
                syms[s] = s.name
    for s in syms:
        s.name = role_of.get(s, "_")
    try:
        p = Printer()
        p.block(stmts)
        text = "".join(p.out)
    finally:
        for s, v in syms.items():
            s.name = v
    for k, v in numbers.items():
        text = re.sub(r"(?<![\w.])%s(?![\w.])" % re.escape(_numtext(k)), v, text)
    return _tokens(text)


def _numtext(v):
    if v == int(v):
        return str(int(v))
    return repr(v)


_TEMPLATE_CACHE = {}


def template_tokens():
    if _TEMPLATE_CACHE:
        return _TEMPLATE_CACHE
    for name, body in HANDLERS.items():
        src = ("local P, U, Env, R, V, K, pc, a, b, c, d, x, y, z, nativeIpairs, nativeUnpack, nativeTonumber, "
               "nativeError, nativeGetfenv, pack, make, COUNT, F_children, F_captures\n" + body)
        ch = parse(src)
        decl = ch.body[0]
        role_of = {}
        for s in decl.syms:
            if s.name in ROLE_NAMES:
                role_of[s] = s.name
            elif s.name in ("x", "y", "z"):
                role_of[s] = "_"
            elif s.name in ("COUNT", "F_children", "F_captures"):
                role_of[s] = s.name
            else:
                role_of[s] = "G_" + s.name
        _TEMPLATE_CACHE[name] = _normalize(ch.body[1:], role_of, {})
    return _TEMPLATE_CACHE


# ---------------------------------------------------------- data analysis
def _is_proto_like(t, keyset):
    return isinstance(t, LuaTable) and set(t.hash.keys()) == keyset


def _array(t):
    out = []
    i = 1.0
    while i in t.hash:
        out.append(t.hash[i])
        i += 1.0
    return out


class Layout(object):
    pass


def infer_layout(root):
    keyset = set(root.hash.keys())
    if len(keyset) != 7:
        raise VMError("unexpected prototype shape")
    lay = Layout()
    lay.fields = {}
    children_key = None
    for k in keyset:
        v = root.hash[k]
        if isinstance(v, LuaTable):
            arr = _array(v)
            if arr and all(_is_proto_like(x, keyset) for x in arr):
                children_key = k
    protos = [root]
    if children_key is not None:
        i = 0
        while i < len(protos):
            for ch in _array(protos[i].hash[children_key]):
                protos.append(ch)
            i += 1
    score = {}
    for k in keyset:
        if k == children_key:
            continue
        sc = {"code": 0, "constants": 0, "captures": 0, "params": 0, "vararg": 0, "maxRegister": 0}
        for p in protos:
            v = p.hash.get(k)
            if isinstance(v, bool):
                sc["vararg"] += 1
            elif isinstance(v, float):
                sc["maxRegister"] += 1
            elif isinstance(v, LuaTable):
                for e in _array(v):
                    if not isinstance(e, LuaTable):
                        sc["constants"] += 1
                        continue
                    keys = set(e.hash.keys())
                    second = e.hash.get(2.0)
                    if keys == set([1.0, 2.0]) and isinstance(second, bool):
                        sc["params"] += 3
                    elif keys == set([1.0, 2.0]) and e.hash.get(1.0) in (0.0, 1.0) and isinstance(second, float):
                        sc["captures"] += 1
                        sc["code"] += 0.5
                    elif 1.0 in keys and keys <= set([1.0, 2.0, 3.0, 4.0, 5.0]):
                        sc["code"] += 3
        score[k] = sc
    assigned = {}
    if children_key is not None:
        assigned["children"] = children_key
    for role in ("vararg", "maxRegister", "params", "code", "constants", "captures"):
        best, bv = None, 0
        for k, sc in score.items():
            if k in assigned.values():
                continue
            if sc[role] > bv:
                best, bv = k, sc[role]
        if best is not None:
            assigned[role] = best
    rest = [k for k in keyset if k not in assigned.values()]
    for role in ("children", "code", "constants", "captures", "params", "vararg", "maxRegister"):
        if role not in assigned and rest:
            assigned[role] = rest.pop()
    lay.fields = assigned
    lay.protos = protos
    # operand slots
    singles, pairs, triples, quads = {}, {}, {}, {}
    for p in protos:
        code = p.hash.get(assigned["code"])
        if not isinstance(code, LuaTable):
            continue
        for ins in _array(code):
            ks = frozenset(k for k in ins.hash.keys() if k != 1.0)
            d = {1: singles, 2: pairs, 3: triples, 4: quads}.get(len(ks))
            if d is not None:
                d[ks] = d.get(ks, 0) + 1
    slots = []
    for d in (singles, pairs, triples, quads):
        cands = sorted(d.items(), key=lambda x: -x[1])
        found = None
        for ks, _ in cands:
            if set(slots) <= ks:
                extra = ks - set(slots)
                if len(extra) == 1:
                    found = next(iter(extra))
                    break
        if found is None:
            break
        slots.append(found)
    for s in (2.0, 3.0, 4.0, 5.0):
        if s not in slots and len(slots) < 4:
            slots.append(s)
    lay.slots = slots
    return lay


# ------------------------------------------------------- runtime analysis
def _unparen(e):
    while isinstance(e, Paren):
        e = e.expr
    return e


def find_vm(chunk):
    """Yield (call_node, runtime_func, data_expr) for every VM invocation."""
    for n in walk(chunk):
        if isinstance(n, Call) and len(n.args) >= 1:
            f = _unparen(n.func)
            if isinstance(f, Func) and len(f.params) == 1 and f.vararg:
                first = _unparen(n.args[0])
                if isinstance(first, Call) and len(first.args) == 3 and isinstance(_unparen(first.args[1]), Number):
                    yield n, f, first


def _find_loop(runtime):
    best = None
    for n in walk(Chunk(runtime.body)):
        if isinstance(n, Func) and len(n.params) == 5:
            for m in walk(Chunk(n.body)):
                if isinstance(m, While):
                    best = n
                    break
    if best is None:
        raise VMError("interpreter loop not found")
    return best


def _const(e):
    e = _unparen(e)
    if isinstance(e, Number):
        return e.value
    if isinstance(e, Un) and e.op == "-" and isinstance(e.expr, Number):
        return -e.expr.value
    return None


def analyze_runtime(runtime, lay):
    loop = _find_loop(runtime)
    P, U, Env, R, V = loop.params
    role_of = {P: "P", U: "U", Env: "Env", R: "R", V: "V"}
    field_by_key = dict((v, k) for k, v in lay.fields.items())
    numbers = {}
    for k, v in lay.fields.items():
        numbers[v] = "F_" + k
    # count key: {[COUNT] = select("#", ...), ...}
    for n in walk(Chunk(runtime.body)):
        if isinstance(n, Table):
            for it in n.items:
                if it.key is not None and _const(it.key) is not None and isinstance(_unparen(it.value), Call):
                    c = _unparen(it.value)
                    if c.args and isinstance(_unparen(c.args[0]), String) and _unparen(c.args[0]).value == "#":
                        numbers[_const(it.key)] = "COUNT"
    # names of runtime level locals (nativeUnpack, pack, make, ...)
    for n in walk(Chunk(runtime.body)):
        if isinstance(n, Local) and len(n.exprs) == len(n.syms):
            for s, e in zip(n.syms, n.exprs):
                e = _unparen(e)
                g = None
                if isinstance(e, Name) and e.sym is None:
                    g = e.name
                elif isinstance(e, Bin) and e.op == "or" and isinstance(_unparen(e.left), Name) and \
                        _unparen(e.left).sym is None:
                    g = _unparen(e.left).name
                if g == "getfenv":
                    role_of[s] = "G_nativeGetfenv"
                elif g == "unpack":
                    role_of[s] = "G_nativeUnpack"
                elif g == "tonumber":
                    role_of[s] = "G_nativeTonumber"
                elif g == "error":
                    role_of[s] = "G_nativeError"
                elif g == "ipairs":
                    role_of[s] = "G_nativeIpairs"
                elif g == "select":
                    role_of[s] = "G_select"
                elif g == "setfenv":
                    role_of[s] = "G_setfenv"
    for n in walk(Chunk(runtime.body)):
        if isinstance(n, LocalFunc) or (isinstance(n, Local) and len(n.exprs) == 1 and isinstance(n.exprs[0], Func)):
            sym = n.sym if isinstance(n, LocalFunc) else n.syms[0]
            f = n.func if isinstance(n, LocalFunc) else n.exprs[0]
            if f.vararg and not f.params and len(f.body) == 1 and isinstance(f.body[0], Return):
                role_of[sym] = "G_pack"
            elif len(f.params) == 3:
                role_of[sym] = "G_make"
        if isinstance(n, Assign) and len(n.targets) == 1 and isinstance(n.targets[0], Name) and \
                n.targets[0].sym is not None and isinstance(n.exprs[0], Func) and len(n.exprs[0].params) == 3:
            role_of[n.targets[0].sym] = "G_make"
    # loop locals: K, code, pc, I, opcode, operands
    defs = []
    for n in walk(Chunk(loop.body)):
        if isinstance(n, Local):
            for i, s in enumerate(n.syms):
                if i < len(n.exprs):
                    defs.append((s, n.exprs[i]))
        elif isinstance(n, Assign):
            for i, t in enumerate(n.targets):
                if isinstance(t, Name) and t.sym is not None and i < len(n.exprs) and len(n.exprs) == len(n.targets):
                    defs.append((t.sym, n.exprs[i]))
    code_sym = I_sym = op_sym = pc_sym = None
    slot_syms = {}
    for s, e in defs:
        e = _unparen(e)
        if isinstance(e, Index) and isinstance(e.obj, Name) and e.obj.sym is P:
            k = _const(e.key)
            if k == lay.fields.get("constants"):
                role_of[s] = "K"
            elif k == lay.fields.get("code"):
                code_sym = s
                role_of[s] = "code"
    for s, e in defs:
        e = _unparen(e)
        if isinstance(e, Index) and isinstance(e.obj, Name) and e.obj.sym is code_sym and isinstance(e.key, Name):
            I_sym = s
            pc_sym = e.key.sym
    if I_sym is None:
        raise VMError("instruction fetch not found")
    role_of[I_sym] = "I"
    role_of[pc_sym] = "pc"
    for s, e in defs:
        e = _unparen(e)
        if isinstance(e, Index) and isinstance(e.obj, Name) and e.obj.sym is I_sym:
            k = _const(e.key)
            if k == 1:
                op_sym = s
                role_of[s] = "opcode"
            elif k is not None:
                slot_syms[k] = s
    if op_sym is None:
        raise VMError("opcode fetch not found")
    for i, slot in enumerate(lay.slots):
        if slot in slot_syms:
            role_of[slot_syms[slot]] = "abcd"[i]
    # handlers: if opcode == N then BODY
    handlers = {}
    for n in walk(Chunk(loop.body)):
        if isinstance(n, If):
            c = _unparen(n.cond)
            if isinstance(c, Bin) and c.op == "==":
                l, r = _unparen(c.left), _unparen(c.right)
                if isinstance(l, Name) and l.sym is op_sym and _const(r) is not None:
                    handlers[_const(r)] = n.body
                elif isinstance(r, Name) and r.sym is op_sym and _const(l) is not None:
                    handlers[_const(l)] = n.body
    if len(handlers) < 40:
        raise VMError("dispatch tree not recognised (%d handlers)" % len(handlers))
    templates = template_tokens()
    scores = []
    for opid, body in handlers.items():
        toks = _normalize(body, role_of, numbers)
        for name, tt in templates.items():
            r = difflib.SequenceMatcher(None, toks, tt, autojunk=False).ratio()
            scores.append((r, opid, name))
    scores.sort(key=lambda x: -x[0])
    opmap, used = {}, set()
    for r, opid, name in scores:
        if opid in opmap or name in used:
            continue
        opmap[opid] = name
        used.add(name)
    return opmap


# --------------------------------------------------------------- lifting
class ProtoLifter(object):
    def __init__(self, vmd, proto, upvals, is_main):
        self.vmd = vmd
        self.proto = proto
        self.upvals = upvals
        self.is_main = is_main
        self.regs = {}
        f = vmd.lay.fields
        self.code = [self.decode(i) for i in _array(proto.hash[f["code"]])]
        self.K = _array(proto.hash[f["constants"]]) if isinstance(proto.hash.get(f["constants"]), LuaTable) else []
        kt = proto.hash.get(f["constants"])
        self.Kmap = kt.hash if isinstance(kt, LuaTable) else {}
        self.children = _array(proto.hash[f["children"]]) if isinstance(proto.hash.get(f["children"]), LuaTable) \
            else []
        self.params = _array(proto.hash[f["params"]]) if isinstance(proto.hash.get(f["params"]), LuaTable) else []
        self.vararg = bool(proto.hash.get(f["vararg"])) or is_main
        self.param_syms = []
        for i in range(len(self.params)):
            s = Symbol("a%d" % (i + 1))
            s.attrs["param"] = True
            self.param_syms.append(s)
        self.extra = 0

    def decode(self, ins):
        op = self.vmd.opmap.get(ins.hash.get(1.0))
        if op is None:
            raise VMError("unknown opcode %r" % ins.hash.get(1.0))
        ops = [ins.hash.get(s) for s in self.vmd.lay.slots]
        return [op] + ops

    def R(self, n):
        if isinstance(n, float):
            n = int(n)
        if n not in self.regs:
            s = Symbol("R%s" % (n,))
            s.attrs["reg"] = True
            self.regs[n] = s
        s = self.regs[n]
        return Name(s.name, s)

    def tmp(self):
        self.extra += 1
        return self.R("t%d" % self.extra)

    def k(self, i):
        v = self.Kmap.get(float(i))
        if v is None:
            return Nil()
        if isinstance(v, bool):
            return Bool(v)
        if isinstance(v, float):
            return Number(v)
        if isinstance(v, str):
            return String(v)
        raise VMError("bad constant")

    def lift(self):
        code = self.code
        n = len(code)
        leaders = set([1])
        for pc, ins in enumerate(code, 1):
            op = ins[0]
            if op == "JMP":
                leaders.add(int(ins[1]))
                leaders.add(pc + 1)
            elif op in ("JTRUE", "JFALSE"):
                leaders.add(int(ins[2]))
                leaders.add(pc + 1)
            elif op.startswith("RETURN") or op.startswith("TAILCALL"):
                leaders.add(pc + 1)
        # generic-for headers are handled as a unit: find CALL2 .. JTRUE patterns
        self.genfor = {}
        self.skip = set()
        for pc in range(1, n + 1):
            g = self.match_genfor(pc)
            if g:
                self.genfor[pc] = g
                leaders.add(pc)
                leaders.add(g["next"])
        starts = sorted(x for x in leaders if 1 <= x <= n)
        blocks = {}
        entry_stmts = []
        for i, p in enumerate(self.params):
            reg, captured = int(p.hash.get(1.0)), p.hash.get(2.0)
            ps = self.param_syms[i]
            if captured:
                entry_stmts.append(Assign([self.R(reg)], [AllocCell()]))
                entry_stmts.append(Assign([CellRef(self.R(reg))], [Name(ps.name, ps)]))
            else:
                entry_stmts.append(Assign([self.R(reg)], [Name(ps.name, ps)]))
        for bi, start in enumerate(starts):
            end = starts[bi + 1] - 1 if bi + 1 < len(starts) else n
            stmts = []
            term = None
            pc = start
            while pc <= end:
                if pc in self.skip:
                    pc += 1
                    continue
                if pc in self.genfor:
                    g = self.genfor[pc]
                    stmts.extend(g["stmts"])
                    term = g["term"]
                    break
                ins = code[pc - 1]
                r = self.lift_ins(ins, pc, stmts)
                if r is not None:
                    term = r
                    break
                pc += 1
            if term is None:
                term = ("goto", end + 1) if end + 1 <= n else ("ret", [])
            if start == 1:
                stmts = entry_stmts + stmts
            blocks[start] = Block(start, stmts, term)
        if 1 not in blocks:
            blocks[1] = Block(1, entry_stmts, ("ret", []))
        return IRFunc(1, blocks, self.param_syms, self.vararg, self.upvals)

    def match_genfor(self, pc):
        code = self.code
        n = len(code)
        if pc + 4 > n:
            return None
        c = code[pc - 1]
        if c[0] != "CALL2" or c[4] != -1:
            return None
        t, nl, eq, jt = code[pc], code[pc + 1], code[pc + 2], code[pc + 3]
        res = c[1]
        if not (t[0] == "TAKE" and t[2] == res and t[3] == 1 and nl[0] in ("NIL", "CLEAR") and eq[0] == "EQ" and
                eq[2] == t[1] and eq[3] == nl[1] and jt[0] == "JTRUE" and jt[1] == eq[1]):
            return None
        mv = code[pc + 3] if False else (code[pc + 4] if pc + 4 < n else None)
        if mv is None or mv[0] != "MOVE" or mv[2] != t[1]:
            return None
        control = mv[1]
        it_reg, (state_reg, ctl_reg) = c[2], (c[3].hash.get(1.0), c[3].hash.get(2.0))
        if ctl_reg != control:
            return None
        # following TAKEs from the results tuple
        takes = {}
        q = pc + 5
        while q <= n and code[q - 1][0] in ("TAKE", "MOVE", "CELL", "CLEAR", "CLEARS"):
            ins = code[q - 1]
            if ins[0] == "TAKE" and ins[2] == res:
                takes[int(ins[3])] = q
            if ins[0] == "CLEARS" and res in _array(ins[1]):
                break
            if ins[0] != "CLEARS" and ins[1] == res:
                break
            q += 1
        nvals = max(takes) if takes else 1
        extra = {}
        targets = [self.R(control)]
        for i in range(2, nvals + 1):
            extra[i] = self.R("g%d_%d" % (pc, i))
            targets.append(extra[i])
        stmts = [Assign(targets, [Call(self.R(it_reg), [self.R(state_reg), self.R(control)])])]
        term = ("cond", Bin("==", self.R(control), Nil()), int(jt[2]), pc + 5)
        self.genfor_takes = getattr(self, "genfor_takes", {})
        for i, qq in takes.items():
            self.genfor_takes[qq] = (i, extra.get(i), control)
        self.skip.add(pc + 5)
        return {"stmts": stmts, "term": term, "next": pc + 5}

    def lift_ins(self, ins, pc, out):
        op, a, b, c, d = ins[0], ins[1], ins[2], ins[3], ins[4]
        R = self.R
        A = Assign
        if op in ("LOAD",):
            out.append(A([R(a)], [self.k(b)]))
        elif op in ("NIL", "CLEAR"):
            out.append(A([R(a)], [Nil()]))
        elif op == "CLEARS":
            for r in _array(a):
                out.append(A([R(r)], [Nil()]))
        elif op == "MOVE":
            out.append(A([R(a)], [R(b)]))
        elif op == "CELL":
            src = R(b) if b else Nil()
            t = self.tmp()
            out.append(A([t], [src]))
            out.append(A([R(a)], [AllocCell()]))
            out.append(A([CellRef(R(a))], [Name(t.name, t.sym)]))
        elif op == "GETCELL":
            out.append(A([R(a)], [CellRef(R(b))]))
        elif op == "SETCELL":
            out.append(A([CellRef(R(a))], [R(b)]))
        elif op == "GETUP":
            out.append(A([R(a)], [CellRef(UpvalRef(int(b) - 1))]))
        elif op == "SETUP":
            out.append(A([CellRef(UpvalRef(int(a) - 1))], [R(b)]))
        elif op == "GLOBAL":
            out.append(A([R(a)], [Index(self.vmd.env_name(), self.k(b))]))
        elif op == "SETGLOBAL":
            out.append(A([Index(self.vmd.env_name(), self.k(a))], [R(b)]))
        elif op == "GETTABLE":
            out.append(A([R(a)], [Index(R(b), R(c))]))
        elif op == "SETTABLE":
            out.append(A([Index(R(a), R(b))], [R(c)]))
        elif op == "TABLE":
            out.append(A([R(a)], [Table([])]))
        elif op == "EXPAND":
            out.append(CallStat(Call(Name(EXPAND.name, EXPAND), [R(a), Number(float(b)), Spread(R(c))])))
        elif op == "ARGS":
            es = [R(r) for r in _array(b)]
            if c:
                es.append(Spread(R(c)))
            out.append(A([R(a)], [TupleE(es)]))
        elif op == "TAKE":
            gt = getattr(self, "genfor_takes", {}).get(pc)
            if gt is not None:
                i, extra, control = gt
                out.append(A([R(a)], [R(control) if i == 1 else extra]))
            else:
                out.append(A([R(a)], [Index(R(b), Number(float(c)))]))
        elif op == "VARARG":
            out.append(A([R(a)], [TupleE([Vararg()])]))
        elif op in ("CALL", "CALL0", "CALL1", "CALL2", "CALL3"):
            if op == "CALL":
                args = [Spread(R(c))]
            else:
                args = [R(r) for r in _array(c)]
            call = Call(R(b), args)
            if d == -1:
                out.append(A([R(a)], [TupleE([call])]))
            elif d == 1:
                out.append(A([R(a)], [call]))
            else:
                out.append(CallStat(call))
        elif op == "TAILCALL":
            return ("ret", [Call(R(a), [Spread(R(b))])])
        elif op.startswith("TAILCALL"):
            return ("ret", [Call(R(a), [R(r) for r in _array(b)])])
        elif op == "RETURN":
            return ("ret", [Spread(R(a))])
        elif op == "RETURN0":
            return ("ret", [])
        elif op == "RETURN1":
            return ("ret", [R(a)])
        elif op == "RETURN2":
            return ("ret", [R(a), R(b)])
        elif op == "RETURN3":
            return ("ret", [R(a), R(b), R(c)])
        elif op == "CLOSURE":
            child = self.children[int(b) - 1]
            caps = _array(child.hash[self.vmd.lay.fields["captures"]])
            ups = []
            for cp in caps:
                kind, idx = cp.hash.get(1.0), int(cp.hash.get(2.0))
                ups.append(R(idx) if kind == 0 else UpvalRef(idx - 1))
            ce = ClosureE(ups)
            ce.proto = child
            out.append(A([R(a)], [ce]))
        elif op == "JMP":
            return ("goto", int(a))
        elif op in ("JFALSE", "JTRUE"):
            t = self.tmp()
            out.append(A([t], [R(a)]))
            out.append(A([R(a)], [Nil()]))
            if op == "JFALSE":
                return ("cond", Name(t.name, t.sym), pc + 1, int(b))
            return ("cond", Name(t.name, t.sym), int(b), pc + 1)
        elif op in BINOPS:
            out.append(A([R(a)], [Bin(BINOPS[op], R(b), R(c))]))
        elif op == "NOT":
            out.append(A([R(a)], [Un("not", R(b))]))
        elif op == "NEG":
            out.append(A([R(a)], [Un("-", R(b))]))
        elif op == "LEN":
            out.append(A([R(a)], [Un("#", R(b))]))
        elif op == "FORPREP":
            for r, what in ((a, "initial value"), (b, "limit"), (c, "step")):
                out.append(A([R(r)], [Bin("or", Call(Name("tonumber", None), [R(r)]),
                                           Call(Name("error", None), [String("'for' %s must be a number" % what),
                                                                      Number(0.0)]))]))
        elif op == "FORCHECK":
            out.append(A([R(a)], [ForCheck(R(b), R(c), R(d))]))
        else:
            raise VMError("unsupported opcode %s" % op)
        return None


class ForCheck(Expr):
    """Numeric for continuation test (pure)."""
    fields = ("i", "limit", "step")


BINOPS = {"ADD": "+", "SUB": "-", "MUL": "*", "DIV": "/", "MOD": "%", "POW": "^", "CONCAT": "..",
          "LT": "<", "LE": "<=", "GT": ">", "GE": ">=", "EQ": "==", "NE": "~="}


class VMDecompiler(object):
    def __init__(self, lay, opmap):
        self.lay = lay
        self.opmap = opmap
        self.env_sym = Symbol("_ENV")
        self.env_sym.attrs["mem"] = True
        self.env_sym.attrs["env"] = True
        self.count = [0]

    def env_name(self):
        return Name(self.env_sym.name, self.env_sym)

    def new_var(self, reg):
        self.count[0] += 1
        s = Symbol("v%d" % self.count[0])
        s.attrs["var"] = True
        return s

    def new_cell(self):
        self.count[0] += 1
        s = Symbol("c%d" % self.count[0])
        s.attrs["mem"] = True
        return s

    def lift_proto(self, proto, upvals, is_main=False):
        pl = ProtoLifter(self, proto, upvals, is_main)
        fn = pl.lift()
        body = decompile(fn, self)
        return Func(pl.param_syms, pl.vararg, body)

    def lower_closure(self, ce):
        ups = []
        for u in ce.upvals:
            if isinstance(u, Name) and u.sym is not None:
                ups.append(u.sym)
            else:
                ups.append(self.new_cell())
        return self.lift_proto(ce.proto, ups)


def decompile(fn, vmd):
    ir.reachable(fn)
    ir.resolve_cells(fn, vmd.new_cell)
    ir.split_webs(fn, vmd.new_var)
    ir.optimize(fn)
    live = ir.liveness(fn)
    try:
        body = ir.Structurer(fn).run()
    except StructError as ex:
        import os, sys
        if os.environ.get("DEOBF_DEBUG"):
            sys.stderr.write("[deobf] structuring failed: %s\n" % ex)
        body = ir.fallback_dispatch(fn, lambda _: vmd.new_var(None))
    syms = set()
    for x in ir._walk_all(body):
        if isinstance(x, Name) and x.sym is not None and x.sym.attrs.get("var"):
            syms.add(x.sym)

    def fix(n):
        if isinstance(n, ClosureE):
            return vmd.lower_closure(n)
        return None
    body = [transform(s, fix) for s in body]
    ir.declare_locals(body, syms, live)
    body = ir.lower_pseudo(body)
    body = recover_vm_constructs(body)
    return body


# ------------------------------------------------------- VM specific cleanup
def recover_vm_constructs(body):
    """Numeric for loops, table constructors and leftover pseudo nodes."""
    from .cleanup import strip_for_checks, assigned, refs_in, subst_sym

    def lists(node):
        for n in walk(node):
            for f in ("body", "orelse"):
                v = getattr(n, f, None)
                if isinstance(v, list):
                    yield v

    root = Chunk(body)
    for lst in list(lists(root)):
        i = 0
        while i < len(lst):
            s = lst[i]
            if isinstance(s, While) and isinstance(s.cond, ForCheck) and s.body:
                fc = s.cond
                if all(isinstance(x, Name) and x.sym is not None for x in (fc.i, fc.limit, fc.step)):
                    iv, lim, st = fc.i.sym, fc.limit.sym, fc.step.sym
                    last = s.body[-1]
                    if isinstance(last, Assign) and len(last.targets) == 1 and \
                            isinstance(last.targets[0], Name) and last.targets[0].sym is iv and \
                            isinstance(last.exprs[0], Bin) and last.exprs[0].op == "+":
                        inner = s.body[:-1]
                        defs = {}
                        for j in range(i - 1, max(-1, i - 8), -1):
                            d = lst[j]
                            if isinstance(d, (Local, Assign)) and len(d.exprs) == 1:
                                tg = d.syms[0] if isinstance(d, Local) else (
                                    d.targets[0].sym if isinstance(d.targets[0], Name) else None)
                                if tg in (iv, lim, st) and tg not in defs:
                                    v, msg = strip_for_checks(d.exprs[0])
                                    if v is not None:
                                        defs[tg] = (j, v)
                        ok = len(defs) == 3 and not (assigned(Chunk(inner)) & set([iv, lim, st])) and \
                            not any(x in refs_in(lst[i + 1:]) for x in (iv, lim, st))
                        if ok:
                            if inner and isinstance(inner[0], Local) and len(inner[0].syms) == 1 and \
                                    len(inner[0].exprs) == 1 and isinstance(inner[0].exprs[0], Name) and \
                                    inner[0].exprs[0].sym is iv:
                                var = inner[0].syms[0]
                                inner = inner[1:]
                            else:
                                var = Symbol("i")
                            inner = [subst_sym(x, iv, var) for x in inner]
                            if True:
                                step = defs[st][1]
                                if isinstance(step, Number) and step.value == 1:
                                    step = None
                                lst[i] = NumFor(var, defs[iv][1], defs[lim][1], step, inner)
                                for j in sorted((defs[iv][0], defs[lim][0], defs[st][0]), reverse=True):
                                    del lst[j]
                                    i -= 1
            i += 1
    # table constructors: local t = {} ; t[k] = v ... ; __expand(t, n, ...)
    for lst in list(lists(root)):
        i = 0
        while i < len(lst):
            s = lst[i]
            if isinstance(s, (Local, Assign)) and len(s.exprs) == 1 and isinstance(s.exprs[0], Table) and \
                    (len(s.syms) == 1 if isinstance(s, Local) else
                     (len(s.targets) == 1 and isinstance(s.targets[0], Name))):
                tsym = s.syms[0] if isinstance(s, Local) else s.targets[0].sym
                tbl = s.exprs[0]
                pos = 1 + sum(1 for it in tbl.items if it.key is None)
                j = i + 1
                while j < len(lst):
                    t = lst[j]
                    if isinstance(t, Assign) and len(t.targets) == 1 and isinstance(t.targets[0], Index) and \
                            isinstance(t.targets[0].obj, Name) and t.targets[0].obj.sym is tsym and \
                            not refs_in([t.targets[0].key] + t.exprs).get(tsym) and len(t.exprs) == 1:
                        tbl.items.append(TItem(t.targets[0].key, t.exprs[0]))
                        j += 1
                        continue
                    if isinstance(t, CallStat) and isinstance(t.call, Call) and isinstance(t.call.func, Name) and \
                            t.call.func.sym is EXPAND and \
                            isinstance(t.call.args[0], Name) and t.call.args[0].sym is tsym and \
                            isinstance(t.call.args[1], Number) and int(t.call.args[1].value) == pos and \
                            not refs_in(t.call.args[2:]).get(tsym):
                        vals = t.call.args[2:]
                        for v in vals:
                            tbl.items.append(TItem(None, v))
                        pos += len(vals)
                        j += 1
                        continue
                    break
                if j > i + 1:
                    del lst[i + 1:j]
            i += 1

    def fix(n):
        if isinstance(n, ForCheck):
            return Bin("or", Bin("and", Bin(">", n.step, Number(0.0)), Bin("<=", n.i, n.limit)),
                       Bin("and", Bin("<=", ir.clone(n.step), Number(0.0)), Bin(">=", ir.clone(n.i),
                                                                                   ir.clone(n.limit))))
        return None
    out = []
    for s in root.body:
        out.append(_expand_fallback(transform(s, lambda n: fix(n) if isinstance(n, ForCheck) else None)))
    return out


def _expand_fallback(s):
    """Turn remaining __expand(t, n, values...) statements into explicit assignments."""
    def fn(n):
        for f in ("body", "orelse"):
            v = getattr(n, f, None)
            if isinstance(v, list):
                new = []
                for x in v:
                    if isinstance(x, CallStat) and isinstance(x.call, Call) and isinstance(x.call.func, Name) and \
                            x.call.func.sym is EXPAND:
                        base, start, vals = x.call.args[0], x.call.args[1], x.call.args[2:]
                        if not vals or not ir.is_multi(vals[-1]):
                            new.append(Assign([Index(ir.clone(base), Number(start.value + i)) for i in range(len(vals))],
                                              vals))
                            continue
                        # local p = pack(values); for i = 1, p.n do t[start + i - 1] = p[i] end
                        p, i = Symbol("p"), Symbol("i")
                        packer = Func([], True, [Return([Table([TItem(String("n"), Call(Name("select", None), [
                            String("#"), Vararg()])), TItem(None, Vararg())])])])
                        body = [Local([p], [Call(Paren(packer), vals)]),
                                NumFor(i, Number(1.0), Index(Name(p.name, p), String("n")), None, [
                                    Assign([Index(ir.clone(base), Bin("+", Number(start.value - 1), Name(i.name, i)))],
                                           [Index(Name(p.name, p), Name(i.name, i))])])]
                        new.append(Do(body))
                    else:
                        new.append(x)
                setattr(n, f, new)
        return None
    wrapper = Do([s])
    transform(wrapper, fn)
    return wrapper.body[0] if len(wrapper.body) == 1 else Do(wrapper.body)


# ------------------------------------------------------------------ driver
def _emulate_value(chunk, expr):
    """Evaluate `expr` (the data reconstruction call) in the sandbox."""
    emu = Emulator(budget=50000000)
    scope = Scope()
    for s in chunk.body:
        if isinstance(s, Return):
            break
        try:
            emu.steps = 0
            emu.exec_block([s], scope, None)
        except Exception:
            continue
    emu.steps = 0
    return emu.eval(expr, scope, None)


def devirtualize(chunk):
    done = 0
    envs = set()
    for call, runtime, data_call in list(find_vm(chunk)):
        try:
            root = _emulate_value(chunk, data_call)
            if not isinstance(root, LuaTable):
                continue
            if len(root.hash) == 1 and isinstance(root.hash.get(1.0), LuaTable):
                root = root.hash[1.0]
            lay = infer_layout(root)
            opmap = analyze_runtime(runtime, lay)
            vmd = VMDecompiler(lay, opmap)
            main = vmd.lift_proto(root, [], is_main=True)
        except (VMError, EmuAbort, LuaError, StructError) as ex:
            import os
            import sys
            if os.environ.get("DEOBF_DEBUG"):
                sys.stderr.write("[deobf] VM not devirtualized (yet): %s\n" % ex)
            continue
        call.func = Paren(main)
        call.args = [Vararg()]
        envs.add(vmd.env_sym)
        done += 1
    return done, envs
