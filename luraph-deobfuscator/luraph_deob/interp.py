"""Sandboxed Luau emulator used to evaluate the Luraph *loader* stage.

The AST is compiled into a tree of Python closures.  Only pure library
functions are exposed (string/table/math/bit32/buffer/...): there is no file,
network or OS access, so the obfuscated program can never touch the host.
The emulator is only ever driven up to the point where the VM hands back the
wrapped main closure; the protected program itself is never executed.
"""
from __future__ import annotations

import math
import struct
import sys

from . import luau_ast as A
from .luapattern import lua_find, lua_gmatch, lua_gsub, lua_match

sys.setrecursionlimit(20000)


class LuaError(Exception):
    def __init__(self, value, traceback=None):
        Exception.__init__(self, value)
        self.value = value
        self.lua_traceback = traceback
        self.positioned = False  # message already carries a "chunk:line:" prefix


class StepLimit(Exception):
    pass


class LuaTable:
    __slots__ = ("h", "meta", "__weakref__", "frozen", "asize")

    def __init__(self, h=None):
        self.h = {} if h is None else h
        self.meta = None
        self.frozen = False
        self.asize = 0  # size of the array part given by a constructor (Lua `#` border semantics)

    def length(self):
        h = self.h
        a = self.asize
        if a:
            if a in h:
                j = a
                while (j + 1) in h:
                    j += 1
                return j
            i, j = 0, a
            while j - i > 1:
                m = (i + j) // 2
                if m in h:
                    i = m
                else:
                    j = m
            return i
        if 1 not in h:
            return 0
        n = len(h)
        if n in h and (n + 1) not in h:
            # fast path for pure arrays
            return n
        # binary search border
        i, j = 1, 2
        while j in h:
            i = j
            j *= 2
            if j > 1 << 52:
                break
        while j - i > 1:
            m = (i + j) // 2
            if m in h:
                i = m
            else:
                j = m
        return i

    def __repr__(self):
        return "<table %x>" % id(self)


class LuaFunction:
    __slots__ = ("proto", "upvals", "name", "env")

    def __init__(self, proto, upvals, env):
        self.proto = proto
        self.upvals = upvals
        self.env = env
        self.name = proto.name

    def __call__(self, *args):
        return self.proto.invoke(self, args)

    def __repr__(self):
        return "<function %s>" % (self.name or "?")


class Builtin:
    __slots__ = ("f", "name")

    def __init__(self, f, name):
        self.f = f
        self.name = name

    def __call__(self, *args):
        return self.f(*args)

    def __repr__(self):
        return "<builtin %s>" % self.name


class Buffer:
    __slots__ = ("b",)

    def __init__(self, b):
        self.b = b

    def __repr__(self):
        return "<buffer %d>" % len(self.b)


class Opaque:
    """Stand-in for Roblox userdata (Vector3, UDim, ...)."""

    __slots__ = ("kind", "args")

    def __init__(self, kind, args):
        self.kind = kind
        self.args = args

    def __repr__(self):
        return "%s(%s)" % (self.kind, ", ".join(map(tostr_py, self.args)))


class Vector(tuple):
    pass


class Coroutine:
    def __init__(self, fn):
        self.fn = fn
        self.status = "suspended"


def key(k):
    # Lua table keys: True/False must not collide with 1/0, floats normalise
    t = type(k)
    if t is bool:
        return (_BOOLK, k)
    if t is float:
        if k.is_integer():
            return int(k)
        if k != k:
            raise LuaError(b"table index is NaN")
    return k


_BOOLK = object()


def unkey(k):
    if type(k) is tuple and len(k) == 2 and k[0] is _BOOLK:
        return k[1]
    return k


def type_name(v):
    if v is None:
        return "nil"
    t = type(v)
    if t is bool:
        return "boolean"
    if t is int or t is float:
        return "number"
    if t is bytes:
        return "string"
    if t is LuaTable:
        return "table"
    if t is LuaFunction or t is Builtin:
        return "function"
    if t is Buffer:
        return "buffer"
    if t is Vector:
        return "vector"
    if t is Coroutine:
        return "thread"
    return "userdata"


def fmt_num(v):
    if type(v) is int:
        return str(v)
    if v != v:
        return "nan" if math.copysign(1, v) > 0 else "-nan"
    if v == math.inf:
        return "inf"
    if v == -math.inf:
        return "-inf"
    if v.is_integer() and abs(v) < 1e15:
        return str(int(v))
    s = "%.14g" % v
    return s


def tostr_py(v):
    if v is None:
        return "nil"
    t = type(v)
    if t is bool:
        return "true" if v else "false"
    if t is int or t is float:
        return fmt_num(v)
    if t is bytes:
        return v.decode("latin-1")
    if t is LuaTable:
        return "table: 0x%08x" % (id(v) & 0xFFFFFFFF)
    if t in (LuaFunction, Builtin):
        return "function: 0x%08x" % (id(v) & 0xFFFFFFFF)
    if t is Buffer:
        return "buffer: 0x%08x" % (id(v) & 0xFFFFFFFF)
    if t is Vector:
        return ", ".join(fmt_num(x) for x in v)
    return repr(v)


def truthy(v):
    return v is not None and v is not False


def tonum(v):
    t = type(v)
    if t is int or t is float:
        return v
    if t is bytes:
        return str2num(v)
    return None


