"""Stage 3: lift the explored VM graph back to Lua source.

For every function discovered by the abstract executor we have a graph of
nodes (mode, pc, context) and, for each (mode, pc), the instantiated handler
of the *steady* instruction.  Lifting then:

  1. propagates the handler-local scratch variables (d, L, s, ...),
  2. turns pc assignments / mode switches / indirect jumps into gotos to the
     successor nodes actually observed (opaque predicates are thereby already
     resolved, junk edges pruned),
  3. drops VM bookkeeping (rolling keys, trampolines, upvalue closing, ...),
  4. names registers, upvalues, library helpers and constants,
  5. rebuilds nested closures,
  6. threads empty nodes, forms basic blocks and emits them.
Later passes (simplify / structure) clean the result further.
"""
from __future__ import annotations

from collections import OrderedDict
from typing import Any, Dict, List, Optional, Set, Tuple

from . import interp as I
from . import luau_ast as A
from .absvm import ClosureRef
from .instantiate import ConstRef
from .interp import Builtin, LuaFunction, LuaTable
from .simplify import copy, fold_block, make_const, transform


class GotoNode(A.Node):
    """Placeholder jump to a VM address (resolved to a node later)."""

    __slots__ = ("mode", "pc", "label")

    def __init__(self, mode, pc, label=None):
        self.mode = mode
        self.pc = pc
        self.label = label

    def __repr__(self):
        return "GotoNode(%s,%s)" % (self.mode, self.pc)


def builtin_names(env: LuaTable) -> Dict[int, str]:
    """id(builtin value) -> qualified source name (e.g. 'bit32.bxor')."""
    names = {}
    for k, v in env.h.items():
        if isinstance(k, bytes):
            ks = k.decode("latin-1")
            if isinstance(v, (Builtin, LuaFunction)):
                names.setdefault(id(v), ks)
            elif isinstance(v, LuaTable) and ks not in ("_G",):
                names.setdefault(id(v), ks)
                for kk, vv in v.h.items():
                    if isinstance(kk, bytes) and isinstance(vv, (Builtin, LuaTable)):
                        names.setdefault(id(vv), "%s.%s" % (ks, kk.decode("latin-1")))
    names[id(env)] = "getfenv()"
    return names


class LiftContext:
    """Information shared by all functions of one script."""

    def __init__(self, ex):
        self.ex = ex
        self.it = ex.it
        self.vm = ex.vm
        self.bnames = builtin_names(ex.cap.env)
        self.loops = ex.loops
        self.regs_name = ex.regs_name
        self.fparams = set(ex.fparams)
        self.key_vars = set(ex.key_vars)
        self.mode_vars = set(l.mode_var for l in ex.vm.loops if l.mode_var)
        self.pc_vars = set(l.pc_var for l in ex.vm.loops)
        self.op_vars = set(l.op_var for l in ex.vm.loops)
        # runtime-level locals of the VM closure
        self.runtime_locals = set()
        for s in ex.vm.runtime.body:
            if isinstance(s, A.Local):
                self.runtime_locals.update(s.names)
        self.persistent = self._persistent_vars()
        self.vm_var_names = self._vm_var_roles()
        self.wrapper_params = list(ex.vm.wrapper.params)
        self.upvals_param = self.wrapper_params[0] if self.wrapper_params else "P"
        self.T = ex.fargs[0]
        self.T_keys = set(getattr(ex, "T_keys_at_capture", None) or ex.fargs[0].h.keys())
        self.funcs_by_key = {fi.key: fi for fi in ex.funcs.values()}
        self.lifted = {}
        self.stats = {"functions": 0, "nodes": 0, "unresolved": 0}

    def _persistent_vars(self):
        """Runtime locals whose value survives from one instruction to the
        next (loop stack, open upvalue lists, keys...): read before written
        in at least one handler."""
        rbw = set()
        for loop in self.vm.loops:
            for h in loop.handlers.values():
                assigned = set()
                for st in h:
                    reads = set()
                    for n in A.walk(st):
                        if type(n) is A.Name:
                            reads.add(n.name)
                    tg = set()
                    if type(st) is A.Local:
                        tg = set(st.names)
                    elif type(st) is A.Assign:
                        tg = {t.name for t in st.targets if type(t) is A.Name}
                        reads -= {t.name for t in st.targets if type(t) is A.Name and not any(
                            type(x) is A.Name and x.name == t.name for v in st.values for x in A.walk(v))}
                    rbw |= (reads - assigned)
                    assigned |= tg
        return (rbw & self.runtime_locals)

    def _vm_var_roles(self):
        """Readable names for the VM's numeric-for machinery, found from the
        FORPREP handler shape: `step, limit = r[a+2] + 0, r[a+1] + 0` and
        `idx = r[a] - step`, plus the table that saves the outer loop."""
        rn = None
        for st in self.vm.runtime.body:
            if isinstance(st, A.Local) and len(st.values) == 1 and isinstance(st.values[0], A.Call):
                rn = st.names[0]
        names = {}
        for loop in self.vm.loops:
            for h in loop.handlers.values():
                for st in h:
                    if type(st) is A.Assign and len(st.targets) == 2 and len(st.values) == 2 and \
                            all(type(t) is A.Name for t in st.targets) and \
                            all(type(v) is A.BinOp and v.op == "+" and type(v.left) is A.Index and type(v.left.obj) is A.Name
                                and v.left.obj.name == rn and type(v.right) is A.Number and v.right.value == 0 for v in st.values):
                        names.setdefault(st.targets[0].name, "for_step")
                        names.setdefault(st.targets[1].name, "for_limit")
        step = [k for k, v in names.items() if v == "for_step"]
        for loop in self.vm.loops:
            for h in loop.handlers.values():
                for st in h:
                    if type(st) is A.Assign and len(st.targets) == 1 and type(st.targets[0]) is A.Name and \
                            type(st.values[0]) is A.BinOp and st.values[0].op == "-" and type(st.values[0].right) is A.Name \
                            and st.values[0].right.name in step:
                        names.setdefault(st.targets[0].name, "for_idx")
                    if type(st) is A.Assign and st.targets and type(st.targets[0]) is A.Name and \
                            type(st.values[0]) is A.Table and any(type(v) is A.Name and v.name in names for _, _, v in st.values[0].items):
                        names.setdefault(st.targets[0].name, "for_saved")
                        for _, _, v in st.values[0].items:
                            if type(v) is A.Name and v.name not in names and v.name != st.targets[0].name:
                                names[v.name] = "for_aux"
        for k in ("z", "v"):
            pass
        return {k: v for k, v in names.items() if k in self.runtime_locals}

    def value_name(self, v):
        if v is None:
            return None
        n = self.bnames.get(id(v))
        if n is not None:
            return n
        if v is self.T:
            return "LURAPH_T"
        return None


