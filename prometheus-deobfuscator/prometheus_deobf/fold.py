"""Constant folding / generic expression simplification (undoes NumbersToExpressions etc.)."""

import math

from .luaast import (Nil, Bool, Number, String, Vararg, Name, Index, Call, Method, Func, Table, Bin, Un, Paren,
                     If, While, Repeat, Do, Local, LocalFunc, Return, Break, transform, is_multi)
from .luavalue import arith, tostr_concat, truthy

ARITH = {"+", "-", "*", "/", "%", "^"}
CMP = {"<", ">", "<=", ">="}


def const_value(e):
    """Return (True, value) for literal constants."""
    if isinstance(e, Nil):
        return True, None
    if isinstance(e, Bool):
        return True, e.value
    if isinstance(e, Number):
        return True, float(e.value)
    if isinstance(e, String):
        return True, e.value
    return False, None


def make_const(v):
    if v is None:
        return Nil()
    if isinstance(v, bool):
        return Bool(v)
    if isinstance(v, (int, float)):
        return Number(float(v))
    if isinstance(v, str):
        return String(v)
    raise TypeError(v)


def is_const(e):
    return const_value(e)[0]


def _boolean_valued(e):
    if isinstance(e, Bool):
        return True
    if isinstance(e, Un) and e.op == "not":
        return True
    return isinstance(e, Bin) and e.op in ("<", ">", "<=", ">=", "==", "~=")


def _single(e):
    return Paren(e) if is_multi(e) else e


def fold_expr(e):
    if isinstance(e, Paren):
        inner = e.expr
        if not is_multi(inner):
            return inner
        return None
    if isinstance(e, Bin):
        lc, lv = const_value(e.left)
        rc, rv = const_value(e.right)
        op = e.op
        if op == "and":
            if lc:
                return _single(e.right) if truthy(lv) else e.left
            if rc and rv is True and _boolean_valued(e.left):
                return e.left          # `cmp and true` -> `cmp`
            return None
        if op == "or":
            if lc:
                return e.left if truthy(lv) else _single(e.right)
            if rc and rv is False and _boolean_valued(e.left):
                return e.left          # `cmp or false` -> `cmp`
            return None
        if not (lc and rc):
            return None
        if op in ARITH:
            if isinstance(lv, float) and isinstance(rv, float):
                r = arith(op, lv, rv)
                if r is not None:
                    return Number(r)
            return None
        if op == "..":
            a, b = tostr_concat(lv), tostr_concat(rv)
            if a is not None and b is not None:
                return String(a + b)
            return None
        if op == "==":
            if type(lv) is type(rv) or lv is None or rv is None:
                return Bool(lv == rv and type(lv) is type(rv))
            return Bool(False)
        if op == "~=":
            if type(lv) is type(rv) or lv is None or rv is None:
                return Bool(not (lv == rv and type(lv) is type(rv)))
            return Bool(True)
        if op in CMP:
            if (isinstance(lv, float) and isinstance(rv, float)) or (isinstance(lv, str) and isinstance(rv, str)):
                if isinstance(lv, str):
                    lv, rv = lv.encode("latin-1"), rv.encode("latin-1")
                return Bool({"<": lv < rv, ">": lv > rv, "<=": lv <= rv, ">=": lv >= rv}[op])
        return None
    if isinstance(e, Un):
        c, v = const_value(e.expr)
        if e.op == "not":
            if c:
                return Bool(not truthy(v))
            if isinstance(e.expr, Un) and e.expr.op == "not" and isinstance(e.expr.expr, Un) and \
                    e.expr.expr.op == "not":
                return e.expr.expr  # not not not x -> not x
            if isinstance(e.expr, Bin) and e.expr.op in ("==", "~="):
                return Bin("~=" if e.expr.op == "==" else "==", e.expr.left, e.expr.right)
            return None
        if e.op == "-":
            if c and isinstance(v, float):
                return Number(-v)
            return None
        if e.op == "#":
            if c and isinstance(v, str):
                return Number(float(len(v)))
            return None
    return None


def fold_stat(s):
    if isinstance(s, If):
        c, v = const_value(s.cond)
        if c:
            body = s.body if truthy(v) else s.orelse
            if not body:
                return []
            return [Do(body)]
        if isinstance(s.cond, Un) and s.cond.op == "not" and not s.body and s.orelse:
            return If(s.cond.expr, s.orelse, [])
        if not s.body and not s.orelse:
            # condition evaluated for side effects only
            return None
    if isinstance(s, While):
        c, v = const_value(s.cond)
        if c and not truthy(v):
            return []
        if c and v is not True:
            s.cond = Bool(True)
    if isinstance(s, Do):
        if not s.body:
            return []
    return None


def fold(node):
    def fn(n):
        r = fold_expr(n)
        if r is not None:
            # fold again until stable (result nodes are already folded children)
            while True:
                r2 = fold_expr(r)
                if r2 is None:
                    break
                r = r2
            return r
        return fold_stat(n)

    return transform(node, fn)


def flatten_do(stats):
    """Inline `do ... end` blocks that declare no locals (recursively)."""
    out = []
    for s in stats:
        if isinstance(s, Do):
            body = flatten_do(s.body)
            if not any(isinstance(x, (Local, LocalFunc)) for x in body) and \
                    not (body and isinstance(body[-1], (Return, Break)) and s is not stats[-1]):
                out.extend(body)
                continue
            s.body = body
        out.append(s)
    return out


def flatten_all_do(node):
    def fn(n):
        for f in n.fields:
            v = getattr(n, f)
            if isinstance(v, list) and v and all(hasattr(x, "fields") for x in v) and f in ("body", "orelse"):
                setattr(n, f, flatten_do(v))
        return None

    return transform(node, fn)
