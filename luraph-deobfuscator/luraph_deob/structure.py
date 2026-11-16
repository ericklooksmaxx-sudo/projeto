"""Stage 4: control-flow structuring.

The lifter emits each function as a flat list of labelled basic blocks
connected by ``goto``.  This module recovers structured control flow:

  1. VM registers held in a table (``R[k]``) are promoted to locals ``vK``;
  2. the flat code is lowered to a CFG;
  3. constant propagation threads jumps through state-variable dispatchers
     (residual control-flow flattening) and dead stores are removed;
  4. the CFG is re-emitted as ``if`` / ``while`` / ``return`` using the
     dominator-tree algorithm of "Beyond Relooper" (Ramsey, 2022);
     edges that cannot be expressed structurally keep a synthetic ``goto``.
"""
from __future__ import annotations

import re
from typing import Dict, List, Optional, Set, Tuple

from . import luau_ast as A
from .simplify import copy, fold, is_const, make_const, transform

REG_RE = re.compile(r"^v\d+(_\d+)?$")


class Unsupported(Exception):
    pass


# ---------------------------------------------------------------------------
# 1. register promotion
# ---------------------------------------------------------------------------

def _own_table(body):
    """Name of the register table declared by this function (``local R = {}``)."""
    for s in body[:4]:
        if type(s) is A.Local and len(s.names) == 1 and len(s.values) == 1 \
                and type(s.values[0]) is A.Table and not s.values[0].items \
                and re.match(r"^R(_\d+)?$", s.names[0]):
            return s.names[0]
    return None


def promote_registers(body, tname):
    """Replace ``T[k]`` (k constant) with ``vK`` / ``vK_d``; return new body or
    None when the table is used in any other way."""
    suffix = "" if tname == "R" else tname[1:]  # "_1"
    ok = [True]

    def count_names(n):
        return sum(1 for x in A.walk(n) if type(x) is A.Name and x.name == tname)

    total = count_names(body)
    promoted = [0]

    def f(n):
        if type(n) is A.Index and type(n.obj) is A.Name and n.obj.name == tname \
                and type(n.key) is A.Number and isinstance(n.key.value, int):
            promoted[0] += 1
            return A.Name("v%d%s" % (n.key.value, suffix))
        return n

    new = transform(body, f)
    # the declaration itself accounts for one use; everything else must be promoted
    if promoted[0] + 1 != total:
        return None
    return [s for s in new if not (type(s) is A.Local and s.names == [tname])]


# ---------------------------------------------------------------------------
# 2. CFG
# ---------------------------------------------------------------------------

class Blk:
    __slots__ = ("id", "stmts", "term")

    def __init__(self, id):
        self.id = id
        self.stmts: list = []
        self.term = None  # ("goto", t) | ("cond", e, tt, tf) | ("ret", vals)


class CFG:
    def __init__(self):
        self.blocks: Dict[int, Blk] = {}
        self.entry = None
        self._n = 0

    def new(self):
        b = Blk(self._n)
        self._n += 1
        self.blocks[b.id] = b
        return b

    def succs(self, b):
        t = b.term
        if t is None or t[0] == "ret":
            return []
        if t[0] == "goto":
            return [t[1]]
        return [t[2], t[3]]

    def preds(self):
        p = {k: [] for k in self.blocks}
        for k, b in self.blocks.items():
            for s in self.succs(b):
                p[s].append(k)
        return p

    def set_succ(self, b, old, new):
        t = b.term
        if t[0] == "goto":
            b.term = ("goto", new if t[1] == old else t[1])
        elif t[0] == "cond":
            b.term = ("cond", t[1], new if t[2] == old else t[2], new if t[3] == old else t[3])


SIMPLE = (A.Assign, A.CallStat, A.Local, A.CompoundAssign, A.LocalFunction, A.FunctionStat)


