"""Stage 2: abstract execution of the Luraph VM over the captured prototype.

Nothing of the protected program is executed.  Each VM handler (a Lua AST
fragment recovered by vm_analysis) is evaluated over an *abstract* state in
which every value is either a concrete constant or TOP (unknown).  This is
enough to:

  * follow the control flow (conditional jumps fork the state),
  * run Luraph's self-modifying handlers, which decrypt instruction blocks
    and string constants in place using the K/m key registers,
  * discover nested closures (calls to the VM factory/wrapper made from
    bytecode) and their entry points/keys,

so that afterwards the instruction arrays are in their final, decrypted,
"steady" form and can be lifted.
"""
from __future__ import annotations

from collections import deque
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Set, Tuple

from . import interp as I
from . import luau_ast as A
from .interp import Buffer, Builtin, LuaError, LuaFunction, LuaTable


class _Top:
    __slots__ = ()

    def __repr__(self):
        return "TOP"


TOP = _Top()

# Upper bound on a plausible instruction address. Real Luraph pcs are at most a few
# thousand; anything beyond this came from TOP-tainted arithmetic and is garbage.
_PC_SANITY = 1_000_000


class Alt:
    __slots__ = ("vals",)

    def __init__(self, vals):
        self.vals = tuple(vals)

    def __repr__(self):
        return "Alt%r" % (self.vals,)


class VarargT:
    __slots__ = ()


VARARG = VarargT()


class RegFile:
    """Abstract register table bound to a state."""

    __slots__ = ("st",)

    def __init__(self, st):
        self.st = st


@dataclass(eq=False)
class ClosureRef:
    entry_pc: int
    mode: int
    nregs: int
    m0: Any
    k0: Any
    upvals: Any
    factory_args: tuple
    created_at: Optional[Tuple[int, int]] = None
    key: Any = None

    def __repr__(self):
        return "<closure pc=%d mode=%s>" % (self.entry_pc, self.mode)


def is_concrete(v):
    return v is not TOP and type(v) is not Alt and type(v) is not RegFile and v is not VARARG


class AState:
    __slots__ = ("vars", "regs", "rf")

    def __init__(self, vars=None, regs=None):
        self.vars = vars if vars is not None else {}
        self.regs = regs if regs is not None else {}
        self.rf = RegFile(self)

    def copy(self):
        s = AState(dict(self.vars), dict(self.regs))
        for k, v in s.vars.items():
            if type(v) is RegFile:
                s.vars[k] = s.rf
        return s


def join_val(a, b):
    if a is b:
        return a
    if type(a) is RegFile and type(b) is RegFile:
        return a
    if is_concrete(a) and is_concrete(b) and type(a) is type(b) and type(a) in (int, float, bytes, bool) and a == b:
        return a
    if a is None and b is None:
        return None
    return TOP


def join_state(old: AState, new: AState):
    """returns (joined, changed)"""
    changed = False
    vars = dict(old.vars)
    for k in set(old.vars) | set(new.vars):
        a = old.vars.get(k, None)
        b = new.vars.get(k, None)
        j = join_val(a, b)
        if j is not a and not (j is TOP and a is TOP):
            changed = True
        vars[k] = j
    regs = {}
    for k in set(old.regs) | set(new.regs):
        a = old.regs.get(k, TOP) if old.regs else TOP
        b = new.regs.get(k, TOP)
        j = join_val(a, b)
        if j is not TOP:
            regs[k] = j
        if j is not a and not (j is TOP and a is TOP):
            changed = True
    st = AState(vars, regs)
    for k, v in st.vars.items():
        if type(v) is RegFile:
            st.vars[k] = st.rf
    return st, changed


# -- control signals ---------------------------------------------------------
BREAK = "break"
CONTINUE = "continue"
RETURN = "return"


class Ctx:
    __slots__ = ("st", "scopes")

    def __init__(self, st, scopes):
        self.st = st
        self.scopes = scopes

    def fork(self):
        st = self.st.copy()
        return Ctx(st, [dict(s) for s in self.scopes])

    def lookup(self, name, ev):
        for s in reversed(self.scopes):
            if name in s:
                v = s[name]
                return self.st.rf if type(v) is RegFile else v
        vs = self.st.vars
        if name in vs:
            v = vs[name]
            return self.st.rf if type(v) is RegFile else v
        if name in ev.upvals:
            return ev.upvals[name]
        return TOP

    def assign(self, name, v):
        for s in reversed(self.scopes):
            if name in s:
                s[name] = v
                return
        self.st.vars[name] = v


_MISS = object()


class Budget(Exception):
    pass


