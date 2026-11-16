"""Lua 5.1 pattern matching (direct port of lstrlib.c's matcher)."""

L_ESC = 37  # '%'
SPECIALS = b"^$*+?.([%-"
MAXCCALLS = 200


class PatternError(Exception):
    pass


def _class_end(p, i):
    if i >= len(p):
        raise PatternError("malformed pattern (ends with '%')")
    c = p[i]
    i += 1
    if c == L_ESC:
        if i >= len(p):
            raise PatternError("malformed pattern (ends with '%')")
        return i + 1
    if c == 91:  # '['
        if i < len(p) and p[i] == 94:
            i += 1
        while True:
            if i >= len(p):
                raise PatternError("malformed pattern (missing ']')")
            cc = p[i]
            i += 1
            if cc == L_ESC and i < len(p):
                i += 1
            if i >= len(p):
                raise PatternError("malformed pattern (missing ']')")
            if p[i] == 93:
                break
        return i + 1
    return i


def _single_class(c, cl):
    lo = cl | 0x20 if 65 <= cl <= 90 or 97 <= cl <= 122 else cl
    ch = chr(c)
    if lo == 97:
        res = ch.isalpha() and c < 128
    elif lo == 99:
        res = c < 32 or c == 127
    elif lo == 100:
        res = 48 <= c <= 57
    elif lo == 103:
        res = 33 <= c <= 126
    elif lo == 108:
        res = 97 <= c <= 122
    elif lo == 112:
        res = (33 <= c <= 47) or (58 <= c <= 64) or (91 <= c <= 96) or (123 <= c <= 126)
    elif lo == 115:
        res = c in (9, 10, 11, 12, 13, 32)
    elif lo == 117:
        res = 65 <= c <= 90
    elif lo == 119:
        res = (48 <= c <= 57) or (65 <= c <= 90) or (97 <= c <= 122)
    elif lo == 120:
        res = (48 <= c <= 57) or (65 <= c <= 70) or (97 <= c <= 102)
    elif lo == 122:
        res = c == 0
    else:
        return cl == c
    if 65 <= cl <= 90:
        return not res
    return res


def _match_class(c, p, pi, ep):
    # p[pi] == '['; ep points after ']'
    sig = True
    pi += 1
    if p[pi] == 94:
        sig = False
        pi += 1
    ec = ep - 1
    while pi < ec:
        if p[pi] == L_ESC:
            pi += 1
            if _single_class(c, p[pi]):
                return sig
            pi += 1
        elif pi + 2 < ec and p[pi + 1] == 45:
            if p[pi] <= c <= p[pi + 2]:
                return sig
            pi += 3
        else:
            if p[pi] == c:
                return sig
            pi += 1
    return not sig


def _single_match(s, si, p, pi, ep):
    if si >= len(s):
        return False
    c = s[si]
    pc = p[pi]
    if pc == 46:
        return True
    if pc == L_ESC:
        return _single_class(c, p[pi + 1])
    if pc == 91:
        return _match_class(c, p, pi, ep)
    return pc == c


class _MS:
    __slots__ = ("src", "pat", "level", "capture", "depth")

    def __init__(self, src, pat):
        self.src = src
        self.pat = pat
        self.level = 0
        self.capture = []
        self.depth = 0


CAP_UNF = -1
CAP_POS = -2


def _do_match(ms, si, pi):
    s, p = ms.src, ms.pat
    ms.depth += 1
    if ms.depth > MAXCCALLS:
        raise PatternError("pattern too complex")
    try:
        while True:
            if pi >= len(p):
                return si
            pc = p[pi]
            if pc == 40:  # (
                if pi + 1 < len(p) and p[pi + 1] == 41:
                    ms.capture.append([si, CAP_POS])
                    r = _do_match(ms, si, pi + 2)
                    if r is None:
                        ms.capture.pop()
                    return r
                ms.capture.append([si, CAP_UNF])
                r = _do_match(ms, si, pi + 1)
                if r is None:
                    ms.capture.pop()
                return r
            if pc == 41:  # )
                l = None
                for i in range(len(ms.capture) - 1, -1, -1):
                    if ms.capture[i][1] == CAP_UNF:
                        l = i
                        break
                if l is None:
                    raise PatternError("invalid pattern capture")
                ms.capture[l][1] = si - ms.capture[l][0]
                r = _do_match(ms, si, pi + 1)
                if r is None:
                    ms.capture[l][1] = CAP_UNF
                return r
            if pc == 36 and pi + 1 == len(p):  # $
                return si if si == len(s) else None
            if pc == L_ESC and pi + 1 < len(p):
                nc = p[pi + 1]
                if nc == 98:  # %b
                    if pi + 3 >= len(p):
                        raise PatternError("missing arguments to '%b'")
                    if si >= len(s) or s[si] != p[pi + 2]:
                        return None
                    b, e = p[pi + 2], p[pi + 3]
                    cont = 1
                    j = si + 1
                    while j < len(s):
                        c = s[j]
                        if c == e:
                            cont -= 1
                            if cont == 0:
                                break
                        elif c == b:
                            cont += 1
                        j += 1
                    else:
                        return None
                    si = j + 1
                    pi += 4
                    continue
                if nc == 102:  # %f
                    pi += 2
                    if pi >= len(p) or p[pi] != 91:
                        raise PatternError("missing '[' after '%f' in pattern")
                    ep = _class_end(p, pi)
                    prev = s[si - 1] if si > 0 else 0
                    cur = s[si] if si < len(s) else 0
                    if (not _match_class(prev, p, pi, ep)) and _match_class(cur, p, pi, ep):
                        pi = ep
                        continue
                    return None
                if 48 <= nc <= 57:  # back reference
                    l = nc - 49
                    if l < 0 or l >= len(ms.capture) or ms.capture[l][1] == CAP_UNF:
                        raise PatternError("invalid capture index")
                    st, ln = ms.capture[l]
                    cap = s[st:st + ln]
                    if s[si:si + len(cap)] == cap:
                        si += len(cap)
                        pi += 2
                        continue
                    return None
            ep = _class_end(p, pi)
            epc = p[ep] if ep < len(p) else None
            if epc == 63:  # ?
                if _single_match(s, si, p, pi, ep):
                    r = _do_match(ms, si + 1, ep + 1)
                    if r is not None:
                        return r
                pi = ep + 1
                continue
            if epc == 43:  # +
                if not _single_match(s, si, p, pi, ep):
                    return None
                return _max_expand(ms, si + 1, pi, ep)
            if epc == 42:  # *
                return _max_expand(ms, si, pi, ep)
            if epc == 45:  # -
                while True:
                    r = _do_match(ms, si, ep + 1)
                    if r is not None:
                        return r
                    if _single_match(s, si, p, pi, ep):
                        si += 1
                    else:
                        return None
            if not _single_match(s, si, p, pi, ep):
                return None
            si += 1
            pi = ep
    finally:
        ms.depth -= 1


