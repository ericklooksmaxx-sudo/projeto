"""Lua 5.1 value semantics shared by the constant folder and the emulator."""

import math


class LuaError(Exception):
    """A Lua runtime error. `value` is the error object; `positioned` once a "chunk:line:" prefix was added."""

    def __init__(self, msg, value=None, positioned=False):
        Exception.__init__(self, msg)
        self.value = msg if value is None else value
        self.positioned = positioned


def num2str(v):
    if v != v:
        return "nan" if math.copysign(1, v) > 0 else "-nan"
    if v == math.inf:
        return "inf"
    if v == -math.inf:
        return "-inf"
    if v == int(v) and abs(v) < 1e15:
        if v == 0 and math.copysign(1, v) < 0:
            return "-0"
        return "%d" % int(v)
    s = "%.14g" % v
    return s


def str2num(s):
    if not isinstance(s, str):
        return None
    t = s.strip(" \t\n\r\f\v")
    if not t:
        return None
    try:
        neg = False
        u = t
        if u[0] in "+-":
            neg = u[0] == "-"
            u = u[1:]
        if u[:2].lower() == "0x":
            v = float(int(u[2:], 16))
            return -v if neg else v
        if u.lower() in ("inf", "nan", "infinity") or "_" in u:
            return None
        return float(t)
    except ValueError:
        return None


def tonum(v):
    if isinstance(v, bool):
        return None
    if isinstance(v, (int, float)):
        return float(v)
    if isinstance(v, str):
        return str2num(v)
    return None


def lua_mod(a, b):
    if b == 0:
        return float("nan")
    if math.isinf(b):
        if math.isinf(a) or a != a:
            return float("nan")
        if (a >= 0) == (b > 0):
            return a
        return b
    return a - math.floor(a / b) * b


def lua_div(a, b):
    try:
        return a / b
    except ZeroDivisionError:
        if a == 0 or a != a:
            return float("nan")
        sign = math.copysign(1, a) * math.copysign(1, b)
        return math.inf if sign > 0 else -math.inf


def lua_pow(a, b):
    try:
        r = math.pow(a, b)
    except (OverflowError, ValueError):
        try:
            r = float(a) ** float(b)
            if isinstance(r, complex):
                return float("nan")
        except OverflowError:
            return math.inf
        except ZeroDivisionError:
            return math.inf
    return r


def arith(op, a, b):
    """Raw arithmetic on numbers/coercible strings. Returns None if not applicable."""
    x, y = tonum(a), tonum(b)
    if x is None or y is None:
        return None
    if op == "+":
        return x + y
    if op == "-":
        return x - y
    if op == "*":
        return x * y
    if op == "/":
        return lua_div(x, y)
    if op == "%":
        return lua_mod(x, y)
    if op == "^":
        return lua_pow(x, y)
    raise ValueError(op)


def tostr_concat(v):
    if isinstance(v, str):
        return v
    if isinstance(v, (int, float)) and not isinstance(v, bool):
        return num2str(float(v))
    return None


def truthy(v):
    return v is not None and v is not False
