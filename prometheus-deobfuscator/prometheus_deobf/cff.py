"""Undo Prometheus' `Cff` step (control-flow flattening into a block dispatcher).

The flattened program looks like::

    return (function(<11 shuffled runtime params>, <helpers...>)
        helpers... = <callFunction>, <pack>, <unpack>, <container>, <closure makers>, ...
        return (CLOSURE_VARARG(startBlock, {...}, ENV))(UNPACK(args))
    end)(<getfenv and getfenv() or _ENV>, <unpack or table.unpack>, newproxy, ...)

`container(pos, args, upvals, proxy, env)` holds `while pos do <binary search
over block ids> end`.  Each block is straight-line code over local "registers"
that ends by assigning the next block id to `pos`.

This module recognises every helper by its *shape* (names/order are random),
lifts each original function into the register IR (see ir.py) and lets the IR
backend rebuild structured Lua.
"""

from .luaast import (Symbol, Nil, Bool, Number, String, Vararg, Name, Index, Call, Method, Func, Table, TItem, Bin,
                     Un, Paren, Local, Assign, CallStat, Do, While, Repeat, If, NumFor, GenFor, LocalFunc, FuncStat,
                     Return, Break, Chunk, Node, transform, walk)
from . import ir
from .ir import TupleE, Spread, CellRef, AllocCell, ClosureE, UpvalRef, IRFunc, Block, StructError


class CffError(Exception):
    pass


RET_BLOCK = -1  # synthetic block: `return unpack(ret)`


def unparen(e):
    while isinstance(e, Paren):
        e = e.expr
    return e


def _contains(node, cls):
    for x in walk(node):
        if isinstance(x, cls):
            return True
    return False


def is_name(e, sym=None):
    return isinstance(e, Name) and (sym is None or e.sym is sym)


# ------------------------------------------------------------ recognition
class Framework(object):
    pass


def classify_arg(a):
    a = unparen(a)
    if isinstance(a, Table) and a.items and a.items[-1].key is None and isinstance(a.items[-1].value, Vararg):
        return "ARGS"
    if isinstance(a, Bin) and a.op == "or":
        l = unparen(a.left)
        if isinstance(l, Bin) and l.op == "and":
            return "ENV"
        if isinstance(l, Name) and l.sym is None and l.name == "unpack":
            return "UNPACK"
    if isinstance(a, Name) and a.sym is None:
        return a.name.upper()
    return None


def _func_of(stmt):
    """The function literal bound by `local f = function ... end` / `local function f ... end`."""
    if isinstance(stmt, LocalFunc):
        return stmt.func
    if isinstance(stmt, Local) and len(stmt.exprs) == 1 and isinstance(unparen(stmt.exprs[0]), Func):
        return unparen(stmt.exprs[0])
    return None


def classify_helper(e, fw):
    e = unparen(e)
    if isinstance(e, Table) and not e.items:
        return "EMPTY"
    if isinstance(e, Number):
        return "COUNTER"
    if not isinstance(e, Func):
        return None
    np = len(e.params)
    body = e.body
    if np in (4, 5) and _contains(Chunk(body), While):
        return "CONTAINER"
    if np == 0 and e.vararg and len(body) == 1 and isinstance(body[0], Return) and \
            len(body[0].exprs) == 1 and isinstance(unparen(body[0].exprs[0]), Table):
        return "PACK"
    if np == 1 and not e.vararg and len(body) == 1 and isinstance(body[0], Return) and len(body[0].exprs) == 1:
        c = unparen(body[0].exprs[0])
        if isinstance(c, Call) and len(c.args) == 3 and is_name(c.args[0], e.params[0]):
            return "UNPACKPACKED"
    if np == 2 and e.vararg and body and isinstance(body[-1], Return) and len(body[-1].exprs) == 1:
        c = unparen(body[-1].exprs[0])
        if isinstance(c, Call) and is_name(c.func, e.params[0]):
            return "CALLFN"
    if np in (2, 3) and len(body) >= 3 and isinstance(body[0], Local) and _func_of(body[1]) is not None:
        inner = _func_of(body[1])
        pf = unparen(body[0].exprs[0]) if body[0].exprs else None
        if isinstance(pf, Call) and isinstance(pf.func, Name):
            fw.proxyfn_candidates.add(pf.func.sym)
        return ("CLOSURE", None if inner.vararg else len(inner.params))
    if np == 0 and not e.vararg:
        return "ALLOC"
    if np == 1:
        if _contains(Chunk(body), NumFor):
            return "PROXYFN"
        if _contains(Chunk(body), While):
            return "GCFN"
        return "FREE"
    return None


