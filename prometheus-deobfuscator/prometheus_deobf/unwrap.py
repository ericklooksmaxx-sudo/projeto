"""Remove `return (function(...) ... end)(...)` wrappers (WrapInFunction, Cff entry)."""

from .luaast import Func, Call, Paren, Return, Vararg, Chunk, Local, transform


def _unparen(e):
    while isinstance(e, Paren):
        e = e.expr
    return e


def _named_wrapper(stmts):
    """`local function f(...) B end; return f(...)` -> B (f used nowhere else)."""
    from .luaast import LocalFunc, Name, walk as w
    if len(stmts) < 2 or not isinstance(stmts[-1], Return) or len(stmts[-1].exprs) != 1:
        return None
    d = stmts[-2]
    if isinstance(d, LocalFunc):
        sym, f = d.sym, d.func
    elif isinstance(d, Local) and len(d.syms) == 1 and len(d.exprs) == 1 and isinstance(d.exprs[0], Func):
        sym, f = d.syms[0], d.exprs[0]
    else:
        return None
    c = _unparen(stmts[-1].exprs[0])
    if not (isinstance(c, Call) and isinstance(c.func, Name) and c.func.sym is sym and len(c.args) == 1 and
            isinstance(c.args[0], Vararg) and not f.params and f.vararg):
        return None
    for n in w(Chunk(f.body)):
        if isinstance(n, Name) and n.sym is sym:
            return None
    for s in stmts[:-2]:
        for n in w(s):
            if isinstance(n, Name) and n.sym is sym:
                return None
    return f.body


def _forwarding_function(stmts):
    """[local function f(...) end, return f(...)] -> f's function literal (f not used elsewhere)."""
    from .luaast import LocalFunc, Name, walk as w
    if len(stmts) != 2 or not isinstance(stmts[1], Return) or len(stmts[1].exprs) != 1:
        return None
    d = stmts[0]
    if isinstance(d, LocalFunc):
        sym, f = d.sym, d.func
    elif isinstance(d, Local) and len(d.syms) == 1 and len(d.exprs) == 1 and isinstance(d.exprs[0], Func):
        sym, f = d.syms[0], d.exprs[0]
    else:
        return None
    c = _unparen(stmts[1].exprs[0])
    if not (isinstance(c, Call) and isinstance(c.func, Name) and c.func.sym is sym and len(c.args) == 1 and
            isinstance(c.args[0], Vararg)):
        return None
    for n in w(Chunk(f.body)):
        if isinstance(n, Name) and n.sym is sym:
            return None
    return f


def _wrapped_body(stmts):
    nb = _named_wrapper(stmts)
    if nb is not None:
        return ("named", nb)
    if not stmts or not isinstance(stmts[-1], Return) or len(stmts[-1].exprs) != 1:
        return None
    c = _unparen(stmts[-1].exprs[0])
    if not isinstance(c, Call):
        return None
    f = _unparen(c.func)
    if not isinstance(f, Func) or f.params or not f.vararg:
        return None
    if len(c.args) != 1 or not isinstance(c.args[0], Vararg):
        return None
    return f.body


def unwrap_body(stmts, is_vararg=True):
    changed = False
    while is_vararg:
        inner = _wrapped_body(stmts)
        if inner is None:
            break
        if isinstance(inner, tuple):
            stmts = stmts[:-2] + inner[1]
        else:
            stmts = stmts[:-1] + inner
        changed = True
    return stmts, changed


def unwrap(chunk):
    changed = [False]
    chunk.body, c = unwrap_body(chunk.body)
    changed[0] |= c

    def fn(n):
        if isinstance(n, Func) and n.vararg:
            n.body, c2 = unwrap_body(n.body)
            changed[0] |= c2
        return None

    transform(chunk, fn)
    return changed[0]


# ---------------------------------------------------------------------------
# beta reduction of the call shapes Cff / flattenVm leave behind
from .luaast import Name, Number, Assign, Local as _Local, walk as _walk, Return as _Return


def _assigned_syms(node):
    out = set()
    for n in _walk(node):
        if isinstance(n, Assign):
            for t in n.targets:
                if isinstance(t, Name) and t.sym is not None:
                    out.add(t.sym)
    return out


def _replace_level(body, fn):
    """Apply fn to nodes of `body` without entering nested functions."""
    def rec(x):
        if isinstance(x, Func):
            return x
        for f in x.fields:
            v = getattr(x, f)
            if hasattr(v, "fields"):
                setattr(x, f, rec(v))
            elif isinstance(v, list):
                setattr(x, f, [rec(y) if hasattr(y, "fields") else y for y in v])
        r = fn(x)
        return x if r is None else r
    return [rec(s) for s in body]


