"""A small sandboxed Lua interpreter over our AST.

It is only used to evaluate *pure* decoder code that the obfuscator embeds in
the output (string pools, ConstantArray decoders, EncryptStrings decryptor,
VM data reconstruction).  It has no I/O, no debug library, no access to the
host and a hard step budget, so the obfuscated program itself is never run.
"""

import math

from .luaast import (Nil, Bool, Number, String, Vararg, Name, Index, Call, Method, Func, Table, Bin, Un, Paren,
                     Local, Assign, CallStat, Do, While, Repeat, If, NumFor, GenFor, LocalFunc, FuncStat, Return,
                     Break, Chunk)
from .luavalue import LuaError, arith, tostr_concat, truthy, num2str, tonum, str2num


# Standard (and common host) globals the sandbox does not provide: reading one must abort the
# emulation instead of silently yielding nil.  Any other undefined global reads as nil, which is how
# WeAreDevs spells `nil` (a read of a random, never-defined name).
KNOWN_GLOBALS = set("""_G _ENV _VERSION assert collectgarbage coroutine debug dofile error gcinfo getfenv
getmetatable io ipairs load loadfile loadstring math module newproxy next os package pairs pcall print rawequal
rawget rawset require select setfenv setmetatable string table tonumber tostring type unpack xpcall bit bit32
utf8 game workspace script wait spawn delay tick time warn typeof Instance Vector3 Vector2 CFrame Color3 Enum
task shared""".split())


class EmuAbort(Exception):
    """Raised when the code is not emulatable (impure, unknown, too long...)."""


class LuaTable(object):
    __slots__ = ("hash", "mt", "tag")

    def __init__(self):
        self.hash = {}
        self.mt = None
        self.tag = None

    def length(self):
        n = 0
        h = self.hash
        while (n + 1.0) in h:
            n += 1
        return float(n)

    def __repr__(self):
        return "<LuaTable %d>" % len(self.hash)


class Closure(object):
    __slots__ = ("func", "scope")

    def __init__(self, func, scope):
        self.func = func
        self.scope = scope


class Builtin(object):
    __slots__ = ("name", "fn", "qualname")

    def __init__(self, name, fn):
        self.name = name
        self.fn = fn
        self.qualname = name


class Scope(object):
    __slots__ = ("vars", "parent")

    def __init__(self, parent=None):
        self.vars = {}
        self.parent = parent

    def lookup(self, sym):
        s = self
        while s is not None:
            c = s.vars.get(sym)
            if c is not None:
                return c
            s = s.parent
        return None


def key_of(v):
    if isinstance(v, float) and v == int(v):
        return float(v)
    if v is None:
        raise LuaError("table index is nil")
    if isinstance(v, float) and v != v:
        raise LuaError("table index is NaN")
    return v


def ltype(v):
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "boolean"
    if isinstance(v, float):
        return "number"
    if isinstance(v, str):
        return "string"
    if isinstance(v, LuaTable):
        return "table"
    if isinstance(v, (Closure, Builtin)):
        return "function"
    return "userdata"


class _Break(Exception):
    pass