def lower(stmts) -> CFG:
    g = CFG()
    labels: Dict[str, int] = {}
    pending: List[Tuple[Blk, str]] = []
    entry = g.new()
    g.entry = entry.id

    def label_block(name):
        if name not in labels:
            labels[name] = g.new().id
        return labels[name]

    def lst(items, cur):
        """Lower a statement list starting in block ``cur``; return the open
        block at the end, or None if control cannot fall through."""
        for s in items:
            t = type(s)
            if cur is None:
                if t is A.Label:
                    cur = g.blocks[label_block(s.name)]
                    continue
                # unreachable code until the next label
                continue
            if t is A.Label:
                nb = g.blocks[label_block(s.name)]
                cur.term = ("goto", nb.id)
                cur = nb
            elif t is A.Goto:
                pending.append((cur, s.label))
                cur.term = ("goto", None)
                cur = None
            elif t is A.Return:
                cur.term = ("ret", s.values)
                cur = None
            elif t is A.Comment:
                continue
            elif t is A.If:
                join = g.new()
                reached = False
                test = cur
                for c, body in s.clauses:
                    bb = g.new()
                    nxt = g.new()
                    test.term = ("cond", c, bb.id, nxt.id)
                    end = lst(body, bb)
                    if end is not None:
                        end.term = ("goto", join.id)
                        reached = True
                    test = nxt
                if s.orelse is not None:
                    end = lst(s.orelse, test)
                    if end is not None:
                        end.term = ("goto", join.id)
                        reached = True
                else:
                    test.term = ("goto", join.id)
                    reached = True
                cur = join if reached else None
                if cur is None:
                    del g.blocks[join.id]
            elif t in SIMPLE or t is A.Do and not any(type(x) in (A.Goto, A.Label) for x in A.walk(s)):
                cur.stmts.append(s)
            else:
                raise Unsupported("statement %s" % t.__name__)
        return cur

    end = lst(stmts, entry)
    if end is not None:
        end.term = ("ret", [])
    for b, name in pending:
        if name not in labels:
            raise Unsupported("goto to unknown label")
        b.term = ("goto", labels[name])
    for k, b in list(g.blocks.items()):
        if b.term is None:  # label block that is never closed
            b.term = ("ret", [])
    return g


# ---------------------------------------------------------------------------
# 3. analyses on the CFG
# ---------------------------------------------------------------------------

def reachable(g):
    seen = {g.entry}
    st = [g.entry]
    while st:
        k = st.pop()
        for s in g.succs(g.blocks[k]):
            if s not in seen:
                seen.add(s)
                st.append(s)
    for k in list(g.blocks):
        if k not in seen:
            del g.blocks[k]


def has_call(e):
    return any(type(n) in (A.Call, A.MethodCall) for n in A.walk(e))


def reg_names(node):
    return {n.name for n in A.walk(node) if type(n) is A.Name and REG_RE.match(n.name)}


def _lit(e):
    return is_const(e)


def eval_const(e, env):
    """Evaluate ``e`` under constant env (name -> literal node); returns literal or None."""
    names = reg_names(e)
    if not names:
        return e if _lit(e) else (fold(copy(e)) if type(e) in (A.BinOp, A.UnOp, A.Paren) and _lit(fold(copy(e))) else None)
    if any(n not in env for n in names):
        return None
    if any(type(x) in (A.Call, A.MethodCall, A.Function, A.Index, A.Table, A.Vararg) for x in A.walk(e)):
        return None

    def f(n):
        if type(n) is A.Name and n.name in env:
            return copy(env[n.name])
        return n
    r = fold(transform(copy(e), f))
    return r if _lit(r) else None


def transfer(stmts, env, captured):
    for s in stmts:
        t = type(s)
        if t is A.Assign and all(type(x) is A.Name for x in s.targets):
            if len(s.targets) == len(s.values):
                vals = [eval_const(v, env) for v in s.values]
                for tg, v in zip(s.targets, vals):
                    if v is not None and tg.name not in captured:
                        env[tg.name] = v
                    else:
                        env.pop(tg.name, None)
            else:
                for tg in s.targets:
                    env.pop(tg.name, None)
        else:
            for n in A.walk(s):
                if type(n) is A.Assign:
                    for tg in n.targets:
                        if type(tg) is A.Name:
                            env.pop(tg.name, None)
                elif type(n) is A.Local:
                    for nm in n.names:
                        env.pop(nm, None)
                elif type(n) is A.CompoundAssign and type(n.target) is A.Name:
                    env.pop(n.target.name, None)
    return env