def match_framework(call):
    if not isinstance(call, Call):
        return None
    f = unparen(call.func)
    if not isinstance(f, Func) or f.vararg or len(f.params) < 16 or len(call.args) < 6:
        return None
    body = f.body
    if len(body) != 2 or not isinstance(body[0], Assign) or not isinstance(body[1], Return):
        return None
    fw = Framework()
    fw.call = call
    fw.roles = {}
    fw.sym_role = {}
    fw.proxyfn_candidates = set()
    for p, a in zip(f.params, call.args):
        r = classify_arg(a)
        if r:
            fw.sym_role[p] = r
            fw.roles.setdefault(r, p)
    helpers = {}
    for t, e in zip(body[0].targets, body[0].exprs):
        if not is_name(t) or t.sym is None:
            return None
        r = classify_helper(e, fw)
        if r is None:
            return None
        helpers[t.sym] = (r, unparen(e))
    fw.closures = {}
    empties = []
    for sym, (r, e) in helpers.items():
        if isinstance(r, tuple):
            fw.closures[sym] = r[1]
        elif r == "EMPTY":
            empties.append(sym)
        else:
            fw.roles[r] = sym
            fw.sym_role[sym] = r
            if r == "CONTAINER":
                fw.container = e
            if r == "ALLOC":
                fw.alloc_fn = e
    if "CONTAINER" not in fw.roles or "ALLOC" not in fw.roles:
        return None
    # Older Prometheus (WeAreDevs): container(pos, args, upvals, proxy), plain `{...}` tuples and
    # `unpack(t)`; no pack / unpackPacked / callFunction helpers and no environment parameter.
    fw.legacy = len(fw.container.params) == 4
    if not fw.legacy:
        for need in ("PACK", "UNPACKPACKED", "CALLFN"):
            if need not in fw.roles:
                return None
    elif "UNPACK" not in fw.roles:
        return None
    # upvalue table vs. reference count table: ALLOC writes RC[id] = 1
    rc = None
    for s in fw.alloc_fn.body:
        if isinstance(s, Assign) and isinstance(s.targets[0], Index) and is_name(s.targets[0].obj):
            rc = s.targets[0].obj.sym
    ups = [s for s in empties if s is not rc]
    if len(ups) != 1:
        return None
    fw.upvals_table = ups[0]
    fw.proxyfn = None
    for s in fw.proxyfn_candidates:
        fw.proxyfn = s
    if "PROXYFN" in fw.roles:
        fw.proxyfn = fw.roles["PROXYFN"]
    # start call
    ret = body[1]
    if len(ret.exprs) != 1:
        return None
    sc = unparen(ret.exprs[0])
    if not isinstance(sc, Call):
        return None
    mk = unparen(sc.func)
    if not (isinstance(mk, Call) and is_name(mk.func) and mk.func.sym in fw.closures and
            isinstance(unparen(mk.args[0]), Number)):
        return None
    fw.start = unparen(mk.args[0]).value
    fw.start_upvals = unparen(mk.args[1]).items if isinstance(unparen(mk.args[1]), Table) else []
    return fw


