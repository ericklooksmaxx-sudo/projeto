"""AST level clean-ups that make the recovered code read like source code."""

from .luaast import (Symbol, Nil, Bool, Number, String, Vararg, Name, Index, Call, Method, Func, Table, TItem, Bin,
                     Un, Paren, Local, Assign, CallStat, Do, While, Repeat, If, NumFor, GenFor, LocalFunc, FuncStat,
                     Return, Break, Chunk, Node, transform, walk, is_multi)
from . import fold, ir
from .printer import is_ident, KEYWORDS


# ------------------------------------------------------------------ helpers
def same_expr(a, b):
    if type(a) is not type(b):
        return False
    if isinstance(a, Name):
        return a.sym is b.sym and (a.sym is not None or a.name == b.name)
    if isinstance(a, (Number, String, Bool)):
        return a.value == b.value
    if isinstance(a, Nil):
        return True
    if isinstance(a, Paren):
        return same_expr(a.expr, b.expr)
    if isinstance(a, Index):
        return same_expr(a.obj, b.obj) and same_expr(a.key, b.key)
    return False


def simple_expr(e):
    """No side effects and cheap to duplicate."""
    if isinstance(e, (Name, Number, String, Bool, Nil)):
        return True
    if isinstance(e, Paren):
        return simple_expr(e.expr)
    if isinstance(e, Index):
        return simple_expr(e.obj) and isinstance(e.key, (String, Number))
    return False


def stat_lists(node):
    """Yield every statement list in the tree (including function bodies)."""
    for n in walk(node):
        if isinstance(n, (Chunk, Func, Do, While, NumFor, GenFor, Repeat)):
            yield n.body
        elif isinstance(n, If):
            yield n.body
            yield n.orelse


def count_refs(node):
    refs = {}
    for n in walk(node):
        if isinstance(n, Name) and n.sym is not None:
            refs[n.sym] = refs.get(n.sym, 0) + 1
    return refs


def assigned(node):
    out = set()
    for n in walk(node):
        if isinstance(n, Assign):
            for t in n.targets:
                if isinstance(t, Name) and t.sym is not None:
                    out.add(t.sym)
        elif isinstance(n, FuncStat) and isinstance(n.target, Name) and n.target.sym is not None:
            out.add(n.target.sym)
    return out


def refs_in(nodes):
    out = {}
    for x in nodes:
        for n in walk(x):
            if isinstance(n, Name) and n.sym is not None:
                out[n.sym] = out.get(n.sym, 0) + 1
    return out


def subst_sym(node, old, new):
    def fn(n):
        if isinstance(n, Name) and n.sym is old:
            return Name(new.name, new)
        return None
    return transform(node, fn)


# --------------------------------------------------------------- globals
def env_to_globals(chunk, env_syms):
    def fix(n):
        if isinstance(n, Index) and isinstance(n.obj, Name) and n.obj.sym in env_syms and \
                isinstance(n.key, String) and is_ident(n.key.value):
            return Name(n.key.value, None)
        return None
    chunk = transform(chunk, fix)

    def fix2(n):
        if isinstance(n, Name) and n.sym in env_syms:
            return Call(Name("getfenv", None), [])
        return None
    return transform(chunk, fix2)


# --------------------------------------------------------------- peepholes
def method_calls(chunk):
    changed = [False]

    def fn(n):
        if isinstance(n, Call) and isinstance(n.func, Index) and isinstance(n.func.key, String) and \
                is_ident(n.func.key.value) and n.args and same_expr(n.func.obj, n.args[0]) and \
                simple_expr(n.args[0]):
            changed[0] = True
            obj = n.func.obj
            if isinstance(obj, (String, Number, Table)):
                obj = Paren(obj)
            return Method(obj, n.func.key.value, n.args[1:])
        return None
    transform(chunk, fn)
    return changed[0]