class FunctionLifter:
    def __init__(self, lc: LiftContext, fi, depth: int, upnames: Dict[int, A.Node]):
        self.lc = lc
        self.fi = fi
        self.depth = depth
        self.upnames = upnames  # upvalue index -> expression in this function
        self.ex = lc.ex
        self.regs_name = lc.regs_name
        self.dynamic_regs = False
        self.used_regs: Set[int] = set()
        # names of helper upvalues (bit32.band ...) in the VM closure scope
        self.helper_names = {}
        for name, val in fi.env.items():
            if name in lc.fparams and isinstance(val, LuaTable):
                continue  # operand arrays
            if name in lc.runtime_locals:
                continue  # shadowed by the VM closure's own locals
            qn = lc.value_name(val)
            if qn is not None:
                self.helper_names[name] = qn

    # ------------------------------------------------------------------
    def regname(self, k):
        self.used_regs.add(k)
        if self.depth == 0:
            return "v%d" % k
        return "v%d_%d" % (k, self.depth)

    def lift(self) -> A.Function:
        fi = self.fi
        bad = getattr(fi, "bad_all", set())
        nodes = [k for k in fi.states if k not in bad]
        nodeset = set(nodes)
        self.nodeset = nodeset
        # per node statements
        body = {}
        for k in nodes:
            body[k] = self.node_stmts(k, nodeset)
        self.lc.stats["nodes"] += len(nodes)
        blocks = self.build_blocks(fi.entry_node if fi.entry_node in nodeset else (nodes[0] if nodes else None), body)
        stmts = self.emit(blocks)
        if self.dynamic_regs:
            regdecl = [A.Local([self.regs_table_name()], [A.Table([])])]
        else:
            regs = sorted(self.used_regs)
            regdecl = []
            for i in range(0, len(regs), 12):
                regdecl.append(A.Local([self.regname(r) for r in regs[i:i + 12]], []))
        fn = A.Function([], True, regdecl + stmts, None)
        self.lc.stats["functions"] += 1
        return fn

    def regs_table_name(self):
        return "R" if self.depth == 0 else "R_%d" % self.depth

    # ------------------------------------------------------------------
    # per-node processing
    # ------------------------------------------------------------------
    def node_stmts(self, key, nodeset):
        mode, pc, sig = key
        fi = self.fi
        entry = fi.code.get((mode, pc))
        if entry is None:
            return [A.Comment("<missing instruction %d>" % pc)]
        op, code = entry
        loop = self.lc.loops.get(mode)
        stmts = copy(code)
        self._declared = set()
        for n in A.walk(stmts):
            if type(n) is A.Local:
                self._declared.update(n.names)
            elif type(n) is A.NumericFor:
                self._declared.add(n.var)
            elif type(n) is A.GenericFor:
                self._declared.update(n.names)
        is_scratch = self.scratch_names(loop)
        stmts = propagate_scratch(stmts, is_scratch)
        stmts = fold_block(stmts)
        stmts = expand_reg_idioms(stmts, self.regs_name, self.helper_names, is_scratch)
        closure_refs = fi.closures.get(pc)
        if closure_refs:
            stmts = self.lift_closure(stmts, closure_refs[0])
        stmts = self.control(stmts, key, loop)
        stmts = self.cleanup_vm(stmts, loop)
        stmts = self.name_things(stmts)
        stmts = fold_block(stmts)
        return stmts

    def scratch_names(self, loop):
        lc = self.lc
        keep = {self.regs_name, loop.pc_var, loop.op_var} | lc.key_vars | lc.mode_vars | lc.pc_vars | lc.persistent
        declared = self._declared

        def is_scratch(name):
            if name in declared:
                return True
            return name in lc.runtime_locals and name not in keep
        return is_scratch

    # -- control flow ----------------------------------------------------
    def control(self, stmts, key, loop):
        mode, pc, sig = key
        pcv = loop.pc_var
        mvars = self.lc.mode_vars
        succ = self.fi.succ.get(key, [])

        def conv(lst, top):
            out = []
            i = 0
            while i < len(lst):
                s = lst[i]
                t = type(s)
                if t is A.Assign and len(s.targets) == 1 and type(s.targets[0]) is A.Name and s.targets[0].name == pcv:
                    v = s.values[0]
                    # mode switch: `N = X ; U = Y ; break`
                    if i + 1 < len(lst) and type(lst[i + 1]) is A.Break:
                        newmode = None
                        for p in out[::-1]:
                            if type(p) is A.Assign and type(p.targets[0]) is A.Name and p.targets[0].name in mvars:
                                newmode = p.values[0].value if type(p.values[0]) is A.Number else None
                                break
                        tgt = v.value if type(v) is A.Number else None
                        out.append(self.jump(newmode, tgt, key, succ, offset=0))
                        return out, True
                    out.append(self.jump_expr(v, key, succ, loop))
                    return out, True
                if t is A.CompoundAssign and type(s.value) is A.Number and (
                        (type(s.target) is A.Name and s.target.name == pcv) or
                        (type(s.target) is A.Number and s.target.value == pc)):
                    out.append(self.jump(mode, pc + s.value.value, key, succ))
                    return out, True
                if t is A.If:
                    clauses = []
                    all_term = True
                    for c, b in s.clauses:
                        nb, term = conv(b, False)
                        clauses.append((c, nb))
                        all_term = all_term and term
                    orelse = None
                    if s.orelse is not None:
                        orelse, term = conv(s.orelse, False)
                        all_term = all_term and term
                    else:
                        all_term = False
                    out.append(A.If(clauses, orelse))
                    if all_term:
                        return out, True
                    i += 1
                    continue
                if t is A.Return:
                    out.append(s)
                    return out, True
                if t is A.Break and top:
                    return out, True
                out.append(s)
                i += 1
            return out, False

        out, term = conv(stmts, True)
        if not term:
            out.append(self.jump(mode, pc, key, succ))
        return out

    def jump_expr(self, v, key, succ, loop):
        mode, pc, _ = key
        if type(v) is A.Number:
            return self.jump(mode, v.value, key, succ)
        if type(v) is A.IfExpr:
            a = self.jump_expr(v.then, key, succ, loop)
            b = self.jump_expr(v.orelse, key, succ, loop)
            # one side never observed in any context: opaque predicate
            if type(a) is GotoNode and a.label is None and not (type(b) is GotoNode and b.label is None):
                return b
            if type(b) is GotoNode and b.label is None and not (type(a) is GotoNode and a.label is None):
                return a
            return A.If([(v.cond, [a])], [b])
        # computed jump: take the observed successor(s)
        targets = [s for s in succ if s[0] == mode]
        if len(targets) == 1:
            return GotoNode(targets[0][0], targets[0][1], targets[0])
        self.lc.stats["unresolved"] += 1
        return A.Comment("<unresolved jump: %s>" % A.to_source(v).strip())

    def jump(self, mode, tgt, key, succ, offset=1):
        if tgt is None:
            targets = succ
            if len(targets) == 1:
                return GotoNode(targets[0][0], targets[0][1], targets[0])
            return A.Comment("<unresolved jump>")
        tpc = int(tgt) + offset
        for s in succ:
            if s[1] == tpc and (mode is None or s[0] == mode):
                return GotoNode(s[0], s[1], s)
        # edge never taken (pruned as infeasible or not explored)
        return GotoNode(mode, tpc, None)

    # -- VM bookkeeping removal ------------------------------------------
    def cleanup_vm(self, stmts, loop):
        lc = self.lc
        drop_names = lc.key_vars | lc.mode_vars | {loop.op_var}
        jregs = getattr(self.fi, "jump_regs", set())
        rn = self.regs_name

        arrays = {n for n in lc.fparams if isinstance(self.fi.env.get(n), LuaTable) and self.fi.env.get(n) is not lc.T}

        def is_vm_target(t):
            if type(t) is A.Name and t.name in drop_names:
                return True
            if type(t) is A.Index and type(t.obj) is A.Name and t.obj.name in arrays:
                return True
            if type(t) is A.Index and type(t.obj) is A.Name and t.obj.name == rn and type(t.key) is A.Number \
                    and int(t.key.value) in jregs and int(t.key.value) == 56 and False:
                return True
            return False

        def walk(lst):
            out = []
            for s in lst:
                t = type(s)
                if t is A.Assign:
                    keep = [(tg, v) for tg, v in zip(s.targets, s.values + [None] * (len(s.targets) - len(s.values)))
                            if not is_vm_target(tg)]
                    if not keep:
                        continue
                    if len(keep) != len(s.targets):
                        out.append(A.Assign([k for k, _ in keep], [v if v is not None else A.Nil() for _, v in keep]))
                        continue
                    out.append(s)
                    continue
                if t is A.If:
                    # closing of open upvalues: `if z then ... end`
                    c0 = s.clauses[0][0]
                    if len(s.clauses) == 1 and s.orelse is None and type(c0) is A.Name and c0.name in ("z", "v") \
                            and c0.name in lc.runtime_locals:
                        continue
                    out.append(A.If([(c, walk(b)) for c, b in s.clauses], walk(s.orelse) if s.orelse is not None else None))
                    continue
                out.append(s)
            return out

        return walk(stmts)

    # -- naming --------------------------------------------------------------
    def name_things(self, stmts):
        rn = self.regs_name
        up = self.lc.upvals_param
        lc = self.lc
        declared = set()
        for n in A.walk(stmts):
            if type(n) is A.Local:
                declared.update(n.names)
            elif type(n) is A.NumericFor:
                declared.add(n.var)
            elif type(n) is A.GenericFor:
                declared.update(n.names)
        helper_names = {k: v for k, v in self.helper_names.items() if k not in declared}

        def f(n):
            t = type(n)
            if t is A.Index:
                o = n.obj
                # register access
                if type(o) is A.Name and o.name == rn:
                    if type(n.key) is A.Number:
                        return A.Name(self.regname(int(n.key.value)))
                    self.dynamic_regs = True
                    return A.Index(A.Name(self.regs_table_name()), n.key)
                # upvalue box: P[k][4][P[k][6]]
                if type(o) is A.Index and type(o.key) is A.Number and o.key.value == 4 and type(o.obj) is A.Index \
                        and type(o.obj.obj) is A.Name and o.obj.obj.name == up and type(o.obj.key) is A.Number:
                    k = int(o.obj.key.value)
                    return self.upname(k)
                if type(o) is A.Name and o.name == up and type(n.key) is A.Number:
                    return self.upname(int(n.key.value))
                # T table entries
                if type(o) is A.Name and o.name in self.fi.env and self.fi.env.get(o.name) is lc.T \
                        and type(n.key) in (A.Number, A.String):
                    kv = I.key(n.key.value)
                    if kv not in lc.T_keys and type(n.key) is A.String:
                        # script globals are kept in Luraph's own table
                        try:
                            gname = n.key.value.decode("ascii")
                        except UnicodeDecodeError:
                            gname = None
                        if gname and A._ident_re.match(gname) and gname not in A.KEYWORDS:
                            return A.Name(gname)
                        return A.Index(A.Name("_G"), n.key)
                    v = lc.T.h.get(kv)
                    qn = lc.value_name(v)
                    if qn:
                        return A.Name(qn)
                    return A.Index(A.Name("LURAPH_T"), n.key)
            if t is A.Name:
                if n.name == rn:
                    self.dynamic_regs = True
                    return A.Name(self.regs_table_name())
                if n.name in helper_names:
                    return A.Name(helper_names[n.name])
                vn = lc.vm_var_names.get(n.name)
                if vn is not None and n.name not in declared:
                    return A.Name(vn if self.depth == 0 else "%s_%d" % (vn, self.depth))
            if t is ConstRef:
                qn = lc.value_name(n.value)
                if qn:
                    return A.Name(qn)
                if isinstance(n.value, LuaTable):
                    return A.Name("--[[table %s]] {}" % n.label)
                return A.Name("--[[%s]] nil" % n.label)
            return n

        return transform(stmts, f)

    def upname(self, k):
        e = self.upnames.get(k)
        if e is not None:
            return copy(e)
        return A.Name("upval%d%s" % (k, "" if self.depth == 0 else "_%d" % self.depth))

    # -- closures --------------------------------------------------------------
    def lift_closure(self, stmts, ref: ClosureRef):
        """Replace a CLOSURE handler by `reg = function(...) ... end`."""
        rn = self.regs_name
        dest = None
        for n in A.walk(stmts):
            if type(n) is A.Assign:
                for t in n.targets:
                    if type(t) is A.Index and type(t.obj) is A.Name and t.obj.name == rn and type(t.key) is A.Number:
                        dest = int(t.key.value)
        child = self.lc.funcs_by_key.get(ref.key)
        if dest is None or child is None:
            return stmts
        # upvalue descriptors live in the constant args table (index -1)
        upnames = {}
        args = None
        for v in (ref.factory_args or ()):
            pass
        desc = self._closure_desc(stmts)
        if desc is not None:
            n = len(desc.h) // 3
            for j in range(n):
                idx = desc.h.get(j * 3 + 1)
                kind = desc.h.get(j * 3 + 2)
                if kind in (0, 2, 1) and isinstance(idx, (int, float)):
                    upnames[j + 1] = A.Name(self.regname(int(idx)))
                elif kind == 3 and isinstance(idx, (int, float)):
                    upnames[j + 1] = self.upname(int(idx))
        ck = (child.key, self.depth, tuple(sorted((k, A.to_source(v)) for k, v in upnames.items())))
        if ck in self.lc.lifted:
            fn = copy(self.lc.lifted[ck])
        else:
            fl = FunctionLifter(self.lc, child, self.depth + 1, upnames)
            fn = fl.lift()
            self.lc.lifted[ck] = fn
        loop_stmts = [A.Assign([A.Index(A.Name(rn), A.Number(dest))], [fn])]
        return loop_stmts

    def _closure_desc(self, stmts):
        for n in A.walk(stmts):
            if type(n) is ConstRef and isinstance(n.value, LuaTable) and -1 in n.value.h:
                d = n.value.h.get(-1)
                if isinstance(d, LuaTable):
                    return d
        return None

    # ------------------------------------------------------------------
    # block formation
    # ------------------------------------------------------------------
    def build_blocks(self, entry, body):
        """Thread empty nodes and merge straight-line chains."""
        if entry is None:
            return OrderedDict()

        def targets(stmts):
            return [n.label for n in A.walk(stmts) if type(n) is GotoNode and n.label is not None]

        # resolve jumps through empty nodes (pure gotos)
        def final(k, seen=None):
            seen = seen or set()
            while True:
                st = body.get(k)
                if st is None or k in seen:
                    return k
                seen.add(k)
                if len(st) == 1 and type(st[0]) is GotoNode and st[0].label is not None:
                    k = st[0].label
                    continue
                return k

        for k, st in body.items():
            def f(n):
                if type(n) is GotoNode and n.label is not None:
                    return GotoNode(n.mode, n.pc, final(n.label))
                return n
            body[k] = transform(st, f)
        entry = final(entry)
        body, entry = minimize(body, entry)
        # reachable nodes from entry
        order = []
        seen = set()
        stack = [entry]
        while stack:
            k = stack.pop()
            if k in seen or k not in body:
                continue
            seen.add(k)
            order.append(k)
            for t in reversed(targets(body[k])):
                stack.append(t)
        preds = {}
        for k in order:
            for t in targets(body[k]):
                preds.setdefault(t, set()).add(k)
        # merge chains: k ends with single goto to j and j has single pred k
        blocks = OrderedDict()
        merged = set()
        for k in order:
            if k in merged:
                continue
            stmts = list(body[k])
            cur = k
            while stmts and type(stmts[-1]) is GotoNode and stmts[-1].label is not None:
                j = stmts[-1].label
                if j == entry or len(preds.get(j, ())) != 1 or j in merged or j == cur or j == k:
                    break
                stmts = stmts[:-1] + list(body[j])
                merged.add(j)
                cur = j
            blocks[k] = stmts
        return blocks

    def emit(self, blocks):
        labels = {}
        for k in blocks:
            labels[k] = "L%d" % k[1] if sum(1 for x in blocks if x[1] == k[1]) == 1 else \
                "L%d_%d" % (k[1], list(x for x in blocks if x[1] == k[1]).index(k))
        keys = list(blocks)
        out = []
        used = set()

        def fix(stmts, nxt):
            def f(n):
                if type(n) is GotoNode:
                    if n.label is None:
                        return A.Comment("<edge to pc %d never taken>" % n.pc)
                    if n.label not in labels:
                        return A.Comment("<edge to pc %d pruned>" % n.pc)
                    used.add(n.label)
                    return A.Goto(labels[n.label])
                return n
            res = transform(stmts, f)
            # drop a trailing goto to the block that follows
            if res and type(res[-1]) is A.Goto and nxt is not None and res[-1].label == labels[nxt]:
                res = res[:-1]
            return res

        emitted = []
        for i, k in enumerate(keys):
            nxt = keys[i + 1] if i + 1 < len(keys) else None
            emitted.append((k, fix(blocks[k], nxt)))
        # recompute used labels after dropping fallthrough gotos
        used_labels = set()
        for _, st in emitted:
            for n in A.walk(st):
                if type(n) is A.Goto:
                    used_labels.add(n.label)
        for k, st in emitted:
            if labels[k] in used_labels:
                out.append(A.Label(labels[k]))
            out.extend(st)
        return out