# -------------------------------------------------------------- container
class Container(object):
    def __init__(self, fw):
        c = fw.container
        self.fw = fw
        if fw.legacy:
            self.pos, self.args, self.upvalsp, self.gcproxy = c.params
            self.envp = None
        else:
            self.pos, self.args, self.upvalsp, self.gcproxy, self.envp = c.params
        body = c.body
        self.overflow = None
        self.regs = set()
        self.ret = None
        loop = None
        for s in body:
            if isinstance(s, Local):
                if len(s.syms) == 1 and len(s.exprs) == 1 and isinstance(unparen(s.exprs[0]), Table):
                    self.overflow = s.syms[0]
                else:
                    self.regs.update(s.syms)
            elif isinstance(s, While):
                loop = s
            elif isinstance(s, Return):
                c2 = unparen(s.exprs[0])
                if isinstance(c2, Call) and c2.args and is_name(c2.args[0]):
                    self.ret = c2.args[0].sym
        if loop is None or self.ret is None:
            raise CffError("container layout not recognised")
        self.regs.discard(self.ret)
        self.tree = loop.body

    def pos_compare(self, cond):
        """Return (lt_bound) meaning: branch taken when pos < bound, or (gt_bound) ..."""
        c = unparen(cond)
        if not isinstance(c, Bin):
            return None
        l, r = unparen(c.left), unparen(c.right)
        if c.op == "<" and is_name(l, self.pos) and isinstance(r, Number):
            return ("lt", r.value)
        if c.op == ">" and isinstance(l, Number) and is_name(r, self.pos):
            return ("lt", l.value)
        if c.op == ">" and is_name(l, self.pos) and isinstance(r, Number):
            return ("gt", r.value)
        if c.op == "<" and isinstance(l, Number) and is_name(r, self.pos):
            return ("gt", l.value)
        return None

    def lookup(self, bid):
        stmts = self.tree
        while len(stmts) == 1 and isinstance(stmts[0], If):
            cmp = self.pos_compare(stmts[0].cond)
            if cmp is None:
                break
            kind, bound = cmp
            take = bid < bound if kind == "lt" else bid > bound
            stmts = stmts[0].body if take else stmts[0].orelse
        return stmts