def const_dataflow(g, captured):
    """OUT environments per block (name -> literal)."""
    order = rpo(g)
    IN: Dict[int, Optional[dict]] = {k: None for k in g.blocks}
    OUT: Dict[int, dict] = {}
    IN[g.entry] = {}
    work = list(order)
    inq = set(work)
    preds = g.preds()
    while work:
        k = work.pop(0)
        inq.discard(k)
        b = g.blocks[k]
        env = dict(IN[k]) if IN[k] is not None else {}
        out = transfer(b.stmts, env, captured)
        if OUT.get(k) == out and k in OUT:
            continue
        OUT[k] = out
        for s in g.succs(b):
            old = IN[s]
            if old is None:
                new = dict(out)
            else:
                new = {n: v for n, v in old.items() if n in out and _same(out[n], v)}
            if new != old:
                IN[s] = new
                if s not in inq:
                    inq.add(s)
                    work.append(s)
    return IN, OUT


def _same(a, b):
    return type(a) is type(b) and getattr(a, "value", None) == getattr(b, "value", None)


def truth(lit):
    t = type(lit)
    if t in (A.Nil, A.FalseE):
        return False
    return True


def thread_jumps(g, captured):
    """Resolve conditions that are constant on an incoming edge."""
    changed_any = False
    for _ in range(50):
        IN, OUT = const_dataflow(g, captured)
        changed = False
        preds = g.preds()
        # fold conditions decidable at the end of their own block
        for k, b in g.blocks.items():
            if b.term and b.term[0] == "cond" and k in OUT:
                v = eval_const(b.term[1], OUT[k])
                if v is not None:
                    b.term = ("goto", b.term[2] if truth(v) else b.term[3])
                    changed = True
        # thread edges through empty blocks
        for k, b in list(g.blocks.items()):
            if k not in g.blocks or b.stmts or k == g.entry:
                continue
            t = b.term
            for p in preds.get(k, ()):
                if p not in g.blocks or p == k or p not in OUT:
                    continue
                pb = g.blocks[p]
                if t[0] == "goto":
                    tgt = t[1]
                elif t[0] == "cond":
                    v = eval_const(t[1], OUT[p])
                    if v is None:
                        continue
                    tgt = t[2] if truth(v) else t[3]
                else:
                    continue
                if tgt != k:
                    g.set_succ(pb, k, tgt)
                    changed = True
        reachable(g)
        if not changed:
            break
        changed_any = True
    return changed_any


def merge_chains(g):
    changed = True
    while changed:
        changed = False
        preds = g.preds()
        for k, b in list(g.blocks.items()):
            if k not in g.blocks:
                continue
            t = b.term
            if t[0] == "goto":
                j = t[1]
                if j != k and j != g.entry and len(preds[j]) == 1:
                    jb = g.blocks[j]
                    b.stmts += jb.stmts
                    b.term = jb.term
                    del g.blocks[j]
                    changed = True
                    preds = g.preds()
        # a cond whose branches coincide
        for k, b in g.blocks.items():
            t = b.term
            if t[0] == "cond" and t[2] == t[3] and not has_call(t[1]):
                b.term = ("goto", t[2])
                changed = True


