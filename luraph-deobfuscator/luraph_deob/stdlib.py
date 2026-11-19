"""Pure, side-effect free subset of the Luau/Roblox standard library."""
from __future__ import annotations

import math
import struct
import threading

from . import interp as I
from .interp import (
    Buffer, Builtin, Coroutine, LuaError, LuaFunction, LuaTable, Opaque, Vector,
    first, fmt_num, key, tonum, tostr_py, truthy, type_name, unkey,
)
from .luapattern import PatternError, lua_find, lua_gmatch, lua_gsub, lua_match


def _int(v, name="number"):
    n = tonum(v)
    if n is None:
        raise LuaError(("invalid argument (%s expected, got %s)" % (name, type_name(v))).encode())
    if type(n) is float:
        if n != n or math.isinf(n):
            return 0
        n = int(math.floor(n)) if n >= 0 else -int(math.floor(-n))
    return n


def _u32(v):
    n = tonum(v)
    if n is None:
        raise LuaError(("invalid argument to bit32 (number expected, got %s)" % type_name(v)).encode())
    if type(n) is float:
        if n != n or math.isinf(n):
            return 0
        n = int(math.floor(n))
    return n & 0xFFFFFFFF


def make_env(it: I.Interp, script_args=()):
    G = LuaTable()

    def reg(tbl, name, f):
        tbl.h[name.encode()] = Builtin(f, name)

    def lib(name):
        t = LuaTable()
        G.h[name.encode()] = t
        return t

    # -- base ---------------------------------------------------------------
    def l_print(*a):
        return ()

    def l_type(*a):
        if not a:
            raise LuaError(b"missing argument #1 to 'type'")
        return (type_name(a[0]).encode(),)

    def l_typeof(*a):
        v = a[0] if a else None
        if isinstance(v, Opaque):
            return (v.kind.split(".")[0].encode(),)
        if type(v) is Vector:
            return (b"Vector3",)
        return (type_name(v).encode(),)

    def l_tostring(*a):
        return (it.tostring(a[0] if a else None),)

    def l_tonumber(v=None, base=None, *rest):
        if base is None:
            n = tonum(v)
            return (n,)
        base = _int(base)
        if type(v) is not bytes:
            v = it.tostring(v)
        try:
            s = v.decode("latin-1").strip().lower()
            neg = s.startswith("-")
            if neg:
                s = s[1:]
            n = int(s, base)
            return (-n if neg else n,)
        except ValueError:
            return (None,)

    def l_select(n, *a):
        if n == b"#":
            return (len(a),)
        n = _int(n)
        if n < 0:
            n = len(a) + n
            if n < 0:
                raise LuaError(b"bad argument #1 to 'select' (index out of range)")
            return a[n:]
        if n == 0:
            raise LuaError(b"bad argument #1 to 'select' (index out of range)")
        return a[n - 1:]

    def l_rawget(t, k, *r):
        return (t.h.get(key(k)),)

    def l_rawset(t, k, v=None, *r):
        if v is None:
            t.h.pop(key(k), None)
        else:
            t.h[key(k)] = v
        return (t,)

    def l_rawequal(a, b, *r):
        return (a is b or (type(a) is type(b) and type(a) in (int, float, bytes, bool) and a == b),)

    def l_rawlen(t, *r):
        return (t.length() if type(t) is LuaTable else len(t),)

    def l_setmetatable(t, m=None, *r):
        if type(t) is not LuaTable:
            raise LuaError(b"bad argument #1 to 'setmetatable' (table expected)")
        if t.meta is not None and b"__metatable" in t.meta.h:
            raise LuaError(b"cannot change a protected metatable")
        t.meta = m
        return (t,)

    def l_getmetatable(t=None, *r):
        if type(t) is LuaTable:
            m = t.meta
        elif type(t) is bytes:
            m = it.string_meta_table
        else:
            m = None
        if m is not None and b"__metatable" in m.h:
            return (m.h[b"__metatable"],)
        return (m,)

    def l_assert(*a):
        if not a or not truthy(a[0]):
            msg = a[1] if len(a) > 1 else b"assertion failed!"
            raise LuaError(msg)
        return a

    def errval(e):
        """Error value as seen by pcall: runtime errors carry a position prefix
        (scripts such as MoonSec V3 self-test for ':%d+:' in messages)."""
        v = e.value
        if type(v) is bytes and not e.positioned:
            return b"script:1: " + v
        return v

    def l_error(msg=None, level=1, *r):
        e = LuaError(msg)
        e.positioned = True
        if type(msg) is bytes and (level is None or (type(level) in (int, float) and level > 0)):
            e.value = b"script:1: " + msg
        raise e

    def l_pcall(f=None, *a):
        try:
            r = it.call(f, a)
            return (True,) + tuple(r)
        except LuaError as e:
            return (False, errval(e))
        except RecursionError:
            return (False, b"stack overflow")
        except PatternError as e:
            return (False, str(e).encode())

    def l_xpcall(f, h, *a):
        try:
            r = it.call(f, a)
            return (True,) + tuple(r)
        except LuaError as e:
            return (False,) + tuple(it.call(h, (errval(e),)))
        except RecursionError:
            return (False,) + tuple(it.call(h, (b"stack overflow",)))

    def l_next(t, k=None, *r):
        return I._builtin_next(t, k)

    def l_pairs(t, *r):
        if type(t) is LuaTable and t.meta is not None and b"__pairs" in t.meta.h:
            return tuple(it.call(t.meta.h[b"__pairs"], (t,)))[:3]
        return (I.BUILTIN_NEXT, t, None)

    def ipairs_iter(t, i):
        i = int(i) + 1
        v = it.index(t, i)
        if v is None:
            return (None,)
        return (i, v)

    IPI = Builtin(ipairs_iter, "ipairs_iter")

    def l_ipairs(t, *r):
        return (IPI, t, 0)

    def l_unpack(t, i=None, j=None, *r):
        i = 1 if i is None else _int(i)
        j = it.length(t) if j is None else _int(j)
        if j - i >= 8000000:
            raise LuaError(b"too many results to unpack")
        h = t.h
        return tuple(h.get(k) for k in range(i, j + 1))

    def l_getfenv(f=None, *r):
        if type(f) is LuaFunction:
            return (f.env,)
        return (G,)

    def l_setfenv(f, t, *r):
        if type(f) is LuaFunction:
            f.env = t
        return (f,)

    def l_loadstring(src=None, name=b"=(load)", *r):
        from .luau_ast import parse
        if type(src) is not bytes:
            return (None, b"bad argument")
        try:
            ast = parse(src)
        except Exception as e:  # syntax error
            return (None, str(e).encode())
        it.loaded_chunks.append((name, src))
        if getattr(it, "on_load", None):
            it.on_load(ast)
        comp = I.Compiler(it, G, name.decode("latin-1") if type(name) is bytes else "load")
        return (comp.compile_chunk(ast),)

    def l_newproxy(*a):
        t = LuaTable()
        if a and truthy(a[0]):
            t.meta = LuaTable()
        return (t,)

    for n, f in [
        ("print", l_print), ("warn", l_print), ("type", l_type), ("typeof", l_typeof),
        ("tostring", l_tostring), ("tonumber", l_tonumber), ("select", l_select),
        ("rawget", l_rawget), ("rawset", l_rawset), ("rawequal", l_rawequal),
        ("rawlen", l_rawlen), ("setmetatable", l_setmetatable),
        ("getmetatable", l_getmetatable), ("assert", l_assert), ("error", l_error),
        ("pcall", l_pcall), ("xpcall", l_xpcall), ("next", l_next), ("pairs", l_pairs),
        ("ipairs", l_ipairs), ("unpack", l_unpack), ("getfenv", l_getfenv),
        ("setfenv", l_setfenv), ("loadstring", l_loadstring), ("load", l_loadstring),
        ("newproxy", l_newproxy),
    ]:
        reg(G, n, f)
    G.h[b"_G"] = G
    G.h[b"_VERSION"] = b"Luau"

    # -- string -------------------------------------------------------------
    S = lib("string")

    def _s(v):
        if type(v) is bytes:
            return v
        if type(v) in (int, float):
            return fmt_num(v).encode()
        raise LuaError(("bad argument (string expected, got %s)" % type_name(v)).encode())

    def s_sub(s, i=1, j=-1, *r):
        s = _s(s)
        ln = len(s)
        i = _int(i)
        j = _int(j) if j is not None else -1
        if i < 0:
            i = max(ln + i + 1, 1)
        elif i == 0:
            i = 1
        if j < 0:
            j = ln + j + 1
        elif j > ln:
            j = ln
        if i > j:
            return (b"",)
        return (s[i - 1:j],)

    def s_byte(s, i=1, j=None, *r):
        s = _s(s)
        ln = len(s)
        i = _int(i) if i is not None else 1
        j = i if j is None else _int(j)
        if i < 0:
            i = max(ln + i + 1, 1)
        elif i == 0:
            i = 1
        if j < 0:
            j = ln + j + 1
        elif j > ln:
            j = ln
        return tuple(s[i - 1:j])

    def s_char(*a):
        try:
            return (bytes(_int(x) for x in a),)
        except ValueError:
            raise LuaError(b"bad argument to 'char' (value out of range)")

    def s_len(s, *r):
        return (len(_s(s)),)

    def s_rep(s, n, sep=b"", *r):
        s = _s(s)
        n = _int(n)
        if n <= 0:
            return (b"",)
        if n * (len(s) + len(sep)) > 1 << 28:
            raise LuaError(b"resulting string too large")
        return (_s(sep).join([s] * n) if sep else s * n,)

    def s_reverse(s, *r):
        return (_s(s)[::-1],)

    def s_lower(s, *r):
        return (_s(s).lower(),)

    def s_upper(s, *r):
        return (_s(s).upper(),)

    def wrap_pat(f):
        def g(*a):
            try:
                return tuple(f(*a))
            except PatternError as e:
                raise LuaError(str(e).encode())
        return g

    def s_find(s, p, init=None, plain=None, *r):
        return lua_find(_s(s), _s(p), init, truthy(plain))

    def s_match(s, p, init=None, *r):
        return lua_match(_s(s), _s(p), init)

    def s_gmatch(s, p, *r):
        f = lua_gmatch(_s(s), _s(p))
        return [Builtin(lambda *a: tuple(f()), "gmatch_iter")]

    def s_gsub(s, p, repl, n=None, *r):
        def call(f, args):
            return it.call(f, tuple(args))
        return lua_gsub(_s(s), _s(p), repl, n, call, lambda v: fmt_num(v).encode() if type(v) in (int, float) else v, it.index)

    def s_format(fmt, *args):
        fmt = _s(fmt)
        out = bytearray()
        i = 0
        ai = 0
        while i < len(fmt):
            c = fmt[i]
            if c != 37:
                out.append(c)
                i += 1
                continue
            i += 1
            if fmt[i] == 37:
                out.append(37)
                i += 1
                continue
            j = i
            while fmt[j] in b"-+ #0123456789.":
                j += 1
            spec = fmt[i:j].decode()
            conv = chr(fmt[j])
            i = j + 1
            a = args[ai] if ai < len(args) else None
            ai += 1
            if conv in "di":
                out += ("%" + spec + "d").encode() % _int(a)
            elif conv in "xXoc":
                if conv == "c":
                    out.append(_int(a) & 0xFF)
                else:
                    out += ("%" + spec + conv).encode() % (_int(a) & 0xFFFFFFFFFFFFFFFF if _int(a) < 0 else _int(a))
            elif conv in "eEfgGaA":
                n = tonum(a)
                if conv in "aA":
                    out += float(n).hex().encode()
                else:
                    out += ("%" + spec + conv).encode() % float(n)
            elif conv == "s":
                sv = it.tostring(a)
                out += ("%" + spec + "s").encode() % sv
            elif conv == "q":
                sv = _s(a)
                out += b'"' + sv.replace(b"\\", b"\\\\").replace(b'"', b'\\"').replace(b"\n", b"\\n").replace(b"\r", b"\\r").replace(b"\0", b"\\0") + b'"'
            else:
                raise LuaError(b"invalid option to 'format'")
        return (bytes(out),)

    def s_split(s, sep=b",", *r):
        parts = _s(s).split(_s(sep)) if sep else list(bytes([c]) for c in _s(s))
        return (LuaTable({i + 1: v for i, v in enumerate(parts)}),)

    def _packfmt(fmt):
        # translate Lua string.pack format to python struct items
        items = []
        endian = "<"
        i = 0
        while i < len(fmt):
            c = chr(fmt[i])
            i += 1
            num = ""
            while i < len(fmt) and 48 <= fmt[i] <= 57:
                num += chr(fmt[i])
                i += 1
            if c == "<" or c == "=":
                endian = "<"
            elif c == ">":
                endian = ">"
            elif c == "!" or c == " ":
                pass
            elif c in "bBhHlLjJTiIfdn":
                items.append((endian, c, int(num) if num else None))
            elif c == "s":
                items.append((endian, "s", int(num) if num else 8))
            elif c == "z":
                items.append((endian, "z", None))
            elif c == "x":
                items.append((endian, "x", None))
            elif c == "c":
                items.append((endian, "c", int(num)))
            else:
                raise LuaError(("invalid format option '%s'" % c).encode())
        return items

    SZ = {"b": 1, "B": 1, "h": 2, "H": 2, "l": 8, "L": 8, "j": 8, "J": 8, "T": 8, "i": 4, "I": 4}

    def s_packsize(fmt=None, *r):
        import re as _re
        fmt = _s(fmt).decode("latin-1")
        total = 0
        for m in _re.finditer(r"([<>=!]\d*|\s)|([bBhHlLjJfdnTxXsz]|[iI]\d*|c\d+)", fmt):
            tok = m.group(2)
            if not tok:
                continue
            c = tok[0]
            if c in "bBx":
                total += 1
            elif c in "hH":
                total += 2
            elif c in "iI":
                total += int(tok[1:]) if len(tok) > 1 else 4
            elif c in "lLjJdnT":
                total += 8
            elif c == "f":
                total += 4
            elif c == "c":
                total += int(tok[1:])
            else:
                raise LuaError(b"variable-size format in packsize")
        return (total,)

    def s_pack(fmt, *args):
        out = bytearray()
        ai = 0
        for endian, c, n in _packfmt(_s(fmt)):
            if c in SZ:
                size = n if (c in "iI" and n) else SZ[c]
                v = _int(args[ai])
                ai += 1
                signed = c in "bhlji"
                out += (v & ((1 << (8 * size)) - 1)).to_bytes(size, "little" if endian == "<" else "big", signed=False) if not signed or v >= 0 else (v + (1 << (8 * size))).to_bytes(size, "little" if endian == "<" else "big")
            elif c == "f":
                out += struct.pack(endian + "f", float(tonum(args[ai])))
                ai += 1
            elif c in "dn":
                out += struct.pack(endian + "d", float(tonum(args[ai])))
                ai += 1
            elif c == "s":
                sv = _s(args[ai])
                ai += 1
                out += len(sv).to_bytes(n, "little" if endian == "<" else "big") + sv
            elif c == "z":
                out += _s(args[ai]) + b"\0"
                ai += 1
            elif c == "x":
                out.append(0)
            elif c == "c":
                sv = _s(args[ai])
                ai += 1
                out += sv[:n].ljust(n, b"\0")
        return (bytes(out),)

    def s_unpack(fmt, s, pos=1, *r):
        s = _s(s)
        p = _int(pos) - 1
        res = []
        for endian, c, n in _packfmt(_s(fmt)):
            if c in SZ:
                size = n if (c in "iI" and n) else SZ[c]
                v = int.from_bytes(s[p:p + size], "little" if endian == "<" else "big", signed=c in "bhlji")
                p += size
                res.append(v)
            elif c == "f":
                res.append(struct.unpack_from(endian + "f", s, p)[0])
                p += 4
            elif c in "dn":
                res.append(struct.unpack_from(endian + "d", s, p)[0])
                p += 8
            elif c == "s":
                ln = int.from_bytes(s[p:p + n], "little" if endian == "<" else "big")
                p += n
                res.append(s[p:p + ln])
                p += ln
            elif c == "z":
                e = s.index(b"\0", p)
                res.append(s[p:e])
                p = e + 1
            elif c == "x":
                p += 1
            elif c == "c":
                res.append(s[p:p + n])
                p += n
        res.append(p + 1)
        return tuple(res)

    for n, f in [
        ("sub", s_sub), ("byte", s_byte), ("char", s_char), ("len", s_len), ("rep", s_rep),
        ("reverse", s_reverse), ("lower", s_lower), ("upper", s_upper),
        ("find", wrap_pat(s_find)), ("match", wrap_pat(s_match)), ("gmatch", wrap_pat(s_gmatch)),
        ("gsub", wrap_pat(s_gsub)), ("format", s_format), ("split", s_split),
        ("pack", s_pack), ("unpack", s_unpack), ("packsize", s_packsize),
    ]:
        reg(S, n, f)
    smeta = LuaTable()
    smeta.h[b"__index"] = S
    it.string_meta = S
    it.string_meta_table = smeta

    # -- table --------------------------------------------------------------
    T = lib("table")

    def t_insert(t, *a):
        h = t.h
        if len(a) == 1:
            h[t.length() + 1] = a[0]
            return ()
        pos, v = _int(a[0]), a[1]
        n = t.length()
        for k in range(n, pos - 1, -1):
            if k in h:
                h[k + 1] = h[k]
            else:
                h.pop(k + 1, None)
        if v is None:
            h.pop(pos, None)
        else:
            h[pos] = v
        return ()

    def t_remove(t, pos=None, *r):
        h = t.h
        n = t.length()
        if pos is None:
            pos = n
        pos = _int(pos)
        if n == 0 and pos in (0, n):
            return (h.get(pos),)
        v = h.get(pos)
        for k in range(pos, n):
            if k + 1 in h:
                h[k] = h[k + 1]
            else:
                h.pop(k, None)
        h.pop(n, None)
        return (v,)

    def t_concat(t, sep=b"", i=1, j=None, *r):
        j = t.length() if j is None else _int(j)
        parts = []
        for k in range(_int(i), j + 1):
            v = t.h.get(k)
            if type(v) in (int, float):
                v = fmt_num(v).encode()
            elif type(v) is not bytes:
                raise LuaError(b"invalid value (at index %d) in table for 'concat'" % k)
            parts.append(v)
        return (_s(sep).join(parts),)

    def t_pack(*a):
        h = {i + 1: v for i, v in enumerate(a) if v is not None}
        h[b"n"] = len(a)
        t = LuaTable(h)
        if len(h) - 1 < len(a):
            t.asize = len(a)
        return (t,)

    def t_unpack(t, i=None, j=None, *r):
        return l_unpack(t, i, j)

    def t_create(n, v=None, *r):
        n = _int(n)
        if v is None:
            return (LuaTable(),)
        return (LuaTable({k: v for k in range(1, n + 1)}),)

    def t_move(a1, f, e, t, a2=None, *r):
        if a2 is None:
            a2 = a1
        f, e, t = _int(f), _int(e), _int(t)
        if e >= f:
            src = a1.h
            dst = a2.h
            if t > e or t <= f or a1 is not a2:
                rng = range(0, e - f + 1)
            else:
                rng = range(e - f, -1, -1)
            for k in rng:
                v = src.get(f + k)
                if v is None:
                    dst.pop(t + k, None)
                else:
                    dst[t + k] = v
        return (a2,)

    def t_clear(t, *r):
        t.h.clear()
        return ()

    def t_find(t, v, init=1, *r):
        k = _int(init)
        while True:
            x = t.h.get(k)
            if x is None:
                return (None,)
            if it.eq(x, v):
                return (k,)
            k += 1

    def t_freeze(t, *r):
        t.frozen = True
        return (t,)

    def t_isfrozen(t, *r):
        return (t.frozen,)

    def t_clone(t, *r):
        c = LuaTable(dict(t.h))
        c.meta = t.meta
        return (c,)

    def t_sort(t, cmp=None, *r):
        import functools
        n = t.length()
        vals = [t.h.get(k) for k in range(1, n + 1)]
        if cmp is None:
            def c(a, b):
                return -1 if it.lt(a, b) else (1 if it.lt(b, a) else 0)
        else:
            def c(a, b):
                if truthy(first(it.call(cmp, (a, b)))):
                    return -1
                if truthy(first(it.call(cmp, (b, a)))):
                    return 1
                return 0
        vals.sort(key=functools.cmp_to_key(c))
        for k, v in enumerate(vals):
            t.h[k + 1] = v
        return ()

    def t_maxn(t, *r):
        m = 0
        for k in t.h:
            if type(k) in (int, float) and k > m:
                m = k
        return (m,)

    for n, f in [
        ("insert", t_insert), ("remove", t_remove), ("concat", t_concat), ("pack", t_pack),
        ("unpack", t_unpack), ("create", t_create), ("move", t_move), ("clear", t_clear),
        ("find", t_find), ("freeze", t_freeze), ("isfrozen", t_isfrozen), ("clone", t_clone),
        ("sort", t_sort), ("maxn", t_maxn),
    ]:
        reg(T, n, f)

    # -- math ---------------------------------------------------------------
    M = lib("math")
    M.h[b"pi"] = math.pi
    M.h[b"huge"] = math.inf

    def m1(f):
        return lambda x, *r: (f(tonum(x)),)

    def m_floor(x, *r):
        x = tonum(x)
        if type(x) is int:
            return (x,)
        if math.isinf(x) or x != x:
            return (x,)
        return (math.floor(x),)

    def m_ceil(x, *r):
        x = tonum(x)
        if type(x) is int or math.isinf(x) or x != x:
            return (x,)
        return (math.ceil(x),)

    def m_fmod(a, b, *r):
        return (math.fmod(tonum(a), tonum(b)),)

    def m_modf(x, *r):
        x = tonum(x)
        f, i = math.modf(x)
        return (float(i), f)

    def m_max(*a):
        return (max(tonum(x) for x in a),)

    def m_min(*a):
        return (min(tonum(x) for x in a),)

    def m_random(*a):
        return (0.5,) if not a else ((_int(a[0]),) if len(a) == 1 else (_int(a[0]),))

    def m_frexp(x, *r):
        m, e = math.frexp(tonum(x))
        return (m, e)

    def m_ldexp(m, e, *r):
        return (math.ldexp(tonum(m), _int(e)),)

    def m_log(x, b=None, *r):
        x = tonum(x)
        try:
            if b is None:
                return (math.log(x),)
            return (math.log(x, tonum(b)),)
        except ValueError:
            return (math.nan if x < 0 else -math.inf,)

    def m_sign(x, *r):
        x = tonum(x)
        return (1 if x > 0 else (-1 if x < 0 else 0),)

    def m_clamp(x, a, b, *r):
        return (min(max(tonum(x), tonum(a)), tonum(b)),)

    def m_round(x, *r):
        x = tonum(x)
        return (math.floor(x + 0.5) if x >= 0 else -math.floor(-x + 0.5),)

    def m_sqrt(x, *r):
        x = tonum(x)
        return (math.sqrt(x) if x >= 0 else math.nan,)

    def m_abs(x, *r):
        return (abs(tonum(x)),)

    for n, f in [
        ("floor", m_floor), ("ceil", m_ceil), ("abs", m_abs), ("sqrt", m_sqrt),
        ("sin", m1(math.sin)), ("cos", m1(math.cos)), ("tan", m1(math.tan)),
        ("asin", m1(math.asin)), ("acos", m1(math.acos)), ("atan", lambda y, x=1, *r: (math.atan2(tonum(y), tonum(x)),)),
        ("atan2", lambda y, x, *r: (math.atan2(tonum(y), tonum(x)),)),
        ("exp", m1(math.exp)), ("log", m_log), ("log10", m1(math.log10)), ("pow", lambda a, b, *r: (I._pow(tonum(a), tonum(b)),)),
        ("fmod", m_fmod), ("modf", m_modf), ("max", m_max), ("min", m_min),
        ("random", m_random), ("randomseed", lambda *a: ()), ("frexp", m_frexp), ("ldexp", m_ldexp),
        ("sign", m_sign), ("clamp", m_clamp), ("round", m_round), ("noise", lambda *a: (0,)),
        ("sinh", m1(math.sinh)), ("cosh", m1(math.cosh)), ("tanh", m1(math.tanh)),
    ]:
        reg(M, n, f)

    # -- bit32 --------------------------------------------------------------
    B = lib("bit32")

    def b_band(*a):
        r = 0xFFFFFFFF
        for x in a:
            r &= _u32(x)
        return (r,)

    def b_bor(*a):
        r = 0
        for x in a:
            r |= _u32(x)
        return (r,)

    def b_bxor(*a):
        r = 0
        for x in a:
            r ^= _u32(x)
        return (r,)

    def b_btest(*a):
        return (b_band(*a)[0] != 0,)

    def b_bnot(x, *r):
        return ((~_u32(x)) & 0xFFFFFFFF,)

    def b_lshift(x, n, *r):
        n = _int(n)
        if n >= 32 or n <= -32:
            return (0,)
        if n < 0:
            return (_u32(x) >> -n,)
        return ((_u32(x) << n) & 0xFFFFFFFF,)

    def b_rshift(x, n, *r):
        n = _int(n)
        if n >= 32 or n <= -32:
            return (0,)
        if n < 0:
            return ((_u32(x) << -n) & 0xFFFFFFFF,)
        return (_u32(x) >> n,)

    def b_arshift(x, n, *r):
        n = _int(n)
        v = _u32(x)
        if v & 0x80000000:
            v -= 1 << 32
        if n >= 32:
            return ((0xFFFFFFFF if v < 0 else 0),)
        if n < 0:
            return ((v << -n) & 0xFFFFFFFF,)
        return ((v >> n) & 0xFFFFFFFF,)

    def b_lrotate(x, n, *r):
        n = _int(n) % 32
        v = _u32(x)
        return (((v << n) | (v >> (32 - n))) & 0xFFFFFFFF,)

    def b_rrotate(x, n, *r):
        n = _int(n) % 32
        v = _u32(x)
        return (((v >> n) | (v << (32 - n))) & 0xFFFFFFFF,)

    def b_extract(x, f, w=1, *r):
        f, w = _int(f), _int(w)
        return ((_u32(x) >> f) & ((1 << w) - 1),)

    def b_replace(x, v, f, w=1, *r):
        f, w = _int(f), _int(w)
        m = ((1 << w) - 1) << f
        return ((_u32(x) & ~m) | ((_u32(v) << f) & m),)

    def b_countlz(x, *r):
        v = _u32(x)
        return (32 - v.bit_length(),)

    def b_countrz(x, *r):
        v = _u32(x)
        if v == 0:
            return (32,)
        return ((v & -v).bit_length() - 1,)

    def b_byteswap(x, *r):
        return (int.from_bytes(_u32(x).to_bytes(4, "little"), "big"),)

    for n, f in [
        ("band", b_band), ("bor", b_bor), ("bxor", b_bxor), ("btest", b_btest), ("bnot", b_bnot),
        ("lshift", b_lshift), ("rshift", b_rshift), ("arshift", b_arshift), ("lrotate", b_lrotate),
        ("rrotate", b_rrotate), ("extract", b_extract), ("replace", b_replace),
        ("countlz", b_countlz), ("countrz", b_countrz), ("byteswap", b_byteswap),
    ]:
        reg(B, n, f)

    # -- buffer -------------------------------------------------------------
    BF = lib("buffer")

    def _off(b, o, n):
        o = _int(o)
        if o < 0 or o + n > len(b.b):
            raise LuaError(b"buffer access out of bounds")
        return o

    def mkread(fmt, n):
        st = struct.Struct("<" + fmt)

        def rd(b, o, *r):
            o = _off(b, o, n)
            return (st.unpack_from(b.b, o)[0],)

        return rd

    def mkwrite(fmt, n, isint, signed):
        st = struct.Struct("<" + fmt)
        mask = (1 << (8 * n)) - 1

        def wr(b, o, v, *r):
            o = _off(b, o, n)
            if isint:
                iv = _int(v) & mask
                if signed and iv >= 1 << (8 * n - 1):
                    iv -= 1 << (8 * n)
                st.pack_into(b.b, o, iv)
            else:
                st.pack_into(b.b, o, float(tonum(v)))
            return ()

        return wr

    def bf_readu8(b, o, *r):
        o = int(o)
        if o < 0:
            raise LuaError(b"buffer access out of bounds")
        try:
            return (b.b[o],)
        except IndexError:
            raise LuaError(b"buffer access out of bounds")

    def bf_writeu8(b, o, v, *r):
        o = int(o)
        if o < 0 or o >= len(b.b):
            raise LuaError(b"buffer access out of bounds")
        b.b[o] = _int(v) & 0xFF
        return ()

    def bf_create(n, *r):
        return (Buffer(bytearray(_int(n))),)

    def bf_fromstring(s, *r):
        return (Buffer(bytearray(_s(s))),)

    def bf_tostring(b, *r):
        return (bytes(b.b),)

    def bf_len(b, *r):
        return (len(b.b),)

    def bf_readstring(b, o, n, *r):
        n = _int(n)
        o = _off(b, o, n)
        return (bytes(b.b[o:o + n]),)

    def bf_writestring(b, o, s, n=None, *r):
        s = _s(s)
        if n is not None:
            s = s[:_int(n)]
        o = _off(b, o, len(s))
        b.b[o:o + len(s)] = s
        return ()

    def bf_copy(dst, doff, src, soff=0, n=None, *r):
        soff = _int(soff) if soff is not None else 0
        n = len(src.b) - soff if n is None else _int(n)
        doff = _off(dst, doff, n)
        _off(src, soff, n)
        dst.b[doff:doff + n] = bytes(src.b[soff:soff + n])
        return ()

    def bf_fill(b, o, v, n=None, *r):
        o = _int(o)
        n = len(b.b) - o if n is None else _int(n)
        _off(b, o, n)
        b.b[o:o + n] = bytes([_int(v) & 0xFF]) * n
        return ()

    def bf_readbits(b, o, n, *r):
        o, n = _int(o), _int(n)
        v = int.from_bytes(b.b, "little")
        return ((v >> o) & ((1 << n) - 1),)

    def bf_writebits(b, o, n, val, *r):
        o, n = _int(o), _int(n)
        v = int.from_bytes(b.b, "little")
        m = ((1 << n) - 1) << o
        v = (v & ~m) | ((_int(val) << o) & m)
        b.b[:] = v.to_bytes(len(b.b), "little")
        return ()

    for n, f in [
        ("create", bf_create), ("fromstring", bf_fromstring), ("tostring", bf_tostring),
        ("len", bf_len), ("readu8", bf_readu8), ("writeu8", bf_writeu8),
        ("readi8", mkread("b", 1)), ("readi16", mkread("h", 2)), ("readu16", mkread("H", 2)),
        ("readi32", mkread("i", 4)), ("readu32", mkread("I", 4)), ("readf32", mkread("f", 4)),
        ("readf64", mkread("d", 8)),
        ("writei8", mkwrite("b", 1, True, True)), ("writei16", mkwrite("h", 2, True, True)),
        ("writeu16", mkwrite("H", 2, True, False)), ("writei32", mkwrite("i", 4, True, True)),
        ("writeu32", mkwrite("I", 4, True, False)), ("writef32", mkwrite("f", 4, False, False)),
        ("writef64", mkwrite("d", 8, False, False)),
        ("readstring", bf_readstring), ("writestring", bf_writestring), ("copy", bf_copy),
        ("fill", bf_fill), ("readbits", bf_readbits), ("writebits", bf_writebits),
    ]:
        reg(BF, n, f)

    # -- vector -------------------------------------------------------------
    V = lib("vector")
    reg(V, "create", lambda x=0, y=0, z=0, *r: (Vector((tonum(x), tonum(y), tonum(z))),))
    V.h[b"zero"] = Vector((0, 0, 0))
    V.h[b"one"] = Vector((1, 1, 1))

    # -- coroutine (thread based, only used if the loader needs it) ---------
    C = lib("coroutine")
    _cur = [None]

    class Co(Coroutine):
        def __init__(self, fn):
            Coroutine.__init__(self, fn)
            self.ev_resume = threading.Event()
            self.ev_yield = threading.Event()
            self.transfer = ()
            self.error = None
            self.thread = None

        def run(self):
            try:
                self.transfer = tuple(it.call(self.fn, self.transfer))
            except LuaError as e:
                self.error = e
            except I.Abort as e:
                self.error = e
            except BaseException as e:  # noqa
                self.error = LuaError(str(e).encode())
            self.status = "dead"
            self.ev_yield.set()

        def resume(self, args):
            if self.status == "dead":
                return (False, b"cannot resume dead coroutine")
            prev = _cur[0]
            _cur[0] = self
            self.status = "running"
            self.transfer = args
            self.ev_yield.clear()
            if self.thread is None:
                self.thread = threading.Thread(target=self.run, daemon=True)
                self.thread.start()
            else:
                self.ev_resume.set()
            while not self.ev_yield.wait(0.25):
                if it.abort:
                    raise I.Abort()
            _cur[0] = prev
            if isinstance(self.error, I.Abort):
                raise self.error
            if self.error is not None:
                e = self.error
                self.error = None
                return (False, e.value)
            if self.status != "dead":
                self.status = "suspended"
            return (True,) + tuple(self.transfer)

        def yield_(self, args):
            self.transfer = args
            self.ev_resume.clear()
            self.ev_yield.set()
            while not self.ev_resume.wait(0.25):
                if it.abort:
                    raise I.Abort()
            return self.transfer

    def co_create(f, *r):
        return (Co(f),)

    def co_resume(co, *a):
        return co.resume(a)

    def co_yield(*a):
        co = _cur[0]
        if co is None:
            raise LuaError(b"attempt to yield from outside a coroutine")
        return co.yield_(a)

    def co_status(co, *r):
        return (co.status.encode(),)

    def co_running(*r):
        return (_cur[0], _cur[0] is None)

    def co_wrap(f, *r):
        co = Co(f)

        def w(*a):
            res = co.resume(a)
            if not res[0]:
                raise LuaError(res[1])
            return res[1:]

        return (Builtin(w, "wrapped"),)

    def co_isyieldable(*r):
        return (_cur[0] is not None,)

    def co_close(co, *r):
        co.status = "dead"
        return (True,)

    for n, f in [
        ("create", co_create), ("resume", co_resume), ("yield", co_yield), ("status", co_status),
        ("running", co_running), ("wrap", co_wrap), ("isyieldable", co_isyieldable), ("close", co_close),
    ]:
        reg(C, n, f)

    # -- os / utf8 / misc (deterministic stubs) -----------------------------
    O = lib("os")
    reg(O, "clock", lambda *a: (0.0,))
    reg(O, "time", lambda *a: (0,))
    U = lib("utf8")
    reg(U, "char", lambda *a: (("".join(chr(_int(x)) for x in a)).encode("utf-8"),))
    U.h[b"charpattern"] = b"[\0-\x7F\xC2-\xFD][\x80-\xBF]*"

    # debug library (Luau subset; getinfo/sethook etc. for Lua 5.1 style scripts)
    D = lib("debug")

    def dbg_traceback(msg=None, *r):
        if msg is not None and type(msg) is not bytes and not isinstance(msg, (int, float)):
            return (msg,)
        base = it.tostring(msg) + b"\n" if msg is not None else b""
        return (base + b"stack traceback:\n\t[C]: in ?",)

    def dbg_info(*a):
        # debug.info(level|func, "slnaf") -> plausible values
        what = a[-1] if a and type(a[-1]) is bytes else b""
        out = []
        for ch in what.decode("latin-1"):
            if ch == "s":
                out.append(b"script")
            elif ch == "l":
                out.append(1)
            elif ch == "n":
                out.append(b"")
            elif ch == "a":
                out.extend((0, False))
            elif ch == "f":
                out.append(a[0] if a and type(a[0]) in (LuaFunction, Builtin) else None)
        return tuple(out)

    def dbg_getinfo(*a):
        t = LuaTable()
        for k, v in (("short_src", b"script"), ("source", b"@script"), ("currentline", 1), ("linedefined", 1),
                     ("lastlinedefined", 1), ("what", b"Lua"), ("name", b""), ("namewhat", b""),
                     ("nups", 0), ("nparams", 0), ("isvararg", True)):
            t.h[k.encode()] = v
        if a and type(a[0]) in (LuaFunction, Builtin):
            t.h[b"func"] = a[0]
        return (t,)

    for n, f in [("traceback", dbg_traceback), ("info", dbg_info), ("getinfo", dbg_getinfo),
                 ("profilebegin", lambda *a: ()), ("profileend", lambda *a: ()),
                 ("getmetatable", lambda o=None, *r: (o.meta if type(o) is LuaTable else None,)),
                 ("setmetatable", lambda o=None, m=None, *r: (o,)),
                 ("sethook", lambda *a: ()), ("gethook", lambda *a: (None,)),
                 ("getlocal", lambda *a: (None,)), ("getupvalue", lambda *a: (None,)),
                 ("setupvalue", lambda *a: ()), ("setlocal", lambda *a: ()),
                 ("upvalueid", lambda *a: (LuaTable(),)), ("upvaluejoin", lambda *a: ()),
                 # Luau-specific memory-category functions (their absence trips some anti-tamper, e.g. Hercules)
                 ("setmemorycategory", lambda *a: ()), ("resetmemorycategory", lambda *a: ()),
                 ("getmemorycategory", lambda *a: (b"",)), ("dumpheap", lambda *a: ()),
                 ("getregistry", lambda *a: (LuaTable(),))]:
        reg(D, n, f)

    # Roblox datatypes -> opaque constructors
    for cls in ("Vector3", "Vector2", "UDim", "UDim2", "Color3", "Rect", "CFrame", "BrickColor",
                "NumberRange", "NumberSequence", "ColorSequence", "Ray", "Region3", "TweenInfo",
                "Instance", "Enum", "Axes", "Faces", "PhysicalProperties", "Font", "DateTime"):
        t = LuaTable()
        for ctor in ("new", "fromRGB", "fromHSV", "fromHex", "fromOffset", "fromScale", "Angles", "lookAt", "fromEulerAnglesXYZ", "now", "fromUnixTimestamp"):
            t.h[ctor.encode()] = Builtin((lambda c, k: (lambda *a: (Opaque("%s.%s" % (c, k), a),)))(cls, ctor), cls + "." + ctor)
        G.h[cls.encode()] = t
    for nm in ("game", "workspace", "script", "shared", "plugin"):
        G.h[nm.encode()] = Opaque(nm, ())
    return G
