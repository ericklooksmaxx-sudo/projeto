"""Decode string pools / ConstantArray / EncryptStrings by emulating the prologue.

Every decoding layer Prometheus adds is inserted at the *top* of the chunk and
is made of pure code (tables, string/math functions).  We emulate the leading
top-level statements in the sandbox until the first one that is not
emulatable, then replace

    pool[123]          (table defined by the prologue, never mutated elsewhere)
    wrapper(456)       (function defined by the prologue, constant arguments)
    STR[DECRYPT(s, n)] (EncryptStrings)

by the constants they evaluate to.  Calls are only folded when their
emulation does not write any state that the rest of the program can observe.
Finally prologue statements that became unreferenced are deleted.
"""

from .luaast import (Name, Index, Call, Method, Func, Table, String, Number, Nil, Bool, Local, LocalFunc, Assign, Break,
                     FuncStat, Return, Paren, Vararg, Node, Chunk, transform, walk)
from .emulator import Emulator, EmuAbort, LuaTable, Closure, Builtin, Scope, is_scalar
from .luavalue import LuaError
from .fold import make_const, const_value


def _syms_mentioned(stmts):
    out = set()
    for s in stmts:
        for n in walk(s):
            if isinstance(n, Name) and n.sym is not None:
                out.add(n.sym)
            elif isinstance(n, Local):
                out.update(n.syms)
            elif isinstance(n, LocalFunc):
                out.add(n.sym)
            elif isinstance(n, Func):
                out.update(n.params)
    return out


def _assigned_syms(stmts):
    out = set()
    for s in stmts:
        for n in walk(s):
            if isinstance(n, Assign):
                for t in n.targets:
                    if isinstance(t, Name) and t.sym is not None:
                        out.add(t.sym)
            elif isinstance(n, FuncStat) and isinstance(n.target, Name) and n.target.sym is not None:
                out.add(n.target.sym)
    return out


class _Watch(object):
    pass


EMU_ERRORS = (EmuAbort, LuaError, RecursionError, ValueError, TypeError, ZeroDivisionError, OverflowError,
              AttributeError, IndexError, KeyError)


def _skip_statement(s):
    from .luaast import Repeat, While
    # `repeat until valid` / `while true do end` are AntiTamper traps
    if isinstance(s, Repeat) and not s.body:
        return True
    if isinstance(s, While) and not s.body:
        return True
    return False


def _run_prologue(body, budget, before=None):
    emu = Emulator(budget=budget)
    scope = Scope()
    emulated = []
    for i, s in enumerate(body):
        if before is not None:
            s = body[i] = before(i, s, emu, scope)
        if isinstance(s, Return) or _skip_statement(s):
            emulated.append(False)
            continue
        if before is not None and not before.emulated[i]:
            emulated.append(False)
            continue
        try:
            emu.steps = 0
            r = emu.exec_block([s], scope, None)
            emulated.append(r is None)
        except EMU_ERRORS:
            emulated.append(False)
    return emu, scope, emulated


