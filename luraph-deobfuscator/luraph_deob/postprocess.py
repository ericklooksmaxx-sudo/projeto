"""Readability passes over lifted code.

* dead-store elimination for VM registers (pure right-hand sides),
* forward substitution of single-use registers inside straight-line code,
* removal of empty/redundant statements.
All passes are conservative: an expression containing a call is only moved
when nothing with side effects lies between its definition and its use.
"""
from __future__ import annotations

import re
from collections import Counter

from . import luau_ast as A
from .simplify import copy, fold_block, transform

REG_RE = re.compile(r"^v\d+(_\d+)?$")


def is_reg(e):
    return type(e) is A.Name and REG_RE.match(e.name) is not None


def has_side_effect(e):
    for n in A.walk(e):
        if type(n) in (A.Call, A.MethodCall):
            return True
    return False


def reads(node):
    """Counter of register names read in node (targets of plain assignment excluded)."""
    c = Counter()

    def visit(n):
        t = type(n)
        if t is A.Assign:
            for tg in n.targets:
                if type(tg) is A.Index:
                    visit(tg)
            for v in n.values:
                visit(v)
            return
        if t is A.CompoundAssign:
            visit(n.target)
            visit(n.value)
            return
        if t is A.Local:
            for v in n.values:
                visit(v)
            return
        if t is A.Name:
            if REG_RE.match(n.name):
                c[n.name] += 1
            return
        if isinstance(n, list):
            for x in n:
                visit(x)
            return
        if isinstance(n, A.Node):
            for ch in A._iter_children(n):
                visit(ch)

    visit(node)
    return c


def dead_store_elim(stmts):
    changed = True
    while changed:
        changed = False
        rc = reads(stmts)

        def f(lst):
            nonlocal changed
            out = []
            for s in lst:
                t = type(s)
                if t is A.Assign and all(is_reg(tg) for tg in s.targets):
                    if all(rc[tg.name] == 0 for tg in s.targets):
                        if any(has_side_effect(v) for v in s.values):
                            calls = [v for v in s.values if type(v) in (A.Call, A.MethodCall)]
                            if len(calls) == len(s.values) == 1:
                                out.append(A.CallStat(s.values[0]))
                                changed = True
                                continue
                            out.append(s)
                            continue
                        changed = True
                        continue
                if t is A.If:
                    out.append(A.If([(c, f(b)) for c, b in s.clauses], f(s.orelse) if s.orelse is not None else None))
                    continue
                if t in (A.While, A.Repeat, A.NumericFor, A.GenericFor, A.Do):
                    s2 = copy(s)
                    s2.body = f(s2.body)
                    out.append(s2)
                    continue
                if t is A.Function:
                    out.append(s)
                    continue
                out.append(s)
            return out

        stmts = f(stmts)
    return stmts


def forward_subst(stmts, total_reads):
    """Inline `vN = e` into the single following use within the same list."""
    out = list(stmts)
    i = 0
    while i < len(out):
        s = out[i]
        if type(s) is A.Assign and len(s.targets) == 1 and len(s.values) == 1 and is_reg(s.targets[0]) \
                and type(s.values[0]) is not A.Function:
            name = s.targets[0].name
            val = s.values[0]
            if total_reads[name] == 1:
                deps = {n.name for n in A.walk(val) if type(n) is A.Name}
                side = has_side_effect(val)
                j = i + 1
                done = False
                while j < len(out):
                    u = out[j]
                    if type(u) in (A.Label, A.Goto):
                        break
                    rc = reads(u)
                    if rc[name]:
                        if rc[name] == 1 and type(u) in (A.Assign, A.CallStat, A.Return, A.Local, A.If):
                            target_u = u
                            if type(u) is A.If:
                                # only substitute into the first condition
                                if reads(u.clauses[0][0])[name] != 1:
                                    break
                            nu = _subst_once(u, name, val)
                            if nu is not None:
                                out[j] = nu
                                del out[i]
                                done = True
                        break
                    # stop at anything that may change deps or have effects (if val has effects)
                    w = writes(u)
                    if w & deps or name in w:
                        break
                    if side and (has_side_effect(u) or type(u) not in (A.Assign, A.Local)):
                        break
                    if type(u) not in (A.Assign, A.Local, A.CallStat):
                        break
                    if has_side_effect(u) and side:
                        break
                    j += 1
                if done:
                    total_reads[name] = 0
                    continue
        i += 1
    return out


def writes(s):
    w = set()
    for n in A.walk(s):
        if type(n) is A.Assign:
            for t in n.targets:
                if type(t) is A.Name:
                    w.add(t.name)
        elif type(n) is A.Local:
            w.update(n.names)
        elif type(n) is A.CompoundAssign and type(n.target) is A.Name:
            w.add(n.target.name)
    return w


def _subst_once(stmt, name, val):
    done = [False]

    def f(n):
        if type(n) is A.Name and n.name == name and not done[0]:
            done[0] = True
            return copy(val)
        return n

    t = type(stmt)
    if t is A.Assign:
        new_vals = [transform(v, f) for v in stmt.values]
        new_t = [tg if type(tg) is A.Name else transform(tg, f) for tg in stmt.targets]
        res = A.Assign(new_t, new_vals)
    elif t is A.If:
        c0, b0 = stmt.clauses[0]
        res = A.If([(transform(c0, f), b0)] + list(stmt.clauses[1:]), stmt.orelse)
    else:
        res = transform(stmt, f)
    return res if done[0] else None


def simplify_function_body(stmts):
    stmts = dead_store_elim(stmts)
    for _ in range(4):
        total = reads(stmts)
        stmts = _apply_lists(stmts, lambda lst: forward_subst(lst, total))
        stmts = dead_store_elim(stmts)
    return stmts


def _apply_lists(stmts, fn):
    res = fn(stmts)
    out = []
    for s in res:
        t = type(s)
        if t is A.If:
            out.append(A.If([(c, _apply_lists(b, fn)) for c, b in s.clauses],
                            _apply_lists(s.orelse, fn) if s.orelse is not None else None))
        elif t in (A.While, A.Repeat, A.NumericFor, A.GenericFor, A.Do):
            s2 = copy(s)
            s2.body = _apply_lists(s2.body, fn)
            out.append(s2)
        else:
            out.append(s)
    return out


def postprocess(stmts, lc):
    # process nested functions bottom-up
    def f(n):
        if type(n) is A.Function:
            return A.Function(n.params, n.is_vararg, simplify_function_body(n.body), n.name)
        return n
    stmts = transform(stmts, f)
    stmts = simplify_function_body(stmts)
    return fold_block(stmts)