class Evaluator:
    """Abstract evaluator for handler ASTs."""

    def __init__(self, interp, upvals, factory_node, wrapper_node, runtime_node, on_closure):
        self.it = interp
        self.upvals = upvals  # name -> concrete value (factory/wrapper scope)
        self.factory_node = factory_node
        self.wrapper_node = wrapper_node
        self.runtime_node = runtime_node
        self.on_closure = on_closure
        self.protected = set()
        self.fast_cache = {}
        self.lazy_cache = {}
        self.regs_name = None
        self.it_env = None
        self.alloc_sites = {}
        self.alloc_ctx = None
        self.corrupt_writes = 0
        self.wrapper_map = {}  # id(wrapper LuaFunction) -> factory args
        self.factory_map = {}
        self.steps = 0
        self.max_steps = 300_000
        self.reg_reads = None  # list of register indices read during a step
        self.const_regs = set()  # registers ever assigned a concrete number

    # -- statements --------------------------------------------------------
    def exec_block(self, stmts, ctxs):
        """ctxs: list of Ctx (all live).  returns list of (ctx, sig)."""
        out = []
        live = ctxs
        for s in stmts:
            nxt = []
            for c in live:
                for c2, sig in self.exec_stmt(s, c):
                    if sig is None:
                        nxt.append(c2)
                    else:
                        out.append((c2, sig))
            live = nxt
            if not live:
                break
        out.extend((c, None) for c in live)
        return out

    def exec_scoped(self, stmts, ctx):
        ctx.scopes.append({})
        res = self.exec_block(stmts, [ctx])
        for c, _ in res:
            c.scopes.pop()
        return res

    def exec_stmt(self, s, ctx):
        self.steps += 1
        if self.steps > self.max_steps:
            raise Budget()
        t = type(s)
        if t is A.Local:
            vals = self.eval_list(s.values, ctx, len(s.names))
            sc = ctx.scopes[-1]
            for i, n in enumerate(s.names):
                sc[n] = vals[i] if i < len(vals) else None
            return [(ctx, None)]
        if t is A.Assign:
            # evaluate targets' object/key first, then values
            tg = []
            for target in s.targets:
                if type(target) is A.Index:
                    tg.append(("idx", self.eval(target.obj, ctx), self.eval(target.key, ctx)))
                else:
                    tg.append(("name", target.name, None))
            vals = self.eval_list(s.values, ctx, len(s.targets))
            for i, (kind, a, b) in enumerate(tg):
                v = vals[i] if i < len(vals) else None
                if kind == "name":
                    ctx.assign(a, v)
                else:
                    self.setindex(a, b, v, ctx)
            return [(ctx, None)]
        if t is A.CompoundAssign:
            target = s.target
            if type(target) is A.Name:
                cur = self.eval(target, ctx)
                v = self.binop(s.op, cur, self.eval(s.value, ctx))
                ctx.assign(target.name, v)
            else:
                o = self.eval(target.obj, ctx)
                k = self.eval(target.key, ctx)
                cur = self.index(o, k, ctx)
                v = self.binop(s.op, cur, self.eval(s.value, ctx))
                self.setindex(o, k, v, ctx)
            return [(ctx, None)]
        if t is A.CallStat:
            self.eval_multi(s.call, ctx)
            return [(ctx, None)]
        if t is A.Do:
            return self.exec_scoped(s.body, ctx)
        if t is A.If:
            return self.exec_if(s, 0, ctx)
        if t is A.Return:
            self.eval_list(s.values, ctx, None)
            return [(ctx, RETURN)]
        if t is A.Break:
            return [(ctx, BREAK)]
        if t is A.Continue:
            return [(ctx, CONTINUE)]
        if t is A.NumericFor:
            return self.exec_numfor(s, ctx)
        if t is A.GenericFor:
            return self.exec_genfor(s, ctx)
        if t is A.Repeat:
            return self.exec_repeat(s, ctx)
        if t is A.While:
            return self.exec_while(s, ctx)
        if t is A.LocalFunction:
            ctx.scopes[-1][s.name] = TOP
            return [(ctx, None)]
        if t is A.FunctionStat:
            return [(ctx, None)]
        if t is A.Comment:
            return [(ctx, None)]
        raise NotImplementedError(t.__name__)

    def exec_if(self, s, i, ctx):
        if i >= len(s.clauses):
            if s.orelse:
                return self.exec_scoped(s.orelse, ctx)
            return [(ctx, None)]
        cond, body = s.clauses[i]
        c = self.eval(cond, ctx)
        tv = self.truth(c)
        if tv is True:
            return self.exec_scoped(body, ctx)
        if tv is False:
            return self.exec_if(s, i + 1, ctx)
        c2 = ctx.fork()
        return self.exec_scoped(body, ctx) + self.exec_if(s, i + 1, c2)

    def _fast_info(self, stmt):
        info = self.fast_cache.get(id(stmt))
        if info is not None:
            return info
        declared = set()
        names = []
        assigned = []
        ok = True
        for n in A.walk(stmt):
            tn = type(n)
            if tn is A.Name:
                if n.name not in names:
                    names.append(n.name)
            elif tn is A.Local:
                declared.update(n.names)
            elif tn is A.NumericFor:
                declared.add(n.var)
            elif tn is A.GenericFor:
                declared.update(n.names)
            elif tn in (A.Vararg, A.Function, A.Return, A.Break, A.Continue):
                if tn in (A.Vararg, A.Function):
                    ok = False
            if tn is A.Assign:
                for t in n.targets:
                    if type(t) is A.Name and t.name not in assigned:
                        assigned.append(t.name)
            elif tn is A.CompoundAssign and type(n.target) is A.Name and n.target.name not in assigned:
                assigned.append(n.target.name)
        if self.regs_name in names:
            ok = False
        if not ok:
            info = False
        else:
            free = [x for x in names if x not in declared]
            outs = [x for x in assigned if x not in declared]
            fn = A.Function(free, False, [stmt, A.Return([A.Name(x) for x in outs] or [A.Nil()])], "fast")
            comp = I.Compiler(self.it, self.it_env, "fast")
            proto = comp.compile_function(fn, None)
            info = (LuaFunction(proto, [], self.it_env), free, outs)
        self.fast_cache[id(stmt)] = info
        return info

    def exec_numfor(self, s, ctx):
        info = self._fast_info(s)
        if info:
            fn, free, outs = info
            vals = [ctx.lookup(n, self) for n in free]
            if all(is_concrete(v) for v in vals):
                try:
                    res = fn.proto.invoke(fn, vals)
                except (LuaError, I.StopEmulation, RecursionError, Exception):
                    res = None
                if res is not None:
                    for i, n in enumerate(outs):
                        ctx.assign(n, res[i] if i < len(res) else None)
                    return [(ctx, None)]
        a = self.eval(s.start, ctx)
        b = self.eval(s.stop, ctx)
        st = self.eval(s.step, ctx) if s.step is not None else 1
        if not (isinstance(a, (int, float)) and isinstance(b, (int, float)) and isinstance(st, (int, float))) or st == 0:
            self.havoc(s.body, ctx)
            return [(ctx, None)]
        live = [ctx]
        out = []
        i = a
        n = 0
        while (i <= b) if st > 0 else (i >= b):
            n += 1
            if n > 1_000_000:
                raise Budget()
            nxt = []
            for c in live:
                c.scopes.append({s.var: i})
                for c2, sig in self.exec_block(s.body, [c]):
                    c2.scopes.pop()
                    if sig is None or sig == CONTINUE:
                        nxt.append(c2)
                    elif sig == BREAK:
                        out.append((c2, None))
                    else:
                        out.append((c2, sig))
            live = nxt
            if not live:
                break
            if len(live) > 8:
                raise Budget()
            i += st
        out.extend((c, None) for c in live)
        return out

    def exec_genfor(self, s, ctx):
        vals = self.eval_list(s.exprs, ctx, 3)
        f = vals[0] if vals else None
        stt = vals[1] if len(vals) > 1 else None
        if f is None or not is_concrete(f) or not is_concrete(stt) or stt is None:
            if stt is None and f is not None and is_concrete(f):
                # iterating over nil (e.g. `for k in next, nil`) -> error at runtime
                return [(ctx, RETURN)]
            self.havoc(s.body, ctx)
            return [(ctx, None)]
        if type(stt) is LuaTable and f in (I.BUILTIN_NEXT,) or (type(f) is Builtin and f.name == "next"):
            items = list(stt.h.items())
            live = [ctx]
            out = []
            for k, v in items:
                nxt = []
                for c in live:
                    c.scopes.append(dict(zip(s.names, [I.unkey(k), v])))
                    for c2, sig in self.exec_block(s.body, [c]):
                        c2.scopes.pop()
                        if sig is None or sig == CONTINUE:
                            nxt.append(c2)
                        elif sig == BREAK:
                            out.append((c2, None))
                        else:
                            out.append((c2, sig))
                live = nxt
                if len(live) > 8:
                    raise Budget()
            out.extend((c, None) for c in live)
            return out
        self.havoc(s.body, ctx)
        return [(ctx, None)]

    def exec_repeat(self, s, ctx):
        live = [ctx]
        out = []
        for _ in range(100000):
            nxt = []
            for c in live:
                c.scopes.append({})
                for c2, sig in self.exec_block(s.body, [c]):
                    if sig == BREAK:
                        c2.scopes.pop()
                        out.append((c2, None))
                        continue
                    if sig is not None and sig != CONTINUE:
                        c2.scopes.pop()
                        out.append((c2, sig))
                        continue
                    cond = self.truth(self.eval(s.cond, c2))
                    c2.scopes.pop()
                    if cond is True:
                        out.append((c2, None))
                    elif cond is False:
                        nxt.append(c2)
                    else:
                        out.append((c2, None))
                        # unknown: assume it may loop -> havoc
                        self.havoc(s.body, c2)
            live = nxt
            if not live:
                return out
            if len(live) > 8:
                raise Budget()
        raise Budget()

    def exec_while(self, s, ctx):
        live = [ctx]
        out = []
        for _ in range(1000000):
            nxt = []
            for c in live:
                cond = self.truth(self.eval(s.cond, c))
                if cond is False:
                    out.append((c, None))
                    continue
                if cond is None:
                    self.havoc(s.body, c)
                    out.append((c, None))
                    continue
                for c2, sig in self.exec_scoped(s.body, c):
                    if sig is None or sig == CONTINUE:
                        nxt.append(c2)
                    elif sig == BREAK:
                        out.append((c2, None))
                    else:
                        out.append((c2, sig))
            live = nxt
            if not live:
                return out
            if len(live) > 8:
                raise Budget()
        raise Budget()

    def havoc(self, stmts, ctx):
        """Make every variable written in stmts unknown."""
        for s in stmts:
            for n in A.walk(s):
                tn = type(n)
                if tn is A.Assign:
                    for t in n.targets:
                        self._havoc_target(t, ctx)
                elif tn is A.CompoundAssign:
                    self._havoc_target(n.target, ctx)
                elif tn is A.CallStat or tn is A.Call:
                    pass

    def _havoc_target(self, t, ctx):
        if type(t) is A.Name:
            ctx.assign(t.name, TOP)
        elif type(t) is A.Index:
            o = self.eval(t.obj, ctx)
            if type(o) is RegFile:
                o.st.regs.clear()

    # -- expressions -------------------------------------------------------
    def truth(self, v):
        if v is TOP or type(v) is Alt or v is VARARG:
            if type(v) is Alt:
                ts = {self.truth(x) for x in v.vals}
                if len(ts) == 1:
                    return ts.pop()
            return None
        return not (v is None or v is False)

    def eval_list(self, exprs, ctx, want):
        out = []
        for i, e in enumerate(exprs):
            if i == len(exprs) - 1 and type(e) in (A.Call, A.MethodCall, A.Vararg):
                r = self.eval_multi(e, ctx)
                if r is None:  # unknown number of values
                    if want is not None:
                        out.extend([TOP] * max(0, want - len(out)))
                    else:
                        out.append(TOP)
                else:
                    out.extend(r)
            else:
                out.append(self.eval(e, ctx))
        return out

    def eval_multi(self, e, ctx):
        """returns list of values or None if unknown arity"""
        t = type(e)
        if t is A.Vararg:
            return None
        if t is A.Call:
            f = self.eval(e.func, ctx)
            args = self.eval_list(e.args, ctx, None)
            unknown_tail = any(type(a) in (A.Call, A.MethodCall, A.Vararg) for a in e.args[-1:]) and args and args[-1] is TOP
            return self.call(f, args, ctx, unknown_tail)
        if t is A.MethodCall:
            o = self.eval(e.obj, ctx)
            f = self.index(o, e.name.encode(), ctx)
            args = [o] + self.eval_list(e.args, ctx, None)
            return self.call(f, args, ctx, False)
        return [self.eval(e, ctx)]

    def eval(self, e, ctx):
        t = type(e)
        if t is A.Number or t is A.String:
            return e.value
        if t is A.Name:
            return ctx.lookup(e.name, self)
        if t is A.Index:
            return self.index(self.eval(e.obj, ctx), self.eval(e.key, ctx), ctx)
        if t is A.Nil:
            return None
        if t is A.TrueE:
            return True
        if t is A.FalseE:
            return False
        if t is A.Paren:
            return self.eval(e.expr, ctx)
        if t is A.BinOp:
            op = e.op
            if op == "and" or op == "or":
                a = self.eval(e.left, ctx)
                tv = self.truth(a)
                if tv is None:
                    b = self.eval(e.right, ctx)
                    return self._alt(a, b) if op == "or" else self._alt(a, b)
                if op == "and":
                    return self.eval(e.right, ctx) if tv else a
                return a if tv else self.eval(e.right, ctx)
            return self.binop(op, self.eval(e.left, ctx), self.eval(e.right, ctx))
        if t is A.UnOp:
            v = self.eval(e.operand, ctx)
            if e.op == "not":
                tv = self.truth(v)
                return TOP if tv is None else (not tv)
            if not is_concrete(v):
                return TOP
            try:
                if e.op == "-":
                    return self.it.unm(v)
                if e.op == "#":
                    return self.it.length(v)
            except (LuaError, Exception):
                return TOP
        if t is A.IfExpr:
            c = self.truth(self.eval(e.cond, ctx))
            if c is True:
                return self.eval(e.then, ctx)
            if c is False:
                return self.eval(e.orelse, ctx)
            return self._alt(self.eval(e.then, ctx), self.eval(e.orelse, ctx))
        if t is A.Call or t is A.MethodCall:
            r = self.eval_multi(e, ctx)
            if r is None:
                return TOP
            return r[0] if r else None
        if t is A.Vararg:
            return TOP
        if t is A.Table:
            # abstract allocation site: the same constructor at the same
            # instruction always yields the same table object, otherwise
            # joins would lose every table-held (opaque) constant
            site = (self.alloc_ctx, id(e))
            tbl = self.alloc_sites.get(site)
            if tbl is None:
                tbl = LuaTable()
                self.alloc_sites[site] = tbl
            ai = 1
            for kind, k, v in e.items:
                if kind == "pos":
                    if type(v) in (A.Call, A.MethodCall, A.Vararg) and v is e.items[-1][2]:
                        r = self.eval_multi(v, ctx)
                        if r is None:
                            tbl.h[b"__unknown_tail"] = TOP
                        else:
                            for x in r:
                                if x is not None:
                                    tbl.h[ai] = x
                                ai += 1
                        continue
                    x = self.eval(v, ctx)
                    if x is not None:
                        tbl.h[ai] = x
                    ai += 1
                else:
                    kk = self.eval(k, ctx)
                    vv = self.eval(v, ctx)
                    if is_concrete(kk) and kk is not None and vv is not None:
                        tbl.h[I.key(kk)] = vv
            return tbl
        if t is A.Function:
            return TOP
        return TOP

    def _alt(self, a, b):
        if is_concrete(a) and is_concrete(b):
            if type(a) is type(b) and a == b:
                return a
            vals = []
            for x in (a, b):
                if type(x) is Alt:
                    vals.extend(x.vals)
                else:
                    vals.append(x)
            return Alt(vals)
        if type(a) is Alt or type(b) is Alt:
            vals = []
            for x in (a, b):
                if type(x) is Alt:
                    vals.extend(x.vals)
                elif is_concrete(x):
                    vals.append(x)
                else:
                    return TOP
            return Alt(vals)
        return TOP

    def binop(self, op, a, b):
        if type(a) is Alt or type(b) is Alt:
            # distribute small alternatives (needed for pc arithmetic)
            av = a.vals if type(a) is Alt else (a,)
            bv = b.vals if type(b) is Alt else (b,)
            if len(av) * len(bv) <= 4 and all(is_concrete(x) for x in av + bv):
                res = []
                for x in av:
                    for y in bv:
                        r = self.binop(op, x, y)
                        if not is_concrete(r):
                            return TOP
                        res.append(r)
                if all(type(r) is type(res[0]) and r == res[0] for r in res):
                    return res[0]
                return Alt(res)
            return TOP
        if not is_concrete(a) or not is_concrete(b):
            if op in ("==", "~=") and (a is TOP or b is TOP):
                return TOP
            return TOP
        it = self.it
        try:
            if op in ("+", "-", "*", "/", "%", "//", "^"):
                return it.arith(op, a, b)
            if op == "..":
                return it.concat(a, b)
            if op == "==":
                return it.eq(a, b)
            if op == "~=":
                return not it.eq(a, b)
            if op == "<":
                return it.lt(a, b)
            if op == "<=":
                return it.le(a, b)
            if op == ">":
                return it.lt(b, a)
            if op == ">=":
                return it.le(b, a)
        except LuaError:
            return TOP
        return TOP

    def index(self, o, k, ctx):
        to = type(o)
        if to is RegFile:
            if type(k) in (int, float):
                if self.reg_reads is not None:
                    self.reg_reads.append(int(k))
                return o.st.regs.get(int(k), TOP)
            return TOP
        if not is_concrete(o) or not is_concrete(k) or o is None:
            return TOP
        if to is ClosureRef:
            return TOP
        if to is LuaTable and o.meta is not None:
            ck = (id(o), k)
            v = self.lazy_cache.get(ck, _MISS)
            if v is not _MISS:
                return v
            try:
                v = self.it.index(o, k)
            except (LuaError, I.StopEmulation, RecursionError, Exception):
                return TOP
            self.lazy_cache[ck] = v
            return v
        try:
            return self.it.index(o, k)
        except (LuaError, I.StopEmulation, RecursionError, Exception):
            return TOP

    def setindex(self, o, k, v, ctx):
        to = type(o)
        if to is RegFile:
            if type(k) in (int, float):
                if v is TOP:
                    o.st.regs.pop(int(k), None)
                else:
                    o.st.regs[int(k)] = v
                    if type(v) in (int, float):
                        self.const_regs.add(int(k))
            else:
                o.st.regs.clear()
            return
        if to is LuaTable and is_concrete(k) and k is not None:
            kk = I.key(k)
            if id(o) in self.protected and not is_concrete(v):
                # never let an unknown value corrupt the real program arrays
                self.corrupt_writes += 1
                return
            if v is None:
                o.h.pop(kk, None)
            else:
                o.h[kk] = v

    # -- calls -------------------------------------------------------------
    def call(self, f, args, ctx, unknown_tail=False):
        tf = type(f)
        has_rf = any(type(a) is RegFile for a in args)
        if tf is Builtin:
            special = getattr(self, "bi_" + f.name.replace(".", "_"), None)
            if special is not None:
                r = special(args, ctx)
                if r is not NotImplemented:
                    return r
            if has_rf:
                ctx.st.regs.clear()
                return None
            if unknown_tail or not all(is_concrete(a) for a in args):
                return None
            if f.name in ("error",):
                return None
            try:
                r = f.f(*args)
                return list(r) if r is not None else []
            except (LuaError, Exception):
                return None
        if tf is LuaFunction:
            node = f.proto.node
            if node is self.factory_node or node is self.wrapper_node:
                if unknown_tail or not all(is_concrete(a) or a is TOP for a in args):
                    return None
                try:
                    return self.call_vm(f, args, ctx)
                except (LuaError, I.StopEmulation, Exception):
                    return None
        if tf is ClosureRef:
            if has_rf:
                ctx.st.regs.clear()
            return None
        if has_rf:
            ctx.st.regs.clear()
        return None

    def call_vm(self, f, args, ctx):
        it = self.it
        node = f.proto.node
        if node is self.factory_node:
            cargs = tuple(None if a is TOP else a for a in args)
            res = it.call(f, cargs)
            if res and type(res[0]) is LuaFunction:
                self.wrapper_map[id(res[0])] = cargs
            return list(res)
        # wrapper(upvals, m0, k0, ...)
        fargs = self.wrapper_map.get(id(f)) or self.factory_map.get(id(f))
        if fargs is None:
            return None
        ref = self.on_closure(fargs, tuple(args))
        return [ref]

    # builtins that may see the register file --------------------------------
    def bi_table_move(self, args, ctx):
        return self._move(args)

    def bi_move(self, args, ctx):
        return self._move(args)

    def _move(self, args):
        if len(args) < 4:
            return NotImplemented
        a1, f, e, t = args[:4]
        a2 = args[4] if len(args) > 4 else a1
        if not all(type(x) in (int, float) for x in (f, e, t)):
            for x in (a1, a2):
                if type(x) is RegFile:
                    x.st.regs.clear()
            return [a2]
        f, e, t = int(f), int(e), int(t)
        if e < f:
            return [a2]
        if e - f > 4096:
            return NotImplemented
        vals = [self._get(a1, f + i) for i in range(e - f + 1)]
        for i, v in enumerate(vals):
            self._set(a2, t + i, v)
        return [a2]

    def _get(self, o, k):
        if type(o) is RegFile:
            return o.st.regs.get(k, TOP)
        if type(o) is LuaTable:
            return o.h.get(k)
        return TOP

    def _set(self, o, k, v):
        if type(o) is RegFile:
            if v is TOP:
                o.st.regs.pop(k, None)
            else:
                o.st.regs[k] = v
        elif type(o) is LuaTable:
            if v is None:
                o.h.pop(k, None)
            else:
                o.h[k] = v

    def bi_unpack(self, args, ctx):
        return self._unpack(args)

    def bi_table_unpack(self, args, ctx):
        return self._unpack(args)

    def _unpack(self, args):
        if not args:
            return NotImplemented
        t = args[0]
        i = args[1] if len(args) > 1 else 1
        j = args[2] if len(args) > 2 else None
        if type(t) is RegFile:
            if type(i) in (int, float) and type(j) in (int, float) and j - i < 4096:
                return [t.st.regs.get(k, TOP) for k in range(int(i), int(j) + 1)]
            return None
        return NotImplemented

    def bi_select(self, args, ctx):
        if args and args[0] == b"#" and any(not is_concrete(a) for a in args[1:]):
            return [TOP]
        return NotImplemented

    def bi_pack(self, args, ctx):
        if any(not is_concrete(a) for a in args):
            t = LuaTable()
            for i, a in enumerate(args):
                if a is not None:
                    t.h[i + 1] = a
            t.h[b"n"] = len(args)
            return [t]
        return NotImplemented

    def bi_create(self, args, ctx):
        # table.create / buffer.create with unknown size
        if args and not is_concrete(args[0]):
            return [LuaTable()]
        return NotImplemented