def emulate_fold(chunk, budget=3000000):
    body = chunk.body
    # pass 1: which top-level statements are emulatable at all
    _, scope1, emulated = _run_prologue(list(body), budget)
    if not any(emulated):
        return False
    rest = [s for s, e in zip(body, emulated) if not e]
    defined_syms = set(scope1.vars)
    rest_assigned = _assigned_syms(rest)
    stable_syms = set(s for s in defined_syms if s not in rest_assigned)
    parents = {}
    for s in rest:
        _collect_parents(s, parents)
    for s in body:
        for n in walk(s):
            if isinstance(n, Assign):
                for t in n.targets:
                    if isinstance(t, Index):
                        t._is_target = True
    for s in body:
        for n in walk(s):
            if isinstance(n, Index) and isinstance(n.obj, Name) and n.obj.sym in stable_syms and \
                    isinstance(n.key, Call):
                n.key._keyed = True
    visible = _syms_mentioned(rest)
    table_ok = {}
    for sym in stable_syms:
        if not isinstance(scope1.vars[sym][0], LuaTable):
            continue
        ok = True
        for n, p in parents.items():
            if isinstance(n, Name) and n.sym is sym:
                if not (isinstance(p, Index) and p.obj is n and not getattr(p, "_is_target", False)):
                    ok = False
                    break
        table_ok[sym] = ok
    # tables mutated anywhere (t[k] = v) cannot have their reads folded
    mutated = set()
    for s in body:
        for n in walk(s):
            if isinstance(n, Assign):
                for t in n.targets:
                    if isinstance(t, Index) and isinstance(t.obj, Name) and t.obj.sym is not None:
                        mutated.add(t.obj.sym)
    for sym in list(table_ok):
        if sym in mutated:
            table_ok[sym] = False
    # a folded call must not write any top-level variable or table (that would drop a side effect)
    guard_write_syms = set(defined_syms)
    rest_visible = set(visible)
    visible = visible | defined_syms
    guard_read_syms = set(s for s in rest_assigned if s in defined_syms)
    escaped_syms = set(s for s in rest_visible if s in defined_syms and not table_ok.get(s, False))
    changed = [False]
    state = {}

    def guards(emu, scope):
        emu.guard_write_syms = guard_write_syms
        emu.guard_read_syms = guard_read_syms
        tw, tr = set(), set()
        for s in visible:
            c = scope.vars.get(s)
            if c is not None and isinstance(c[0], LuaTable):
                tw.add(id(c[0]))
                if s in escaped_syms:
                    tr.add(id(c[0]))
        emu.guard_write_tables = tw
        emu.guard_read_tables = tr

    def unguard(emu):
        emu.guard_write_syms = emu.guard_read_syms = None
        emu.guard_write_tables = emu.guard_read_tables = None

    def make_fix(emu, scope):
        def value_of(e):
            if isinstance(e, Paren):
                return value_of(e.expr)
            if isinstance(e, Name) and e.sym in stable_syms:
                c = scope.vars.get(e.sym)
                if c is None:
                    return False, None
                return True, c[0]
            if isinstance(e, Index):
                ok, base = value_of(e.obj)
                if ok and isinstance(base, LuaTable):
                    c, kv = const_value(e.key)
                    if c and kv is not None:
                        try:
                            emu.steps = 0
                            return True, emu.index(base, kv)
                        except EMU_ERRORS:
                            return False, None
            return False, None

        def eval_call(n):
            ok, f = value_of(n.func)
            if not ok or not isinstance(f, Closure):
                return False, None
            args = []
            for a in n.args:
                c, v = const_value(a)
                if not c:
                    return False, None
                args.append(v)
            try:
                emu.steps = 0
                r = emu.call(f, args)
                if len(r) != 1 or not is_scalar(r[0]):
                    return False, None
                # stateful functions (counters, generators...) cannot be replaced by one value
                emu.steps = 0
                r2 = emu.call(f, args)
            except EMU_ERRORS:
                return False, None
            if len(r2) == 1 and r2[0] == r[0] and type(r2[0]) is type(r[0]):
                return True, r[0]
            return False, None

        def fix(n):
            if isinstance(n, Index) and isinstance(n.obj, Name) and n.obj.sym in stable_syms and \
                    isinstance(n.key, Call):
                n.key._keyed = True
            if isinstance(n, Call):
                if getattr(n, "_keyed", False):
                    return None  # folded together with the enclosing index (e.g. STR[DECRYPT(s, n)])
                ok, v = eval_call(n)
                if ok:
                    changed[0] = True
                    return make_const(v)
                return None
            if isinstance(n, Index) and isinstance(n.obj, Name) and table_ok.get(n.obj.sym) and \
                    not getattr(n, "_is_target", False):
                cell = scope.vars.get(n.obj.sym)
                if cell is None:
                    return None
                if isinstance(n.key, Call):
                    ok, kv = eval_call(n.key)
                    c = ok
                else:
                    c, kv = const_value(n.key)
                if not c or kv is None:
                    return None
                try:
                    emu.steps = 0
                    v = emu.index(cell[0], kv)
                except EMU_ERRORS:
                    return None
                if v is not None and is_scalar(v):
                    changed[0] = True
                    return make_const(v)
            return None

        def fix_pre(n):
            return fix(n)
        return fix

    def fold_outside_funcs(node, fix):
        """Fold everything except nested function bodies (those run later)."""
        def rec(x):
            if isinstance(x, Func):
                return x
            for f in x.fields:
                v = getattr(x, f)
                if isinstance(v, Node):
                    setattr(x, f, rec(v))
                elif isinstance(v, list):
                    setattr(x, f, [rec(y) if isinstance(y, Node) else y for y in v])
            r = fix(x)
            return x if r is None else r
        for _ in range(4):
            before = changed[0]
            changed[0] = False
            node = rec(node)
            if not changed[0]:
                changed[0] = before
                break
            changed[0] = True
        return node

    def before(i, s, emu, scope):
        guards(emu, scope)
        try:
            return fold_outside_funcs(s, make_fix(emu, scope))
        finally:
            unguard(emu)
    before.emulated = emulated

    # pass 2: fold each statement with the emulator state at that point
    body2 = list(body)
    emu2, scope2, _ = _run_prologue(body2, budget, before)
    # pass 3: nested function bodies are folded with the final state
    guards(emu2, scope2)
    fix = make_fix(emu2, scope2)
    try:
        for _ in range(4):
            before_c = changed[0]
            changed[0] = False
            body2 = [transform(s, fix) for s in body2]
            if not changed[0]:
                changed[0] = before_c
                break
            changed[0] = True
    finally:
        unguard(emu2)
    chunk.body = body2
    removed = remove_dead_prologue(chunk, emulated)
    return changed[0] or removed