def merge_decl_assign(chunk):
    """`local x` followed by `x = e` -> `local x = e`; `local f = function` -> local function."""
    changed = False
    for lst in list(stat_lists(chunk)):
        i = 0
        while i < len(lst) - 1:
            a, b = lst[i], lst[i + 1]
            if isinstance(a, Local) and (not a.exprs or all(isinstance(x, Nil) for x in a.exprs)) and \
                    isinstance(b, Assign) and \
                    len(b.targets) == len(a.syms) and \
                    all(isinstance(t, Name) and t.sym is s for t, s in zip(b.targets, a.syms)):
                rhs_refs = refs_in(b.exprs)
                if len(a.syms) == 1 and len(b.exprs) == 1 and isinstance(b.exprs[0], Func):
                    lst[i:i + 2] = [LocalFunc(a.syms[0], b.exprs[0])]
                    changed = True
                    continue
                if not any(s in rhs_refs for s in a.syms):
                    lst[i:i + 2] = [Local(a.syms, b.exprs)]
                    changed = True
                    continue
            i += 1
        i = 0
        while i < len(lst) - 2:
            a, b, c = lst[i], lst[i + 1], lst[i + 2]
            if isinstance(a, Local) and len(a.syms) == 1 and all(isinstance(x, Nil) for x in a.exprs) and \
                    isinstance(b, LocalFunc) and isinstance(c, Assign) and len(c.targets) == 1 and \
                    len(c.exprs) == 1 and isinstance(c.targets[0], Name) and c.targets[0].sym is a.syms[0] and \
                    isinstance(c.exprs[0], Name) and c.exprs[0].sym is b.sym and count_refs(chunk).get(b.sym) == 1:
                lst[i:i + 3] = [LocalFunc(a.syms[0], b.func)]
                changed = True
                continue
            i += 1
        for j, s in enumerate(lst):
            if isinstance(s, Local) and len(s.syms) == 1 and len(s.exprs) == 1 and isinstance(s.exprs[0], Func):
                lst[j] = LocalFunc(s.syms[0], s.exprs[0])
                changed = True
    return changed


def drop_trailing_return(chunk):
    changed = False
    for n in walk(chunk):
        if isinstance(n, (Chunk, Func)) and n.body and isinstance(n.body[-1], Return) and not n.body[-1].exprs:
            n.body.pop()
            changed = True
    return changed


def flatten_else(chunk):
    """`if c then ... return end else B end` -> `if c then ... return end B`."""
    changed = False
    for lst in list(stat_lists(chunk)):
        i = 0
        while i < len(lst):
            s = lst[i]
            if isinstance(s, If) and s.orelse and s.body and isinstance(s.body[-1], (Return, Break)) and \
                    not (len(s.orelse) == 1 and isinstance(s.orelse[0], If)):
                rest = s.orelse
                s.orelse = []
                lst[i + 1:i + 1] = rest
                changed = True
            elif isinstance(s, If) and len(s.orelse) == 1 and isinstance(s.orelse[0], If) is False and False:
                pass
            i += 1
    return changed


def nested_elseif(chunk):
    """`else if .. end end` is printed as elseif automatically (orelse == [If])."""
    return False


def strip_for_checks(e):
    """`tonumber(x) or error("'for' ... must be a number")` -> x."""
    if isinstance(e, Bin) and e.op == "or" and isinstance(e.right, Call) and isinstance(e.right.func, Name) and \
            e.right.func.sym is None and e.right.func.name == "error" and e.right.args and \
            isinstance(e.right.args[0], String) and e.right.args[0].value.startswith("'for' "):
        l = e.left
        if isinstance(l, Call) and isinstance(l.func, Name) and l.func.sym is None and l.func.name == "tonumber" \
                and len(l.args) == 1:
            return l.args[0], e.right.args[0].value
    return None, None


def _is_sym(e, sym):
    return isinstance(e, Name) and e.sym is sym


def _apply_until_stable(chunk, attempt):
    changed = False
    while True:
        hit = False
        for owner in list(walk(chunk)):
            for lst in _lists_of(owner):
                for i in range(len(lst)):
                    if attempt(lst, i):
                        hit = True
                        break
                if hit:
                    break
            if hit:
                break
        if not hit:
            return changed
        changed = True


def _discarded_compare(s, cur):
    return isinstance(s, Local) and len(s.syms) == 1 and s.syms[0].attrs.get("discard") and len(s.exprs) == 1 and \
        isinstance(s.exprs[0], Bin) and s.exprs[0].op in ("<", ">", "<=", ">=") and \
        (_is_sym(s.exprs[0].left, cur) or _is_sym(s.exprs[0].right, cur))


