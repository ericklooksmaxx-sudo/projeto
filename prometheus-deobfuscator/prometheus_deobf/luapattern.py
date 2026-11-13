"""Lua 5.1 string patterns (port of lstrlib.c's matcher)."""

L_ESC = "%"
SPECIALS = "^$*+?.([%-"
MAXCAPTURES = 32
CAP_UNFINISHED = -1
CAP_POSITION = -2


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
    if c == "[":
        if i < len(p) and p[i] == "^":
            i += 1
        while True:
            if i >= len(p):
                raise PatternError("malformed pattern (missing ']')")
            c = p[i]
            i += 1
            if c == L_ESC:
                i += 1
            if i < len(p) and p[i] == "]":
                return i + 1
            if i >= len(p):
                raise PatternError("malformed pattern (missing ']')")
    return i


def _single_class(c, cl):
    o = ord(c)
    lo = cl.lower()
    if lo == "a":
        r = c.isalpha() and o < 128
    elif lo == "c":
        r = o < 32 or o == 127
    elif lo == "d":
        r = "0" <= c <= "9"
    elif lo == "l":
        r = "a" <= c <= "z"
    elif lo == "p":
        r = 33 <= o <= 47 or 58 <= o <= 64 or 91 <= o <= 96 or 123 <= o <= 126
    elif lo == "s":
        r = c in " \t\n\r\f\v"
    elif lo == "u":
        r = "A" <= c <= "Z"
    elif lo == "w":
        r = (c.isalnum() and o < 128)
    elif lo == "x":
        r = c in "0123456789abcdefABCDEF"
    elif lo == "z":
        r = o == 0
    else:
        return cl == c
    if cl.isupper():
        return not r
    return r


def _match_bracket(c, p, pi, ec):
    # p[pi] == '[' ; ec is index of ']'
    sig = True
    i = pi + 1
    if p[i] == "^":
        sig = False
        i += 1
    while i < ec:
        if p[i] == L_ESC:
            i += 1
            if _single_class(c, p[i]):
                return sig
            i += 1
        elif i + 2 < ec and p[i + 1] == "-":
            if p[i] <= c <= p[i + 2]:
                return sig
            i += 3
        else:
            if p[i] == c:
                return sig
            i += 1
    return not sig


def _single_match(s, si, p, pi, ep):
    if si >= len(s):
        return False
    c = s[si]
    pc = p[pi]
    if pc == ".":
        return True
    if pc == L_ESC:
        return _single_class(c, p[pi + 1])
    if pc == "[":
        return _match_bracket(c, p, pi, ep - 1)
    return pc == c


class _MS(object):
    def __init__(self, s, p):
        self.s = s
        self.p = p
        self.level = 0
        self.capture = []
        self.depth = 0


def _match(ms, si, pi):
    ms.depth += 1
    if ms.depth > 200:
        raise PatternError("pattern too complex")
    try:
        return _do_match(ms, si, pi)
    finally:
        ms.depth -= 1


def _do_match(ms, si, pi):
    s, p = ms.s, ms.p
    while True:
        if pi >= len(p):
            return si
        c = p[pi]
        if c == "(":
            if pi + 1 < len(p) and p[pi + 1] == ")":
                return _start_capture(ms, si, pi + 2, CAP_POSITION)
            return _start_capture(ms, si, pi + 1, CAP_UNFINISHED)
        if c == ")":
            return _end_capture(ms, si, pi + 1)
        if c == L_ESC and pi + 1 < len(p):
            nc = p[pi + 1]
            if nc == "b":
                return _match_balance(ms, si, pi + 2)
            if nc == "f":
                pi += 2
                if pi >= len(p) or p[pi] != "[":
                    raise PatternError("missing '[' after '%f' in pattern")
                ep = _class_end(p, pi)
                prev = s[si - 1] if si > 0 else "\0"
                cur = s[si] if si < len(s) else "\0"
                if (not _match_bracket(prev, p, pi, ep - 1)) and _match_bracket(cur, p, pi, ep - 1):
                    pi = ep
                    continue
                return None
            if nc.isdigit():
                si = _match_capture(ms, si, int(nc))
                if si is None:
                    return None
                pi += 2
                continue
        if c == "$" and pi + 1 == len(p):
            return si if si == len(s) else None
        ep = _class_end(p, pi)
        m = si < len(s) and _single_match(s, si, p, pi, ep)
        if ep < len(p):
            q = p[ep]
            if q == "?":
                if m:
                    r = _match(ms, si + 1, ep + 1)
                    if r is not None:
                        return r
                pi = ep + 1
                continue
            if q == "*":
                return _max_expand(ms, si, pi, ep)
            if q == "+":
                return _max_expand(ms, si + 1, pi, ep) if m else None
            if q == "-":
                return _min_expand(ms, si, pi, ep)
        if not m:
            return None
        si += 1
        pi = ep