# ----------------------------------------------------------------------------
# scratch variable propagation (inside one handler)
# ----------------------------------------------------------------------------

def _free_names(e):
    return {n.name for n in A.walk(e) if type(n) is A.Name}


def _has_call(e):
    return any(type(n) in (A.Call, A.MethodCall) for n in A.walk(e))


def propagate_scratch(stmts, is_scratch):
    """Forward-substitute handler temporaries.

    `d = 18 ; r[d] = r[d + 1]`  ->  `r[18] = r[19]`
    `L, s = r[3], r[4] ; r[3] = L(s)` -> `r[3] = r[3](r[4])`
    Only straight-line top-level code is rewritten; a scratch variable is
    substituted when its defining expression is a constant, or is pure and
    its operands are not modified before the use.
    """
    env: Dict[str, A.Node] = {}
    out = []

    def subst(e):
        def f(n):
            if type(n) is A.Name and n.name in env:
                return copy(env[n.name])
            return n
        return transform(e, f)

    def invalidate(written_names, regs_written):
        for k in list(env):
            fv = _free_names(env[k])
            if fv & written_names:
                del env[k]
            elif regs_written and any(type(n) is A.Index for n in A.walk(env[k])):
                del env[k]

    for s in stmts:
        t = type(s)
        if t in (A.Local, A.Assign):
            names = s.names if t is A.Local else s.targets
            vals = [subst(v) for v in s.values]
            if t is A.Local and len(vals) < len(names) and not any(type(v) in (A.Call, A.MethodCall, A.Vararg) for v in vals[-1:]):
                vals = vals + [A.Nil()] * (len(names) - len(vals))
            targets = names if t is A.Local else [subst(x) if type(x) is A.Index else x for x in names]
            tnames = [x if t is A.Local else (x.name if type(x) is A.Name else None) for x in targets]
            simple = len(vals) == len(tnames) and all(n is not None and is_scratch(n) for n in tnames) \
                and not any(type(v) in (A.Call, A.MethodCall, A.Vararg) or _has_call(v) for v in vals)
            written = {n for n in tnames if n}
            regs_written = any(n is None for n in tnames)
            if simple:
                invalidate(written, False)
                for n, v in zip(tnames, vals):
                    env[n] = v
                # keep the definition too (dead ones are removed later)
                out.append(A.Local(list(tnames), vals) if t is A.Local else A.Assign([A.Name(n) for n in tnames], vals))
                continue
            for n in written:
                env.pop(n, None)
            invalidate(written, regs_written)
            if t is A.Local:
                out.append(A.Local(list(names), vals))
            else:
                out.append(A.Assign(targets, vals))
            continue
        if t is A.CallStat:
            out.append(A.CallStat(subst(s.call)))
            invalidate(set(), True)
            continue
        if t is A.CompoundAssign:
            tg = subst(s.target) if type(s.target) is A.Index else s.target
            out.append(A.CompoundAssign(s.op, tg, subst(s.value)))
            if type(tg) is A.Name:
                env.pop(tg.name, None)
                invalidate({tg.name}, False)
            else:
                invalidate(set(), True)
            continue
        if t is A.Return:
            out.append(A.Return([subst(v) for v in s.values]))
            continue
        if t is A.If:
            clauses = [(subst(c), propagate_nested(b, env, is_scratch)) for c, b in s.clauses]
            orelse = propagate_nested(s.orelse, env, is_scratch) if s.orelse is not None else None
            out.append(A.If(clauses, orelse))
            # conservatively forget everything written inside
            for n in A.walk(s):
                if type(n) is A.Assign:
                    for tg in n.targets:
                        if type(tg) is A.Name:
                            env.pop(tg.name, None)
            invalidate(set(), True)
            continue
        # loops etc: names not reassigned inside keep their value
        inner_w = writes_in(s)
        keep_env = {k: v for k, v in env.items() if k not in inner_w and not (_free_names(v) & inner_w)}

        def sub_loop(n):
            if type(n) is A.Name and n.name in keep_env:
                return copy(keep_env[n.name])
            return n
        if t in (A.Repeat, A.While, A.NumericFor, A.GenericFor, A.Do):
            out.append(_subst_stmt_reads(s, sub_loop))
        else:
            out.append(s)
        env.clear()
        env.update(keep_env)
    # remove scratch definitions that are no longer used
    return remove_dead_scratch(out, is_scratch)