def _try_numfor_plain(lst, w):
    """`local c = c0; while true do c = c + s; if not (c <= L) then break end; BODY end` (no coercion checks)."""
    loop = lst[w]
    if not (isinstance(loop, While) and isinstance(loop.cond, Bool) and loop.cond.value and len(loop.body) >= 2):
        return False
    first = loop.body[0]
    if not (isinstance(first, Assign) and len(first.targets) == 1 and isinstance(first.targets[0], Name) and
            len(first.exprs) == 1 and isinstance(first.exprs[0], Bin) and first.exprs[0].op == "+"):
        return False
    cur = first.targets[0].sym
    # comparisons evaluated and thrown away (the obfuscator computes both branches of the direction test)
    skip = 1
    while skip < len(loop.body) - 1 and _discarded_compare(loop.body[skip], cur):
        skip += 1
    chk = loop.body[skip]
    add = first.exprs[0]
    if _is_sym(add.left, cur) and isinstance(add.right, Number):
        step = add.right.value
    elif _is_sym(add.right, cur) and isinstance(add.left, Number):
        step = add.left.value
    else:
        return False
    if step == 0 or not (isinstance(chk, If) and len(chk.body) == 1 and isinstance(chk.body[0], Break) and
                         not chk.orelse and isinstance(chk.cond, Un) and chk.cond.op == "not" and
                         isinstance(chk.cond.expr, Bin)):
        return False
    c = chk.cond.expr
    flip = {"<=": ">=", ">=": "<=", "<": ">", ">": "<"}
    if _is_sym(c.left, cur):
        op, lim = c.op, c.right
    elif _is_sym(c.right, cur):
        op, lim = flip.get(c.op), c.left
    else:
        return False
    if op != ("<=" if step > 0 else ">="):
        return False
    if not isinstance(lim, (Number, Name)):
        return False
    jc, init = _def_of(lst, w, cur)
    if jc is None or not isinstance(init, Number):
        return False
    rest = loop.body[skip + 1:]
    asg = assigned(Chunk(rest))
    if cur in asg or (isinstance(lim, Name) and lim.sym in asg):
        return False
    after = refs_in(lst[w + 1:])
    if cur in after:
        return False
    if rest and isinstance(rest[0], Local) and len(rest[0].syms) == 1 and len(rest[0].exprs) == 1 and \
            _is_sym(rest[0].exprs[0], cur) and rest[0].syms[0] not in assigned(Chunk(rest[1:])):
        var = rest[0].syms[0]
        rest = rest[1:]
    else:
        var = Symbol("i")
    rest = [subst_sym(s, cur, var) for s in rest]
    start = init.value + step
    lst[w] = NumFor(var, Number(start), lim, None if step == 1 else Number(step), rest)
    del lst[jc]
    return True


def recover_numeric_for(chunk):
    return _apply_until_stable(chunk, lambda l, i: _try_numfor(l, i) or _try_numfor_plain(l, i))


def tuple_for(chunk):
    """`local t = {f(x)}; for k, v in t[1], t[2], t[3] do` -> `for k, v in f(x) do`."""
    changed = False
    for owner in list(walk(chunk)):
        for lst in _lists_of(owner):
            for w, s in enumerate(lst):
                if not (isinstance(s, GenFor) and s.exprs and w > 0):
                    continue
                prev = lst[w - 1]
                if not (isinstance(prev, Local) and len(prev.syms) == 1 and len(prev.exprs) == 1 and
                        isinstance(prev.exprs[0], Table) and len(prev.exprs[0].items) == 1 and
                        prev.exprs[0].items[0].key is None and
                        isinstance(prev.exprs[0].items[0].value, (Call, Method))):
                    continue
                t = prev.syms[0]
                ok = all(isinstance(e, Index) and _is_sym(e.obj, t) and isinstance(e.key, Number) and
                         e.key.value == i + 1 for i, e in enumerate(s.exprs))
                if not ok or refs_in(lst[w + 1:]).get(t) or refs_in(s.body).get(t):
                    continue
                s.exprs = [prev.exprs[0].items[0].value]
                del lst[w - 1]
                changed = True
                break
    return changed


def _lists_of(n):
    if isinstance(n, (Chunk, Func, Do, While, NumFor, GenFor, Repeat)):
        return [n.body]
    if isinstance(n, If):
        return [n.body, n.orelse]
    return []


def _def_of(lst, start, sym):
    """Find the statement (index, expr) that defines sym (Local or Assign), scanning backwards."""
    for j in range(start - 1, max(-1, start - 12), -1):
        s = lst[j]
        if isinstance(s, Local) and len(s.syms) == 1 and s.syms[0] is sym and len(s.exprs) == 1:
            return j, s.exprs[0]
        if isinstance(s, Assign) and len(s.targets) == 1 and _is_sym(s.targets[0], sym) and len(s.exprs) == 1:
            return j, s.exprs[0]
    return None, None


def _absorb_cond_temps(body):
    """[x = a+b, local t = <cmp>, if <uses t once> then break end, ...] -> t inlined into the condition."""
    k = 1
    temps = []
    while k < len(body) and isinstance(body[k], Local) and len(body[k].syms) == 1 and len(body[k].exprs) == 1 \
            and not any(isinstance(x, (Call, Method)) for x in walk(body[k].exprs[0])):
        temps.append(body[k])
        k += 1
    if not temps or k >= len(body) or not isinstance(body[k], If):
        return body
    chk = body[k]
    refs = count_refs(Chunk(body))
    cond_refs = refs_in([chk.cond])
    for t in temps:
        s = t.syms[0]
        if refs.get(s, 0) != 1 or cond_refs.get(s, 0) != 1:
            return body
    for t in temps:
        s, e = t.syms[0], t.exprs[0]
        chk.cond = transform(chk.cond, lambda n, s=s, e=e: e if isinstance(n, Name) and n.sym is s else None)
    return [body[0]] + body[k:]