# ------------------------------------------------------------ the lifter
class FuncLifter(object):
    def __init__(self, lifter, entry, upvals, arity, is_main=False):
        self.L = lifter
        self.c = lifter.container
        self.fw = lifter.fw
        self.entry = entry
        self.upvals = upvals
        self.arity = arity
        self.is_main = is_main
        self.regmap = {}
        self.params = {}
        self.vararg = is_main or arity is None
        self.nparams_vararg = 0
        self.ret_sym = self.new_reg("ret")
        self.pos_reg = self.new_reg("pos")   # legacy frameworks also use `pos` as a scratch register
        self.pos_written = False

    def new_reg(self, hint):
        s = Symbol("r_%s" % hint)
        s.attrs["reg"] = True
        return s

    def reg(self, key):
        if key not in self.regmap:
            self.regmap[key] = self.new_reg(key if isinstance(key, str) else key[1] if isinstance(key, tuple)
                                            else key.name)
        return self.regmap[key]

    def param(self, i):
        if i not in self.params:
            s = Symbol("a%d" % i)
            s.attrs["param"] = True
            self.params[i] = s
        return self.params[i]

    # --------------------------------------------------------- expressions
    def tr(self, e, bid):
        fw, c = self.fw, self.c
        t = type(e)
        if t is Paren:
            inner = self.tr(e.expr, bid)
            return Paren(inner) if not isinstance(inner, (TupleE, Spread)) else inner
        if t is Name:
            s = e.sym
            if s is None:
                return Name(e.name, None)
            if s is c.pos:
                if self.pos_written:
                    return Name(self.pos_reg.name, self.pos_reg)
                return Number(float(bid))
            if s in c.regs:
                r = self.reg(s)
                return Name(r.name, r)
            if s is c.ret:
                return Name(self.ret_sym.name, self.ret_sym)
            if s is c.envp:
                return self.L.env_name()
            if s is c.args:
                self.vararg = True
                return self.tuple([Vararg()])
            role = fw.sym_role.get(s)
            if role in ("NEWPROXY", "SETMETATABLE", "GETMETATABLE", "SELECT", "TONUMBER", "ERROR", "GETFENV",
                        "SETFENV"):
                return Name(role.lower(), None)
            if role == "UNPACK":
                return Name("unpack", None)
            if role == "ENV":
                return self.L.env_name()
            return Name(e.name, s)
        if t is Index:
            obj = e.obj
            if is_name(obj) and obj.sym is fw.upvals_table:
                k = e.key
                if isinstance(k, Index) and is_name(k.obj, c.upvalsp) and isinstance(k.key, Number):
                    return CellRef(UpvalRef(int(k.key.value) - 1))
                return CellRef(self.tr(k, bid))
            if is_name(obj, c.upvalsp) and isinstance(e.key, Number):
                return UpvalRef(int(e.key.value) - 1)  # cell id of an upvalue (passed to closures)
            if is_name(obj, c.args) and isinstance(e.key, Number):
                return Name(*self._param_name(int(e.key.value)))
            if is_name(obj, c.overflow) and isinstance(e.key, Number) and c.overflow is not None:
                r = self.reg(("T", int(e.key.value)))
                return Name(r.name, r)
            ix = Index(self.tr(obj, bid), self.tr(e.key, bid))
            if fw.legacy and is_name(obj) and fw.sym_role.get(obj.sym) == "ENV" and isinstance(e.key, String):
                ix.env_read = True   # a global read: no observable effect, removable when unused
            return ix
        if t is Call:
            f = e.func
            if is_name(f) and f.sym is not None:
                role = fw.sym_role.get(f.sym)
                if role == "UNPACK" and fw.legacy and len(e.args) == 1:
                    sp = Spread(self.tr(e.args[0], bid))
                    sp.plain = True
                    return sp
                if role == "CALLFN":
                    return Call(self.tr(e.args[0], bid), [self.tr(a, bid) for a in e.args[2:]])
                if role == "PACK":
                    # vararg prologue: pack(select(i, unpack(args)))
                    if len(e.args) == 1:
                        a = unparen(e.args[0])
                        if isinstance(a, Call) and is_name(a.func) and fw.sym_role.get(a.func.sym) == "SELECT" and \
                                len(a.args) == 2 and isinstance(unparen(a.args[0]), Number):
                            u = unparen(a.args[1])
                            if isinstance(u, Call) and is_name(u.func) and \
                                    fw.sym_role.get(u.func.sym) == "UNPACKPACKED" and is_name(u.args[0], c.args):
                                self.vararg = True
                                self.nparams_vararg = int(unparen(a.args[0]).value) - 1
                                return TupleE([Vararg()])
                    return TupleE([self.tr(a, bid) for a in e.args])
                if role == "UNPACKPACKED":
                    return Spread(self.tr(e.args[0], bid))
                if role == "ALLOC":
                    return AllocCell()
                if role == "FREE":
                    return FreeMarker()
                if f.sym in fw.closures:
                    ent = unparen(e.args[1])
                    ups = [self.tr(it.value, bid) for it in ent.items]
                    ce = ClosureE(ups)
                    ce.kind = "closure"
                    ce.block = int(unparen(e.args[0]).value)
                    ce.arity = fw.closures[f.sym]
                    return ce
            fu = unparen(f)
            if isinstance(fu, Func) and len(fu.params) == 3 and len(e.args) == 3 and \
                    is_name(unparen(e.args[2]), fw.upvals_table):
                return self.native(fu, e.args, bid)
            return Call(self.tr(f, bid), [self.tr(a, bid) for a in e.args])
        if t is Method:
            return Method(self.tr(e.obj, bid), e.name, [self.tr(a, bid) for a in e.args])
        if t is Bin:
            return Bin(e.op, self.tr(e.left, bid), self.tr(e.right, bid))
        if t is Un:
            return Un(e.op, self.tr(e.expr, bid))
        if t is Table:
            if fw.legacy and all(it.key is None for it in e.items):
                return self.tuple([self.tr(it.value, bid) for it in e.items])
            return Table([TItem(self.tr(it.key, bid) if it.key is not None else None, self.tr(it.value, bid))
                          for it in e.items])
        if t is Func:
            return e  # native function (should not happen outside native expressions)
        return e  # literals, vararg

    def _jumpy(self, e):
        """Could `e` be a jump target expression (`cond and A or B`, ids, nil)? Only those are decoded."""
        e = unparen(e)
        if isinstance(e, (Number, Nil, Name)):
            return True
        if isinstance(e, Index) and is_name(e.obj) and self.fw.sym_role.get(e.obj.sym) == "ENV" and \
                isinstance(e.key, String):
            return True
        if isinstance(e, Bin) and e.op in ("and", "or"):
            return self._jumpy(e.left) and self._jumpy(e.right)
        return False

    def tuple(self, exprs):
        """A value list. In legacy frameworks lists are plain tables without an `n` field."""
        t = TupleE(exprs)
        t.plain = self.fw.legacy
        return t

    def _param_name(self, i):
        s = self.param(i)
        return (s.name, s)

    def native(self, factory, args, bid):
        """Cff keeps some expressions native: factory(proxy, env, upvalues)."""
        proxy_sym, env_sym, values_sym = factory.params
        pa = unparen(args[0])
        entries = []
        if isinstance(pa, Call) and pa.args and isinstance(unparen(pa.args[0]), Table):
            entries = [self.tr(it.value, bid) for it in unparen(pa.args[0]).items]
        body = factory.body
        if not body or not isinstance(body[0], Local) or len(body[0].exprs) != 1:
            raise CffError("native expression layout")
        expr = body[0].exprs[0]
        placeholders = [Symbol("cap%d" % (i + 1)) for i in range(len(entries))]
        for p in placeholders:
            p.attrs["mem"] = True
        env_name = self.L.env_name

        def fix(n):
            if isinstance(n, Index) and is_name(n.obj, values_sym) and isinstance(n.key, Index) and \
                    is_name(n.key.obj, proxy_sym) and isinstance(n.key.key, Number):
                k = int(n.key.key.value) - 1
                return Name(placeholders[k].name, placeholders[k])
            if isinstance(n, Name) and n.sym is env_sym:
                return env_name()
            return None

        expr = transform(expr, fix)
        ce = ClosureE([CellRef(x) for x in entries])
        ce.upvals = entries
        ce.kind = "native"
        ce.expr = expr
        ce.placeholders = placeholders
        return ce

    # ---------------------------------------------------------- statements
    def lift_block(self, bid):
        stmts_in = self.c.lookup(bid)
        self.pos_written = False
        out = []
        known = {}
        posv = None
        has_ret = False
        cap_n = [0]

        def capture(e):
            cap_n[0] += 1
            s = self.new_reg("c%d" % cap_n[0])
            out.append(Assign([Name(s.name, s)], [self.tr(e, bid)]))
            return Name(s.name, s)

        def sym_pos(e):
            e = unparen(e)
            if isinstance(e, Number):
                return Number(e.value)
            if isinstance(e, Nil):
                return Nil()
            if self.fw.legacy and isinstance(e, Index) and is_name(e.obj) and \
                    self.fw.sym_role.get(e.obj.sym) == "ENV" and isinstance(e.key, String):
                return Nil()  # WeAreDevs spells nil as a read of a random, undefined global
            if is_name(e, self.c.pos):
                if posv is not None:
                    return posv
                if self.pos_written:
                    return capture(e)   # `pos` currently holds an ordinary value (e.g. a condition)
                return Number(float(bid))
            if is_name(e) and e.sym in known:
                return Number(known[e.sym])
            if isinstance(e, Bin) and e.op in ("and", "or"):
                return Bin(e.op, sym_pos(e.left), sym_pos(e.right))
            return capture(e)

        pairs = []
        for s in stmts_in:
            if isinstance(s, Assign) and len(s.targets) == len(s.exprs) and len(s.targets) > 1:
                for tg, ex in zip(s.targets, s.exprs):
                    pairs.append(Assign([tg], [ex]))
            else:
                pairs.append(s)
        for s in pairs:
            if isinstance(s, CallStat):
                out.append(CallStat(self.tr(s.call, bid)))
                continue
            if not isinstance(s, Assign):
                raise CffError("unexpected statement in block: %s" % type(s).__name__)
            if len(s.targets) == 1:
                tg = s.targets[0]
                ex = s.exprs[0] if s.exprs else Nil()
                if is_name(tg, self.c.pos):
                    if self.fw.legacy:
                        # the right-hand side reads the previous `pos`; keep it as a register value
                        # (dead stores are removed later) and decode the jump only from the last one
                        value = self.tr(ex, bid)
                        jump_like = self._jumpy(ex)
                        new_posv = sym_pos(ex) if jump_like else None
                        out.append(Assign([Name(self.pos_reg.name, self.pos_reg)], [value]))
                        self.pos_written = True
                        posv = new_posv
                        continue
                    posv = sym_pos(ex)
                    continue
                if is_name(tg) and (tg.sym in self.c.regs or tg.sym is self.c.ret):
                    u = unparen(ex)
                    if isinstance(u, Number):
                        known[tg.sym] = u.value
                    else:
                        known.pop(tg.sym, None)
                    if isinstance(u, Call) and is_name(u.func) and self.fw.sym_role.get(u.func.sym) == "FREE":
                        continue
                if is_name(tg, self.c.ret):
                    has_ret = True
            else:
                for tg in s.targets:
                    if is_name(tg):
                        known.pop(tg.sym, None)
            targets = []
            exprs = [self.tr(x, bid) for x in s.exprs]
            for tg in s.targets:
                if is_name(tg) and tg.sym is self.c.pos:
                    if not self.fw.legacy:
                        raise CffError("pos in multiple assignment")
                    self.pos_written = True
                    posv = None
                    targets.append(Name(self.pos_reg.name, self.pos_reg))
                    continue
                targets.append(self.tr_target(tg, bid))
            out.append(Assign(targets, exprs))
        # terminator
        if posv is None:
            raise CffError("block %d has no successor" % bid)
        term = self.term_of(posv, has_ret, bid)
        return Block(bid, out, term)

    def tr_target(self, tg, bid):
        if is_name(tg):
            r = self.tr(tg, bid)
            if isinstance(r, TupleE):
                raise CffError("assignment to args")
            return r
        if isinstance(tg, Index):
            return self.tr(tg, bid)
        raise CffError("bad target")

    def term_of(self, p, has_ret, bid):
        p = unparen(p)
        if isinstance(p, Number):
            return ("goto", int(p.value))
        if isinstance(p, Nil):
            r = self.ret_sym
            sp = Spread(Name(r.name, r))
            sp.plain = self.fw.legacy
            return ("ret", [sp])
        if isinstance(p, Bin) and p.op == "or":
            l = unparen(p.left)

            def target(x):
                x = unparen(x)
                if isinstance(x, Number):
                    return int(x.value)
                if isinstance(x, Nil):
                    return RET_BLOCK
                return None
            if isinstance(l, Bin) and l.op == "and":
                a, b = target(l.right), target(p.right)
                if a is not None and b is not None:
                    return ("cond", l.left, a, b)
        from .printer import Printer
        raise CffError("cannot decode jump in block %d: %s" % (bid, Printer().expr(p)))

    # -------------------------------------------------------------- driver
    def lift(self):
        blocks = {}
        work = [self.entry]
        while work:
            b = work.pop()
            if b in blocks:
                continue
            if b == RET_BLOCK:
                r = self.ret_sym
                sp = Spread(Name(r.name, r))
                sp.plain = self.fw.legacy
                blocks[b] = Block(b, [], ("ret", [sp]))
                continue
            blk = self.lift_block(b)
            blocks[b] = blk
            for s in blk.succs():
                work.append(s)
        fn = IRFunc(self.entry, blocks, [], self.vararg, self.upvals)
        return fn