def str2num(s):
    try:
        s2 = s.decode("latin-1").strip()
    except Exception:
        return None
    if not s2:
        return None
    try:
        neg = False
        body = s2
        if body[0] in "+-":
            neg = body[0] == "-"
            body = body[1:]
        if body[:2] in ("0x", "0X"):
            v = int(body[2:], 16)
            return -v if neg else v
        if body[:2] in ("0b", "0B"):
            v = int(body[2:], 2)
            return -v if neg else v
        if body.lower() in ("inf", "nan", "infinity") or "_" in body:
            return None
        v = float(s2)
        if v.is_integer() and "." not in s2 and "e" not in s2.lower():
            return int(v)
        return v
    except ValueError:
        return None


def arith_err(op, a, b):
    bad = a if tonum(a) is None else b
    raise LuaError(("attempt to perform arithmetic (%s) on %s" % (op, type_name(bad))).encode())


# ---------------------------------------------------------------------------
# metatable-aware primitives
# ---------------------------------------------------------------------------


class Interp:
    def __init__(self, max_steps=None):
        self.steps = 0
        self.max_steps = max_steps
        self.string_meta = None
        self.hooks = {}  # id(proto Function node) -> python replacement
        self.call_depth = 0
        self.loaded_chunks = []
        self.invoke_hooks = {}  # id(Function node) -> cb(fn, args, invoke)
        self.string_meta_table = None

    # -- indexing ----------------------------------------------------------
    def index(self, o, k):
        t = type(o)
        if t is LuaTable:
            v = o.h.get(key(k))
            if v is not None or o.meta is None:
                return v
            h = o.meta.h.get(b"__index")
            if h is None:
                return None
            if type(h) is LuaTable:
                return self.index(h, k)
            return first(self.call(h, (o, k)))
        if t is bytes:
            return self.index(self.string_meta, k)
        if t is Vector:
            if k in (b"x", b"X"):
                return o[0]
            if k in (b"y", b"Y"):
                return o[1]
            if k in (b"z", b"Z"):
                return o[2]
            if k == b"Magnitude":
                return math.sqrt(sum(c * c for c in o))
            return None
        if t is Opaque:
            return Opaque("%s.%s" % (o.kind, tostr_py(k)), ())
        raise LuaError(("attempt to index %s with %s" % (type_name(o), tostr_py(k) if type(k) is bytes else type_name(k))).encode())

    def setindex(self, o, k, v):
        if type(o) is LuaTable:
            if o.meta is not None:
                kk = key(k)
                if kk not in o.h:
                    h = o.meta.h.get(b"__newindex")
                    if h is not None:
                        if type(h) is LuaTable:
                            return self.setindex(h, k, v)
                        self.call(h, (o, k, v))
                        return
            if k is None:
                raise LuaError(b"table index is nil")
            if o.frozen:
                raise LuaError(b"attempt to modify a readonly table")
            if v is None:
                o.h.pop(key(k), None)
            else:
                o.h[key(k)] = v
            return
        raise LuaError(("attempt to index %s with %s" % (type_name(o), tostr_py(k) if type(k) is bytes else type_name(k))).encode())

    def call(self, f, args):
        t = type(f)
        if t is LuaFunction:
            return f.proto.invoke(f, args)
        if t is Builtin:
            try:
                r = f.f(*args)
            except _PYERR as e:
                raise LuaError(("%s: %s" % (f.name, e)).encode())
            except LuaError as e:
                if e.lua_traceback is None:
                    e.lua_traceback = "in builtin '%s'" % f.name
                raise
            if r is None:
                return ()
            return r
        if t is LuaTable and f.meta is not None:
            h = f.meta.h.get(b"__call")
            if h is not None:
                return self.call(h, (f,) + tuple(args))
        raise LuaError(("attempt to call a %s value" % type_name(f)).encode())

    def metaop(self, ev, a, b):
        for o in (a, b):
            if type(o) is LuaTable and o.meta is not None:
                h = o.meta.h.get(ev)
                if h is not None:
                    return first(self.call(h, (a, b)))
        return _NOMETA

    def arith(self, op, a, b):
        ta, tb = type(a), type(b)
        if (ta is int or ta is float) and (tb is int or tb is float):
            return ARITH[op](a, b)
        if ta is Vector or tb is Vector:
            return vec_arith(op, a, b)
        r = self.metaop(META_ARITH[op], a, b)
        if r is not _NOMETA:
            return r
        na, nb = tonum(a), tonum(b)
        if na is None or nb is None:
            arith_err(op, a, b)
        return ARITH[op](na, nb)

    def concat(self, a, b):
        ta, tb = type(a), type(b)
        if (ta is bytes or ta is int or ta is float) and (tb is bytes or tb is int or tb is float):
            if ta is not bytes:
                a = fmt_num(a).encode()
            if tb is not bytes:
                b = fmt_num(b).encode()
            return a + b
        r = self.metaop(b"__concat", a, b)
        if r is not _NOMETA:
            return r
        raise LuaError(("attempt to concatenate %s with %s" % (type_name(a), type_name(b))).encode())

    def eq(self, a, b):
        if a is b:
            return True
        ta, tb = type(a), type(b)
        if ta is bool or tb is bool:
            return ta is tb and a == b
        if (ta is int or ta is float) and (tb is int or tb is float):
            return a == b
        if ta is not tb:
            return False
        if ta is bytes or ta is Vector:
            return a == b
        if ta is LuaTable and a.meta is not None:
            r = self.metaop(b"__eq", a, b)
            if r is not _NOMETA:
                return truthy(r)
        return False

    def lt(self, a, b):
        ta, tb = type(a), type(b)
        if (ta is int or ta is float) and (tb is int or tb is float):
            return a < b
        if ta is bytes and tb is bytes:
            return a < b
        r = self.metaop(b"__lt", a, b)
        if r is not _NOMETA:
            return truthy(r)
        raise LuaError(("attempt to compare %s < %s" % (type_name(a), type_name(b))).encode())

    def le(self, a, b):
        ta, tb = type(a), type(b)
        if (ta is int or ta is float) and (tb is int or tb is float):
            return a <= b
        if ta is bytes and tb is bytes:
            return a <= b
        r = self.metaop(b"__le", a, b)
        if r is not _NOMETA:
            return truthy(r)
        raise LuaError(("attempt to compare %s <= %s" % (type_name(a), type_name(b))).encode())

    def length(self, o):
        t = type(o)
        if t is bytes:
            return len(o)
        if t is LuaTable:
            if o.meta is not None:
                h = o.meta.h.get(b"__len")
                if h is not None:
                    return first(self.call(h, (o,)))
            return o.length()
        raise LuaError(("attempt to get length of a %s value" % type_name(o)).encode())

    def unm(self, a):
        t = type(a)
        if t is int or t is float:
            return -a
        if t is Vector:
            return Vector(-x for x in a)
        if t is LuaTable and a.meta is not None:
            h = a.meta.h.get(b"__unm")
            if h is not None:
                return first(self.call(h, (a, a)))
        n = tonum(a)
        if n is None:
            raise LuaError(("attempt to perform arithmetic (unm) on %s" % type_name(a)).encode())
        return -n

    def tostring(self, v):
        if type(v) is LuaTable and v.meta is not None:
            h = v.meta.h.get(b"__tostring")
            if h is not None:
                return first(self.call(h, (v,)))
            n = v.meta.h.get(b"__name")
            if type(n) is bytes:
                return n + (": 0x%08x" % (id(v) & 0xFFFFFFFF)).encode()
        return tostr_py(v).encode("latin-1")