def dead_stores(g, captured):
    """Backward liveness over register variables; remove dead pure stores."""
    blocks = g.blocks
    use = {}
    defs = {}
    for k, b in blocks.items():
        pass
    live_in = {k: set() for k in blocks}
    live_out = {k: set() for k in blocks}
    order = list(reversed(rpo(g)))
    preds = g.preds()

    def block_use_def(b):
        u, d = set(), set()
        # walk backwards computing gen/kill precisely
        live = set()
        return u, d

    def step(b, live_after, rewrite=False):
        """Backward transfer; if rewrite, delete dead statements in place."""
        live = set(live_after)
        t = b.term
        if t[0] == "cond":
            live |= reg_names(t[1])
        elif t[0] == "ret":
            for v in t[1]:
                live |= reg_names(v)
        out = []
        for s in reversed(b.stmts):
            ty = type(s)
            if ty is A.Assign and all(type(x) is A.Name and REG_RE.match(x.name) for x in s.targets):
                tn = [x.name for x in s.targets]
                dead = [n not in live and n not in captured for n in tn]
                if all(dead):
                    if any(has_call(v) for v in s.values):
                        if rewrite:
                            if len(s.values) == 1 and type(s.values[0]) in (A.Call, A.MethodCall):
                                out.append(A.CallStat(s.values[0]))
                            else:
                                out.append(s)
                        live |= reg_names(s.values)
                        continue
                    continue  # pure and dead
                if any(dead) and len(s.targets) == len(s.values) and not any(has_call(v) for v in s.values):
                    keep = [i for i, d in enumerate(dead) if not d]
                    s = A.Assign([s.targets[i] for i in keep], [s.values[i] for i in keep])
                for x in s.targets:
                    live.discard(x.name)
                live |= reg_names(s.values)
                out.append(s)
                continue
            # generic statement: everything it mentions is live; plain-name targets are killed
            if ty is A.Assign:
                for x in s.targets:
                    if type(x) is A.Name:
                        live.discard(x.name)
                    else:
                        live |= reg_names(x)
                live |= reg_names(s.values)
            else:
                live |= reg_names(s)
            out.append(s)
        if rewrite:
            b.stmts = list(reversed(out))
        return live

    changed = True
    while changed:
        changed = False
        for k in order:
            b = blocks[k]
            lo = set()
            for s in g.succs(b):
                lo |= live_in[s]
            li = step(b, lo)
            if lo != live_out[k] or li != live_in[k]:
                live_out[k] = lo
                live_in[k] = li
                changed = True
    for k, b in blocks.items():
        lo = set()
        for s in g.succs(b):
            lo |= live_in[s]
        step(b, lo, rewrite=True)


def rpo(g):
    seen = set()
    post = []
    stack = [(g.entry, iter(g.succs(g.blocks[g.entry])))]
    seen.add(g.entry)
    while stack:
        k, it = stack[-1]
        for s in it:
            if s not in seen:
                seen.add(s)
                stack.append((s, iter(g.succs(g.blocks[s]))))
                break
        else:
            post.append(k)
            stack.pop()
    return list(reversed(post))


# ---------------------------------------------------------------------------
# 4. structuring
# ---------------------------------------------------------------------------

class Irreducible(Exception):
    pass