class FreeMarker(Name):
    def __init__(self):
        Name.__init__(self, "__free__", None)


class Lifter(object):
    def __init__(self, fw):
        self.fw = fw
        self.container = Container(fw)
        self.env_sym = Symbol("_ENV")
        self.env_sym.attrs["mem"] = True
        self.env_sym.attrs["env"] = True
        self.var_count = [0]

    def env_name(self):
        return Name(self.env_sym.name, self.env_sym)

    def new_var(self, reg):
        self.var_count[0] += 1
        s = Symbol("v%d" % self.var_count[0])
        s.attrs["var"] = True
        return s

    def new_cell(self):
        self.var_count[0] += 1
        s = Symbol("c%d" % self.var_count[0])
        s.attrs["mem"] = True
        return s

    def lift_function(self, entry, upvals, arity, is_main=False):
        fl = FuncLifter(self, entry, upvals, arity, is_main)
        fn = fl.lift()
        # drop FREE statements (they only release cell ids)
        for blk in fn.blocks.values():
            blk.stmts = [s for s in blk.stmts if not (isinstance(s, Assign) and len(s.exprs) == 1 and
                                                      isinstance(s.exprs[0], FreeMarker))]
        if fl.vararg and not is_main and arity is None:
            nparams = fl.nparams_vararg
        elif is_main:
            nparams = 0
        else:
            nparams = max(fl.params) if fl.params else 0
        params = [fl.param(i) for i in range(1, nparams + 1)]
        body = decompile(fn, self.new_var, self.new_cell, self)
        f = Func(params, fl.vararg, body)
        return f

    def lower_closure(self, ce):
        if ce.kind == "native":
            mapping = dict((p, u) for p, u in zip(ce.placeholders, ce.upvals))

            def fix(n):
                if isinstance(n, Name) and n.sym in mapping:
                    u = mapping[n.sym]
                    return Name(u.name, u.sym) if isinstance(u, Name) else u
                return None
            return transform(ce.expr, fix)
        ups = []
        pre = []
        for u in ce.upvals:
            if isinstance(u, Name) and u.sym is not None:
                ups.append(u.sym)
            else:
                import os, sys
                if os.environ.get("DEOBF_DEBUG"):
                    sys.stderr.write("[deobf] non-cell upvalue entry %r\n" % (u,))
                s = self.new_cell()
                ups.append(s)
        return self.lift_function(ce.block, ups, ce.arity)

    def run(self):
        fw = self.fw
        ups = []
        for it in fw.start_upvals:
            s = self.new_cell()
            ups.append(s)
        main = self.lift_function(fw.start, ups, None, is_main=True)
        if ups:
            main.body = [Local(ups, [])] + main.body
        return main