_NOMETA = object()
_PYERR = (TypeError, ValueError, IndexError, KeyError, AttributeError, OverflowError, ZeroDivisionError, struct.error)


def first(r):
    return r[0] if r else None


def _div(a, b):
    try:
        return a / b
    except ZeroDivisionError:
        if a == 0 or a != a:
            return math.nan
        return math.copysign(math.inf, a) * math.copysign(1, b)


def _mod(a, b):
    try:
        if type(a) is int and type(b) is int:
            return a % b
        if math.isinf(b):
            if a != a or math.isinf(a):
                return math.nan
            if (a >= 0) == (b > 0):
                return float(a)
            return b
        return a - math.floor(a / b) * b
    except (ZeroDivisionError, OverflowError, ValueError):
        return math.nan


def _idiv(a, b):
    try:
        return math.floor(a / b) if type(a) is float or type(b) is float else a // b
    except ZeroDivisionError:
        return _div(a, b)
    except OverflowError:
        return a / b


def _pow(a, b):
    try:
        r = float(a) ** float(b)
        if type(r) is complex:
            return math.nan
        return r
    except ZeroDivisionError:
        return math.inf
    except OverflowError:
        return math.inf


def _norm(v):
    return v


ARITH = {
    "+": lambda a, b: a + b,
    "-": lambda a, b: a - b,
    "*": lambda a, b: a * b,
    "/": _div,
    "%": _mod,
    "//": _idiv,
    "^": _pow,
}
META_ARITH = {"+": b"__add", "-": b"__sub", "*": b"__mul", "/": b"__div", "%": b"__mod", "//": b"__idiv", "^": b"__pow"}


def vec_arith(op, a, b):
    f = ARITH[op]
    if type(a) is Vector and type(b) is Vector:
        return Vector(f(x, y) for x, y in zip(a, b))
    if type(a) is Vector:
        return Vector(f(x, b) for x in a)
    return Vector(f(a, y) for y in b)


# ---------------------------------------------------------------------------
# Compiler: AST -> closures
# ---------------------------------------------------------------------------

BREAK = 1
CONTINUE = 2
RETURN = 3


class Frame:
    __slots__ = ("r", "u", "va", "ret", "fn")

    def __init__(self, nregs, upvals, va, fn):
        self.r = [None] * nregs
        self.u = upvals
        self.va = va
        self.ret = ()
        self.fn = fn


class Cell:
    __slots__ = ("v",)

    def __init__(self, v=None):
        self.v = v


class Scope:
    def __init__(self, fs, parent):
        self.fs = fs
        self.parent = parent
        self.vars = {}


class VarInfo:
    __slots__ = ("idx", "captured", "name")

    def __init__(self, idx, name):
        self.idx = idx
        self.captured = False
        self.name = name


class FuncState:
    def __init__(self, parent, node):
        self.parent = parent
        self.node = node
        self.nregs = 0
        self.upvals = []  # list of (from_parent_is_local, index, VarInfo)
        self.upmap = {}  # id(VarInfo) -> upvalue index