def _try_numfor(lst, w):
    loop = lst[w]
    if not (isinstance(loop, While) and isinstance(loop.cond, Bool) and loop.cond.value and len(loop.body) >= 2):
        return False
    loop.body = _absorb_cond_temps(loop.body)
    first, chk = loop.body[0], loop.body[1]
    if not (isinstance(first, Assign) and len(first.targets) == 1 and isinstance(first.targets[0], Name) and
            len(first.exprs) == 1 and isinstance(first.exprs[0], Bin) and first.exprs[0].op == "+"):
        return False
    cur = first.targets[0].sym
    add = first.exprs[0]
    if _is_sym(add.left, cur) and isinstance(add.right, Name):
        step = add.right.sym
    elif _is_sym(add.right, cur) and isinstance(add.left, Name):
        step = add.left.sym
    else:
        return False
    if not (isinstance(chk, If) and chk.body == [] or isinstance(chk, If) and len(chk.body) == 1 and
            isinstance(chk.body[0], Break) and not chk.orelse):
        return False
    # definitions before the loop
    jc, cur_init = _def_of(lst, w, cur)
    js, step_e = _def_of(lst, w, step)
    if jc is None or js is None:
        return False
    step_v, msg = strip_for_checks(step_e)
    if step_v is None or "step" not in msg:
        return False
    if not (isinstance(cur_init, Bin) and cur_init.op == "-" and _is_sym(cur_init.right, step)):
        return False
    init_e = cur_init.left
    ji = None
    init_v, msg = strip_for_checks(init_e)
    if init_v is None and isinstance(init_e, Name):
        ji, ie = _def_of(lst, jc, init_e.sym)
        if ji is None:
            return False
        init_v, msg = strip_for_checks(ie)
        init_sym = init_e.sym
    if init_v is None or "initial" not in msg:
        return False
    # limit and sign symbols come from the break condition
    cond_syms = set(n.sym for n in walk(chk.cond) if isinstance(n, Name) and n.sym is not None)
    cond_syms.discard(cur)
    lim = neg = None
    jl = jn = None
    for s in cond_syms:
        j, e = _def_of(lst, w, s)
        if j is None:
            return False
        v, msg = strip_for_checks(e)
        if v is not None and "limit" in msg:
            lim, jl, lim_v = s, j, v
        elif isinstance(e, Bin) and e.op in ("<", ">"):
            neg, jn = s, j
        else:
            return False
    if lim is None:
        return False
    rest = loop.body[2:]
    temps = set([cur, step, lim] + ([neg] if neg else []))
    if assigned(Chunk(rest)) & temps:
        return False
    after = refs_in(lst[w + 1:])
    if any(t in after for t in temps):
        return False
    # loop variable
    if rest and isinstance(rest[0], Local) and len(rest[0].syms) == 1 and len(rest[0].exprs) == 1 and \
            _is_sym(rest[0].exprs[0], cur) and rest[0].syms[0] not in assigned(Chunk(rest[1:])):
        var = rest[0].syms[0]
        rest = rest[1:]
    else:
        var = Symbol("i")
    rest = [subst_sym(s, cur, var) for s in rest]
    step_out = None if (isinstance(step_v, Number) and step_v.value == 1) else step_v
    nf = NumFor(var, init_v, lim_v, step_out, rest)
    drop = set(x for x in (jc, js, ji, jl, jn) if x is not None)
    lst[w] = nf
    for j in sorted(drop, reverse=True):
        del lst[j]
    return True


