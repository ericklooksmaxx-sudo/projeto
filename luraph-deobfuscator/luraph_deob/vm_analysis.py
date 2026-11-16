"""Static analysis of the Luraph v15 virtual machine.

Luraph v15.2 emits a closure factory ``F(T, <proto fields...>)`` that
returns ``function(upvals, ...)`` which returns the runtime closure
``function(...)``.  The runtime closure contains several interpreter loops
(``while true do local op = ARR[pc] <binary if-tree> pc = pc + 1 end``),
each guarded by a mode check (``if MODE == k``).  Every proto picks one of
the modes; the roles of the operand arrays and the opcode numbering differ
per mode and per file.

This module recovers, for each mode:
  * the guard constant,
  * the array holding opcodes,
  * the mapping ``opcode -> handler statements`` by walking the if-tree.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

from . import luau_ast as A


def node_size(n):
    return sum(1 for _ in A.walk(n))


@dataclass
class DispatchLoop:
    mode: Optional[int]  # guard constant (None if unconditional)
    mode_var: Optional[str]
    op_var: str  # local holding the opcode inside the loop
    op_array: str  # name of the array indexed by pc
    pc_var: str
    handlers: Dict[int, List[A.Node]]
    prologue: List[A.Node]  # statements in loop before the tree (other than op fetch)
    epilogue: List[A.Node]  # statements after the tree (normally pc += 1)
    tree: Optional[A.If] = None

    def lookup(self, op):
        """Handler for an arbitrary opcode value (exact VM semantics: values
        outside the decoded range fall into whichever leaf the tree selects)."""
        h = self.handlers.get(op)
        if h is not None:
            return h
        if not isinstance(op, (int, float)) or self.tree is None:
            return None
        node = [self.tree]
        while True:
            if len(node) == 1 and isinstance(node[0], A.If) and _is_dispatch_if(node[0], self.op_var):
                ifs = node[0]
                for cond, body in ifs.clauses:
                    c = _cmp_on(cond, self.op_var)
                    if _eval_cmp(op, c[0], c[1]):
                        node = body
                        break
                else:
                    node = ifs.orelse or []
                continue
            # leaf (possibly wrapping a nested dispatch: specialise)
            h = specialise(node, self.op_var, op)
            self.handlers[op] = h
            return h


@dataclass
class VMInfo:
    factory: A.Function  # F(T, fields...)
    wrapper: A.Function  # function(upvals, ...)
    runtime: A.Function  # function(...)
    factory_params: List[str]
    loops: List[DispatchLoop]
    pre: List[A.Node]  # runtime statements before the first loop
    lib_locals: Dict[str, A.Node] = field(default_factory=dict)  # local name -> expression (T[x])


class AnalysisError(Exception):
    pass


def find_factory(ast) -> A.Function:
    """The VM factory is the function whose body returns a function that
    returns a vararg function containing ``while true`` dispatch loops."""
    best = None
    for n in A.walk(ast):
        if not isinstance(n, A.Function):
            continue
        w = _returned_function(n)
        if w is None:
            continue
        r = _returned_function(w)
        if r is None or not r.is_vararg:
            continue
        sz = node_size(r)
        if best is None or sz > best[0]:
            best = (sz, n, w, r)
    if best is None:
        raise AnalysisError("VM factory not found")
    return best[1], best[2], best[3]


def _returned_function(f):
    for s in f.body:
        if isinstance(s, A.Return) and len(s.values) == 1 and isinstance(s.values[0], A.Function):
            return s.values[0]
    return None


def effective_params(params):
    """Lua binds duplicated parameter names to the *last* occurrence."""
    eff = {}
    for i, p in enumerate(params):
        eff[p] = i
    return eff


def analyze(ast) -> VMInfo:
    factory, wrapper, runtime = find_factory(ast)
    loops = []
    pre = []
    _collect_loops(runtime.body, None, None, loops, pre, top=True)
    if not loops:
        raise AnalysisError("no dispatch loops found")
    info = VMInfo(factory, wrapper, runtime, factory.params, loops, pre)
    return info


def _is_true_loop(s):
    return isinstance(s, A.While) and isinstance(s.cond, A.TrueE)


def _guard(cond):
    # MODE == k  or k == MODE
    if isinstance(cond, A.BinOp) and cond.op == "==":
        if isinstance(cond.left, A.Name) and isinstance(cond.right, A.Number):
            return cond.left.name, cond.right.value
        if isinstance(cond.right, A.Name) and isinstance(cond.left, A.Number):
            return cond.right.name, cond.left.value
    return None


def _collect_loops(stmts, mode_var, mode, out, pre, top=False):
    for s in stmts:
        if isinstance(s, A.If):
            for cond, body in s.clauses:
                g = _guard(cond)
                if g and any(_is_true_loop(x) for x in body):
                    _collect_loops(body, g[0], g[1], out, pre)
            if s.orelse:
                _collect_loops(s.orelse, None, None, out, pre)
        elif _is_true_loop(s):
            dl = _parse_loop(s, mode_var, mode)
            if dl:
                out.append(dl)
        elif top and not out:
            pre.append(s)


def _parse_loop(loop, mode_var, mode):
    body = loop.body
    op_var = op_array = pc_var = None
    prologue = []
    tree = None
    epilogue = []
    for i, s in enumerate(body):
        if tree is None and op_var is None:
            # local X = ARR[pc]   |  local X, junk = ARR[pc]  |  X = ARR[pc]
            vals = getattr(s, "values", None)
            names = getattr(s, "names", None) or [t.name for t in getattr(s, "targets", []) if isinstance(t, A.Name)]
            if vals and isinstance(vals[0], A.Index) and isinstance(vals[0].obj, A.Name) and isinstance(vals[0].key, A.Name) and names:
                op_var = names[0]
                op_array = vals[0].obj.name
                pc_var = vals[0].key.name
                continue
            prologue.append(s)
        elif tree is None and isinstance(s, A.If):
            tree = s
        else:
            epilogue.append(s)
    if op_var is None or tree is None:
        return None
    handlers: Dict[int, List[A.Node]] = {}
    hi = max([c for n in A.walk(tree) if isinstance(n, A.BinOp)
              for c in [(_cmp_on(n, op_var) or (None, None))[1]] if isinstance(c, int)] or [0])
    _walk_tree(tree, op_var, Cands(0, hi + 1), handlers)
    return DispatchLoop(mode, mode_var, op_var, op_array, pc_var, handlers, prologue, epilogue, tree)


# -- dispatch tree decoding --------------------------------------------------

class Cands:
    """Set of candidate opcode values as interval minus/plus explicit sets."""

    __slots__ = ("lo", "hi", "excl", "only")

    def __init__(self, lo=-(1 << 30), hi=1 << 30, excl=frozenset(), only=None):
        self.lo, self.hi, self.excl, self.only = lo, hi, excl, only

    def values(self):
        if self.only is not None:
            return sorted(v for v in self.only if self.lo <= v <= self.hi and v not in self.excl)
        if self.hi - self.lo > 4096:
            return None
        return [v for v in range(self.lo, self.hi + 1) if v not in self.excl]

    def restrict(self, op, c, positive):
        lo, hi, excl, only = self.lo, self.hi, self.excl, self.only
        if not positive:
            op = {"<": ">=", ">=": "<", "<=": ">", ">": "<=", "==": "~=", "~=": "=="}[op]
        if op == "<":
            hi = min(hi, c - 1)
        elif op == "<=":
            hi = min(hi, c)
        elif op == ">":
            lo = max(lo, c + 1)
        elif op == ">=":
            lo = max(lo, c)
        elif op == "==":
            only = frozenset([c]) if only is None else only & {c}
        elif op == "~=":
            excl = excl | {c}
        return Cands(lo, hi, excl, only)


_FLIP = {"<": ">", ">": "<", "<=": ">=", ">=": "<=", "==": "==", "~=": "~="}


def _cmp_on(cond, var):
    """Return (op, const) if cond compares var with an integer constant."""
    if isinstance(cond, A.BinOp) and cond.op in _FLIP:
        l, r = cond.left, cond.right
        if isinstance(l, A.Name) and l.name == var and isinstance(r, A.Number):
            return cond.op, r.value
        if isinstance(r, A.Name) and r.name == var and isinstance(l, A.Number):
            return _FLIP[cond.op], l.value
    if isinstance(cond, A.UnOp) and cond.op == "not":
        x = _cmp_on(cond.operand, var)
        if x:
            inv = {"<": ">=", ">=": "<", "<=": ">", ">": "<=", "==": "~=", "~=": "=="}
            return inv[x[0]], x[1]
    return None


def _walk_tree(node, var, cands, out):
    if cands is None:
        cands = Cands(0, 1 << 16)
    if isinstance(node, list):
        if len(node) == 1 and isinstance(node[0], A.If) and _is_dispatch_if(node[0], var):
            return _walk_tree(node[0], var, cands, out)
        vals = cands.values()
        if vals is None or not vals:
            if node:
                raise AnalysisError("ambiguous handler for %s: %r" % (var, (cands.lo, cands.hi)))
            return
        for v in vals:
            out[v] = specialise(node, var, v) if len(vals) > 1 or _mentions(node, var) else node
        return
    assert isinstance(node, A.If)
    cur = cands
    for cond, body in node.clauses:
        c = _cmp_on(cond, var)
        if c is None:
            raise AnalysisError("non-dispatch condition in tree: %s" % A.to_source(cond))
        _walk_tree(body, var, cur.restrict(c[0], c[1], True), out)
        cur = cur.restrict(c[0], c[1], False)
    _walk_tree(node.orelse or [], var, cur, out)


def _eval_cmp(v, op, c):
    return {"<": v < c, "<=": v <= c, ">": v > c, ">=": v >= c, "==": v == c, "~=": v != c}[op]


def _is_dispatch_if(s, var):
    return all(_cmp_on(c, var) is not None for c, _ in s.clauses)


def _mentions(stmts, var):
    for s in stmts:
        for n in A.walk(s):
            if isinstance(n, A.Name) and n.name == var:
                return True
    return False


def specialise(stmts, var, value):
    """Replace var by a constant and fold the trivially decidable parts."""
    from .simplify import subst_name, fold_block
    return fold_block(subst_name(stmts, var, A.Number(value)))