class Structurer:
    def __init__(self, g: CFG):
        self.g = g
        self.order = rpo(g)
        self.num = {k: i for i, k in enumerate(self.order)}
        self.preds = g.preds()
        self.idom = self._dominators()
        self.children: Dict[int, List[int]] = {k: [] for k in self.order}
        for k, d in self.idom.items():
            if k != g.entry:
                self.children[d].append(k)
        for k in self.children:
            self.children[k].sort(key=lambda x: self.num[x])
        self.back: Set[Tuple[int, int]] = set()
        for k in self.order:
            for s in g.succs(g.blocks[k]):
                if self.num[s] <= self.num[k]:
                    if not self.dominates(s, k):
                        raise Irreducible()
                    self.back.add((k, s))
        self.headers = {t for _, t in self.back}
        self.fwd_in = {k: 0 for k in self.order}
        for k in self.order:
            for s in g.succs(g.blocks[k]):
                if (k, s) not in self.back:
                    self.fwd_in[s] += 1
        self.body = {h: self._loop_body(h) for h in self.headers}
        self.claimed: Dict[int, List[int]] = {h: [] for h in self.headers}
        self.claimed_by: Dict[int, int] = {}
        self._claim_exits()
        self.used_labels: Set[str] = set()
        self.emitted: Set[int] = set()

    # -- analyses --
    def _dominators(self):
        g = self.g
        idom = {g.entry: g.entry}
        changed = True
        while changed:
            changed = False
            for k in self.order[1:]:
                new = None
                for p in self.preds[k]:
                    if p not in idom or p not in self.num:
                        continue
                    new = p if new is None else self._intersect(p, new, idom)
                if idom.get(k) != new:
                    idom[k] = new
                    changed = True
        return idom

    def _intersect(self, a, b, idom):
        while a != b:
            while self.num[a] > self.num[b]:
                a = idom[a]
            while self.num[b] > self.num[a]:
                b = idom[b]
        return a

    def dominates(self, a, b):
        while True:
            if a == b:
                return True
            if b == self.g.entry:
                return False
            b = self.idom[b]

    def _loop_body(self, h):
        body = {h}
        st = [s for s, t in self.back if t == h]
        while st:
            n = st.pop()
            if n in body:
                continue
            body.add(n)
            st.extend(self.preds[n])
        return body

    def _claim_exits(self):
        outer_first = sorted(self.headers, key=lambda h: len(self.body[h]), reverse=True)
        for h in outer_first:
            for n in self.body[h]:
                for s in self.g.succs(self.g.blocks[n]):
                    if s in self.body[h] or s in self.claimed_by:
                        continue
                    d = self.idom[s]
                    if d in self.body[h]:
                        self.claimed_by[s] = h
                        self.claimed[h].append(s)
        for h in self.claimed:
            self.claimed[h].sort(key=lambda x: self.num[x])

    def is_merge(self, n):
        return n in self.claimed_by or self.fwd_in[n] >= 2

    # -- emission --
    def run(self):
        out = self.do_tree(self.g.entry, [])
        if len(self.emitted) != len(self.order):
            raise Irreducible()
        return out

    def label(self, kind, n):
        name = "%s%d" % (kind, n)
        self.used_labels.add(name)
        return name

    def do_tree(self, x, ctx):
        if x in self.emitted:
            raise Irreducible()
        self.emitted.add(x)
        if x in self.headers:
            outs = self.claimed[x]
            ys_in = [c for c in self.children[x] if c in self.body[x] and self.is_merge(c)]

            def inner(c):
                def in2(c2):
                    return self.node_code(x, c2)
                body = self.with_blocks(ys_in, [("loop", x)] + c, in2)
                return [A.While(A.TrueE(), body + [A.Label("C%d" % x)])]
            return self.with_blocks(outs, ctx, inner)
        ys = [c for c in self.children[x] if self.is_merge(c) and c not in self.claimed_by]
        return self.with_blocks(ys, ctx, lambda c: self.node_code(x, c))

    def with_blocks(self, ys, ctx, inner):
        if not ys:
            return inner(ctx)
        y = ys[-1]
        body = self.with_blocks(ys[:-1], [("block", y)] + ctx, inner)
        return [A.Do(body), A.Label("L%d" % y)] + self.do_tree(y, ctx)

    def node_code(self, x, ctx):
        b = self.g.blocks[x]
        out = list(b.stmts)
        t = b.term
        if t[0] == "ret":
            out.append(A.Return(t[1]))
        elif t[0] == "goto":
            out += self.branch(x, t[1], ctx)
        else:
            a = self.branch(x, t[2], ctx)
            c = self.branch(x, t[3], ctx)
            out.append(A.If([(t[1], a)], c))
        return out

    def branch(self, src, t, ctx):
        if (src, t) in self.back:
            for fr in ctx:
                if fr[0] == "loop":
                    if fr[1] == t:
                        return [A.Continue()]
                    break
            return [A.Goto(self.label("C", t))]
        if self.is_merge(t):
            idx = None
            for i, fr in enumerate(ctx):
                if fr == ("block", t):
                    idx = i
                    break
            if idx is None:
                raise Irreducible()
            if idx >= 1 and ctx[idx - 1][0] == "loop" and all(f[0] == "block" for f in ctx[:idx - 1]):
                return [A.Break()]
            return [A.Goto(self.label("L", t))]
        return self.do_tree(t, ctx)


# ---------------------------------------------------------------------------
# 5. cleanup of the structured AST
# ---------------------------------------------------------------------------

def _terminates(s):
    return type(s) in (A.Return, A.Break, A.Continue, A.Goto)


def _drop_dead_tail(stmts):
    out = []
    for s in stmts:
        out.append(s)
        if _terminates(s):
            # keep following labels (jump targets) and everything after them
            idx = len(out)
            rest = stmts[len(out):]
            k = 0
            while k < len(rest) and type(rest[k]) is not A.Label:
                k += 1
            out.extend(_drop_dead_tail(rest[k:]))
            return out
    return out


def _next_label_after(stmts, i):
    j = i + 1
    names = []
    while j < len(stmts) and type(stmts[j]) is A.Label:
        names.append(stmts[j].name)
        j += 1
    return names