# ---------------------------------------------------------------------------
# Exploration driver
# ---------------------------------------------------------------------------

@dataclass
class FuncInfo:
    entry: int
    mode: int
    nregs: int
    m0: Any
    k0: Any
    ref: Optional[ClosureRef] = None
    env: Dict[str, Any] = field(default_factory=dict)
    key: Any = None
    fargs: tuple = ()
    visited: Dict[int, Set[int]] = field(default_factory=dict)  # pc -> set(modes)
    states: Dict[Tuple[int, int], AState] = field(default_factory=dict)
    closures: Dict[int, List[ClosureRef]] = field(default_factory=dict)  # pc -> created closures
    succ: Dict[Tuple[int, int], Set[Tuple[int, int]]] = field(default_factory=dict)
    code: Dict[Tuple[int, int], Any] = field(default_factory=dict)
    failures: List[str] = field(default_factory=list)


class Explorer:
    def __init__(self, cap, log=None):
        from .loader import Captured  # noqa
        self.cap = cap
        self.vm = cap.vm
        self.log = log or (lambda *a: None)
        self.it = cap.interp
        self.fparams = cap.vm.factory_params
        self.fargs = cap.factory_args
        self.T_keys_at_capture = set(cap.factory_args[0].h.keys())
        self.upvals = self._collect_upvals()
        self.loops = {l.mode: l for l in self.vm.loops}
        self.mode_var = self.vm.loops[0].mode_var
        self.funcs: Dict[int, FuncInfo] = {}
        self.queue_funcs: deque = deque()
        self.ev = Evaluator(self.it, self.upvals, self.vm.factory, self.vm.wrapper, self.vm.runtime, self._on_closure)
        self.ev.factory_map = cap.factory_map
        for v in self.fargs:
            if isinstance(v, LuaTable):
                self.ev.protected.add(id(v))
                for w in v.h.values():
                    if isinstance(w, LuaTable):
                        self.ev.protected.add(id(w))
        self._cur_func = None
        self._cur_pc = None
        self.ctx_limit = 256
        self._fp_cache = {}
        self._inst_cache = {}
        self.func_budget = 300000
        self.max_cmp_regs = 6
        self.prune_rounds = 4

    # resolve the concrete values of every name the runtime closure captures
    def _collect_upvals(self):
        main = self.cap.main_runtime
        wfn, wargs = None, None
        # the wrapper LuaFunction is the one recorded for main
        vals = {}
        proto = main.proto.inner if hasattr(main.proto, "inner") else main.proto
        wrapper_fn = None
        # locate wrapper fn via the interpreter hooks state is not kept; use upsrc chain
        for i, (kind, ref) in enumerate(proto.upsrc):
            if kind == "local":
                vals[ref.name] = main.upvals[i].v
        # names captured through the wrapper (factory locals/params)
        unresolved = [(i, ref) for i, (kind, ref) in enumerate(proto.upsrc) if kind == "up"]
        if unresolved:
            wproto = self.vm.wrapper
            # find the wrapper's compiled proto via any captured closure: rebuild names by
            # compiling scopes is overkill; instead map by evaluating the factory body
            names = self._wrapper_up_names()
            for i, pidx in unresolved:
                if pidx < len(names):
                    vals[names[pidx]] = main.upvals[i].v
        return vals

    def _wrapper_up_names(self):
        # Re-run the factory with the captured args to obtain a wrapper
        # LuaFunction whose proto exposes upvalue names.
        it = self.it
        fac = None
        for fn_id, args in []:
            pass
        names = []
        # the wrapper proto is HookedProto/Proto attached to closures created by factory;
        # obtain one by calling the factory again (pure)
        factory_fn = self._find_factory_fn()
        res = it.call(factory_fn, self.fargs)
        w = res[0]
        wp = w.proto.inner if hasattr(w.proto, "inner") else w.proto
        fp = factory_fn.proto.inner if hasattr(factory_fn.proto, "inner") else factory_fn.proto
        for kind, ref in wp.upsrc:
            if kind == "local":
                names.append(ref.name)
            else:
                names.append("?up%d" % ref)
        return names

    def _find_factory_fn(self):
        # the factory is reachable from T (first factory arg) as a value
        T = self.fargs[0]
        for v in T.h.values():
            if type(v) is LuaFunction and v.proto.node is self.vm.factory:
                return v
        # search one level deeper
        for v in T.h.values():
            if type(v) is LuaTable:
                for w in v.h.values():
                    if type(w) is LuaFunction and w.proto.node is self.vm.factory:
                        return w
        raise RuntimeError("factory function value not found")

    def _param(self, args, name):
        eff = {}
        for i, p in enumerate(self.fparams):
            eff[p] = i
        i = eff.get(name)
        return args[i] if i is not None and i < len(args) else None

    def _on_closure(self, fargs, wargs):
        # map factory params to entry/mode/nregs using how the runtime prologue
        # consumes them: `U, m, K, N = h, p, S, Y` and `local r = R(U)`.
        entry = self._param(fargs, self.entry_param)
        mode = self._param(fargs, self.mode_param)
        nregs = self._param(fargs, self.nregs_param) if self.nregs_param else None
        m0 = wargs[self.m_index] if self.m_index is not None and self.m_index < len(wargs) else None
        k0 = wargs[self.k_index] if self.k_index is not None and self.k_index < len(wargs) else None
        upv = wargs[0] if wargs else None
        ref = ClosureRef(entry, mode, nregs, m0, k0, upv, fargs,
                         (self._cur_func.entry, self._cur_pc) if self._cur_func else None)
        pk = self.proto_key(fargs)
        ref.key = pk
        if isinstance(entry, (int, float)) and pk not in self.funcs:
            fi = FuncInfo(int(entry), mode, nregs, m0, k0, ref)
            fi.key = pk
            fi.fargs = fargs
            fi.env = self.env_for(fargs)
            self.funcs[pk] = fi
            self.queue_funcs.append(fi)
        if self._cur_func is not None:
            self._cur_func.closures.setdefault(self._cur_pc, []).append(ref)
        return ref

    # -- prologue analysis: which params feed pc/mode/keys -------------------
    def analyse_prologue(self):
        """Interpret the runtime closure's prologue statements symbolically."""
        rt = self.vm.runtime
        wparams = self.vm.wrapper.params
        weff = {p: i for i, p in enumerate(wparams)}
        self.entry_param = self.mode_param = self.nregs_param = None
        self.m_index = self.k_index = None
        loop0 = self.vm.loops[0]
        pc_var = loop0.pc_var
        assigns = {}

        def scan(stmts):
            for s in stmts:
                if isinstance(s, (A.Local, A.Assign)):
                    names = s.names if isinstance(s, A.Local) else [t.name if isinstance(t, A.Name) else None for t in s.targets]
                    for n, v in zip(names, s.values):
                        if n and isinstance(v, A.Name):
                            assigns.setdefault(n, v.name)
                        elif n and isinstance(v, A.Call) and isinstance(v.func, A.Name) and len(v.args) == 1 and isinstance(v.args[0], A.Name):
                            assigns.setdefault("__regs_size", v.args[0].name)
                elif isinstance(s, A.If):
                    for c, b in s.clauses:
                        if not any(_is_loop(x) for x in b):
                            scan(b)
                        else:
                            scan([x for x in b if not _is_loop(x)])
                    if s.orelse:
                        scan(s.orelse)

        scan(rt.body)
        self.pc_var = pc_var
        self.entry_param = assigns.get(pc_var)
        self.mode_param = assigns.get(loop0.mode_var) or loop0.mode_var
        self.nregs_param = assigns.get("__regs_size")
        # key registers: runtime locals initialised from wrapper params
        self.key_vars = {}
        for var, src in assigns.items():
            if src in weff and var != pc_var:
                self.key_vars[var] = weff[src]
        self.key_var_names = sorted(self.key_vars)
        idxs = sorted(self.key_vars.items(), key=lambda kv: kv[1])
        self.m_index = idxs[0][1] if idxs else None
        self.k_index = idxs[1][1] if len(idxs) > 1 else None
        # the mode var of the first loop is the factory param directly
        if self.mode_param not in self.fparams:
            self.mode_param = loop0.mode_var
        return assigns

    def initial_state(self, fi: FuncInfo, wargs):
        st = AState()
        st.vars["__regs"] = st.rf
        # every runtime-level local starts nil
        for s in self.vm.runtime.body:
            if isinstance(s, A.Local):
                for n in s.names:
                    st.vars[n] = None
        regs_name = None
        for s in self.vm.runtime.body:
            if isinstance(s, A.Local) and len(s.values) == 1 and isinstance(s.values[0], A.Call):
                regs_name = s.names[0]
        self.regs_name = regs_name
        self.ev.regs_name = regs_name
        self.ev.it_env = self.cap.env
        st.vars[regs_name] = st.rf
        for var, wi in self.key_vars.items():
            st.vars[var] = wargs[wi] if wi < len(wargs) else None
        st.vars[self.pc_var] = fi.entry
        for l in self.vm.loops:
            if l.mode_var and l.mode_var not in self.fparams:
                st.vars[l.mode_var] = fi.mode
        return st

    def explore(self, max_insns=400000):
        self.analyse_prologue()
        main = FuncInfo(int(self._param(self.fargs, self.entry_param)), self._param(self.fargs, self.mode_param),
                        self._param(self.fargs, self.nregs_param) if self.nregs_param else None,
                        self.cap.wrapper_args[self.m_index] if self.m_index is not None else None,
                        self.cap.wrapper_args[self.k_index] if self.k_index is not None else None)
        self.main = main
        main.key = self.proto_key(self.fargs)
        main.fargs = self.fargs
        main.env = self.env_for(self.fargs)
        self.funcs[main.key] = main
        wargs_main = self.cap.wrapper_args
        self.queue_funcs.append(main)
        self.wargs = {main.key: wargs_main}
        total = 0
        while self.queue_funcs:
            fi = self.queue_funcs.popleft()
            wargs = self.wargs.get(fi.key)
            if wargs is None:
                wargs = (fi.ref.upvals, fi.m0, fi.k0) if fi.ref else ()
                wargs = self._wargs_for(fi)
            import time as _t
            t0 = _t.time()
            n = self.explore_func(fi, wargs, self.func_budget)
            total += n
            self.log("    [absvm] func@%d mode=%s: %d steps, %d nodes, %d restarts, %.1fs%s" % (
                fi.entry, fi.mode, n, len(fi.states), getattr(fi, "restarts", 0), _t.time() - t0,
                (" (" + "; ".join(sorted(set(fi.failures))[:3]) + ")") if fi.failures else ""))
        return self.funcs

    def _wargs_for(self, fi):
        n = max(self.key_vars.values()) + 1 if self.key_vars else 1
        w = [None] * n
        if fi.ref is not None:
            w = list(fi.ref.factory_args[:0])  # placeholder
            w = [fi.ref.upvals] + [None] * (n - 1)
            if self.m_index is not None and self.m_index < n:
                w[self.m_index] = fi.m0
            if self.k_index is not None and self.k_index < n:
                w[self.k_index] = fi.k0
        return tuple(w)

    def proto_key(self, fargs):
        """Content fingerprint of a prototype (the same child proto may be
        deserialised into fresh tables at every CLOSURE site)."""
        entry = self._param(fargs, self.entry_param)
        mode = self._param(fargs, self.mode_param)
        cache = self._fp_cache
        parts = [entry, mode]
        for v in fargs:
            if isinstance(v, LuaTable) and v.h and v is not self.fargs[0]:
                fp = cache.get(id(v))
                if fp is None:
                    items = []
                    for k, x in v.h.items():
                        if type(x) in (int, float, bytes, bool):
                            items.append((repr(k), repr(x)))
                    fp = (len(v.h), hash(tuple(sorted(items))))
                    cache[id(v)] = fp
                parts.append(fp)
        return tuple(parts)

    def env_for(self, fargs):
        env = dict(self.upvals)
        for i, p in enumerate(self.fparams):
            if i < len(fargs):
                env[p] = fargs[i]  # later duplicates win, like Lua
        for v in fargs:
            if isinstance(v, LuaTable):
                self.ev.protected.add(id(v))
                for w in v.h.values():
                    if isinstance(w, LuaTable):
                        self.ev.protected.add(id(w))
        return env

    def _mutable_objects(self, fargs):
        seen = set()
        out = []
        T = self.fargs[0]

        def visit(v, depth):
            if id(v) in seen or v is T:
                return
            if isinstance(v, LuaTable):
                seen.add(id(v))
                out.append(v)
                if depth < 2:
                    for w in list(v.h.values()):
                        visit(w, depth + 1)
            elif isinstance(v, Buffer):
                seen.add(id(v))
                out.append(v)
        for v in fargs:
            visit(v, 0)
        return out

    def snapshot(self, fargs):
        snap = []
        for o in self._mutable_objects(fargs):
            if isinstance(o, LuaTable):
                snap.append((o, dict(o.h)))
            else:
                snap.append((o, bytes(o.b)))
        return snap

    def restore(self, snap):
        for o, data in snap:
            if isinstance(o, LuaTable):
                o.h.clear()
                o.h.update(data)
            else:
                o.b[:] = data
        I._NEXT_CACHE.clear()

    def explore_func(self, fi: FuncInfo, wargs, budget):
        self.ev.upvals = fi.env
        fi.jump_regs = set()
        fi.cmp_regs = set()
        fi.cmp_sites = {}
        fi.copy_sites = {}
        fi.forbidden = set()
        fi.ncode = max((len(v.h) for v in fi.fargs if isinstance(v, LuaTable)), default=1 << 20) + 2
        snap = self.snapshot(fi.fargs)
        total = 0
        for rnd in range(self.prune_rounds):
            if rnd:
                self.restore(snap)
            total += self._attempts(fi, wargs, budget, snap)
            new = self._infeasible_edges(fi)
            new -= fi.forbidden
            if not new:
                break
            self.log("      prune round %d: %d infeasible edges" % (rnd + 1, len(new)))
            fi.forbidden |= new
        return total

    def _infeasible_edges(self, fi):
        """Edges from nodes that have a viable continuation into nodes from
        which every path ends in a VM failure (junk reached through an
        unresolved opaque predicate)."""
        succ = fi.succ
        bad = set(fi.bad)
        # nodes with no successors that did not end in a proper return/stop
        preds = {}
        for k, ss in succ.items():
            for s2 in ss:
                preds.setdefault(s2, []).append(k)
        changed = True
        work = list(bad)
        while work:
            n = work.pop()
            for p in preds.get(n, []):
                if p in bad:
                    continue
                ss = succ.get(p, [])
                if ss and all(x in bad for x in ss):
                    bad.add(p)
                    work.append(p)
        edges = set()
        for k, ss in succ.items():
            if k in bad:
                continue
            for s2 in ss:
                if s2 in bad:
                    edges.add((k[0], k[1], s2[0], s2[1]))
        # an edge is only infeasible if it is bad in *every* context
        good_edges = set()
        for k, ss in succ.items():
            for s2 in ss:
                if s2 not in bad:
                    good_edges.add((k[0], k[1], s2[0], s2[1]))
        fi.bad_all = bad
        return edges - good_edges

    def _attempts(self, fi, wargs, budget, snap):
        total = 0
        for attempt in range(8):
            fi.restarts = attempt
            if attempt:
                self.restore(snap)
            self.ev.alloc_sites = {}
            fi.visited.clear()
            fi.bad = set()
            fi.code.clear()
            fi.states.clear()
            fi.succ.clear()
            fi.closures.clear()
            fi.failures.clear()
            fi.pending_jump = set()
            fi.pending_cmp = set()
            total += self._explore_func(fi, wargs, budget)
            room = self.max_cmp_regs - len(fi.cmp_regs)
            newc = sorted(fi.pending_cmp - fi.cmp_regs)[:max(room, 0)]
            newj = sorted(fi.pending_jump - fi.jump_regs)[:max(0, 10 - len(fi.jump_regs))]
            if not newc and not newj:
                return total
            self.log("      restart with jump %s cmp %s" % (newj, newc))
            fi.cmp_regs |= set(newc)
            fi.jump_regs |= set(newj)
        return total

    def _sig(self, fi, st):
        ncode = fi.ncode
        j = tuple(_pcval(st.regs.get(r, TOP), ncode) for r in sorted(fi.jump_regs))
        c = tuple(_sigval(st.regs.get(r, TOP)) for r in sorted(fi.cmp_regs))
        c += tuple(_sigval(st.vars.get(v, TOP)) for v in self.key_var_names)
        return (j, c)

    def _explore_func(self, fi, wargs, budget):
        st0 = self.initial_state(fi, wargs)
        mode0 = fi.mode
        k0 = (mode0, fi.entry, self._sig(fi, st0))
        fi.entry_node = k0
        work = deque([k0])
        fi.states[k0] = st0
        count = 0
        visits = {}
        per_pc = {}
        while work:
            key = work.popleft()
            mode, pc, sig = key
            st = fi.states[key]
            visits[key] = visits.get(key, 0) + 1
            if visits[key] > 40:
                continue
            count += 1
            if count % 20000 == 0:
                self.log("      .. %d steps, %d nodes, queue %d, jregs %s cmpregs %s, pc %d" % (
                    count, len(fi.states), len(work), sorted(fi.jump_regs), sorted(fi.cmp_regs), pc))
            if count > budget:
                fi.failures.append("instruction budget exhausted")
                break
            fi.visited.setdefault(pc, set()).add(mode)
            fi.cur_failed = False
            succs = self.step(fi, mode, pc, st.copy())
            if fi.cur_failed:
                fi.bad.add(key)
            if fi.forbidden:
                succs = [x for x in succs if (mode, pc, x[0], x[1]) not in fi.forbidden]
            keys = []
            for m2, pc2, st2 in succs:
                sig2 = self._sig(fi, st2)
                # bound context splitting per pc (loop counters would explode)
                seen = per_pc.setdefault((m2, pc2), set())
                if sig2[1] not in seen and len(seen) >= self.ctx_limit:
                    sig2 = (sig2[0], ("W",))
                    for r in fi.cmp_regs:
                        st2.regs.pop(r, None)
                    for v in self.key_var_names:
                        st2.vars[v] = TOP
                seen.add(sig2[1])
                k = (m2, pc2, sig2)
                keys.append(k)
                old = fi.states.get(k)
                if old is None:
                    fi.states[k] = st2
                    work.append(k)
                else:
                    j, changed = join_state(old, st2)
                    if changed:
                        fi.states[k] = j
                        work.append(k)
            fi.succ[key] = keys
        return count

    def _fail(self, fi, msg):
        fi.failures.append(msg)
        fi.cur_failed = True

    def step(self, fi, mode, pc, st):
        """Execute one instruction abstractly; return successors."""
        loop = self.loops.get(mode)
        if loop is None:
            self._fail(fi, "unknown mode %r at pc %d" % (mode, pc))
            return []
        for _ in range(64):  # re-execution after self-rewrite (pc - 1 + 1)
            oparr = fi.env.get(loop.op_array)
            op = oparr.h.get(pc) if isinstance(oparr, LuaTable) else None
            if op is None:
                self._fail(fi, "no opcode at pc %d (mode %s)" % (pc, mode))
                return []
            h = loop.lookup(op)
            if h is None:
                self._fail(fi, "unknown opcode %r at pc %d (mode %s)" % (op, pc, mode))
                return []
            st.vars[loop.pc_var] = pc
            st.vars[loop.op_var] = op
            self._cur_mode = mode
            self._cur_code = self._instantiate(fi, loop, mode, pc, op) if fi.cmp_regs else None
            jreg = self._computed_jump_reg(loop, h, st)
            pre_regs = dict(st.regs)
            ctx = Ctx(st, [{}])
            self._cur_func, self._cur_pc = fi, pc
            self.ev.reg_reads = reads = []
            self.ev.steps = 0
            self.ev.alloc_ctx = (fi.key, pc)
            try:
                results = self.ev.exec_block(h, [ctx])
            except Budget:
                self._fail(fi, "evaluation budget at pc %d" % pc)
                return []
            finally:
                self._cur_func = None
            # state registers copied from another register: track the source too
            if fi.cmp_regs and len(fi.cmp_regs) < self.max_cmp_regs:
                for src in self._copy_sources(fi, loop, h, pc):
                    fi.copy_sites.setdefault(src, set()).add(pc)
                    if src not in fi.cmp_regs and src not in pre_regs and src in self.ev.const_regs \
                            and (fi.nregs is None or src < fi.nregs) and len(fi.copy_sites[src]) >= 2:
                        if src not in fi.pending_cmp:
                            fi.pending_cmp.add(src)
                            self.log("      new cmp reg %d via copy (pc %d)" % (src, pc))
            results = self._split_alts(fi, results)
            out = []
            for c, sig in results:
                s2 = c.st
                if sig == RETURN:
                    continue
                newpc = s2.vars.get(loop.pc_var)
                pcs = self._pcs(newpc)
                if jreg is not None and pcs:
                    # indirect jump: a target register derived from TOP arithmetic can hold a
                    # garbage address (e.g. 134419826) that is never a real instruction. Exploring
                    # it wastes the whole budget chasing dead paths, so drop the clearly-absurd ones
                    # (real pcs are small). Keep in-array and plausibly-not-yet-decrypted targets.
                    pcs = [p for p in pcs if (p + 1) in oparr.h or -1 <= p <= _PC_SANITY]
                if not pcs and jreg is not None and (fi.nregs is None or jreg < fi.nregs) \
                        and len(fi.jump_regs) < 10:
                    if jreg not in fi.jump_regs:
                        if jreg not in fi.pending_jump:
                            fi.pending_jump.add(jreg)
                            self.log("      new jump reg %d (pc %d)" % (jreg, pc))
                    self._fail(fi, "unresolved indirect jump at pc %d" % pc)
                if jreg is not None:
                    s2.regs.pop(jreg, None)  # consumed jump target
                if sig == BREAK:
                    nm = s2.vars.get(self.mode_var_runtime(loop))
                    for p in pcs:
                        for m in self._pcs(nm):
                            out.append((m, p, s2))
                    continue
                for p in pcs:
                    out.append((mode, p + 1, s2))
            if len(out) == 1 and out[0][1] == pc and out[0][0] == mode:
                st = out[0][2]
                continue
            self._record(fi, loop, mode, pc)
            if len(set(p for _, p, _ in out)) > 1 and len(fi.cmp_regs) < self.max_cmp_regs:
                # conditional branch comparing a register with a numeric
                # constant whose value was lost by a join: this is the
                # bytecode-level control-flow-flattening dispatcher; track it
                # path-sensitively.
                ccr = self._const_compared_regs(fi, loop, h, pc)
                if DEBUG_PCS and pc in DEBUG_PCS:
                    self.log("      dbg branch pc %d regs %s pre %s const %s" % (pc, ccr, {r: pre_regs.get(r, 'TOP') for r in ccr}, [r in self.ev.const_regs for r in ccr]))
                for r in ccr:
                    fi.cmp_sites.setdefault(r, set()).add(pc)
                for r in ccr:
                    if r not in pre_regs and r in self.ev.const_regs and r not in fi.cmp_regs \
                            and r not in fi.jump_regs and len(fi.cmp_sites[r]) >= 3:
                        if r not in fi.pending_cmp:
                            fi.pending_cmp.add(r)
                            self.log("      new cmp reg %d (pc %d)" % (r, pc))
            return out
        self._fail(fi, "rewrite loop at pc %d" % pc)
        return []

    def _split_alts(self, fi, results):
        """A context register holding one of a few alternatives (e.g. the
        CFF state set by `cond and A or B`) forks the state per value."""
        ctx_regs = fi.cmp_regs | fi.jump_regs
        if not ctx_regs:
            return results
        out = []
        for c, sig in results:
            todo = [c]
            for r in ctx_regs:
                nxt = []
                for cc in todo:
                    v = cc.st.regs.get(r)
                    if type(v) is Alt and len(v.vals) <= 8:
                        for x in dict.fromkeys(v.vals):
                            c2 = cc.fork()
                            c2.st.regs[r] = x
                            nxt.append(c2)
                    else:
                        nxt.append(cc)
                todo = nxt
            out.extend((cc, sig) for cc in todo)
        return out

    def _copy_sources(self, fi, loop, h, pc):
        code = self._cur_code
        if code is None:
            return []
        rn = self.regs_name
        out = []
        for n in A.walk(code):
            if isinstance(n, A.Assign):
                for t, v in zip(n.targets, n.values):
                    if isinstance(t, A.Index) and isinstance(t.obj, A.Name) and t.obj.name == rn \
                            and isinstance(t.key, A.Number) and int(t.key.value) in fi.cmp_regs \
                            and isinstance(v, A.Index) and isinstance(v.obj, A.Name) and v.obj.name == rn \
                            and isinstance(v.key, A.Number):
                        out.append(int(v.key.value))
        return out

    def _record(self, fi, loop, mode, pc):
        """Remember the steady (post-rewrite) instruction executed at pc."""
        from .instantiate import Instantiator
        arrays = {n: v for n, v in fi.env.items() if isinstance(v, LuaTable) and n in self.fparams and n != self.fparams[0]}
        op = fi.env[loop.op_array].h.get(pc)
        fi.code[(mode, pc)] = (op, self._instantiate(fi, loop, mode, pc, op, arrays))

    def _instantiate(self, fi, loop, mode, pc, op, arrays=None):
        from .instantiate import Instantiator
        if arrays is None:
            arrays = {n: v for n, v in fi.env.items() if isinstance(v, LuaTable) and n in self.fparams and n != self.fparams[0]}
        sig = tuple(repr(a.h.get(pc + i)) for a in arrays.values() for i in range(4))
        ck = (id(fi.env[loop.op_array]), mode, pc, op, sig)
        code = self._inst_cache.get(ck)
        if code is None:
            h = loop.lookup(op) or []
            try:
                inst = Instantiator(self.it, arrays, loop.pc_var)
                inst.cache = self.ev.lazy_cache
                code = inst.instantiate(h, pc)
            except Exception as e:  # pragma: no cover - defensive
                code = [A.Comment("instantiation failed: %s" % e)]
            self._inst_cache[ck] = code
        return code

    def _const_compared_regs(self, fi, loop, h, pc):
        from .instantiate import Instantiator
        op = fi.env[loop.op_array].h.get(pc)
        code = self._instantiate(fi, loop, self._cur_mode, pc, op)
        regs = []
        rn = self.regs_name
        if DEBUG_PCS and pc in DEBUG_PCS:
            self.log("      dbg code: %r rn=%r" % (A.to_source(code), rn))
        for n in A.walk(code):
            if isinstance(n, A.BinOp) and n.op in ("<", "<=", ">", ">=", "==", "~="):
                for a, b in ((n.left, n.right), (n.right, n.left)):
                    if isinstance(a, A.Index) and isinstance(a.obj, A.Name) and a.obj.name == rn \
                            and isinstance(a.key, A.Number) and isinstance(b, A.Number):
                        regs.append(int(a.key.value))
        return regs

    def _computed_jump_reg(self, loop, h, st):
        """If the handler is `pc = REGS[k]`, return the concrete k."""
        for s in h:
            if isinstance(s, A.Assign) and len(s.targets) == 1 and isinstance(s.targets[0], A.Name) \
                    and s.targets[0].name == loop.pc_var and isinstance(s.values[0], A.Index) \
                    and isinstance(s.values[0].obj, A.Name) and s.values[0].obj.name == self.regs_name:
                k = self.ev.eval(s.values[0].key, Ctx(st, [{}]))
                if type(k) in (int, float):
                    return int(k)
        return None

    def mode_var_runtime(self, loop):
        # all loops after the first use the same runtime mode variable
        for l in self.vm.loops:
            if l.mode_var and l.mode_var not in self.fparams:
                return l.mode_var
        return loop.mode_var

    def _pcs(self, v):
        if type(v) is Alt:
            return [int(x) for x in v.vals if type(x) in (int, float)]
        if type(v) in (int, float):
            return [int(v)]
        return []


import os as _os
DEBUG_PCS = set(int(x) for x in _os.environ.get("ABSVM_DEBUG_PCS", "").split(",") if x)


class _Restart(Exception):
    pass


def _pcval(v, ncode):
    if type(v) in (int, float) and 0 <= v <= ncode:
        return v
    return "T"


def _sigval(v):
    if type(v) in (int, float):
        return v
    return "T"


def _is_loop(s):
    return isinstance(s, A.While) and isinstance(s.cond, A.TrueE)