def multi_results(chunk):
    """`local t = {f()}; local a = t[1]; local b = t[2]` (any order) -> `local a, b = f()`."""
    changed = False
    refs = count_refs(chunk)
    for lst in list(stat_lists(chunk)):
        i = 0
        while i < len(lst):
            s = lst[i]
            if isinstance(s, (Local, Assign)) and len(s.exprs) == 1 and isinstance(s.exprs[0], Table) and \
                    len(s.exprs[0].items) == 1 and s.exprs[0].items[0].key is None and \
                    isinstance(s.exprs[0].items[0].value, (Call, Method)):
                if isinstance(s, Local):
                    tsym = s.syms[0] if len(s.syms) == 1 else None
                else:
                    tsym = s.targets[0].sym if len(s.targets) == 1 and isinstance(s.targets[0], Name) else None
                if tsym is None:
                    i += 1
                    continue
                k = i + 1
                picked = {}
                is_local = None
                while k < len(lst):
                    t = lst[k]
                    if isinstance(t, (Local, Assign)) and len(t.exprs) == 1 and isinstance(t.exprs[0], Index) and \
                            _is_sym(t.exprs[0].obj, tsym) and isinstance(t.exprs[0].key, Number) and \
                            t.exprs[0].key.value not in picked:
                        tl = isinstance(t, Local)
                        if is_local is None:
                            is_local = tl
                        if tl != is_local:
                            break
                        if tl and len(t.syms) == 1:
                            picked[t.exprs[0].key.value] = t.syms[0]
                        elif not tl and len(t.targets) == 1 and isinstance(t.targets[0], Name):
                            picked[t.exprs[0].key.value] = t.targets[0]
                        else:
                            break
                        k += 1
                    else:
                        break
                n = len(picked)
                if n and sorted(picked) == [float(x) for x in range(1, n + 1)] and refs.get(tsym, 0) == n:
                    targets = [picked[float(x)] for x in range(1, n + 1)]
                    call = s.exprs[0].items[0].value
                    new = Local(targets, [call]) if is_local else Assign(targets, [call])
                    lst[i:k] = [new]
                    changed = True
            i += 1
    return changed


def vararg_tables(chunk):
    """`local t = {...}` (or `{select(1, ...)}`) only ever read as `unpack(t)` -> use `...` directly."""
    changed = False
    for fn in list(walk(chunk)):
        if not isinstance(fn, (Func, Chunk)) or (isinstance(fn, Func) and not fn.vararg):
            continue
        body = fn.body
        for i, s in enumerate(body):
            if not (isinstance(s, Local) and len(s.syms) == 1 and len(s.exprs) == 1 and
                    isinstance(s.exprs[0], Table) and len(s.exprs[0].items) == 1 and
                    s.exprs[0].items[0].key is None):
                continue
            v = s.exprs[0].items[0].value
            if isinstance(v, Call) and isinstance(v.func, Name) and v.func.sym is None and \
                    v.func.name == "select" and len(v.args) == 2 and isinstance(v.args[0], Number) and \
                    v.args[0].value == 1 and isinstance(v.args[1], Vararg):
                v = v.args[1]
            if not isinstance(v, Vararg):
                continue
            t = s.syms[0]
            uses, nested, other = [], False, False
            parents = {}
            for st in body[i + 1:]:
                _collect_parents(st, parents)
            for n in [x for st in body[i + 1:] for x in walk(st)]:
                if isinstance(n, Name) and n.sym is t:
                    p = parents.get(n)
                    if isinstance(p, Call) and isinstance(p.func, Name) and p.func.sym is None and \
                            p.func.name == "unpack" and len(p.args) == 1 and p.args[0] is n:
                        uses.append(p)
                    else:
                        other = True
            if other or not uses:
                continue
            # `...` is not visible inside nested functions
            inner = set()
            for st in body[i + 1:]:
                for n in walk(st):
                    if isinstance(n, Func):
                        inner |= set(id(x) for x in walk(n))
            if any(id(u) in inner for u in uses):
                continue
            ids = set(id(u) for u in uses)

            def fix(n, ids=ids):
                return Vararg() if id(n) in ids else None
            for j in range(i + 1, len(body)):
                body[j] = transform(body[j], fix)
            del body[i]
            changed = True
            break
    return changed


def _collect_parents(node, parents):
    stack = [node]
    while stack:
        x = stack.pop()
        for f in x.fields:
            v = getattr(x, f)
            if isinstance(v, Node):
                parents[v] = x
                stack.append(v)
            elif isinstance(v, list):
                for y in v:
                    if isinstance(y, Node):
                        parents[y] = x
                        stack.append(y)


def recover_generic_for(chunk):
    return _apply_until_stable(chunk, _try_genfor)