def writes_in(s):
    w = set()
    for n in A.walk(s):
        tn = type(n)
        if tn is A.Assign:
            for t in n.targets:
                if type(t) is A.Name:
                    w.add(t.name)
        elif tn is A.Local:
            w.update(n.names)
        elif tn is A.CompoundAssign and type(n.target) is A.Name:
            w.add(n.target.name)
        elif tn is A.NumericFor:
            w.add(n.var)
        elif tn is A.GenericFor:
            w.update(n.names)
    return w


def _subst_stmt_reads(s, f):
    """Substitute names in a statement without touching assignment targets
    that are plain names."""
    t = type(s)
    if t is A.Assign:
        return A.Assign([x if type(x) is A.Name else transform(x, f) for x in s.targets],
                        [transform(v, f) for v in s.values])
    if t is A.Local:
        return A.Local(s.names, [transform(v, f) for v in s.values])
    if t is A.CompoundAssign:
        return A.CompoundAssign(s.op, s.target if type(s.target) is A.Name else transform(s.target, f), transform(s.value, f))
    if t is A.If:
        return A.If([(transform(c, f), [_subst_stmt_reads(x, f) for x in b]) for c, b in s.clauses],
                    [_subst_stmt_reads(x, f) for x in s.orelse] if s.orelse is not None else None)
    if t is A.Repeat:
        return A.Repeat([_subst_stmt_reads(x, f) for x in s.body], transform(s.cond, f))
    if t is A.While:
        return A.While(transform(s.cond, f), [_subst_stmt_reads(x, f) for x in s.body])
    if t is A.NumericFor:
        return A.NumericFor(s.var, transform(s.start, f), transform(s.stop, f),
                            transform(s.step, f) if s.step is not None else None,
                            [_subst_stmt_reads(x, f) for x in s.body])
    if t is A.GenericFor:
        return A.GenericFor(s.names, [transform(e, f) for e in s.exprs], [_subst_stmt_reads(x, f) for x in s.body])
    if t is A.Do:
        return A.Do([_subst_stmt_reads(x, f) for x in s.body])
    return transform(s, f)