def _strip_trailing_jump(stmts, follow, loop_tail):
    """Remove a tail ``goto L`` / ``continue`` that merely falls through.

    ``follow``: label names that are reached by falling off the end of ``stmts``.
    ``loop_tail``: True when falling off the end re-enters the enclosing loop."""
    if not stmts:
        return stmts
    last = stmts[-1]
    t = type(last)
    if t is A.Goto and last.label in follow:
        return _strip_trailing_jump(stmts[:-1], follow, loop_tail)
    if t is A.Continue and loop_tail:
        return _strip_trailing_jump(stmts[:-1], follow, loop_tail)
    if t is A.If:
        cl = [(c, _strip_trailing_jump(b, follow, loop_tail)) for c, b in last.clauses]
        oe = _strip_trailing_jump(last.orelse, follow, loop_tail) if last.orelse is not None else None
        return stmts[:-1] + [A.If(cl, oe)]
    if t is A.Do:
        return stmts[:-1] + [A.Do(_strip_trailing_jump(last.body, follow, loop_tail))]
    return stmts


def cleanup(stmts, follow=(), loop_tail=False):
    """Recursive cleanup of a statement list. ``follow`` are the labels that
    directly follow the list in the enclosing code."""
    stmts = _drop_dead_tail(stmts)
    # first recurse into children with their own follow sets
    res = []
    n = len(stmts)
    for i, s in enumerate(stmts):
        t = type(s)
        after = list(_next_label_after(stmts, i)) if i < n - 1 else []
        is_last = i == n - 1
        fol = tuple(after) + (tuple(follow) if is_last else ())
        # statements between us and the next label are not "following"; only direct
        if not is_last and not after:
            fol = ()
        lt = loop_tail and is_last
        if t is A.If:
            cl = [(c, cleanup(b, fol, lt)) for c, b in s.clauses]
            oe = cleanup(s.orelse, fol, lt) if s.orelse is not None else None
            s = A.If(cl, oe)
        elif t is A.Do:
            s = A.Do(cleanup(s.body, fol, lt))
        elif t is A.While:
            s = A.While(s.cond, cleanup(s.body, (), True))
        res.append(s)
    # tidy: flip empty-then ifs, merge else-if chains
    res = [_tidy_if(s) if type(s) is A.If else s for s in res]
    res = [_tidy_while(s) if type(s) is A.While else s for s in res]
    return res


def negate(c):
    if type(c) is A.UnOp and c.op == "not":
        return c.operand
    if type(c) is A.BinOp and c.op in ("==", "~="):
        return A.BinOp("~=" if c.op == "==" else "==", c.left, c.right)
    if type(c) is A.Paren:
        return negate(c.expr)
    return A.UnOp("not", c if type(c) in (A.Name, A.Index, A.Call, A.Paren) else A.Paren(c))


def _tidy_if(s):
    clauses = list(s.clauses)
    orelse = s.orelse
    if len(clauses) == 1 and not clauses[0][1] and orelse:
        clauses = [(negate(clauses[0][0]), orelse)]
        orelse = None
    if orelse is not None and not orelse:
        orelse = None
    # else { if ... } -> elseif
    while orelse is not None and len(orelse) == 1 and type(orelse[0]) is A.If:
        inner = orelse[0]
        clauses += list(inner.clauses)
        orelse = inner.orelse
    # drop else after terminating then
    if orelse is not None and len(clauses) == 1 and clauses[0][1] and _terminates(clauses[0][1][-1]) \
            and False:
        pass
    return A.If(clauses, orelse)


def _tidy_while(s):
    if type(s.cond) is not A.TrueE or not s.body:
        return s
    first = s.body[0]
    if type(first) is A.If and len(first.clauses) == 1:
        c, b = first.clauses[0]
        if first.orelse is None and len(b) == 1 and type(b[0]) is A.Break:
            return A.While(negate(c), s.body[1:])
        if first.orelse is not None and len(first.orelse) == 1 and type(first.orelse[0]) is A.Break and len(s.body) == 1:
            return A.While(c, b)
        if first.orelse is not None and len(b) == 1 and type(b[0]) is A.Break and len(s.body) == 1:
            return A.While(negate(c), first.orelse)
    return s


def finalize_labels(stmts):
    """Drop unused labels and inline label-free ``do`` blocks."""
    used = {n.label for n in A.walk(stmts) if type(n) is A.Goto}

    def lst(items):
        out = []
        for s in items:
            t = type(s)
            if t is A.Label:
                if s.name in used:
                    out.append(s)
                continue
            if t is A.If:
                s = A.If([(c, lst(b)) for c, b in s.clauses], lst(s.orelse) if s.orelse is not None else None)
            elif t is A.While:
                s = A.While(s.cond, lst(s.body))
            elif t is A.Do:
                inner = lst(s.body)
                if not any(type(x) is A.Label for x in inner):
                    out.extend(inner)
                    continue
                s = A.Do(inner)
            out.append(s)
        return out
    return lst(stmts)