def _try_genfor(lst, w):
    loop = lst[w]
    if not (isinstance(loop, While) and isinstance(loop.cond, Bool) and loop.cond.value):
        return False
    body = list(loop.body)
    pre_locals = []
    while body and isinstance(body[0], Local) and not body[0].exprs:
        pre_locals.extend(body[0].syms)
        body = body[1:]
    if len(body) < 2:
        return False
    call_s, chk = body[0], body[1]
    if not (isinstance(call_s, Assign) and len(call_s.exprs) == 1 and isinstance(call_s.exprs[0], Call) and
            all(isinstance(t, Name) and t.sym is not None for t in call_s.targets)):
        return False
    call = call_s.exprs[0]
    ctl = call_s.targets[0].sym
    if not (isinstance(call.func, Name) and call.func.sym is not None and len(call.args) == 2 and
            isinstance(call.args[0], Name) and call.args[0].sym is not None and _is_sym(call.args[1], ctl)):
        return False
    f, st = call.func.sym, call.args[0].sym
    if not (isinstance(chk, If) and len(chk.body) == 1 and isinstance(chk.body[0], Break) and not chk.orelse):
        return False
    c = chk.cond
    if not ((isinstance(c, Un) and c.op == "not" and _is_sym(c.expr, ctl)) or
            (isinstance(c, Bin) and c.op == "==" and _is_sym(c.left, ctl) and isinstance(c.right, Nil))):
        return False
    others = [t.sym for t in call_s.targets[1:]]
    if any(o not in pre_locals for o in others) or any(p not in others for p in pre_locals):
        return False
    # initial f, s, ctl
    init = {}
    jdefs = []
    j = w - 1
    while j >= 0 and len(init) < 3:
        s = lst[j]
        if isinstance(s, Local) and set(s.syms) <= set([f, st, ctl]) and not (set(s.syms) & set(init)):
            if len(s.exprs) == len(s.syms) and not any(is_multi(e) for e in s.exprs):
                for sy, e in zip(s.syms, s.exprs):
                    init[sy] = e
                jdefs.append(j)
            elif len(s.exprs) == 1 and len(s.syms) >= 1 and is_multi(s.exprs[0]) and s.syms[0] is f:
                init[f] = ("multi", s.exprs[0], s.syms)
                for sy in s.syms[1:]:
                    init[sy] = None
                jdefs.append(j)
            else:
                break
            j -= 1
        else:
            break
    if f not in init or st not in init or ctl not in init:
        return False
    rest = body[2:]
    if assigned(Chunk(rest)) & set([f, st, ctl]):
        return False
    after = refs_in(lst[w + 1:])
    if any(x in after for x in (f, st, ctl)):
        return False
    if isinstance(init[f], tuple):
        _, e, syms = init[f]
        if syms != [f, st, ctl][:len(syms)]:
            return False
        exprs = [e]
    else:
        exprs = [init[f], init[st] if init[st] is not None else Nil(), init[ctl] if init[ctl] is not None else Nil()]
        while len(exprs) > 1 and isinstance(exprs[-1], Nil):
            exprs.pop()
    if rest and isinstance(rest[0], Local) and len(rest[0].syms) == 1 and len(rest[0].exprs) == 1 and \
            _is_sym(rest[0].exprs[0], ctl) and rest[0].syms[0] not in assigned(Chunk(rest[1:])):
        var = rest[0].syms[0]
        rest = rest[1:]
    else:
        var = Symbol("k")
    rest = [subst_sym(s, ctl, var) for s in rest]
    lst[w] = GenFor([var] + others, exprs, rest)
    for j in sorted(jdefs, reverse=True):
        del lst[j]
    return True


def inline_adjacent(chunk):
    """`local t = E; <stmt using t once>` -> inline when t is not used anywhere else."""
    changed = False
    refs = count_refs(chunk)
    asg = assigned(chunk)
    for lst in list(stat_lists(chunk)):
        i = 0
        while i < len(lst) - 1:
            s = lst[i]
            if isinstance(s, Local) and len(s.syms) == 1 and len(s.exprs) == 1 and refs.get(s.syms[0]) == 1 and \
                    s.syms[0] not in asg and not isinstance(s.exprs[0], Vararg) and \
                    not (isinstance(s.exprs[0], Func)):
                sym, E = s.syms[0], s.exprs[0]
                nxt = lst[i + 1]
                slots = _eval_slots(nxt)
                if slots is not None and _try_inline(slots, sym, E):
                    del lst[i]
                    changed = True
                    refs = count_refs(chunk)
                    continue
            i += 1
    return changed


def _eval_slots(s):
    """Expressions of a statement evaluated exactly once, before anything else in it."""
    if isinstance(s, (Local, Return)):
        return ("exprs", s)
    if isinstance(s, Assign):
        return ("assign", s)
    if isinstance(s, CallStat):
        return ("call", s)
    if isinstance(s, If):
        return ("cond", s)
    if isinstance(s, (NumFor,)):
        return ("for", s)
    if isinstance(s, GenFor):
        return ("exprs", s)
    return None