def propagate_nested(stmts, env, is_scratch):
    saved = dict(env)

    def subst(e):
        def f(n):
            if type(n) is A.Name and n.name in saved:
                return copy(saved[n.name])
            return n
        return transform(e, f)
    res = []
    for s in stmts:
        if type(s) in (A.Assign,):
            targets = [subst(x) if type(x) is A.Index else x for x in s.targets]
            res.append(A.Assign(targets, [subst(v) for v in s.values]))
            for tg in s.targets:
                if type(tg) is A.Name:
                    saved.pop(tg.name, None)
        elif type(s) is A.CallStat:
            res.append(A.CallStat(subst(s.call)))
        elif type(s) is A.Return:
            res.append(A.Return([subst(v) for v in s.values]))
        elif type(s) is A.If:
            res.append(A.If([(subst(c), propagate_nested(b, saved, is_scratch)) for c, b in s.clauses],
                            propagate_nested(s.orelse, saved, is_scratch) if s.orelse is not None else None))
        else:
            res.append(s)
    return res


def remove_dead_scratch(stmts, is_scratch):
    used = set()
    for s in stmts:
        if type(s) in (A.Local, A.Assign):
            for v in s.values:
                used |= _free_names(v)
            if type(s) is A.Assign:
                for t in s.targets:
                    if type(t) is A.Index:
                        used |= _free_names(t)
        else:
            used |= _free_names(s)
    out = []
    for s in stmts:
        if type(s) in (A.Local, A.Assign):
            names = s.names if type(s) is A.Local else [t.name if type(t) is A.Name else None for t in s.targets]
            if names and all(n is not None and is_scratch(n) and n not in used for n in names) \
                    and not any(_has_call(v) for v in s.values):
                continue
        out.append(s)
    return out