class Proto:
    __slots__ = ("name", "nregs", "params", "vararg", "body", "interp", "upsrc", "node", "nparams")

    def invoke(self, fn, args):
        it = self.interp
        it.call_depth += 1
        if it.call_depth > 7000:
            it.call_depth = 0
            raise LuaError(b"stack overflow")
        fr = Frame(self.nregs, fn.upvals, None, fn)
        r = fr.r
        np = self.nparams
        params = self.params
        la = len(args)
        for i in range(np):
            idx, cap = params[i]
            v = args[i] if i < la else None
            r[idx] = Cell(v) if cap else v
        if self.vararg:
            fr.va = tuple(args[np:]) if la > np else ()
        try:
            sig = self.body(fr)
        finally:
            it.call_depth -= 1
        if sig == RETURN:
            return fr.ret
        return ()


class HookedProto:
    __slots__ = ("inner", "cb", "name", "upsrc", "node")

    def __init__(self, inner, cb):
        self.inner = inner
        self.cb = cb
        self.name = inner.name
        self.upsrc = inner.upsrc
        self.node = inner.node

    def invoke(self, fn, args):
        return self.cb(fn, args, self.inner.invoke)


class StopEmulation(Exception):
    def __init__(self, value):
        Exception.__init__(self, "stop")
        self.value = value