def _collect_parents(node, parents):
    stack = [node]
    while stack:
        x = stack.pop()
        if isinstance(x, Assign):
            for t in x.targets:
                if isinstance(t, Index):
                    t._is_target = True
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


def remove_dead_prologue(chunk, emulated):
    body = chunk.body
    rest = [s for s, e in zip(body, emulated) if not e]
    from .luaast import CallStat
    # statements with observable intent (calls such as assert/print) are never dropped
    keep = [(not e) or isinstance(s, CallStat) for s, e in zip(body, emulated)]
    refs = _syms_mentioned([s for s, k in zip(body, keep) if k])
    changed = True
    while changed:
        changed = False
        for i, s in enumerate(body):
            if keep[i]:
                continue
            m = _syms_mentioned([s])
            if m & refs:
                keep[i] = True
                refs |= m
                changed = True
    new = [s for i, s in enumerate(body) if keep[i]]
    chunk.body = new
    return len(new) != len(body)


# --------------------------------------------------------------- AntiTamper
def _mentions_marker(stmt):
    for n in walk(stmt):
        if isinstance(n, String) and n.value == "Tamper Detected!":
            return True
    return False


def _strip_antitamper_list(lst):
    """In one statement list, delete the AntiTamper block.

    It starts with `local valid = "<random>"`, contains the "Tamper Detected!"
    string and ends with either `if valid then <rest> else <trap> end` (current
    Prometheus) or a `repeat until valid` trap (older versions).
    """
    from .luaast import Repeat, While, Un, If, String as S_
    for mi, s in enumerate(lst):
        if not _mentions_marker(s):
            continue
        for di in range(mi, -1, -1):
            d = lst[di]
            if not (isinstance(d, Local) and len(d.syms) == 1 and len(d.exprs) == 1 and isinstance(d.exprs[0], S_)):
                continue
            valid = d.syms[0]
            for ri in range(mi, len(lst)):
                r = lst[ri]
                if isinstance(r, Repeat) and not r.body and isinstance(r.cond, Name) and r.cond.sym is valid:
                    del lst[di:ri + 1]
                    return True
                if isinstance(r, While) and not r.body and isinstance(r.cond, Un) and \
                        isinstance(r.cond.expr, Name) and r.cond.expr.sym is valid:
                    del lst[di:ri + 1]
                    return True
                if isinstance(r, If) and isinstance(r.cond, Name) and r.cond.sym is valid and ri > mi:
                    keep = list(r.body)
                    if keep and isinstance(keep[-1], (Return, Break)):
                        del lst[ri + 1:]  # what follows is the tamper trap
                    lst[di:ri + 1] = keep
                    return True
                if isinstance(r, If) and isinstance(r.cond, Un) and r.cond.op == "not" and \
                        isinstance(r.cond.expr, Name) and r.cond.expr.sym is valid and ri > mi:
                    lst[di:ri + 1] = list(r.orelse)
                    return True
    return False


def remove_antitamper(chunk):
    """Delete the AntiTamper code (recognised by its error string and `repeat until valid` trap)."""
    removed = [False]

    def visit_list(lst):
        while _strip_antitamper_list(lst):
            removed[0] = True
        for s in lst:
            for f in ("body", "orelse"):
                v = getattr(s, f, None)
                if isinstance(v, list):
                    visit_list(v)
            if isinstance(s, (Local, Assign, Return)) or True:
                for n in walk(s):
                    if isinstance(n, Func) and n.body is not lst:
                        pass

    visit_list(chunk.body)
    for n in list(walk(chunk)):
        if isinstance(n, Func):
            visit_list(n.body)
        for f in ("body", "orelse"):
            v = getattr(n, f, None)
            if isinstance(v, list) and n is not chunk:
                while _strip_antitamper_list(v):
                    removed[0] = True
    return removed[0]