def _capture_header(body):
    """`local c1, c2 = ...` or `local c1 = (...); local c2 = (select(2, ...))` -> ([c1, c2], nstmts)."""
    caps = []
    i = 0
    while i < len(body):
        s = body[i]
        if not isinstance(s, _Local) or len(s.exprs) != 1:
            break
        e = _unparen(s.exprs[0])
        if isinstance(e, Vararg) and not caps:
            if isinstance(s.exprs[0], Paren) and len(s.syms) != 1:
                break
            caps.extend(s.syms if not isinstance(s.exprs[0], Paren) else s.syms[:1])
            i += 1
            continue
        if isinstance(e, Call) and isinstance(e.func, Name) and e.func.sym is None and e.func.name == "select" and \
                len(e.args) == 2 and isinstance(e.args[0], Number) and isinstance(e.args[1], Vararg) and \
                e.args[0].value == len(caps) + 1 and len(s.syms) == 1:
            caps.append(s.syms[0])
            i += 1
            continue
        break
    return caps, i


def beta_reduce(chunk):
    changed = [False]
    assigned = _assigned_syms(chunk)
    # variables assigned inside function bodies may change at any time
    in_funcs = set()
    for n in _walk(chunk):
        if isinstance(n, Func):
            in_funcs |= _assigned_syms(Chunk(n.body))
    # top-level statement index of each call node / last top-level assignment of each variable
    stmt_of = {}
    last_assign = {}
    for i, s in enumerate(chunk.body):
        for n in _walk(s):
            stmt_of[id(n)] = i
        for sym in _assigned_syms(s):
            last_assign[sym] = i

    def stable_at(sym, node):
        if sym not in assigned:
            return True
        if sym in in_funcs or id(node) not in stmt_of:
            return False
        return last_assign.get(sym, -1) < stmt_of[id(node)]

    def fn(n):
        if not isinstance(n, Call):
            return None
        f = _unparen(n.func)
        if not isinstance(f, Func) or f.params or not f.vararg:
            return None
        # (function(...) return F(...) end)(args)  ->  F(args)
        if len(f.body) == 1 and isinstance(f.body[0], _Return) and len(f.body[0].exprs) == 1:
            inner = _unparen(f.body[0].exprs[0])
            if isinstance(inner, Call) and len(inner.args) == 1 and isinstance(inner.args[0], Vararg) and \
                    isinstance(_unparen(inner.func), Func):
                changed[0] = True
                return Call(inner.func, n.args)
        # (function(...) local function f(...) B end; return f(...) end)(args) -> (function(...) B end)(args)
        inner = _forwarding_function(f.body)
        if inner is not None:
            changed[0] = True
            return Call(Paren(inner), n.args)
        # (function(...) local c1..ck = ...; BODY end)(x1..xk, ...)
        args = n.args
        caps, nhead = _capture_header(f.body)
        if not caps:
            return None
        k = len(caps)
        if len(args) != k + 1 or not isinstance(args[-1], Vararg):
            return None
        if not all(isinstance(a, Name) and a.sym is not None and stable_at(a.sym, n) for a in args[:-1]):
            return None
        if any(c in assigned for c in caps):
            return None
        mapping = dict(zip(caps, args[:-1]))
        uses = [0]

        marker = []

        def sub(x):
            if isinstance(x, Call) and isinstance(x.func, Name) and x.func.sym is None and x.func.name == "select" \
                    and len(x.args) == 2 and isinstance(x.args[0], Number) and x.args[0].value == k + 1 and \
                    isinstance(x.args[1], Vararg):
                m = Vararg()
                marker.append(m)
                return m
            return None

        def count(x):
            if isinstance(x, Vararg) and not any(x is m for m in marker):
                uses[0] += 1
            return None
        from .luaast import transform as _tr
        body = [_tr(s, lambda x: (lambda a: Name(a.name, a.sym))(mapping[x.sym])
                    if isinstance(x, Name) and x.sym in mapping else None) for s in f.body[nhead:]]
        body = _replace_level(body, sub)
        uses[0] = 0
        _replace_level(body, count)
        if uses[0]:
            return None  # other uses of the shifted varargs
        changed[0] = True
        return Call(Paren(Func([], True, body)), [Vararg()])

    transform(chunk, fn)
    return changed[0]