class Compiler:
    """Resolves scopes and produces closures."""

    def __init__(self, interp, env, chunkname="chunk"):
        self.it = interp
        self.env = env
        self.chunkname = chunkname

    # -- scope helpers -----------------------------------------------------
    def declare(self, scope, name):
        fs = scope.fs
        vi = VarInfo(fs.nregs, name)
        fs.nregs += 1
        scope.vars[name] = vi
        return vi

    def resolve(self, scope, name):
        """returns ('local', VarInfo) | ('up', idx) | ('global', None)"""
        s = scope
        fs = scope.fs
        while s is not None and s.fs is fs:
            if name in s.vars:
                return ("local", s.vars[name])
            s = s.parent
        # search enclosing functions
        if s is None:
            return ("global", None)
        res = self.resolve(s, name)
        if res[0] == "global":
            return res
        if res[0] == "local":
            vi = res[1]
            vi.captured = True
            k = ("L", id(vi))
            if k not in fs.upmap:
                fs.upmap[k] = len(fs.upvals)
                fs.upvals.append(("local", vi))
            return ("up", fs.upmap[k])
        # upvalue of parent
        pidx = res[1]
        k = ("U", pidx)
        if k not in fs.upmap:
            fs.upmap[k] = len(fs.upvals)
            fs.upvals.append(("up", pidx))
        return ("up", fs.upmap[k])

    # Two passes would be needed to know whether a local is captured before
    # emitting code for its declaration.  We pre-scan instead.
    def compile_chunk(self, block):
        fnode = A.Function([], True, block.body, self.chunkname)
        proto = self.compile_function(fnode, None)
        return LuaFunction(proto, [], self.env)

    def compile_function(self, fnode, scope):
        fs = FuncState(scope.fs if scope else None, fnode)
        sc = Scope(fs, scope)
        captured = self.prescan_captures(fnode)
        params = []
        for p in fnode.params:
            vi = self.declare(sc, p)
            params.append(vi)
        body = self.block(fnode.body, sc, captured)
        proto = Proto()
        proto.name = fnode.name
        proto.interp = self.it
        proto.nregs = fs.nregs
        proto.params = [(vi.idx, vi.captured) for vi in params]
        proto.nparams = len(params)
        proto.vararg = fnode.is_vararg
        proto.body = body
        proto.upsrc = fs.upvals
        proto.node = fnode
        hook = self.it.invoke_hooks.get(id(fnode))
        if hook is not None:
            proto = HookedProto(proto, hook)
        return proto

    def prescan_captures(self, fnode):
        return None

    # -- blocks/statements -------------------------------------------------
    def block(self, stmts, scope, captured=None, new_scope=False):
        if new_scope:
            scope = Scope(scope.fs, scope)
        fns = [self.stat(s, scope) for s in stmts]
        fns = [f for f in fns if f is not None]
        if not fns:
            return lambda fr: None
        if len(fns) == 1:
            return fns[0]
        if len(fns) == 2:
            f0, f1 = fns

            def run2(fr):
                s = f0(fr)
                if s:
                    return s
                return f1(fr)

            return run2
        fns = tuple(fns)

        def run(fr):
            for f in fns:
                s = f(fr)
                if s:
                    return s
            return None

        return run

    def stat(self, s, scope):
        t = type(s)
        m = getattr(self, "st_" + t.__name__)
        return m(s, scope)

    def st_Comment(self, s, scope):
        return None

    def st_Do(self, s, scope):
        return self.block(s.body, scope, new_scope=True)

    def st_Local(self, s, scope):
        vals = s.values
        nv = len(s.names)
        # values are evaluated in the outer scope before declaring names
        if not vals:
            infos = [self.declare(scope, n) for n in s.names]

            def run(fr):
                r = fr.r
                for vi in infos:
                    r[vi.idx] = Cell() if vi.captured else None

            return run
        if nv == 1 and len(vals) == 1:
            ev = self.expr1(vals[0], scope)
            vi = self.declare(scope, s.names[0])
            idx = vi.idx

            def run(fr):
                v = ev(fr)
                if vi.captured:
                    fr.r[idx] = Cell(v)
                else:
                    fr.r[idx] = v

            return run
        evm = self.exprlist(vals, scope, nv)
        infos = [self.declare(scope, n) for n in s.names]

        def run(fr):
            vs = evm(fr)
            r = fr.r
            for i, vi in enumerate(infos):
                v = vs[i] if i < len(vs) else None
                r[vi.idx] = Cell(v) if vi.captured else v

        return run

    def st_LocalFunction(self, s, scope):
        vi = self.declare(scope, s.name)
        mk = self.closure(s.func, scope)
        idx = vi.idx

        def run(fr):
            if vi.captured:
                c = Cell()
                fr.r[idx] = c
                c.v = mk(fr)
            else:
                fr.r[idx] = mk(fr)

        return run

    def st_FunctionStat(self, s, scope):
        mk = self.closure(s.func, scope)
        return self.assign_to(s.target, scope, mk)

    def assign_to(self, target, scope, ev):
        t = type(target)
        if t is A.Name:
            kind, info = self.resolve(scope, target.name)
            if kind == "local":
                vi = info
                idx = vi.idx

                def run(fr):
                    v = ev(fr)
                    if vi.captured:
                        fr.r[idx].v = v
                    else:
                        fr.r[idx] = v

                return run
            if kind == "up":
                ui = info

                def run(fr):
                    fr.u[ui].v = ev(fr)

                return run
            name = target.name.encode()
            it = self.it

            def run(fr):
                it.setindex(fr.fn.env, name, ev(fr))

            return run
        if t is A.Index:
            eo = self.expr1(target.obj, scope)
            ek = self.expr1(target.key, scope)
            it = self.it

            def run(fr):
                o = eo(fr)
                k = ek(fr)
                v = ev(fr)
                if type(o) is LuaTable and o.meta is None:
                    if v is None:
                        o.h.pop(key(k), None)
                    else:
                        if k is None:
                            raise LuaError(b"table index is nil")
                        o.h[key(k)] = v
                else:
                    it.setindex(o, k, v)

            return run
        raise LuaError(b"cannot assign")

    def setter(self, target, scope):
        """returns (prep(fr)->state, store(fr, state, v))"""
        t = type(target)
        if t is A.Name:
            kind, info = self.resolve(scope, target.name)
            if kind == "local":
                vi = info
                idx = vi.idx

                def store(fr, st, v):
                    if vi.captured:
                        fr.r[idx].v = v
                    else:
                        fr.r[idx] = v

                return (lambda fr: None), store
            if kind == "up":
                ui = info

                def store(fr, st, v):
                    fr.u[ui].v = v

                return (lambda fr: None), store
            name = target.name.encode()
            it = self.it

            def store(fr, st, v):
                it.setindex(fr.fn.env, name, v)

            return (lambda fr: None), store
        eo = self.expr1(target.obj, scope)
        ek = self.expr1(target.key, scope)
        it = self.it

        def prep(fr):
            return (eo(fr), ek(fr))

        def store(fr, st, v):
            it.setindex(st[0], st[1], v)

        return prep, store

    def st_Assign(self, s, scope):
        if len(s.targets) == 1 and len(s.values) == 1:
            return self.assign_to(s.targets[0], scope, self.expr1(s.values[0], scope))
        setters = [self.setter(t, scope) for t in s.targets]
        evm = self.exprlist(s.values, scope, len(s.targets))

        def run(fr):
            states = [p(fr) for p, _ in setters]
            vs = evm(fr)
            for i, (p, st) in enumerate(setters):
                st(fr, states[i], vs[i] if i < len(vs) else None)

        return run

    def st_CompoundAssign(self, s, scope):
        prep, store = self.setter(s.target, scope)
        ev = self.expr1(s.value, scope)
        it = self.it
        op = s.op
        tgt = s.target
        if type(tgt) is A.Index:
            eo = self.expr1(tgt.obj, scope)
            ek = self.expr1(tgt.key, scope)

            def run(fr):
                o = eo(fr)
                k = ek(fr)
                cur = it.index(o, k)
                v = ev(fr)
                nv = it.concat(cur, v) if op == ".." else it.arith(op, cur, v)
                it.setindex(o, k, nv)

            return run
        getter = self.expr1(tgt, scope)
        if op == "..":
            def run(fr):
                store(fr, None, it.concat(getter(fr), ev(fr)))
        else:
            fop = ARITH[op]

            def run(fr):
                a = getter(fr)
                b = ev(fr)
                ta, tb = type(a), type(b)
                if (ta is int or ta is float) and (tb is int or tb is float):
                    store(fr, None, fop(a, b))
                else:
                    store(fr, None, it.arith(op, a, b))

        return run

    def st_CallStat(self, s, scope):
        evm = self.exprmulti(s.call, scope)

        def run(fr):
            evm(fr)

        return run

    def st_Return(self, s, scope):
        vals = s.values
        if len(vals) == 1 and type(vals[0]) in (A.Call, A.MethodCall):
            # proper tail call semantics are not required; plain call
            ev = self.exprmulti(vals[0], scope)

            def run(fr):
                fr.ret = ev(fr)
                return RETURN

            return run
        evm = self.exprlist(vals, scope, None)

        def run(fr):
            fr.ret = evm(fr)
            return RETURN

        return run

    def st_Break(self, s, scope):
        return lambda fr: BREAK

    def st_Continue(self, s, scope):
        return lambda fr: CONTINUE

    def st_While(self, s, scope):
        ec = self.expr1(s.cond, scope)
        body = self.block(s.body, scope, new_scope=True)
        it = self.it

        def run(fr):
            while True:
                c = ec(fr)
                if c is None or c is False:
                    return None
                sig = body(fr)
                if sig:
                    if sig == BREAK:
                        return None
                    if sig == RETURN:
                        return sig
            return None

        return run

    def st_Repeat(self, s, scope):
        inner = Scope(scope.fs, scope)
        body = self.block(s.body, inner)
        ec = self.expr1(s.cond, inner)

        def run(fr):
            while True:
                sig = body(fr)
                if sig:
                    if sig == BREAK:
                        return None
                    if sig == RETURN:
                        return sig
                c = ec(fr)
                if c is not None and c is not False:
                    return None

        return run

    def st_If(self, s, scope):
        clauses = [(self.expr1(c, scope), self.block(b, scope, new_scope=True)) for c, b in s.clauses]
        orelse = self.block(s.orelse, scope, new_scope=True) if s.orelse else None
        if len(clauses) == 1:
            c0, b0 = clauses[0]
            if orelse is None:
                def run(fr):
                    c = c0(fr)
                    if c is not None and c is not False:
                        return b0(fr)
                    return None
            else:
                def run(fr):
                    c = c0(fr)
                    if c is not None and c is not False:
                        return b0(fr)
                    return orelse(fr)
            return run

        def run(fr):
            for ec, b in clauses:
                c = ec(fr)
                if c is not None and c is not False:
                    return b(fr)
            if orelse is not None:
                return orelse(fr)
            return None

        return run

    def st_NumericFor(self, s, scope):
        e1 = self.expr1(s.start, scope)
        e2 = self.expr1(s.stop, scope)
        e3 = self.expr1(s.step, scope) if s.step is not None else None
        inner = Scope(scope.fs, scope)
        vi = self.declare(inner, s.var)
        body = self.block(s.body, inner, new_scope=True)
        idx = vi.idx

        def run(fr):
            a = tonum(e1(fr))
            b = tonum(e2(fr))
            st = tonum(e3(fr)) if e3 else 1
            if a is None or b is None or st is None:
                raise LuaError(b"invalid 'for' initial value (number expected)")
            if st == 0:
                raise LuaError(b"'for' step is zero")
            i = a
            r = fr.r
            cap = vi.captured
            if st > 0:
                while i <= b:
                    r[idx] = Cell(i) if cap else i
                    sig = body(fr)
                    if sig:
                        if sig == BREAK:
                            break
                        if sig == RETURN:
                            return sig
                    i += st
            else:
                while i >= b:
                    r[idx] = Cell(i) if cap else i
                    sig = body(fr)
                    if sig:
                        if sig == BREAK:
                            break
                        if sig == RETURN:
                            return sig
                    i += st
            return None

        return run

    def st_GenericFor(self, s, scope):
        evm = self.exprlist(s.exprs, scope, 3)
        inner = Scope(scope.fs, scope)
        infos = [self.declare(inner, n) for n in s.names]
        body = self.block(s.body, inner, new_scope=True)
        it = self.it

        def run(fr):
            vs = evm(fr)
            f, st, ctl = (list(vs) + [None, None, None])[:3]
            r = fr.r
            # Luau generalized iteration over tables
            if type(f) is LuaTable and (f.meta is None or b"__call" not in f.meta.h):
                if f.meta is not None and b"__iter" in f.meta.h:
                    vs2 = it.call(f.meta.h[b"__iter"], (f,))
                    f, st, ctl = (list(vs2) + [None, None, None])[:3]
                else:
                    f, st, ctl = BUILTIN_NEXT, f, None
            while True:
                rs = it.call(f, (st, ctl))
                v0 = rs[0] if rs else None
                if v0 is None:
                    return None
                ctl = v0
                for i, vi in enumerate(infos):
                    v = rs[i] if i < len(rs) else None
                    r[vi.idx] = Cell(v) if vi.captured else v
                sig = body(fr)
                if sig:
                    if sig == BREAK:
                        return None
                    if sig == RETURN:
                        return sig

        return run

    # -- expressions -------------------------------------------------------
    def closure(self, fnode, scope):
        proto = self.it.hooks.get(id(fnode)) or self.compile_function(fnode, scope)
        upsrc = proto.upsrc
        env = self.env

        def mk(fr):
            ups = []
            for kind, ref in upsrc:
                if kind == "local":
                    ups.append(fr.r[ref.idx])
                else:
                    ups.append(fr.u[ref])
            return LuaFunction(proto, ups, fr.fn.env if fr.fn is not None else env)

        return mk

    def exprlist(self, exprs, scope, want):
        """returns f(fr) -> tuple of values (expanding last multi expr)"""
        if not exprs:
            return lambda fr: ()
        evs = [self.expr1(e, scope) for e in exprs[:-1]]
        last = exprs[-1]
        if type(last) in (A.Call, A.MethodCall, A.Vararg):
            evl = self.exprmulti(last, scope)

            def run(fr):
                return tuple(e(fr) for e in evs) + tuple(evl(fr))

            return run
        evs.append(self.expr1(last, scope))
        evs = tuple(evs)

        def run(fr):
            return tuple(e(fr) for e in evs)

        return run

    def exprmulti(self, e, scope):
        t = type(e)
        it = self.it
        if t is A.Vararg:
            return lambda fr: fr.va
        if t is A.Call:
            ef = self.expr1(e.func, scope)
            ea = self.exprlist(e.args, scope, None)
            callnode = e
            if type(e.func) is A.Index:
                _eo = self.expr1(e.func.obj, scope)
                _ek = self.expr1(e.func.key, scope)
            else:
                _eo = _ek = None

            def run(fr):
                f = ef(fr)
                args = ea(fr)
                tf = type(f)
                if tf is LuaFunction:
                    return f.proto.invoke(f, args)
                if tf is Builtin:
                    try:
                        r = f.f(*args)
                    except _PYERR as e:
                        raise LuaError(("%s: %s" % (f.name, e)).encode())
                    except LuaError as e:
                        if e.lua_traceback is None:
                            e.lua_traceback = "in builtin '%s'" % f.name
                        raise
                    return () if r is None else r
                if f is None:
                    desc = _short_src(callnode.func)
                    if _eo is not None:
                        try:
                            k = _ek(fr)
                            desc = "field '%s'" % (tostr_py(k) if type(k) in (bytes, int, float) else type_name(k))
                        except Exception:
                            pass
                    raise LuaError(("attempt to call a nil value (%s)" % desc).encode())
                return it.call(f, args)

            return run
        if t is A.MethodCall:
            eo = self.expr1(e.obj, scope)
            name = e.name.encode()
            ea = self.exprlist(e.args, scope, None)

            def run(fr):
                o = eo(fr)
                f = it.index(o, name)
                if f is None:
                    raise LuaError(("attempt to call method '%s' (a nil value)" % e.name).encode())
                return it.call(f, (o,) + tuple(ea(fr)))

            return run
        ev = self.expr1(e, scope)
        return lambda fr: (ev(fr),)

    def expr1(self, e, scope):
        t = type(e)
        it = self.it
        if t is A.Number:
            v = e.value
            return lambda fr: v
        if t is A.String:
            v = e.value
            return lambda fr: v
        if t is A.Nil:
            return lambda fr: None
        if t is A.TrueE:
            return lambda fr: True
        if t is A.FalseE:
            return lambda fr: False
        if t is A.Vararg:
            return lambda fr: fr.va[0] if fr.va else None
        if t is A.Paren:
            return self.expr1(e.expr, scope)
        if t is A.Name:
            kind, info = self.resolve(scope, e.name)
            if kind == "local":
                idx = info.idx
                vi = info
                # capture flag may flip later during compilation of inner
                # closures, so check at runtime.
                def run(fr):
                    v = fr.r[idx]
                    if vi.captured:
                        return v.v
                    return v

                return run
            if kind == "up":
                ui = info
                return lambda fr: fr.u[ui].v
            name = e.name.encode()

            def run(fr):
                env = fr.fn.env
                v = env.h.get(name)
                if v is None and env.meta is not None:
                    return it.index(env, name)
                return v

            return run
        if t is A.Index:
            eo = self.expr1(e.obj, scope)
            if type(e.key) is A.String or type(e.key) is A.Number:
                kv = e.key.value
                kk = key(kv)

                def run(fr):
                    o = eo(fr)
                    if type(o) is LuaTable:
                        v = o.h.get(kk)
                        if v is not None or o.meta is None:
                            return v
                    return it.index(o, kv)

                return run
            ek = self.expr1(e.key, scope)

            def run(fr):
                o = eo(fr)
                k = ek(fr)
                if type(o) is LuaTable:
                    tk = type(k)
                    v = o.h.get(int(k) if tk is float and k.is_integer() else (key(k) if tk is bool else k))
                    if v is not None or o.meta is None:
                        return v
                return it.index(o, k)

            return run
        if t is A.Call or t is A.MethodCall:
            em = self.exprmulti(e, scope)

            def run(fr):
                r = em(fr)
                return r[0] if r else None

            return run
        if t is A.Function:
            return self.closure(e, scope)
        if t is A.Table:
            return self.table(e, scope)
        if t is A.BinOp:
            return self.binop(e, scope)
        if t is A.UnOp:
            ev = self.expr1(e.operand, scope)
            if e.op == "not":
                return lambda fr: not truthy(ev(fr))
            if e.op == "-":
                def run(fr):
                    v = ev(fr)
                    tv = type(v)
                    if tv is int or tv is float:
                        return -v
                    return it.unm(v)

                return run
            if e.op == "#":
                def run(fr):
                    v = ev(fr)
                    if type(v) is bytes:
                        return len(v)
                    return it.length(v)

                return run
        if t is A.IfExpr:
            ec = self.expr1(e.cond, scope)
            ea = self.expr1(e.then, scope)
            eb = self.expr1(e.orelse, scope)

            def run(fr):
                c = ec(fr)
                return ea(fr) if (c is not None and c is not False) else eb(fr)

            return run
        raise LuaError(("cannot compile %s" % t.__name__).encode())

    def table(self, e, scope):
        parts = []
        it = self.it
        n = len(e.items)
        for i, (kind, k, v) in enumerate(e.items):
            if kind == "pos":
                if i == n - 1 and type(v) in (A.Call, A.MethodCall, A.Vararg):
                    parts.append(("multi", None, self.exprmulti(v, scope)))
                else:
                    parts.append(("pos", None, self.expr1(v, scope)))
            else:
                parts.append(("kv", self.expr1(k, scope), self.expr1(v, scope)))
        parts = tuple(parts)

        def run(fr):
            h = {}
            ai = 1
            for kind, ek, ev in parts:
                if kind == "pos":
                    v = ev(fr)
                    if v is not None:
                        h[ai] = v
                    ai += 1
                elif kind == "multi":
                    for v in ev(fr):
                        if v is not None:
                            h[ai] = v
                        ai += 1
                else:
                    k = ek(fr)
                    if k is None:
                        raise LuaError(b"table index is nil")
                    v = ev(fr)
                    if v is not None:
                        h[key(k)] = v
            t = LuaTable(h)
            if ai > 2 and len(h) < ai - 1:
                t.asize = ai - 1  # holes: keep constructor array size
            return t

        return run

    def binop(self, e, scope):
        op = e.op
        it = self.it
        ea = self.expr1(e.left, scope)
        eb = self.expr1(e.right, scope)
        if op == "and":
            def run(fr):
                a = ea(fr)
                if a is None or a is False:
                    return a
                return eb(fr)

            return run
        if op == "or":
            def run(fr):
                a = ea(fr)
                if a is None or a is False:
                    return eb(fr)
                return a

            return run
        if op in ARITH:
            f = ARITH[op]
            if op == "+":
                def run(fr):
                    a = ea(fr)
                    b = eb(fr)
                    ta = type(a)
                    tb = type(b)
                    if (ta is int or ta is float) and (tb is int or tb is float):
                        return a + b
                    return _ar(it, "+", a, b, e)
            elif op == "-":
                def run(fr):
                    a = ea(fr)
                    b = eb(fr)
                    ta = type(a)
                    tb = type(b)
                    if (ta is int or ta is float) and (tb is int or tb is float):
                        return a - b
                    return _ar(it, "-", a, b, e)
            elif op == "*":
                def run(fr):
                    a = ea(fr)
                    b = eb(fr)
                    ta = type(a)
                    tb = type(b)
                    if (ta is int or ta is float) and (tb is int or tb is float):
                        return a * b
                    return _ar(it, "*", a, b, e)
            else:
                def run(fr):
                    a = ea(fr)
                    b = eb(fr)
                    ta = type(a)
                    tb = type(b)
                    if (ta is int or ta is float) and (tb is int or tb is float):
                        return f(a, b)
                    return _ar(it, op, a, b, e)

            return run
        if op == "..":
            return lambda fr: it.concat(ea(fr), eb(fr))
        if op == "==":
            return lambda fr: it.eq(ea(fr), eb(fr))
        if op == "~=":
            return lambda fr: not it.eq(ea(fr), eb(fr))
        if op == "<":
            def run(fr):
                a = ea(fr)
                b = eb(fr)
                ta = type(a)
                tb = type(b)
                if (ta is int or ta is float) and (tb is int or tb is float):
                    return a < b
                return it.lt(a, b)

            return run
        if op == "<=":
            def run(fr):
                a = ea(fr)
                b = eb(fr)
                ta = type(a)
                tb = type(b)
                if (ta is int or ta is float) and (tb is int or tb is float):
                    return a <= b
                return it.le(a, b)

            return run
        if op == ">":
            def run(fr):
                a = ea(fr)
                b = eb(fr)
                ta = type(a)
                tb = type(b)
                if (ta is int or ta is float) and (tb is int or tb is float):
                    return a > b
                return it.lt(b, a)

            return run
        if op == ">=":
            def run(fr):
                a = ea(fr)
                b = eb(fr)
                ta = type(a)
                tb = type(b)
                if (ta is int or ta is float) and (tb is int or tb is float):
                    return a >= b
                return it.le(b, a)

            return run
        raise LuaError(("bad binop %s" % op).encode())