# ---------------------------------------------------------------------------
# flat fallback (irreducible graphs)
# ---------------------------------------------------------------------------

def emit_flat(g: CFG):
    order = rpo(g)
    out = []
    used = set()
    for i, k in enumerate(order):
        b = g.blocks[k]
        nxt = order[i + 1] if i + 1 < len(order) else None
        out.append(A.Label("L%d" % k))
        out.extend(b.stmts)
        t = b.term
        if t[0] == "ret":
            out.append(A.Return(t[1]))
        elif t[0] == "goto":
            if t[1] != nxt:
                out.append(A.Goto("L%d" % t[1]))
        else:
            if t[3] == nxt:
                out.append(A.If([(t[1], [A.Goto("L%d" % t[2])])], None))
            else:
                out.append(A.If([(t[1], [A.Goto("L%d" % t[2])])], [A.Goto("L%d" % t[3])]))
    return finalize_labels(out)


# ---------------------------------------------------------------------------
# driver
# ---------------------------------------------------------------------------

def _captured(body):
    """Register names mentioned inside nested function bodies."""
    cap = set()
    for n in A.walk(body):
        if type(n) is A.Function:
            cap |= reg_names(n.body)
    return cap


def structure_body(body, stats=None):
    """Structure one function body (``body`` is the flat statement list with the
    register table already promoted). Returns new statements."""
    captured = _captured(body)
    g = lower(body)
    reachable(g)
    thread_jumps(g, captured)
    merge_chains(g)
    dead_stores(g, captured)
    thread_jumps(g, captured)
    merge_chains(g)
    reachable(g)
    try:
        st = Structurer(g)
        out = st.run()
        out = cleanup(out)
        out = finalize_labels(out)
        out = cleanup(out)
        mode = "structured"
    except Irreducible:
        out = emit_flat(g)
        mode = "flat"
    if stats is not None:
        stats[mode] = stats.get(mode, 0) + 1
    return out


def process_function_body(body, stats=None):
    tname = _own_table(body)
    if tname is None:
        return _recurse_nested(body, stats)
    prom = promote_registers(body, tname)
    if prom is None:
        if stats is not None:
            stats["unpromoted"] = stats.get("unpromoted", 0) + 1
        return _recurse_nested(body, stats)
    try:
        out = structure_body(prom, stats)
    except Unsupported:
        if stats is not None:
            stats["unsupported"] = stats.get("unsupported", 0) + 1
        out = prom
    out = _recurse_nested(out, stats)
    regs = sorted({n.name for n in A.walk(out) if type(n) is A.Name and REG_RE.match(n.name)
                   and n.name.endswith(tname[1:] if tname != "R" else "")} , key=_regkey)
    own = [r for r in regs if _is_own(r, tname)]
    decl = [A.Local(own[i:i + 12], []) for i in range(0, len(own), 12)]
    return decl + out


def _regkey(n):
    m = re.match(r"^v(\d+)(?:_(\d+))?$", n)
    return (int(m.group(2) or 0), int(m.group(1)))


def _is_own(name, tname):
    sfx = "" if tname == "R" else tname[1:]
    m = re.match(r"^v\d+((?:_\d+)?)$", name)
    return m is not None and m.group(1) == sfx


def _recurse_nested(body, stats):
    def visit(n):
        if type(n) is A.Function:
            n.body = process_function_body(n.body, stats)
        return n
    # transform rebuilds nodes; nested functions are processed in place instead
    for node in list(A.walk(body)):
        if type(node) is A.Function and not getattr(node, "_done", False):
            pass
    funcs = []
    stack = list(body) if isinstance(body, list) else [body]
    while stack:
        n = stack.pop()
        if type(n) is A.Function:
            funcs.append(n)
            continue  # its own nested functions are handled recursively
        if isinstance(n, A.Node):
            stack.extend(A._iter_children(n))
    for f in funcs:
        f.body = process_function_body(f.body, stats)
    return body


def structure_program(body, stats=None):
    return process_function_body(body, stats)