def _max_expand(ms, si, pi, ep):
    i = 0
    while _single_match(ms.s, si + i, ms.p, pi, ep):
        i += 1
    while i >= 0:
        r = _match(ms, si + i, ep + 1)
        if r is not None:
            return r
        i -= 1
    return None


def _min_expand(ms, si, pi, ep):
    while True:
        r = _match(ms, si, ep + 1)
        if r is not None:
            return r
        if _single_match(ms.s, si, ms.p, pi, ep):
            si += 1
        else:
            return None


def _start_capture(ms, si, pi, what):
    ms.capture.append([si, what])
    ms.level += 1
    r = _match(ms, si, pi)
    if r is None:
        ms.level -= 1
        ms.capture.pop()
    return r


def _end_capture(ms, si, pi):
    l = -1
    for i in range(ms.level - 1, -1, -1):
        if ms.capture[i][1] == CAP_UNFINISHED:
            l = i
            break
    if l < 0:
        raise PatternError("invalid pattern capture")
    ms.capture[l][1] = si - ms.capture[l][0]
    r = _match(ms, si, pi)
    if r is None:
        ms.capture[l][1] = CAP_UNFINISHED
    return r


def _match_balance(ms, si, pi):
    p, s = ms.p, ms.s
    if pi + 1 >= len(p):
        raise PatternError("unbalanced pattern")
    if si >= len(s) or s[si] != p[pi]:
        return None
    b, e = p[pi], p[pi + 1]
    cont = 1
    i = si + 1
    while i < len(s):
        if s[i] == e:
            cont -= 1
            if cont == 0:
                return _match(ms, i + 1, pi + 2)
        elif s[i] == b:
            cont += 1
        i += 1
    return None


def _match_capture(ms, si, l):
    l -= 1
    if l < 0 or l >= ms.level or ms.capture[l][1] == CAP_UNFINISHED:
        raise PatternError("invalid capture index")
    start, ln = ms.capture[l]
    cap = ms.s[start:start + ln]
    if ms.s[si:si + len(cap)] == cap:
        return si + len(cap)
    return None


def _get_capture(ms, i, si, ei):
    if i >= ms.level:
        if i == 0:
            return ms.s[si:ei]
        raise PatternError("invalid capture index")
    start, ln = ms.capture[i]
    if ln == CAP_POSITION:
        return float(start + 1)
    return ms.s[start:start + ln]


def _captures(ms, si, ei, whole_if_none=True):
    n = ms.level if (ms.level or not whole_if_none) else 1
    return [_get_capture(ms, i, si, ei) for i in range(n)]


def find(s, p, init=1, plain=False, want_captures=True):
    n = len(s)
    if init < 0:
        init = n + init + 1
        if init < 1:
            init = 1
    elif init == 0:
        init = 1
    if init > n + 1:
        return None
    if plain or not any(c in SPECIALS for c in p):
        i = s.find(p, init - 1)
        if i < 0:
            return None
        return [float(i + 1), float(i + len(p))]
    anchor = p.startswith("^")
    pi = 1 if anchor else 0
    si = init - 1
    while True:
        ms = _MS(s, p)
        e = _match(ms, si, pi)
        if e is not None:
            if want_captures:
                return [float(si + 1), float(e)] + (_captures(ms, si, e, False) if ms.level else [])
            return [float(si + 1), float(e)]
        si += 1
        if anchor or si > n:
            return None


def match(s, p, init=1):
    n = len(s)
    if init < 0:
        init = max(n + init + 1, 1)
    elif init == 0:
        init = 1
    if init > n + 1:
        return None
    anchor = p.startswith("^")
    pi = 1 if anchor else 0
    si = init - 1
    while True:
        ms = _MS(s, p)
        e = _match(ms, si, pi)
        if e is not None:
            return _captures(ms, si, e)
        si += 1
        if anchor or si > n:
            return None


def gmatch_iter(s, p):
    pos = [0]

    def nxt():
        while pos[0] <= len(s):
            ms = _MS(s, p)
            si = pos[0]
            e = _match(ms, si, 0)
            if e is not None:
                pos[0] = e + 1 if e == si else e
                return _captures(ms, si, e)
            pos[0] += 1
        return None
    return nxt


def gsub(s, p, repl_fn, max_n=None):
    """repl_fn(whole, captures) -> replacement string or None/False (keep)."""
    anchor = p.startswith("^")
    pi = 1 if anchor else 0
    si = 0
    out = []
    n = 0
    while max_n is None or n < max_n:
        ms = _MS(s, p)
        e = _match(ms, si, pi)
        if e is not None:
            n += 1
            whole = s[si:e]
            r = repl_fn(whole, _captures(ms, si, e))
            out.append(whole if r is None else r)
        if e is not None and e > si:
            si = e
        elif si < len(s):
            out.append(s[si])
            si += 1
        else:
            break
        if anchor:
            break
    out.append(s[si:])
    return "".join(out), n