def _ar(it, op, a, b, node):
    try:
        return it.arith(op, a, b)
    except LuaError as ex:
        if ex.lua_traceback is None:
            ex.lua_traceback = "in `%s`" % _short_src(node)
        raise


def _short_src(node):
    try:
        return A.to_source(A.Block([A.CallStat(A.Call(node, []))])).strip()[:60]
    except Exception:
        return type(node).__name__


def _builtin_next(t, k=None):
    h = t.h
    if k is None:
        for kk in h:
            keys = list(h.keys())
            _NEXT_CACHE[id(t)] = (h, len(h), keys, {kx: i for i, kx in enumerate(keys)})
            return (unkey(kk), h[kk])
        return (None,)
    kk = key(k)
    # O(n) next: keep an iteration cache keyed by table id
    cache = _NEXT_CACHE.get(id(t))
    if cache is None or cache[0] is not h or kk not in cache[3]:
        # (a cache built earlier stays valid while fields are only removed
        #  during traversal, which Lua allows)
        keys = list(h.keys())
        pos = {kx: i for i, kx in enumerate(keys)}
        cache = (h, len(h), keys, pos)
        _NEXT_CACHE[id(t)] = cache
    _, _, keys, pos = cache
    i = pos.get(kk)
    if i is None:
        return (None,)  # key vanished (table cleared during traversal): end of iteration
    i += 1
    while i < len(keys):
        kx = keys[i]
        if kx in h:
            return (unkey(kx), h[kx])
        i += 1
    return (None,)


_NEXT_CACHE = {}
BUILTIN_NEXT = Builtin(_builtin_next, "next")