# ----------------------------------------------------------------------------
# register-file idioms
# ----------------------------------------------------------------------------

def _num(e):
    return type(e) is A.Number


def expand_reg_idioms(stmts, rn, helpers, is_scratch):
    """Rewrite VM helpers that receive the register table itself."""
    def helper(e):
        if type(e) is A.Name:
            return helpers.get(e.name)
        return None

    def is_regs(e):
        return type(e) is A.Name and e.name == rn

    def reg(k):
        return A.Index(A.Name(rn), A.Number(int(k)))

    # split scratch multi-assignments into single ones when independent
    split = []
    for s in stmts:
        if type(s) in (A.Assign, A.Local) and len(s.values) == len(getattr(s, "targets", getattr(s, "names", []))) > 1:
            tg = s.targets if type(s) is A.Assign else [A.Name(n) for n in s.names]
            names = {t.name for t in tg if type(t) is A.Name}
            if all(type(t) is A.Name and is_scratch(t.name) for t in tg) and \
                    not any(type(x) is A.Name and x.name in names for v in s.values for x in A.walk(v)):
                for t, v in zip(tg, s.values):
                    split.append(A.Local([t.name], [v]) if type(s) is A.Local else A.Assign([t], [v]))
                continue
        split.append(s)
    stmts = split

    def expand_args(args):
        if args:
            last = args[-1]
            if type(last) is A.Call and helper(last.func) in ("unpack", "table.unpack") and len(last.args) == 3 \
                    and is_regs(last.args[0]) and _num(last.args[1]) and _num(last.args[2]):
                a, b = int(last.args[1].value), int(last.args[2].value)
                if b - a < 250:
                    return list(args[:-1]) + [reg(k) for k in range(a, b + 1)]
        return args

    def fix_expr(n):
        t = type(n)
        if t is A.Call:
            return A.Call(n.func, expand_args(n.args))
        if t is A.MethodCall:
            return A.MethodCall(n.obj, n.name, expand_args(n.args))
        return n

    out = []
    i = 0
    while i < len(stmts):
        s = transform(stmts[i], fix_expr)
        # G = table.pack(X) ; table.move(G, 1, S, D, REGS)
        if type(s) in (A.Assign, A.Local) and i + 1 < len(stmts):
            tg = s.targets if type(s) is A.Assign else [A.Name(n) for n in s.names]
            nxt = stmts[i + 1]
            if len(tg) == 1 and type(tg[0]) is A.Name and len(s.values) == 1 and type(s.values[0]) is A.Call \
                    and helper(s.values[0].func) == "table.pack" and type(nxt) is A.CallStat \
                    and type(nxt.call) is A.Call and helper(nxt.call.func) == "table.move":
                a = nxt.call.args
                if len(a) == 5 and type(a[0]) is A.Name and a[0].name == tg[0].name and _num(a[1]) and a[1].value == 1 \
                        and _num(a[2]) and _num(a[3]) and is_regs(a[4]):
                    cnt, d = int(a[2].value), int(a[3].value)
                    inner = s.values[0].args
                    call = inner[0] if len(inner) == 1 else None
                    if call is not None and type(call) in (A.Call, A.MethodCall):
                        call = fix_expr(call)
                        if cnt <= 0:
                            out.append(A.CallStat(call))
                        else:
                            out.append(A.Assign([reg(d + k) for k in range(cnt)], [call]))
                        i += 2
                        continue
        if type(s) is A.CallStat and type(s.call) is A.Call and helper(s.call.func) == "table.move" and len(s.call.args) == 5:
            src, a, b, t, dst = s.call.args
            if _num(a) and _num(b) and _num(t):
                a, b, t = int(a.value), int(b.value), int(t.value)
                if b < a:
                    i += 1
                    continue
                if b - a < 250 and (is_regs(dst) or is_regs(src)):
                    if is_regs(dst) and type(src) is A.Table and len(src.items) == 1 and type(src.items[0][2]) is A.Vararg:
                        vals = [A.Vararg()] if a == 1 else [A.Call(A.Name("select"), [A.Number(a), A.Vararg()])]
                        out.append(A.Assign([reg(t + k) for k in range(b - a + 1)], vals))
                    else:
                        targets = [A.Index(dst, A.Number(t + k)) if not is_regs(dst) else reg(t + k) for k in range(b - a + 1)]
                        vals = [A.Index(src, A.Number(a + k)) if not is_regs(src) else reg(a + k) for k in range(b - a + 1)]
                        out.append(A.Assign(targets, vals))
                    i += 1
                    continue
        out.append(s)
        i += 1
    return out