class Emulator(object):
    def __init__(self, budget=5000000):
        self.budget = budget
        self.steps = 0
        self.G = LuaTable()
        self.rng_state = 12345
        self.dynamic_globals = set()
        self.guard_read_syms = None
        self.guard_write_syms = None
        self.guard_read_cells = None
        self.guard_write_cells = None
        self.guard_read_tables = None
        self.guard_write_tables = None
        self.strict_tables = set()
        self.full = False
        self._install()

    # ------------------------------------------------------------- builtins
    def _install(self):
        G = self.G

        def reg(tbl, name, fn):
            tbl.hash[name] = Builtin(name, fn)

        def arg(a, i, default=None):
            return a[i] if i < len(a) else default

        def checknum(v, fname):
            n = tonum(v)
            if n is None:
                raise LuaError("bad argument to '%s' (number expected)" % fname)
            return n

        def checkint(v, fname):
            return int(math.floor(checknum(v, fname)))

        def checkstr(v, fname):
            if isinstance(v, str):
                return v
            if isinstance(v, float):
                return num2str(v)
            raise LuaError("bad argument to '%s' (string expected)" % fname)

        # --- string
        S = LuaTable()

        def s_sub(a):
            s = checkstr(arg(a, 0), "sub")
            i = checkint(arg(a, 1, 1.0), "sub")
            j = checkint(arg(a, 2, -1.0), "sub")
            n = len(s)
            if i < 0:
                i = max(n + i + 1, 1)
            elif i == 0:
                i = 1
            if j < 0:
                j = n + j + 1
            elif j > n:
                j = n
            return [s[i - 1:j]] if i <= j else [""]

        def s_byte(a):
            s = checkstr(arg(a, 0), "byte")
            i = checkint(arg(a, 1, 1.0), "byte")
            j = checkint(arg(a, 2, float(i)), "byte")
            n = len(s)
            if i < 0:
                i = n + i + 1
            if j < 0:
                j = n + j + 1
            i = max(i, 1)
            j = min(j, n)
            return [float(ord(c)) for c in s[i - 1:j]]

        def s_char(a):
            out = []
            for v in a:
                c = checkint(v, "char")
                if c < 0 or c > 255:
                    raise LuaError("invalid value to 'char'")
                out.append(chr(c))
            return ["".join(out)]

        def s_rep(a):
            s = checkstr(arg(a, 0), "rep")
            n = checkint(arg(a, 1), "rep")
            if n * len(s) > 10000000:
                raise EmuAbort("string too large")
            return [s * max(n, 0)]

        reg(S, "sub", s_sub)
        reg(S, "byte", s_byte)
        reg(S, "char", s_char)
        reg(S, "rep", s_rep)
        reg(S, "len", lambda a: [float(len(checkstr(arg(a, 0), "len")))])
        reg(S, "upper", lambda a: [checkstr(arg(a, 0), "upper").upper()])
        reg(S, "lower", lambda a: [checkstr(arg(a, 0), "lower").lower()])
        reg(S, "reverse", lambda a: [checkstr(arg(a, 0), "reverse")[::-1]])

        def s_format(a):
            fmt = checkstr(arg(a, 0), "format")
            out, i, k = [], 0, 1
            while i < len(fmt):
                c = fmt[i]
                if c != "%":
                    out.append(c)
                    i += 1
                    continue
                j = i + 1
                while j < len(fmt) and fmt[j] in "-+ #0123456789.":
                    j += 1
                spec, conv = fmt[i:j], fmt[j]
                i = j + 1
                if conv == "%":
                    out.append("%")
                    continue
                v = arg(a, k)
                k += 1
                if conv in "di":
                    out.append((spec + "d") % checkint(v, "format"))
                elif conv in "xXo":
                    out.append((spec + conv) % checkint(v, "format"))
                elif conv in "eEfgG":
                    out.append((spec + conv) % checknum(v, "format"))
                elif conv == "s":
                    out.append((spec + "s") % self.tostring(v))
                elif conv == "q":
                    out.append('"' + checkstr(v, "format").replace("\\", "\\\\").replace('"', '\\"') + '"')
                elif conv == "c":
                    out.append(chr(checkint(v, "format")))
                else:
                    raise EmuAbort("format %" + conv)
            return ["".join(out)]

        reg(S, "format", s_format)
        G.hash["string"] = S
        self.string_lib = S

        # --- math
        M = LuaTable()
        reg(M, "floor", lambda a: [float(math.floor(checknum(arg(a, 0), "floor")))])
        reg(M, "ceil", lambda a: [float(math.ceil(checknum(arg(a, 0), "ceil")))])
        reg(M, "abs", lambda a: [abs(checknum(arg(a, 0), "abs"))])
        reg(M, "sqrt", lambda a: [math.sqrt(checknum(arg(a, 0), "sqrt"))])
        reg(M, "max", lambda a: [max(checknum(x, "max") for x in a)])
        reg(M, "min", lambda a: [min(checknum(x, "min") for x in a)])
        reg(M, "fmod", lambda a: [math.fmod(checknum(arg(a, 0), "fmod"), checknum(arg(a, 1), "fmod"))])
        reg(M, "exp", lambda a: [math.exp(checknum(arg(a, 0), "exp"))])
        reg(M, "log", lambda a: [math.log(checknum(arg(a, 0), "log"))])
        reg(M, "log10", lambda a: [math.log10(checknum(arg(a, 0), "log10"))])
        reg(M, "pow", lambda a: [arith("^", checknum(arg(a, 0), "pow"), checknum(arg(a, 1), "pow"))])

        def m_modf(a):
            x = checknum(arg(a, 0), "modf")
            ip = float(math.floor(x)) if x >= 0 else float(math.ceil(x))
            return [ip, x - ip]

        reg(M, "modf", m_modf)

        def m_random(a):
            # deterministic LCG; decoders only use it for shuffles whose result is order independent
            self.rng_state = (self.rng_state * 1103515245 + 12345) % 2147483648
            r = self.rng_state / 2147483648.0
            if not a:
                return [r]
            if len(a) == 1:
                lo, hi = 1, checkint(a[0], "random")
            else:
                lo, hi = checkint(a[0], "random"), checkint(a[1], "random")
            if lo > hi:
                raise LuaError("interval is empty")
            return [float(lo + int(r * (hi - lo + 1)))]

        reg(M, "random", m_random)
        reg(M, "randomseed", lambda a: [])
        M.hash["huge"] = math.inf
        M.hash["pi"] = math.pi
        G.hash["math"] = M

        # --- table
        T = LuaTable()

        def t_insert(a):
            t = arg(a, 0)
            if not isinstance(t, LuaTable):
                raise LuaError("bad argument to 'insert'")
            n = int(t.length())
            if len(a) == 2:
                t.hash[float(n + 1)] = a[1]
            else:
                pos = checkint(a[1], "insert")
                for i in range(n, pos - 1, -1):
                    t.hash[float(i + 1)] = t.hash.get(float(i))
                t.hash[float(pos)] = a[2]
            return []

        def t_remove(a):
            t = arg(a, 0)
            if not isinstance(t, LuaTable):
                raise LuaError("bad argument to 'remove'")
            n = int(t.length())
            if n == 0:
                return [None]
            pos = checkint(arg(a, 1, float(n)), "remove")
            v = t.hash.get(float(pos))
            for i in range(pos, n):
                t.hash[float(i)] = t.hash.get(float(i + 1))
            t.hash.pop(float(n), None)
            return [v]

        def t_concat(a):
            t = arg(a, 0)
            sep = checkstr(arg(a, 1, ""), "concat") if arg(a, 1) is not None else ""
            i = checkint(arg(a, 2, 1.0), "concat")
            j = checkint(arg(a, 3, t.length()), "concat") if arg(a, 3) is not None else int(t.length())
            parts = []
            for k in range(i, j + 1):
                v = t.hash.get(float(k))
                s = tostr_concat(v)
                if s is None:
                    raise LuaError("invalid value (at index %d) in table for 'concat'" % k)
                parts.append(s)
            return [sep.join(parts)]

        def unpack(a):
            t = arg(a, 0)
            if not isinstance(t, LuaTable):
                raise LuaError("bad argument to 'unpack'")
            i = checkint(arg(a, 1, 1.0), "unpack") if arg(a, 1) is not None else 1
            j = checkint(arg(a, 2), "unpack") if arg(a, 2) is not None else int(t.length())
            if j - i > 100000:
                raise EmuAbort("unpack too large")
            return [t.hash.get(float(k)) for k in range(i, j + 1)]

        reg(T, "insert", t_insert)
        reg(T, "remove", t_remove)
        reg(T, "concat", t_concat)
        reg(T, "unpack", unpack)
        G.hash["table"] = T
        reg(G, "unpack", unpack)

        def select(a):
            n = arg(a, 0)
            if n == "#":
                return [float(len(a) - 1)]
            i = checkint(n, "select")
            if i < 0:
                i = len(a) - 1 + i + 1
            if i < 1:
                raise LuaError("bad argument #1 to 'select'")
            return list(a[i:])

        reg(G, "select", select)
        reg(G, "type", lambda a: [ltype(arg(a, 0))])

        def tonumber(a):
            v = arg(a, 0)
            base = arg(a, 1)
            if base is None:
                return [tonum(v)]
            b = checkint(base, "tonumber")
            try:
                return [float(int(checkstr(v, "tonumber").strip(), b))]
            except ValueError:
                return [None]

        reg(G, "tonumber", tonumber)
        reg(G, "tostring", lambda a: [self.tostring(arg(a, 0))])

        def ipairs(a):
            t = arg(a, 0)

            def it(b):
                i = b[1] + 1.0
                v = self.index(b[0], i)
                if v is None:
                    return [None]
                return [i, v]

            return [Builtin("ipairs_iter", it), t, 0.0]

        reg(G, "ipairs", ipairs)

        def lnext(a):
            t = arg(a, 0)
            k = arg(a, 1)
            keys = list(t.hash.keys())
            if k is None:
                idx = 0
            else:
                try:
                    idx = keys.index(key_of(k)) + 1
                except ValueError:
                    raise LuaError("invalid key to 'next'")
            while idx < len(keys):
                kk = keys[idx]
                if t.hash[kk] is not None:
                    return [kk, t.hash[kk]]
                idx += 1
            return [None]

        reg(G, "next", lnext)
        reg(G, "pairs", lambda a: [G.hash["next"], arg(a, 0), None])

        def setmetatable(a):
            t = arg(a, 0)
            if not isinstance(t, LuaTable):
                raise LuaError("bad argument to 'setmetatable'")
            t.mt = arg(a, 1)
            return [t]

        reg(G, "setmetatable", setmetatable)
        reg(G, "getmetatable", lambda a: [arg(a, 0).mt if isinstance(arg(a, 0), LuaTable) else
                                          (LuaTable() if isinstance(arg(a, 0), str) else None)])
        reg(G, "rawget", lambda a: [a[0].hash.get(key_of(a[1]))])

        def rawset(a):
            a[0].hash[key_of(a[1])] = a[2]
            return [a[0]]

        reg(G, "rawset", rawset)
        reg(G, "rawequal", lambda a: [arg(a, 0) is arg(a, 1) or arg(a, 0) == arg(a, 1)])

        def error(a):
            v = arg(a, 0)
            level = arg(a, 1, 1.0)
            if isinstance(v, str) and level not in (0, 0.0):
                raise LuaError(v, v, positioned=False)   # position added at the call site
            raise LuaError(self.tostring(v) if not isinstance(v, LuaTable) else "error object", v, positioned=True)

        reg(G, "error", error)

        def assert_(a):
            if not truthy(arg(a, 0)):
                raise LuaError(arg(a, 1, "assertion failed!"))
            return list(a)

        reg(G, "assert", assert_)

        def pcall(a):
            try:
                return [True] + self.call(arg(a, 0), list(a[1:]))
            except LuaError as ex:
                return [False, ex.value]

        reg(G, "pcall", pcall)
        G.hash["_G"] = G
        for t in (S, M, T):
            self.strict_tables.add(id(t))
        self._qualify()

    def _qualify(self):
        """Give every builtin its qualified name (string.sub, math.floor, print...)."""
        for k, v in list(self.G.hash.items()):
            if isinstance(v, Builtin):
                v.qualname = k
            elif isinstance(v, LuaTable) and k != "_G":
                for k2, v2 in v.hash.items():
                    if isinstance(v2, Builtin):
                        v2.qualname = "%s.%s" % (k, k2)

    def enable_roblox_mock(self):
        """Mock Roblox globals: every access / call on them is recorded in self.trace."""
        G = self.G
        self.trace = []
        self.output = []
        trace = self.trace
        emu = self
        mt = LuaTable()

        def mock(path):
            t = LuaTable()
            t.mt = mt
            t.tag = path
            return t

        def fmt(v):
            if isinstance(v, LuaTable) and v.tag:
                return v.tag
            if isinstance(v, str):
                return repr(v)
            return emu.tostring(v) if not isinstance(v, (LuaTable, Closure, Builtin)) else ltype(v)

        def m_index(a):
            o, k = a[0], a[1] if len(a) > 1 else None
            path = "%s.%s" % (o.tag, k if isinstance(k, str) else fmt(k))
            trace.append("get " + path)
            return [mock(path)]

        def m_newindex(a):
            o, k, v = a[0], a[1], a[2] if len(a) > 2 else None
            trace.append("set %s.%s = %s" % (o.tag, k if isinstance(k, str) else fmt(k), fmt(v)))
            return []

        def m_call(a):
            o = a[0]
            args = a[1:]
            path = "%s(%s)" % (o.tag, ", ".join(fmt(x) for x in args))
            trace.append("call " + path)
            return [mock(path)]

        mt.hash["__index"] = Builtin("mock_index", m_index)
        mt.hash["__newindex"] = Builtin("mock_newindex", m_newindex)
        mt.hash["__call"] = Builtin("mock_call", m_call)
        for ev in ("__add", "__sub", "__mul", "__div", "__mod", "__pow", "__concat"):
            mt.hash[ev] = Builtin(ev, lambda a, ev=ev: [mock("(%s %s %s)" % (fmt(a[0]), ev, fmt(a[1])))])
        mt.hash["__tostring"] = Builtin("mock_tostring", lambda a: [a[0].tag])
        for name in ("game", "workspace", "script", "Vector3", "Vector2", "CFrame", "Color3", "UDim2", "UDim",
                     "Instance", "Enum", "TweenInfo", "Ray", "BrickColor", "NumberSequence", "Drawing",
                     "syn", "shared", "task", "Random", "RaycastParams", "PhysicalProperties", "Region3",
                     "NumberRange", "ColorSequence", "Rect", "Axes", "Faces", "DockWidgetPluginGuiInfo",
                     "plugin", "debug", "os", "utf8", "coroutine", "getgenv", "getrenv", "getrawmetatable",
                     "setreadonly", "hookfunction", "hookmetamethod", "newcclosure", "firetouchinterest",
                     "fireclickdetector", "request", "http_request", "identifyexecutor", "loadstring",
                     "readfile", "writefile", "isfile", "setclipboard", "getconnections", "firesignal",
                     "gethui", "checkcaller", "getnamecallmethod", "setfpscap", "queue_on_teleport",
                     "spawn", "delay", "wait", "warn", "require", "printidentity", "Mouse", "Players"):
            if name not in G.hash:
                G.hash[name] = mock(name)

        def p_print(a):
            line = "\t".join(emu.tostring(x) if not (isinstance(x, LuaTable) and x.tag) else x.tag for x in a)
            emu.output.append(line)
            trace.append("print " + line)
            return []
        G.hash["print"] = Builtin("print", p_print)
        G.hash["typeof"] = Builtin("typeof", lambda a: ["Instance" if isinstance(a[0], LuaTable) and a[0].tag
                                                        else ltype(a[0]) if a else "nil"])
        G.hash["tick"] = Builtin("tick", lambda a: [1000.0])
        G.hash["time"] = Builtin("time", lambda a: [1.0])
        self._qualify()

    def tostring(self, v):
        if isinstance(v, LuaTable) and v.mt is not None and isinstance(v.mt, LuaTable) and self.full:
            h = v.mt.hash.get("__tostring")
            if h is not None:
                r = self.call1(h, [v])
                return r if isinstance(r, str) else num2str(r) if isinstance(r, float) else "?"
        return self._tostring(v)

    def enable_full(self):
        """Extra library surface needed to run whole obfuscator loaders (still no I/O).

        Globals may be written (they live in the sandbox's own `_G`)."""
        from . import luapattern as LP
        self.full = True
        G, S = self.G, self.string_lib

        def reg(tbl, name, fn):
            tbl.hash[name] = Builtin(name, fn)

        def arg(a, i, default=None):
            return a[i] if i < len(a) else default

        def sarg(v, what):
            if isinstance(v, str):
                return v
            if isinstance(v, float):
                return num2str(v)
            raise LuaError("bad argument to '%s' (string expected, got %s)" % (what, ltype(v)))

        def pat(fn):
            def w(a):
                try:
                    return fn(a)
                except LP.PatternError as ex:
                    raise LuaError(str(ex))
            return w

        def s_find(a):
            s, p = sarg(arg(a, 0), "find"), sarg(arg(a, 1), "find")
            init = int(tonum(arg(a, 2, 1.0)) or 1)
            r = LP.find(s, p, init, truthy(arg(a, 3)))
            return [None] if r is None else r

        def s_match(a):
            s, p = sarg(arg(a, 0), "match"), sarg(arg(a, 1), "match")
            init = int(tonum(arg(a, 2, 1.0)) or 1)
            r = LP.match(s, p, init)
            return [None] if r is None else r

        def s_gmatch(a):
            it = LP.gmatch_iter(sarg(arg(a, 0), "gmatch"), sarg(arg(a, 1), "gmatch"))

            def nxt(_):
                r = it()
                return [None] if r is None else r
            return [Builtin("gmatch_iter", pat(nxt))]

        def s_gsub(a):
            s, p = sarg(arg(a, 0), "gsub"), sarg(arg(a, 1), "gsub")
            repl = arg(a, 2)
            mx = arg(a, 3)
            mx = None if mx is None else int(tonum(mx))

            def rf(whole, caps):
                if isinstance(repl, (str, float)):
                    r = sarg(repl, "gsub")
                    out, i = [], 0
                    while i < len(r):
                        c = r[i]
                        if c == "%" and i + 1 < len(r):
                            d = r[i + 1]
                            if d == "0":
                                out.append(whole)
                            elif d.isdigit():
                                v = caps[int(d) - 1] if int(d) - 1 < len(caps) else whole
                                out.append(self.tostring(v))
                            else:
                                out.append(d)
                            i += 2
                            continue
                        out.append(c)
                        i += 1
                    return "".join(out)
                key = caps[0] if caps else whole
                if isinstance(repl, LuaTable):
                    v = self.index(repl, key)
                else:
                    v = self.call1(repl, list(caps) if caps else [whole])
                if v is None or v is False:
                    return None
                if isinstance(v, (str, float)):
                    return sarg(v, "gsub")
                raise LuaError("invalid replacement value (a %s)" % ltype(v))
            out, n = LP.gsub(s, p, rf, mx)
            return [out, float(n)]

        reg(S, "find", pat(s_find))
        reg(S, "match", pat(s_match))
        reg(S, "gmatch", pat(s_gmatch))
        reg(S, "gsub", pat(s_gsub))
        reg(G, "getfenv", lambda a: [G])
        reg(G, "setfenv", lambda a: [arg(a, 0)])

        # bit32 (Roblox / Lua 5.2)
        B = LuaTable()
        M32 = 0xFFFFFFFF

        def u(v):
            n = tonum(v)
            if n is None:
                raise LuaError("bad argument to bit32 function (number expected)")
            return int(n) & M32

        def fold_bits(op, init):
            def f(a):
                r = init
                for v in a:
                    r = op(r, u(v))
                return [float(r & M32)]
            return f

        reg(B, "band", fold_bits(lambda x, y: x & y, M32))
        reg(B, "bor", fold_bits(lambda x, y: x | y, 0))
        reg(B, "bxor", fold_bits(lambda x, y: x ^ y, 0))
        reg(B, "bnot", lambda a: [float(~u(arg(a, 0)) & M32)])
        reg(B, "lshift", lambda a: [float((u(arg(a, 0)) << int(tonum(arg(a, 1)))) & M32)
                                    if int(tonum(arg(a, 1))) < 32 else 0.0])
        reg(B, "rshift", lambda a: [float(u(arg(a, 0)) >> int(tonum(arg(a, 1))))
                                    if int(tonum(arg(a, 1))) < 32 else 0.0])
        reg(B, "btest", lambda a: [fold_bits(lambda x, y: x & y, M32)(a)[0] != 0])

        def extract(a):
            n, f = u(arg(a, 0)), int(tonum(arg(a, 1)))
            w = int(tonum(arg(a, 2, 1.0)))
            return [float((n >> f) & ((1 << w) - 1))]
        reg(B, "extract", extract)
        G.hash["bit32"] = B

        M = G.hash["math"]

        def ldexp(a):
            import math as _m
            return [_m.ldexp(tonum(arg(a, 0)), int(tonum(arg(a, 1))))]
        reg(M, "ldexp", ldexp)

        def frexp(a):
            import math as _m
            m, e = _m.frexp(tonum(arg(a, 0)))
            return [m, float(e)]
        reg(M, "frexp", frexp)
        self._qualify()

    # ------------------------------------------------------------- semantics
    def tick(self):
        self.steps += 1
        if self.steps > self.budget:
            raise EmuAbort("step budget exceeded")

    def _tostring(self, v):
        if v is None:
            return "nil"
        if v is True:
            return "true"
        if v is False:
            return "false"
        if isinstance(v, float):
            return num2str(v)
        if isinstance(v, str):
            return v
        return "%s: 0x%08x" % (ltype(v), id(v) & 0xffffffff)

    def index(self, o, k):
        if isinstance(o, LuaTable):
            if self.guard_read_tables is not None and id(o) in self.guard_read_tables:
                raise EmuAbort("reads guarded table")
            if id(o) in self.strict_tables and k not in o.hash and not self.full:
                raise EmuAbort("unsupported library function %r" % (k,))
            if k is None:
                v = None
            else:
                if isinstance(k, float) and k != k:
                    v = None
                else:
                    v = o.hash.get(key_of(k))
            if v is None and o.mt is not None:
                h = o.mt.hash.get("__index") if isinstance(o.mt, LuaTable) else None
                if h is None:
                    return None
                if isinstance(h, LuaTable):
                    return self.index(h, k)
                return self.call1(h, [o, k])
            return v
        if isinstance(o, str):
            if isinstance(k, str) and k not in self.string_lib.hash and not self.full:
                raise EmuAbort("unsupported string method %r" % (k,))
            return self.string_lib.hash.get(k) if isinstance(k, str) else None
        raise LuaError("attempt to index a %s value" % ltype(o))

    def setindex(self, o, k, v):
        if not isinstance(o, LuaTable):
            raise LuaError("attempt to index a %s value" % ltype(o))
        if self.guard_write_tables is not None and id(o) in self.guard_write_tables:
            raise EmuAbort("writes guarded table")
        if id(o) in self.strict_tables:
            raise EmuAbort("writes library table")
        kk = key_of(k)
        if o.mt is not None and kk not in o.hash:
            h = o.mt.hash.get("__newindex") if isinstance(o.mt, LuaTable) else None
            if h is not None:
                if not self.full:
                    raise EmuAbort("__newindex")
                if isinstance(h, LuaTable):
                    return self.setindex(h, k, v)
                self.call(h, [o, k, v])
                return
        if v is None:
            o.hash.pop(kk, None)
        else:
            o.hash[kk] = v

    def call(self, f, args):
        self.tick()
        if isinstance(f, Builtin):
            return f.fn(args)
        if isinstance(f, Closure):
            return self.call_closure(f, args)
        if isinstance(f, LuaTable) and f.mt is not None and isinstance(f.mt.hash.get("__call"), (Closure, Builtin)):
            return self.call(f.mt.hash.get("__call"), [f] + args)
        raise LuaError("attempt to call a %s value" % ltype(f))

    def call1(self, f, args):
        r = self.call(f, args)
        return r[0] if r else None

    def call_closure(self, c, args):
        fn = c.func
        sc = Scope(c.scope)
        for i, p in enumerate(fn.params):
            sc.vars[p] = [args[i] if i < len(args) else None]
        va = list(args[len(fn.params):]) if fn.vararg else None
        r = self.exec_block(fn.body, sc, va)
        if r is not None and r[0] == "return":
            return r[1]
        return []

    def metamethod(self, event, a, b=None):
        for o in (a, b):
            if isinstance(o, LuaTable) and isinstance(o.mt, LuaTable):
                h = o.mt.hash.get(event)
                if h is not None:
                    return h
        return None

    def arith(self, op, a, b):
        r = arith(op, a, b)
        if r is None and self.full:
            ev = {"+": "__add", "-": "__sub", "*": "__mul", "/": "__div", "%": "__mod", "^": "__pow"}[op]
            h = self.metamethod(ev, a, b)
            if h is not None:
                return self.call1(h, [a, b])
        if r is None:
            raise LuaError("attempt to perform arithmetic on a %s value" % ltype(b if tonum(a) is not None else a))
        return r

    def eval_multi(self, exprs, sc, va):
        out = []
        n = len(exprs)
        for i, e in enumerate(exprs):
            if i == n - 1 and isinstance(e, (Call, Method, Vararg)):
                out.extend(self.eval_m(e, sc, va))
            else:
                out.append(self.eval(e, sc, va))
        return out

    def eval_m(self, e, sc, va):
        if self.full and getattr(e, "line", None) is not None:
            try:
                return self._eval_m(e, sc, va)
            except LuaError as ex:
                self._position(ex, e)
                raise
        return self._eval_m(e, sc, va)

    def _eval_m(self, e, sc, va):
        if isinstance(e, Vararg):
            if va is None:
                raise EmuAbort("vararg outside vararg function")
            return list(va)
        if isinstance(e, Call):
            f = self.eval(e.func, sc, va)
            return self.call(f, self.eval_multi(e.args, sc, va))
        if isinstance(e, Method):
            o = self.eval(e.obj, sc, va)
            f = self.index(o, e.name)
            return self.call(f, [o] + self.eval_multi(e.args, sc, va))
        return [self.eval(e, sc, va)]

    chunkname = "input"

    def _position(self, ex, e):
        line = getattr(e, "line", None)
        if line is not None and not ex.positioned:
            ex.positioned = True
            if isinstance(ex.value, str):
                ex.value = "%s:%d: %s" % (self.chunkname, line, ex.value)
                ex.args = (ex.value,)

    def eval(self, e, sc, va):
        if self.full and getattr(e, "line", None) is not None:
            try:
                return self._eval(e, sc, va)
            except LuaError as ex:
                self._position(ex, e)
                raise
        return self._eval(e, sc, va)

    def _eval(self, e, sc, va):
        self.tick()
        t = type(e)
        if t is Number:
            return float(e.value)
        if t is String:
            return e.value
        if t is Name:
            if e.sym is not None:
                c = sc.lookup(e.sym)
                if c is None:
                    raise EmuAbort("unbound local %s" % e.sym.name)
                if self.guard_read_cells is not None and id(c) in self.guard_read_cells:
                    raise EmuAbort("reads guarded variable")
                if self.guard_read_syms is not None and e.sym in self.guard_read_syms:
                    raise EmuAbort("reads guarded variable")
                return c[0]
            if e.name in self.G.hash:
                return self.G.hash[e.name]
            if e.name in KNOWN_GLOBALS or e.name in self.dynamic_globals or \
                    getattr(self, "treat_all_globals_dynamic", False):
                raise EmuAbort("global %s" % e.name)
            return None
        if t is Index:
            return self.index(self.eval(e.obj, sc, va), self.eval(e.key, sc, va))
        if t is Bin:
            op = e.op
            if op == "and":
                l = self.eval(e.left, sc, va)
                return self.eval(e.right, sc, va) if truthy(l) else l
            if op == "or":
                l = self.eval(e.left, sc, va)
                return l if truthy(l) else self.eval(e.right, sc, va)
            l = self.eval(e.left, sc, va)
            r = self.eval(e.right, sc, va)
            if op in ("+", "-", "*", "/", "%", "^"):
                if type(l) is float and type(r) is float:
                    if op == "+":
                        return l + r
                    if op == "-":
                        return l - r
                    if op == "*":
                        return l * r
                return self.arith(op, l, r)
            if op == "..":
                a, b = tostr_concat(l), tostr_concat(r)
                if (a is None or b is None) and self.full:
                    h = self.metamethod("__concat", l, r)
                    if h is not None:
                        return self.call1(h, [l, r])
                if a is None or b is None:
                    raise LuaError("attempt to concatenate a %s value" % ltype(l if a is None else r))
                if len(a) + len(b) > 20000000:
                    raise EmuAbort("string too large")
                return a + b
            if op == "==":
                return l is r or (type(l) is type(r) and l == r)
            if op == "~=":
                return not (l is r or (type(l) is type(r) and l == r))
            if type(l) is float and type(r) is float or (type(l) is str and type(r) is str):
                if op == "<":
                    return l < r
                if op == ">":
                    return l > r
                if op == "<=":
                    return l <= r
                if op == ">=":
                    return l >= r
            raise LuaError("attempt to compare %s with %s" % (ltype(l), ltype(r)))
        if t is Un:
            v = self.eval(e.expr, sc, va)
            if e.op == "not":
                return not truthy(v)
            if e.op == "-":
                n = tonum(v)
                if n is None:
                    raise LuaError("attempt to perform arithmetic on a %s value" % ltype(v))
                return -n
            if e.op == "#":
                if isinstance(v, str):
                    return float(len(v))
                if isinstance(v, LuaTable):
                    return v.length()
                raise LuaError("attempt to get length of a %s value" % ltype(v))
        if t is Nil:
            return None
        if t is Bool:
            return e.value
        if t is Paren:
            return self.eval(e.expr, sc, va)
        if t is Call or t is Method or t is Vararg:
            r = self.eval_m(e, sc, va)
            return r[0] if r else None
        if t is Func:
            return Closure(e, sc)
        if t is Table:
            tb = LuaTable()
            n = len(e.items)
            pos = 1
            for i, it in enumerate(e.items):
                if it.key is None:
                    if i == n - 1 and isinstance(it.value, (Call, Method, Vararg)):
                        for v in self.eval_m(it.value, sc, va):
                            if v is not None:
                                tb.hash[float(pos)] = v
                            pos += 1
                    else:
                        v = self.eval(it.value, sc, va)
                        if v is not None:
                            tb.hash[float(pos)] = v
                        pos += 1
                else:
                    k = self.eval(it.key, sc, va)
                    v = self.eval(it.value, sc, va)
                    if v is not None:
                        tb.hash[key_of(k)] = v
            return tb
        raise EmuAbort("cannot evaluate %s" % t.__name__)

    def assign(self, target, value, sc, va, pre=None):
        if isinstance(target, Name):
            if target.sym is not None:
                c = sc.lookup(target.sym)
                if c is None:
                    raise EmuAbort("unbound local")
                if self.guard_write_cells is not None and id(c) in self.guard_write_cells:
                    raise EmuAbort("writes guarded variable")
                if self.guard_write_syms is not None and target.sym in self.guard_write_syms:
                    raise EmuAbort("writes guarded variable")
                c[0] = value
            else:
                if not self.full:
                    raise EmuAbort("global write %s" % target.name)
                self.setindex(self.G, target.name, value)
        else:
            o, k = pre
            self.setindex(o, k, value)

    def exec_block(self, stats, sc, va):
        for s in stats:
            self.tick()
            t = type(s)
            if t is Local:
                vals = self.eval_multi(s.exprs, sc, va)
                for i, sym in enumerate(s.syms):
                    sc.vars[sym] = [vals[i] if i < len(vals) else None]
            elif t is Assign:
                pres = []
                for tg in s.targets:
                    if isinstance(tg, Index):
                        pres.append((self.eval(tg.obj, sc, va), self.eval(tg.key, sc, va)))
                    else:
                        pres.append(None)
                vals = self.eval_multi(s.exprs, sc, va)
                for i in range(len(s.targets) - 1, -1, -1):
                    self.assign(s.targets[i], vals[i] if i < len(vals) else None, sc, va, pres[i])
            elif t is CallStat:
                self.eval_m(s.call, sc, va)
            elif t is LocalFunc:
                cell = [None]
                sc.vars[s.sym] = cell
                cell[0] = Closure(s.func, sc)
            elif t is FuncStat:
                f = Closure(s.func, sc)
                if isinstance(s.target, Name):
                    self.assign(s.target, f, sc, va)
                else:
                    self.setindex(self.eval(s.target.obj, sc, va), self.eval(s.target.key, sc, va), f)
            elif t is Return:
                return ("return", self.eval_multi(s.exprs, sc, va))
            elif t is If:
                if truthy(self.eval(s.cond, sc, va)):
                    r = self.exec_block(s.body, Scope(sc), va)
                else:
                    r = self.exec_block(s.orelse, Scope(sc), va)
                if r is not None:
                    return r
            elif t is While:
                while truthy(self.eval(s.cond, sc, va)):
                    r = self.exec_block(s.body, Scope(sc), va)
                    if r is not None:
                        if r[0] == "break":
                            break
                        return r
            elif t is Repeat:
                while True:
                    inner = Scope(sc)
                    r = self.exec_block(s.body, inner, va)
                    if r is not None:
                        if r[0] == "break":
                            break
                        return r
                    if truthy(self.eval(s.cond, inner, va)):
                        break
            elif t is NumFor:
                a = tonum(self.eval(s.start, sc, va))
                b = tonum(self.eval(s.stop, sc, va))
                c = tonum(self.eval(s.step, sc, va)) if s.step is not None else 1.0
                if a is None or b is None or c is None:
                    raise LuaError("'for' value must be a number")
                i = a
                while (c > 0 and i <= b) or (c <= 0 and i >= b):
                    inner = Scope(sc)
                    inner.vars[s.sym] = [i]
                    r = self.exec_block(s.body, inner, va)
                    if r is not None:
                        if r[0] == "break":
                            break
                        return r
                    i += c
            elif t is GenFor:
                vals = self.eval_multi(s.exprs, sc, va)
                f = vals[0] if vals else None
                st = vals[1] if len(vals) > 1 else None
                ctl = vals[2] if len(vals) > 2 else None
                while True:
                    rs = self.call(f, [st, ctl])
                    if not rs or rs[0] is None:
                        break
                    ctl = rs[0]
                    inner = Scope(sc)
                    for i, sym in enumerate(s.syms):
                        inner.vars[sym] = [rs[i] if i < len(rs) else None]
                    r = self.exec_block(s.body, inner, va)
                    if r is not None:
                        if r[0] == "break":
                            break
                        return r
            elif t is Do:
                r = self.exec_block(s.body, Scope(sc), va)
                if r is not None:
                    return r
            elif t is Break:
                return ("break",)
            else:
                raise EmuAbort("statement %s" % t.__name__)
        return None


def is_scalar(v):
    return v is None or isinstance(v, (bool, float, str))