def _try_inline(slots, sym, E):
    kind, s = slots
    if kind == "exprs":
        exprs = s.exprs
    elif kind == "assign":
        exprs = [x for t in s.targets if isinstance(t, Index) for x in (t.obj, t.key)] + s.exprs
    elif kind == "call":
        exprs = [s.call]
    elif kind == "cond":
        exprs = [s.cond]
    else:
        exprs = [x for x in (s.start, s.stop, s.step) if x is not None]
    order = ir.eval_order_nodes(exprs)
    e_call = ir.has_call(E)
    e_mem = ir.reads_mem(E)
    found = False
    for node, cond in order:
        if node is None:
            continue
        if isinstance(node, Func):
            for n in walk(node):
                if isinstance(n, Name) and n.sym is sym:
                    return False
            continue
        if isinstance(node, Name) and node.sym is sym:
            if cond and any(isinstance(x, (Call, Method)) for x in walk(E)):
                return False
            found = True
            break
        if (e_call or e_mem) and ir._effectful(node):
            return False
        if e_call and isinstance(node, Index):
            return False
        if e_call and isinstance(node, Name) and node.sym is None:
            return False
    if not found:
        return False
    val = Paren(E) if is_multi(E) else E

    def fn(n):
        if isinstance(n, Name) and n.sym is sym:
            return val
        return None
    if kind == "exprs":
        s.exprs = [transform(x, fn) for x in s.exprs]
    elif kind == "assign":
        for t in s.targets:
            if isinstance(t, Index):
                t.obj = transform(t.obj, fn)
                t.key = transform(t.key, fn)
        s.exprs = [transform(x, fn) for x in s.exprs]
    elif kind == "call":
        s.call = transform(s.call, fn)
    elif kind == "cond":
        s.cond = transform(s.cond, fn)
    else:
        s.start = transform(s.start, fn)
        s.stop = transform(s.stop, fn)
        if s.step is not None:
            s.step = transform(s.step, fn)
    return True


def inline_literal_locals(chunk):
    """`local k = "event"` assigned nowhere else and read once -> use the literal at the read."""
    refs = count_refs(chunk)
    asg = assigned(chunk)
    cands = {}
    owners = []
    for lst in stat_lists(chunk):
        for s in lst:
            if isinstance(s, Local) and len(s.syms) == 1 and len(s.exprs) == 1 and \
                    isinstance(s.exprs[0], (String, Number, Bool)) and s.syms[0] not in asg and \
                    refs.get(s.syms[0]) == 1 and not s.syms[0].attrs.get("discard"):
                cands[s.syms[0]] = s.exprs[0]
    if not cands:
        return False

    def fix(n):
        if isinstance(n, Name) and n.sym in cands:
            return cands[n.sym].copy()
        return None
    transform(chunk, fix)
    for lst in stat_lists(chunk):
        lst[:] = [s for s in lst if not (isinstance(s, Local) and len(s.syms) == 1 and s.syms[0] in cands and
                                         len(s.exprs) == 1)]
    return True


def named_function_stores(chunk):
    """`local function f() end; T.k = f` (f used nowhere else) -> `function T.k() end`."""
    changed = False
    refs = count_refs(chunk)
    for lst in list(stat_lists(chunk)):
        i = 0
        while i < len(lst) - 1:
            a, b = lst[i], lst[i + 1]
            if isinstance(a, LocalFunc) and isinstance(b, Assign) and len(b.targets) == 1 and \
                    len(b.exprs) == 1 and _is_sym(b.exprs[0], a.sym) and refs.get(a.sym) == 1 and \
                    not refs_in([a.func]).get(a.sym):
                t = b.targets[0]
                x = t
                while isinstance(x, Index) and isinstance(x.key, String) and is_ident(x.key.value):
                    x = x.obj
                if isinstance(x, Name) and (isinstance(t, Index) or t.sym is None):
                    lst[i:i + 2] = [FuncStat(t, a.func, False)]
                    changed = True
                    continue
            i += 1
    return changed


def func_statements(chunk):
    """`T.x = function(...)` -> `function T.x(...)`; `g = function` -> `function g(...)`."""
    changed = False
    for lst in list(stat_lists(chunk)):
        for i, s in enumerate(lst):
            if isinstance(s, Assign) and len(s.targets) == 1 and len(s.exprs) == 1 and isinstance(s.exprs[0], Func):
                t = s.targets[0]
                ok = isinstance(t, Name)
                x = t
                while isinstance(x, Index) and isinstance(x.key, String) and is_ident(x.key.value):
                    x = x.obj
                    ok = isinstance(x, Name)
                if ok:
                    lst[i] = FuncStat(t, s.exprs[0], False)
                    changed = True
    return changed


def truncate_dead(chunk):
    """Statements after `return` / `break` in the same block are unreachable."""
    changed = False
    for lst in list(stat_lists(chunk)):
        for i, s in enumerate(lst):
            if isinstance(s, (Return, Break)) and i < len(lst) - 1:
                del lst[i + 1:]
                changed = True
                break
    return changed


