"""Instantiate a VM handler for one concrete instruction.

Every read ``ARR[pc]`` (or ``ARR[pc + k]``) of an operand array is replaced
by the concrete value stored in the (decrypted) array, the pc variable is
replaced by the instruction address and the result is constant-folded.
What remains is a small Lua fragment expressed over the register table,
the VM state variables and the helper functions -- i.e. the semantics of
that instruction.
"""
from __future__ import annotations

from . import interp as I
from . import luau_ast as A
from .interp import LuaTable
from .simplify import fold_block, make_const, transform


class ConstRef(A.Node):
    """A constant that cannot be written as a literal (table, function...)."""

    __slots__ = ("value", "label")

    def __init__(self, value, label):
        self.value = value
        self.label = label

    def __repr__(self):
        return "ConstRef(%s)" % self.label


def literal(v, label="?"):
    try:
        return make_const(v)
    except ValueError:
        return ConstRef(v, label)


class Instantiator:
    def __init__(self, interp, arrays, pc_var):
        """arrays: name -> LuaTable (operand arrays, possibly with lazy __index)"""
        self.it = interp
        self.arrays = arrays
        self.pc_var = pc_var
        self.cache = None  # shared lazy-constant cache (id(table), key) -> value

    def read(self, name, idx):
        t = self.arrays[name]
        v = t.h.get(idx)
        if v is None and t.meta is not None:
            ck = (id(t), idx)
            if self.cache is not None and ck in self.cache:
                v = self.cache[ck]
            else:
                try:
                    v = self.it.index(t, idx)
                except (I.LuaError, I.StopEmulation, Exception):
                    return ConstRef(None, "%s[%d]!" % (name, idx))
                if self.cache is not None:
                    self.cache[ck] = v
        return literal(v, "%s[%d]" % (name, idx))

    def instantiate(self, stmts, pc, extra=None):
        pc_var = self.pc_var
        arrays = self.arrays
        # handlers that alias the pc (`local p = U ... U = p`) are handled by
        # substituting the alias as well
        aliases = {pc_var}
        for s in stmts:
            if isinstance(s, A.Local) and len(s.names) == 1 and len(s.values) == 1 \
                    and isinstance(s.values[0], A.Name) and s.values[0].name == pc_var:
                aliases.add(s.names[0])

        def pcval(e):
            if type(e) is A.Name and e.name in aliases:
                return pc
            if type(e) is A.BinOp and e.op in ("+", "-") and type(e.left) is A.Name and e.left.name in aliases \
                    and type(e.right) is A.Number:
                return pc + e.right.value if e.op == "+" else pc - e.right.value
            return None

        def f(n):
            if type(n) is A.Index and type(n.obj) is A.Name and n.obj.name in arrays:
                p = pcval(n.key)
                if p is not None:
                    return self.read(n.obj.name, p)
            return n

        out = _transform_reads(stmts, f, set(arrays))
        # replace remaining reads of the pc itself (e.g. `U = if c then U else 7`)
        def g(n):
            if type(n) is A.Name and n.name in aliases:
                return A.Number(pc)
            return n
        out = _subst_reads(out, g, aliases)
        return fold_block(out)


def _transform_reads(stmts, f, arrays):
    """transform() that leaves `ARR[pc] = v` assignment targets alone."""
    out = []
    for s in stmts:
        if isinstance(s, A.Assign):
            targets = []
            for t in s.targets:
                if isinstance(t, A.Index) and isinstance(t.obj, A.Name) and t.obj.name in arrays:
                    targets.append(A.Index(t.obj, transform(t.key, f)))
                else:
                    targets.append(transform(t, f))
            out.append(A.Assign(targets, [transform(v, f) for v in s.values]))
        elif isinstance(s, A.If):
            out.append(A.If([(transform(c, f), _transform_reads(b, f, arrays)) for c, b in s.clauses],
                            _transform_reads(s.orelse, f, arrays) if s.orelse is not None else None))
        elif isinstance(s, A.Do):
            out.append(A.Do(_transform_reads(s.body, f, arrays)))
        elif isinstance(s, (A.NumericFor,)):
            out.append(A.NumericFor(s.var, transform(s.start, f), transform(s.stop, f),
                                    transform(s.step, f) if s.step is not None else None,
                                    _transform_reads(s.body, f, arrays)))
        else:
            out.append(transform(s, f))
    return out


def _subst_reads(stmts, g, aliases):
    """Substitute reads of pc aliases but leave assignment targets intact."""
    def fix_targets(n):
        return n

    res = []
    for s in stmts:
        if isinstance(s, A.Local) and len(s.names) == 1 and s.names[0] in aliases and len(s.values) == 1 \
                and isinstance(s.values[0], A.Name) and s.values[0].name in aliases:
            continue  # `local p = U`
        if isinstance(s, A.Assign):
            targets = [t if (isinstance(t, A.Name) and t.name in aliases) else transform(t, g) for t in s.targets]
            vals = [transform(v, g) for v in s.values]
            # drop `U = p` (restoring the alias) -- it is a no-op after substitution
            if len(targets) == 1 and isinstance(targets[0], A.Name) and targets[0].name in aliases \
                    and isinstance(vals[0], A.Number) and len(s.values) == 1 and isinstance(s.values[0], A.Name) \
                    and s.values[0].name in aliases:
                continue
            res.append(A.Assign(targets, vals))
            continue
        if isinstance(s, A.If):
            res.append(A.If([(transform(c, g), _subst_reads(b, g, aliases)) for c, b in s.clauses],
                            _subst_reads(s.orelse, g, aliases) if s.orelse else None))
            continue
        if isinstance(s, (A.Do,)):
            res.append(A.Do(_subst_reads(s.body, g, aliases)))
            continue
        if isinstance(s, A.CompoundAssign) and isinstance(s.target, A.Name) and s.target.name in aliases:
            res.append(A.CompoundAssign(s.op, s.target, transform(s.value, g)))
            continue
        if isinstance(s, (A.While, A.Repeat, A.NumericFor, A.GenericFor)):
            res.append(transform(s, g))
            continue
        res.append(transform(s, g))
    return res
