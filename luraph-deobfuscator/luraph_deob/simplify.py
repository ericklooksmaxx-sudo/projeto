"""AST transformation helpers: substitution, copying and constant folding."""
from __future__ import annotations

import math

from . import luau_ast as A


def transform(node, fn):
    """Bottom-up rebuild. fn(node) returns replacement (or same node).
    Works on expressions, statements and lists of statements."""
    if isinstance(node, list):
        out = []
        for s in node:
            r = transform(s, fn)
            if isinstance(r, list):
                out.extend(r)
            elif r is not None:
                out.append(r)
        return out
    if not isinstance(node, A.Node):
        return node
    t = type(node)
    if t is A.Table:
        items = [(k, transform(kk, fn) if kk is not None else None, transform(v, fn)) for k, kk, v in node.items]
        return fn(A.Table(items))
    if t is A.If:
        clauses = [(transform(c, fn), transform(b, fn)) for c, b in node.clauses]
        return fn(A.If(clauses, transform(node.orelse, fn) if node.orelse is not None else None))
    vals = []
    for name in t.__slots__:
        v = getattr(node, name)
        if isinstance(v, A.Node):
            v = transform(v, fn)
        elif isinstance(v, list):
            v = [transform(x, fn) if isinstance(x, (A.Node, list)) else x for x in v]
            v = [x for x in v if x is not None]
            # flatten statement lists
            if v and any(isinstance(x, list) for x in v):
                flat = []
                for x in v:
                    if isinstance(x, list):
                        flat.extend(x)
                    else:
                        flat.append(x)
                v = flat
        vals.append(v)
    return fn(t(*vals))


def copy(node):
    return transform(node, lambda n: n)


def subst_name(node, name, expr):
    def f(n):
        if type(n) is A.Name and n.name == name:
            return copy(expr)
        return n
    return transform(node, f)


def is_const(e):
    return type(e) in (A.Number, A.String, A.Nil, A.TrueE, A.FalseE)


def const_value(e):
    t = type(e)
    if t is A.Number:
        return e.value
    if t is A.String:
        return e.value
    if t is A.Nil:
        return None
    if t is A.TrueE:
        return True
    if t is A.FalseE:
        return False
    raise ValueError


def make_const(v):
    if v is None:
        return A.Nil()
    if v is True:
        return A.TrueE()
    if v is False:
        return A.FalseE()
    if isinstance(v, (bytes, bytearray)):
        return A.String(bytes(v))
    if isinstance(v, float) and v.is_integer() and abs(v) < 2**53:
        return A.Number(int(v))
    if isinstance(v, (int, float)):
        return A.Number(v)
    raise ValueError(repr(v))


def truthy_const(e):
    if type(e) in (A.Nil, A.FalseE):
        return False
    if type(e) in (A.Number, A.String, A.TrueE, A.Table, A.Function):
        return True
    return None


def _num(e):
    return type(e) is A.Number


def fold_expr(n):
    t = type(n)
    if t is A.Paren:
        inner = n.expr
        if type(inner) in (A.Name, A.Number, A.String, A.Nil, A.TrueE, A.FalseE, A.Index, A.Paren, A.Table, A.Function):
            return inner
        return n
    if t is A.BinOp:
        l, r, op = n.left, n.right, n.op
        if op == "and":
            tl = truthy_const(l)
            if tl is True:
                return r
            if tl is False:
                return l
            return n
        if op == "or":
            tl = truthy_const(l)
            if tl is True:
                return l
            if tl is False:
                return r
            return n
        if _num(l) and _num(r):
            a, b = l.value, r.value
            try:
                if op == "+":
                    return make_const(a + b)
                if op == "-":
                    return make_const(a - b)
                if op == "*":
                    return make_const(a * b)
                if op == "/" and b != 0:
                    return make_const(a / b)
                if op == "%" and b != 0:
                    return make_const(a - math.floor(a / b) * b)
                if op == "//" and b != 0:
                    return make_const(math.floor(a / b))
                if op == "^":
                    return make_const(float(a) ** b)
                if op == "==":
                    return make_const(a == b)
                if op == "~=":
                    return make_const(a != b)
                if op == "<":
                    return make_const(a < b)
                if op == "<=":
                    return make_const(a <= b)
                if op == ">":
                    return make_const(a > b)
                if op == ">=":
                    return make_const(a >= b)
            except (OverflowError, ValueError, ZeroDivisionError):
                return n
        if op in ("==", "~=") and is_const(l) and is_const(r):
            eq = type(l) is type(r) and const_value(l) == const_value(r)
            return make_const(eq if op == "==" else not eq)
        if op == ".." and type(l) is A.String and type(r) is A.String:
            return A.String(l.value + r.value)
        # x + 0, 0 + x, x - 0, x * 1
        if op == "+" and _num(r) and r.value == 0:
            return l
        if op == "+" and _num(l) and l.value == 0:
            return r
        if op == "-" and _num(r) and r.value == 0:
            return l
        if op == "*" and _num(r) and r.value == 1:
            return l
        if op == "*" and _num(l) and l.value == 1:
            return r
        # (x + a) + b  -> x + (a+b)  and (x + a) - b
        if op in ("+", "-") and _num(r) and type(l) is A.BinOp and l.op in ("+", "-") and _num(l.right):
            a = l.right.value if l.op == "+" else -l.right.value
            b = r.value if op == "+" else -r.value
            s = a + b
            if s == 0:
                return l.left
            return A.BinOp("+" if s > 0 else "-", l.left, A.Number(abs(s)))
        return n
    if t is A.UnOp:
        o = n.operand
        if n.op == "not":
            tv = truthy_const(o)
            if tv is not None:
                return make_const(not tv)
            if type(o) is A.UnOp and o.op == "not" and type(o.operand) is A.BinOp and o.operand.op in ("==", "~=", "<", "<=", ">", ">="):
                return o.operand
            if type(o) is A.BinOp and o.op in ("==", "~="):
                return A.BinOp("~=" if o.op == "==" else "==", o.left, o.right)
            return n
        if n.op == "-" and _num(o):
            return make_const(-o.value)
        if n.op == "#" and type(o) is A.String:
            return A.Number(len(o.value))
        return n
    if t is A.IfExpr:
        tv = truthy_const(n.cond)
        if tv is True:
            return n.then
        if tv is False:
            return n.orelse
        return n
    return n


def fold_stmt(n):
    t = type(n)
    if t is A.If:
        clauses = []
        for c, b in n.clauses:
            tv = truthy_const(c)
            if tv is False:
                continue
            if tv is True:
                if not clauses:
                    return A.Do(b) if b else None
                return A.If(clauses, b)
            clauses.append((c, b))
        if not clauses:
            if n.orelse:
                return A.Do(n.orelse)
            return None
        return A.If(clauses, n.orelse)
    if t is A.While and truthy_const(n.cond) is False:
        return None
    return n


def _fold(n):
    r = fold_expr(n)
    if r is n:
        r = fold_stmt(n)
    return r


def fold(node):
    return transform(node, _fold)


def fold_block(stmts):
    out = fold(stmts)
    return flatten_do(out)


def flatten_do(stmts):
    """Inline `do ... end` blocks that declare no locals."""
    out = []
    for s in stmts:
        if type(s) is A.Do and not any(type(x) in (A.Local, A.LocalFunction) for x in s.body):
            out.extend(flatten_do(s.body))
        else:
            out.append(s)
    return out