def strip_parens(chunk):
    """Drop `( )` around calls / varargs where only one value is used anyway."""
    changed = [False]

    def strip(e):
        if isinstance(e, Paren) and is_multi(e.expr):
            changed[0] = True
            return e.expr
        return e

    def fix_list(lst, keep_last):
        return [strip(x) if (i < len(lst) - 1 or not keep_last) else x for i, x in enumerate(lst)]

    for n in walk(chunk):
        if isinstance(n, (Call, Method)):
            n.args = fix_list(n.args, True)
            if isinstance(n, Call):
                n.func = strip(n.func)
            else:
                n.obj = strip(n.obj)
        elif isinstance(n, Return):
            n.exprs = fix_list(n.exprs, True)
        elif isinstance(n, Local):
            n.exprs = fix_list(n.exprs, len(n.syms) > len(n.exprs))
        elif isinstance(n, Assign):
            n.exprs = fix_list(n.exprs, len(n.targets) > len(n.exprs))
        elif isinstance(n, Table):
            pos = [it for it in n.items if it.key is None]
            for it in n.items:
                if it.key is not None:
                    it.key = strip(it.key)
                    it.value = strip(it.value)
                elif it is not (pos[-1] if pos else None) or n.items[-1] is not it:
                    it.value = strip(it.value)
        elif isinstance(n, Bin):
            n.left, n.right = strip(n.left), strip(n.right)
        elif isinstance(n, Un):
            n.expr = strip(n.expr)
        elif isinstance(n, Index):
            n.obj, n.key = strip(n.obj), strip(n.key)
        elif isinstance(n, (If, While)):
            n.cond = strip(n.cond)
        elif isinstance(n, Repeat):
            n.cond = strip(n.cond)
        elif isinstance(n, NumFor):
            n.start, n.stop = strip(n.start), strip(n.stop)
            if n.step is not None:
                n.step = strip(n.step)
        elif isinstance(n, GenFor):
            n.exprs = fix_list(n.exprs, True)
    return changed[0]


def simplify(chunk):
    changed = False
    for _ in range(10):
        c = False
        fold.fold(chunk)
        fold.flatten_all_do(chunk)
        c |= inline_literal_locals(chunk)
        c |= truncate_dead(chunk)
        c |= method_calls(chunk)
        c |= merge_decl_assign(chunk)
        c |= multi_results(chunk)
        c |= recover_numeric_for(chunk)
        c |= tuple_for(chunk)
        c |= vararg_tables(chunk)
        c |= named_function_stores(chunk)
        c |= recover_generic_for(chunk)
        c |= inline_adjacent(chunk)
        c |= flatten_else(chunk)
        c |= drop_trailing_return(chunk)
        strip_parens(chunk)
        if not c:
            break
        changed = True
    return changed


# ---------------------------------------------------------------- renaming
LUA_GLOBALS = set("""_G _VERSION assert collectgarbage coroutine debug dofile error getfenv getmetatable io ipairs
load loadfile loadstring math module next os package pairs pcall print rawequal rawget rawset require select
setfenv setmetatable string table tonumber tostring type unpack xpcall newproxy gcinfo bit bit32 utf8 game
workspace script""".split())


def rename(chunk):
    """Give every local a unique readable name."""
    used = set(LUA_GLOBALS) | set(KEYWORDS)
    for n in walk(chunk):
        if isinstance(n, Name) and n.sym is None:
            used.add(n.name)
    counters = {}

    def fresh(base):
        k = counters.get(base, 0)
        while True:
            k += 1
            name = "%s%d" % (base, k)
            if name not in used:
                counters[base] = k
                used.add(name)
                return name

    done = set()

    def name_sym(s, base):
        if s in done:
            return
        if s.attrs.get("discard"):
            done.add(s)
            s.name = "_"
            return
        done.add(s)
        s.name = fresh(base)

    def visit_func(f, is_method=False):
        for p in f.params:
            if p.name == "self" and is_method:
                done.add(p)
                continue
            name_sym(p, "arg")

    for n in walk(chunk):
        if isinstance(n, LocalFunc):
            name_sym(n.sym, "func")
        elif isinstance(n, FuncStat):
            visit_func(n.func, n.method)
        if isinstance(n, Func):
            visit_func(n)
        elif isinstance(n, Local):
            for s in n.syms:
                base = "var"
                if len(n.exprs) == 1 and isinstance(n.exprs[0], Name) and n.exprs[0].sym is None:
                    pass
                name_sym(s, base)
        elif isinstance(n, NumFor):
            name_sym(n.sym, "i")
        elif isinstance(n, GenFor):
            if len(n.syms) == 2:
                name_sym(n.syms[0], "k")
                name_sym(n.syms[1], "v")
            else:
                for s in n.syms:
                    name_sym(s, "v")
    # anything left (should not happen)
    for n in walk(chunk):
        if isinstance(n, Name) and n.sym is not None and n.sym not in done:
            name_sym(n.sym, "var")
    # keep references in sync
    for n in walk(chunk):
        if isinstance(n, Name) and n.sym is not None:
            n.name = n.sym.name


def finish(chunk):
    simplify(chunk)
    rename(chunk)