# ----------------------------------------------------------------------------
# context minimisation (bisimulation)
# ----------------------------------------------------------------------------

def _shape(stmts):
    """Text of a node with jump targets blanked out, plus its target list."""
    tg = []

    def f(n):
        if type(n) is GotoNode:
            tg.append(n.label)
            return GotoNode(None, -1, None)
        return n
    blank = transform(stmts, f)
    return A.to_source(blank), tg


def minimize(body, entry):
    """Merge nodes that execute the same instruction with the same lifted
    code and equivalent successors (contexts that turned out irrelevant)."""
    keys = list(body)
    shapes = {}
    targets = {}
    for k in keys:
        txt, tg = _shape(body[k])
        shapes[k] = (k[0], k[1], txt)
        targets[k] = tg
    cls = {}
    ids = {}
    for k in keys:
        cls[k] = ids.setdefault(shapes[k], len(ids))
    n_cls = len(ids)
    for _ in range(64):
        ids = {}
        new = {}
        for k in keys:
            sig = (cls[k], tuple(cls.get(t, ("ext", t)) for t in targets[k]))
            new[k] = ids.setdefault(sig, len(ids))
        cls = new
        if len(ids) == n_cls:
            break
        n_cls = len(ids)
    rep = {}
    for k in keys:
        rep.setdefault(cls[k], k)
    canon = {k: rep[cls[k]] for k in keys}

    def f(n):
        if type(n) is GotoNode and n.label is not None and n.label in canon:
            return GotoNode(n.mode, n.pc, canon[n.label])
        return n
    nb = OrderedDict()
    for k in keys:
        r = canon[k]
        if r not in nb:
            nb[r] = transform(body[r], f)
    return nb, canon.get(entry, entry)