def decompile(fn, new_var, new_cell, lifter):
    """IR function -> list of statements."""
    ir.reachable(fn)
    ir.resolve_cells(fn, new_cell)
    ir.split_webs(fn, new_var)
    ir.optimize(fn)
    live = ir.liveness(fn)
    try:
        body = ir.Structurer(fn).run()
    except StructError as ex:
        import os, sys
        if os.environ.get("DEOBF_DEBUG"):
            sys.stderr.write("[deobf] structuring failed: %s\n" % ex)
            with open(os.environ["DEOBF_DEBUG"], "w") as fh:
                ir.dump(fn, fh)
        body = ir.fallback_dispatch(fn, lambda _: new_var(None))
    syms = set()
    for blk in fn.blocks.values():
        for s in blk.stmts:
            for x in ir._walk_all(ir._stmt_all_exprs(s)):
                if isinstance(x, Name) and x.sym is not None and x.sym.attrs.get("var"):
                    syms.add(x.sym)
        for e in ir.term_exprs(blk.term):
            for x in ir._walk_all([e]):
                if isinstance(x, Name) and x.sym is not None and x.sym.attrs.get("var"):
                    syms.add(x.sym)
    for x in ir._walk_all(body):
        if isinstance(x, Name) and x.sym is not None and x.sym.attrs.get("var"):
            syms.add(x.sym)
    # closures -> functions
    def fix(n):
        if isinstance(n, ClosureE):
            return lifter.lower_closure(n)
        return None
    body = [transform(s, fix) for s in body]
    ir.declare_locals(body, syms, live)
    body = ir.lower_pseudo(body)
    return body


def env_to_globals(node, env_syms):
    """ENV["name"] -> name."""
    from .printer import is_ident

    def fix(n):
        if isinstance(n, Index) and isinstance(n.obj, Name) and n.obj.sym in env_syms and \
                isinstance(n.key, String) and is_ident(n.key.value):
            return Name(n.key.value, None)
        return None
    node = transform(node, fix)

    def fix2(n):
        if isinstance(n, Name) and n.sym in env_syms:
            return Call(Name("getfenv", None), [])
        return None
    return transform(node, fix2)


def undo_cff(chunk):
    """Find and lift every Cff framework in the chunk. Returns number undone."""
    done = [0]
    envs = set()

    def fix(n):
        if isinstance(n, Call):
            fw = match_framework(n)
            if fw is not None:
                lifter = Lifter(fw)
                main = lifter.run()
                envs.add(lifter.env_sym)
                done[0] += 1
                return Call(Paren(main), [Vararg()])
        return None

    transform(chunk, fix)
    return done[0], envs