def _max_expand(ms, si, pi, ep):
    i = 0
    while _single_match(ms.src, si + i, ms.pat, pi, ep):
        i += 1
    while i >= 0:
        r = _do_match(ms, si + i, ep + 1)
        if r is not None:
            return r
        i -= 1
    return None


def _get_capture(ms, i, s, e):
    if i >= len(ms.capture):
        if i == 0:
            return ms.src[s:e]
        raise PatternError("invalid capture index")
    st, ln = ms.capture[i]
    if ln == CAP_UNF:
        raise PatternError("unfinished capture")
    if ln == CAP_POS:
        return st + 1
    return ms.src[st:st + ln]


def _captures(ms, s, e, whole_if_none=True):
    n = len(ms.capture)
    if n == 0 and whole_if_none:
        return [ms.src[s:e]]
    return [_get_capture(ms, i, s, e) for i in range(n)]


def _norm_init(init, ln):
    if init is None:
        init = 1
    init = int(init)
    if init < 0:
        init = ln + init + 1
        if init < 1:
            init = 1
    elif init == 0:
        init = 1
    return init - 1


def lua_find(s, p, init=None, plain=False, find=True):
    si = _norm_init(init, len(s))
    if si > len(s):
        return [None]
    if find and (plain or not any(c in SPECIALS for c in p)):
        j = s.find(p, si)
        if j < 0:
            return [None]
        return [j + 1, j + len(p)]
    anchor = len(p) > 0 and p[0] == 94
    pi = 1 if anchor else 0
    while True:
        ms = _MS(s, p)
        e = _do_match(ms, si, pi)
        if e is not None:
            if find:
                return [si + 1, e] + _captures(ms, si, e, False)
            return _captures(ms, si, e)
        si += 1
        if anchor or si > len(s):
            return [None]


def lua_match(s, p, init=None):
    return lua_find(s, p, init, False, False)


def lua_gmatch(s, p):
    pos = [0]
    lastmatch = [-1]

    def it():
        anchor = len(p) > 0 and p[0] == 94
        pi = 1 if anchor else 0
        si = pos[0]
        while si <= len(s):
            ms = _MS(s, p)
            e = _do_match(ms, si, pi)
            if e is not None and e != lastmatch[0]:
                pos[0] = e
                lastmatch[0] = e
                if e == si:
                    pos[0] = e
                return _captures(ms, si, e)
            si += 1
            if anchor:
                break
        pos[0] = len(s) + 1
        return [None]

    return it


def lua_gsub(s, p, repl, n, call, tostr, index):
    """call(f, args)->list, tostr(v)->bytes, index(t,k)->v"""
    anchor = len(p) > 0 and p[0] == 94
    pi = 1 if anchor else 0
    si = 0
    out = bytearray()
    count = 0
    maxn = len(s) + 1 if n is None else int(n)
    while count < maxn:
        ms = _MS(s, p)
        e = _do_match(ms, si, pi)
        if e is not None:
            count += 1
            whole = s[si:e]
            caps = _captures(ms, si, e)
            tr = type(repl)
            if tr is bytes:
                i = 0
                while i < len(repl):
                    c = repl[i]
                    if c == L_ESC:
                        i += 1
                        d = repl[i]
                        if d == L_ESC:
                            out.append(L_ESC)
                        elif 48 <= d <= 57:
                            if d == 48:
                                out += whole
                            else:
                                v = _get_capture(ms, d - 49, si, e)
                                out += v if type(v) is bytes else str(v).encode()
                        else:
                            raise PatternError("invalid use of '%' in replacement string")
                    else:
                        out.append(c)
                    i += 1
            else:
                if tr is int or tr is float:
                    v = tostr(repl)
                elif callable(repl) and not hasattr(repl, "h"):
                    r = call(repl, caps)
                    v = r[0] if r else None
                else:
                    v = index(repl, caps[0])
                if v is None or v is False:
                    out += whole
                elif type(v) is bytes:
                    out += v
                elif type(v) in (int, float):
                    out += tostr(v)
                else:
                    raise PatternError("invalid replacement value")
        if e is not None and e > si:
            si = e
        elif si < len(s):
            out.append(s[si])
            si += 1
        else:
            break
        if anchor:
            break
    out += s[si:]
    return bytes(out), count
