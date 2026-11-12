"""Register IR -> structured Lua.

Both the Cff ("block dispatcher") lifter and the VM devirtualizer lower code into
this IR: a control-flow graph whose blocks contain ordinary AST statements over
*register* symbols, plus a terminator.  This module then

  * resolves heap cells (captured locals) to real variables,
  * splits registers into variables (def-use webs),
  * removes dead stores / folds constants / inlines single-use temporaries,
  * re-creates `a and b` / `a or b` expressions,
  * structures the CFG into if / while / repeat / break, and
  * places `local` declarations.
"""

from .luaast import (Symbol, Expr, Stat, Nil, Bool, Number, String, Vararg, Name, Index, Call, Method, Func, Table,
                     TItem, Bin, Un, Paren, Local, Assign, CallStat, Do, While, Repeat, If, NumFor, GenFor, LocalFunc,
                     FuncStat, Return, Break, Node, is_multi)
from . import fold


# ------------------------------------------------------------ pseudo nodes
class TupleE(Expr):
    """A packed value list (VM/Cff `pack(...)`)."""
    fields = ("exprs",)


class Spread(Expr):
    """Unpack of a tuple value (multi-valued)."""
    fields = ("expr",)


class CellRef(Expr):
    """Access to a heap cell; `ref` is the register holding the cell id or an upvalue."""
    fields = ("ref",)


class AllocCell(Expr):
    fields = ()


class ClosureE(Expr):
    """Closure creation. `proto` is lifter specific, `upvals` a list of expressions."""
    fields = ("upvals",)


class UpvalRef(Expr):
    """Reference to the current function's n-th upvalue cell."""
    fields = ("index",)


class StructError(Exception):
    pass


DEBUG = []


# ------------------------------------------------------------------- CFG
class Block(object):
    def __init__(self, bid, stmts=None, term=None):
        self.id = bid
        self.stmts = stmts or []
        self.term = term  # ('goto', b) | ('cond', expr, t, f) | ('ret', [exprs])

    def succs(self):
        t = self.term
        if t[0] == "goto":
            return [t[1]]
        if t[0] == "cond":
            return [t[2], t[3]] if t[2] != t[3] else [t[2]]
        return []


class IRFunc(object):
    def __init__(self, entry, blocks, params, vararg, upvals=None):
        self.entry = entry
        self.blocks = blocks
        self.params = params
        self.vararg = vararg
        self.upvals = upvals or []


def is_reg(e):
    return isinstance(e, Name) and e.sym is not None and e.sym.attrs.get("reg")


# --------------------------------------------------------- tree utilities
def iter_expr(e):
    """Yield every node in an expression tree (pre-order), not descending into Func bodies."""
    stack = [e]
    while stack:
        x = stack.pop()
        if x is None:
            continue
        yield x
        if isinstance(x, Func):
            continue
        for f in reversed(x.fields):
            v = getattr(x, f)
            if isinstance(v, Node):
                stack.append(v)
            elif isinstance(v, list):
                for y in reversed(v):
                    if isinstance(y, Node):
                        stack.append(y)


def stmt_exprs(s):
    """Expressions read by a statement, in evaluation order."""
    if isinstance(s, Assign):
        out = []
        for t in s.targets:
            if isinstance(t, Index):
                out.append(t.obj)
                out.append(t.key)
            elif isinstance(t, CellRef):
                out.append(t.ref)
        out.extend(s.exprs)
        return out
    if isinstance(s, CallStat):
        return [s.call]
    if isinstance(s, Local):
        return list(s.exprs)
    return []


def term_exprs(t):
    if t[0] == "cond":
        return [t[1]]
    if t[0] == "ret":
        return list(t[1])
    return []


def stmt_defs(s):
    if isinstance(s, Assign):
        return [t.sym for t in s.targets if is_reg(t)]
    return []


def replace_in(node, pred, make):
    """Replace sub-expressions of `node` for which pred(x) is true with make(x)."""
    def rec(x):
        if isinstance(x, list):
            return [rec(y) for y in x]
        if not isinstance(x, Node):
            return x
        if pred(x):
            return make(x)
        if isinstance(x, Func):
            return x
        for f in x.fields:
            v = getattr(x, f)
            if isinstance(v, (Node, list)):
                setattr(x, f, rec(v))
        return x
    return rec(node)


def map_stmt_exprs(s, fn):
    """Apply fn to every read expression slot of a statement (in place)."""
    if isinstance(s, Assign):
        for t in s.targets:
            if isinstance(t, Index):
                t.obj = fn(t.obj)
                t.key = fn(t.key)
            elif isinstance(t, CellRef):
                t.ref = fn(t.ref)
        s.exprs = [fn(e) for e in s.exprs]
    elif isinstance(s, CallStat):
        s.call = fn(s.call)
    elif isinstance(s, Local):
        s.exprs = [fn(e) for e in s.exprs]


def map_term_exprs(t, fn):
    if t[0] == "cond":
        return ("cond", fn(t[1]), t[2], t[3])
    if t[0] == "ret":
        return ("ret", [fn(e) for e in t[1]])
    return t


_EFFECT_BIN = set(["+", "-", "*", "/", "%", "^", "..", "<", "<=", ">", ">=", "==", "~="])


def _effectful(x):
    """Nodes that may run arbitrary code (calls, metamethods) or raise."""
    if isinstance(x, (Call, Method)):
        return True
    if isinstance(x, Index):
        return True
    if isinstance(x, Bin) and x.op in _EFFECT_BIN:
        return not (is_literal(x.left) and is_literal(x.right))
    if isinstance(x, Un) and x.op in ("-", "#"):
        return not is_literal(x.expr)
    return False


def _has_real_call(e):
    for x in iter_expr(e):
        if isinstance(x, (Call, Method)):
            return True
    return False


def has_call(e):
    for x in iter_expr(e):
        if _effectful(x):
            return True
    return False


def reads_mem(e):
    for x in iter_expr(e):
        if isinstance(x, (Index, CellRef, Call, Method, UpvalRef)):
            return True
        if isinstance(x, Name) and (x.sym is None or x.sym.attrs.get("mem")):
            return True
    return False


def read_syms(e):
    out = set()
    for x in iter_expr(e):
        if isinstance(x, Name) and x.sym is not None:
            out.add(x.sym)
    return out


def stmt_writes_mem(s):
    if isinstance(s, Assign):
        for t in s.targets:
            if not isinstance(t, Name) or t.sym is None or t.sym.attrs.get("mem"):
                return True
    return any(has_call(e) for e in stmt_exprs(s))


def stmt_written_syms(s):
    if isinstance(s, Assign):
        return set(t.sym for t in s.targets if isinstance(t, Name) and t.sym is not None)
    if isinstance(s, Local):
        return set(s.syms)
    return set()


def is_pure(e):
    for x in iter_expr(e):
        if _effectful(x) or isinstance(x, CellRef) and False:
            return False
    return True


# ------------------------------------------------------------- analyses
def reachable(fn):
    seen, order, stack = set(), [], [fn.entry]
    while stack:
        b = stack.pop()
        if b in seen:
            continue
        seen.add(b)
        order.append(b)
        for s in fn.blocks[b].succs():
            if s not in fn.blocks:
                raise StructError("jump to unknown block %r" % (s,))
            stack.append(s)
    for b in list(fn.blocks):
        if b not in seen:
            del fn.blocks[b]
    return order


def predecessors(fn):
    preds = dict((b, []) for b in fn.blocks)
    for b, blk in fn.blocks.items():
        for s in blk.succs():
            preds[s].append(b)
    return preds


def rpo(fn):
    seen, out = set(), []

    def dfs(b):
        stack = [(b, iter(fn.blocks[b].succs()))]
        seen.add(b)
        while stack:
            n, it = stack[-1]
            for s in it:
                if s not in seen:
                    seen.add(s)
                    stack.append((s, iter(fn.blocks[s].succs())))
                    break
            else:
                stack.pop()
                out.append(n)

    dfs(fn.entry)
    out.reverse()
    return out


def dominators(nodes, entry, preds):
    """Cooper/Harvey/Kennedy. nodes in RPO."""
    idx = dict((n, i) for i, n in enumerate(nodes))
    idom = {entry: entry}

    def intersect(a, b):
        while a != b:
            while idx[a] > idx[b]:
                a = idom[a]
            while idx[b] > idx[a]:
                b = idom[b]
        return a

    changed = True
    while changed:
        changed = False
        for n in nodes:
            if n == entry:
                continue
            ps = [p for p in preds[n] if p in idom and p in idx]
            if not ps:
                continue
            new = ps[0]
            for p in ps[1:]:
                new = intersect(p, new)
            if idom.get(n) != new:
                idom[n] = new
                changed = True
    return idom


def dominates(idom, a, b):
    while True:
        if a == b:
            return True
        nb = idom.get(b)
        if nb is None or nb == b:
            return False
        b = nb


EXIT = "__exit__"


def postdominators(fn):
    succ = {}
    for b, blk in fn.blocks.items():
        s = blk.succs()
        succ[b] = s if s else [EXIT]
    rpreds = dict((b, list(s)) for b, s in succ.items())  # reverse graph preds = succs
    rsucc = {EXIT: []}
    for b in fn.blocks:
        rsucc.setdefault(b, [])
    for b, ss in succ.items():
        for s in ss:
            rsucc.setdefault(s, []).append(b)
    # RPO on reverse graph from EXIT
    seen, order = set([EXIT]), []
    stack = [(EXIT, iter(rsucc[EXIT]))]
    while stack:
        n, it = stack[-1]
        for s in it:
            if s not in seen:
                seen.add(s)
                stack.append((s, iter(rsucc[s])))
                break
        else:
            stack.pop()
            order.append(n)
    order.reverse()
    rp = dict((n, rpreds.get(n, [])) for n in order)
    return dominators(order, EXIT, rp)


# ------------------------------------------------------ reaching defs
class Dataflow(object):
    """Reaching definitions for register symbols."""

    def __init__(self, fn):
        self.fn = fn
        self.compute()

    def compute(self):
        fn = self.fn
        self.preds = predecessors(fn)
        gen, kill = {}, {}
        self.defs_of = {}
        for b, blk in fn.blocks.items():
            for i, s in enumerate(blk.stmts):
                for sym in stmt_defs(s):
                    self.defs_of.setdefault(sym, set()).add((b, i))
        for b, blk in fn.blocks.items():
            last = {}
            for i, s in enumerate(blk.stmts):
                for sym in stmt_defs(s):
                    last[sym] = (b, i)
            gen[b] = last
        IN = dict((b, {}) for b in fn.blocks)
        OUT = dict((b, {}) for b in fn.blocks)
        order = rpo(fn)
        changed = True
        while changed:
            changed = False
            for b in order:
                inn = {}
                for p in self.preds[b]:
                    for sym, ds in OUT[p].items():
                        inn.setdefault(sym, set()).update(ds)
                IN[b] = inn
                out = dict((k, set(v)) for k, v in inn.items())
                for sym, d in gen[b].items():
                    out[sym] = set([d])
                if out != OUT[b]:
                    OUT[b] = out
                    changed = True
        self.IN = IN

    def reaching_at(self, b, i):
        """Map sym -> set(defs) reaching statement i of block b (i == len => terminator)."""
        cur = dict((k, set(v)) for k, v in self.IN[b].items())
        blk = self.fn.blocks[b]
        for k in range(i):
            for sym in stmt_defs(blk.stmts[k]):
                cur[sym] = set([(b, k)])
        return cur


# ------------------------------------------------------------- cells
def resolve_cells(fn, new_cell_symbol):
    """Turn CellRef(register) into real variables (one per allocation site)."""
    df = Dataflow(fn)
    site_sym = {}
    holder_defs = set()

    def site_of(d, seen):
        if d in seen:
            return set()
        seen.add(d)
        b, i = d
        s = fn.blocks[b].stmts[i]
        if not isinstance(s, Assign) or len(s.targets) != 1:
            return set()
        e = s.exprs[0] if s.exprs else None
        if isinstance(e, AllocCell):
            return set([d])
        if is_reg(e):
            out = set()
            reach = df.reaching_at(b, i)
            for d2 in reach.get(e.sym, ()):
                out |= site_of(d2, seen)
            return out
        return set()

    def resolve(ref, b, i):
        if isinstance(ref, UpvalRef):
            return Name(fn.upvals[ref.index].name, fn.upvals[ref.index])
        if is_reg(ref):
            reach = df.reaching_at(b, i)
            sites = set()
            for d in reach.get(ref.sym, ()):
                sites |= site_of(d, set())
            if len(sites) == 1:
                site = sites.pop()
                if site not in site_sym:
                    site_sym[site] = new_cell_symbol()
                sym = site_sym[site]
                return Name(sym.name, sym)
        raise StructError("cannot resolve cell reference")

    # first pass: find sites and resolve all references
    for b, blk in fn.blocks.items():
        for i, s in enumerate(blk.stmts):
            if isinstance(s, Assign) and len(s.targets) == 1 and s.exprs and isinstance(s.exprs[0], AllocCell):
                if (b, i) not in site_sym:
                    site_sym[(b, i)] = new_cell_symbol()
    for b, blk in fn.blocks.items():
        for i, s in enumerate(blk.stmts):
            def fix(e, b=b, i=i):
                def mk(x):
                    if isinstance(x, CellRef):
                        return resolve(x.ref, b, i)
                    return resolve(x, b, i) if isinstance(x, UpvalRef) else x
                def pr(x):
                    return isinstance(x, (CellRef, UpvalRef))
                e = replace_in(e, pr, mk)
                # closures capture cells
                for x in iter_expr(e):
                    if isinstance(x, ClosureE):
                        x.upvals = [resolve(u, b, i) if (is_reg(u) or isinstance(u, UpvalRef)) else u
                                    for u in x.upvals]
                return e
            if isinstance(s, Assign):
                s.targets = [resolve(t.ref, b, i) if isinstance(t, CellRef) else t for t in s.targets]
            map_stmt_exprs(s, fix)
        blk.term = map_term_exprs(blk.term, lambda e, b=b, n=len(blk.stmts): replace_in(
            e, lambda x: isinstance(x, (CellRef, UpvalRef)),
            lambda x: resolve(x.ref if isinstance(x, CellRef) else x, b, n)))
    # second pass: allocation sites become declarations, cell-id copies vanish
    for b, blk in fn.blocks.items():
        new = []
        for i, s in enumerate(blk.stmts):
            if (b, i) in site_sym:
                new.append(Local([site_sym[(b, i)]], []))
                continue
            if isinstance(s, Assign) and len(s.targets) == 1 and is_reg(s.targets[0]) and s.exprs and \
                    is_reg(s.exprs[0]) and site_of((b, i), set()):
                continue  # copy of a cell id
            new.append(s)
        blk.stmts = new


# --------------------------------------------------------------- webs
def split_webs(fn, new_var):
    df = Dataflow(fn)
    parent = {}

    def find(x):
        while parent.setdefault(x, x) != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb

    use_sites = []  # (b, i, nameNode, defs)
    for b, blk in fn.blocks.items():
        n = len(blk.stmts)
        for i in range(n + 1):
            exprs = stmt_exprs(blk.stmts[i]) if i < n else term_exprs(blk.term)
            reach = None
            for e in exprs:
                for x in iter_expr(e):
                    if is_reg(x):
                        if reach is None:
                            reach = df.reaching_at(b, i)
                        ds = reach.get(x.sym, set())
                        ds = [(x.sym, d) for d in ds]
                        use_sites.append((x, ds))
                        for d in ds:
                            find(d)
                        for d in ds[1:]:
                            union(ds[0], d)
    for sym, ds in df.defs_of.items():
        for d in ds:
            find((sym, d))
    web_sym = {}

    def sym_for(key):
        r = find(key)
        if r not in web_sym:
            web_sym[r] = new_var(key[0])
        return web_sym[r]

    undefined = {}
    for x, ds in use_sites:
        if ds:
            s = sym_for(ds[0])
        else:
            if x.sym not in undefined:
                undefined[x.sym] = new_var(x.sym)
            s = undefined[x.sym]
        x.sym = s
        x.name = s.name
    for b, blk in fn.blocks.items():
        for i, s in enumerate(blk.stmts):
            if isinstance(s, Assign):
                for t in s.targets:
                    if is_reg(t):
                        ns = sym_for((t.sym, (b, i)))
                        t.sym = ns
                        t.name = ns.name


# ------------------------------------------------------ simplifications
def count_uses(fn):
    uses, defs = {}, {}
    for b, blk in fn.blocks.items():
        n = len(blk.stmts)
        for i in range(n + 1):
            exprs = stmt_exprs(blk.stmts[i]) if i < n else term_exprs(blk.term)
            for e in exprs:
                for x in iter_expr(e):
                    if isinstance(x, Name) and x.sym is not None and x.sym.attrs.get("var"):
                        uses.setdefault(x.sym, []).append((b, i))
                    if isinstance(x, ClosureE):
                        for u in x.upvals:
                            if isinstance(u, Name) and u.sym is not None and u.sym.attrs.get("var"):
                                uses.setdefault(u.sym, []).append((b, i))
            if i < n:
                s = blk.stmts[i]
                if isinstance(s, Assign):
                    for t in s.targets:
                        if isinstance(t, Name) and t.sym is not None and t.sym.attrs.get("var"):
                            defs.setdefault(t.sym, []).append((b, i))
    return uses, defs


def substitute(e, sym, value):
    """Replace reads of `sym`. Registers hold exactly one value, so a call
    moved into a multi-value position is parenthesised."""
    def pr(x):
        return isinstance(x, Name) and x.sym is sym

    def mk(x):
        v = clone(value)
        return Paren(v) if is_multi(v) else v
    return replace_in(e, pr, mk)


def clone(e):
    if isinstance(e, list):
        return [clone(x) for x in e]
    if not isinstance(e, Node) or isinstance(e, Func):
        return e
    y = e.copy()
    for f in y.fields:
        v = getattr(y, f)
        if isinstance(v, (Node, list)):
            setattr(y, f, clone(v))
    return y


def is_literal(e):
    return isinstance(e, (Nil, Bool, Number, String))


def propagate_constants(fn):
    """Single-definition variables holding literals / varargs / immutable copies are substituted everywhere."""
    changed = False
    uses, defs = count_uses(fn)
    for sym, ds in defs.items():
        if len(ds) != 1:
            continue
        b, i = ds[0]
        s = fn.blocks[b].stmts[i]
        if len(s.targets) != 1 or len(s.exprs) != 1:
            continue
        v = s.exprs[0]
        ok = is_literal(v) or (isinstance(v, TupleE) and len(v.exprs) == 1 and isinstance(v.exprs[0], Vararg))
        if not ok and isinstance(v, Name) and v.sym is not None and v.sym is not sym:
            src = v.sym
            if src.attrs.get("param") or (src.attrs.get("var") and len(defs.get(src, ())) == 1):
                ok = True
        if not ok and isinstance(v, Name) and v.sym is None:
            ok = False
        if not ok:
            continue
        if sym in uses:
            for b2, blk in fn.blocks.items():
                for st in blk.stmts:
                    map_stmt_exprs(st, lambda e: substitute(e, sym, v))
                    for x in stmt_exprs(st):
                        for c in iter_expr(x):
                            if isinstance(c, ClosureE):
                                c.upvals = [clone(v) if isinstance(u, Name) and u.sym is sym else u for u in c.upvals]
                blk.term = map_term_exprs(blk.term, lambda e: substitute(e, sym, v))
        fn.blocks[b].stmts[i] = None
        changed = True
    if changed:
        for blk in fn.blocks.values():
            blk.stmts = [s for s in blk.stmts if s is not None]
    return changed


def dead_code(fn):
    changed = False
    while True:
        uses, defs = count_uses(fn)
        again = False
        for blk in fn.blocks.values():
            new = []
            for s in blk.stmts:
                if isinstance(s, Assign) and all(isinstance(t, Name) and t.sym is not None and
                                                 t.sym.attrs.get("var") and t.sym not in uses for t in s.targets):
                    if all(is_pure(e) for e in s.exprs):
                        again = True
                        continue
                    if len(s.exprs) == 1 and isinstance(s.exprs[0], (Call, Method)):
                        new.append(CallStat(s.exprs[0]))
                        again = True
                        continue
                    if len(s.exprs) == 1 and isinstance(s.exprs[0], Paren) and isinstance(s.exprs[0].expr, (Call, Method)):
                        new.append(CallStat(s.exprs[0].expr))
                        again = True
                        continue
                    if len(s.exprs) == len(s.targets):
                        # evaluated only for its side effects (metamethods / errors)
                        d = Symbol("_")
                        d.attrs["discard"] = True
                        new.append(Local([d], [e for e in s.exprs if not is_pure(e)] or s.exprs[:1]))
                        again = True
                        continue
                new.append(s)
            blk.stmts = new
        if not again:
            break
        changed = True
    return changed


def eval_order_nodes(exprs):
    """Nodes in evaluation (post) order with a flag telling if they sit in a conditional operand."""
    out = []

    def rec(x, cond):
        if isinstance(x, Func) or x is None:
            out.append((x, cond))
            return
        if isinstance(x, Bin) and x.op in ("and", "or"):
            rec(x.left, cond)
            rec(x.right, True)
            out.append((x, cond))
            return
        for f in x.fields:
            v = getattr(x, f)
            if isinstance(v, Node):
                rec(v, cond)
            elif isinstance(v, list):
                for y in v:
                    if isinstance(y, Node):
                        rec(y, cond)
        out.append((x, cond))

    for e in exprs:
        rec(e, False)
    return out


def inline_temps(fn):
    changed = False
    progress = True
    while progress:
        progress = False
        uses, defs = count_uses(fn)
        for b, blk in fn.blocks.items():
            i = len(blk.stmts) - 1
            while i >= 0:
                s = blk.stmts[i]
                i -= 1
                if not (isinstance(s, Assign) and len(s.targets) == 1 and len(s.exprs) == 1):
                    continue
                t = s.targets[0]
                if not (isinstance(t, Name) and t.sym is not None and t.sym.attrs.get("var")):
                    continue
                sym = t.sym
                if len(defs.get(sym, ())) != 1 or len(uses.get(sym, ())) != 1:
                    continue
                ub, ui = uses[sym][0]
                di = i + 1
                if ub != b or ui <= di:
                    continue
                E = s.exprs[0]
                if isinstance(E, ClosureE) and getattr(E, "kind", "closure") != "native":
                    continue  # keep function definitions as named locals
                if sym in read_syms(E):
                    continue
                e_call = has_call(E)
                e_mem = reads_mem(E)
                e_syms = read_syms(E)
                ok = True
                for k in range(di + 1, ui):
                    sk = blk.stmts[k]
                    if stmt_written_syms(sk) & e_syms:
                        ok = False
                        break
                    if e_call or e_mem:
                        wm = stmt_writes_mem(sk)
                        if wm:
                            ok = False
                            break
                        if e_call and any(reads_mem(x) for x in stmt_exprs(sk)):
                            ok = False
                            break
                if not ok:
                    continue
                n = len(blk.stmts)
                use_exprs = stmt_exprs(blk.stmts[ui]) if ui < n else term_exprs(blk.term)
                order = eval_order_nodes(use_exprs)
                found = False
                for node, cond in order:
                    if isinstance(node, Name) and node.sym is sym:
                        found = True
                        if cond and _has_real_call(E):
                            ok = False
                        break
                    if node is None:
                        continue
                    if e_call or e_mem:
                        if _effectful(node):
                            ok = False
                            break
                        if e_call and (isinstance(node, (Index, CellRef)) or
                                       (isinstance(node, Name) and (node.sym is None or node.sym.attrs.get("mem")))):
                            ok = False
                            break
                if not found or not ok:
                    continue
                # the use statement must not be a Local declaring before reading etc.
                if ui < n:
                    target_stmt = blk.stmts[ui]
                    map_stmt_exprs(target_stmt, lambda e: substitute(e, sym, E))
                else:
                    blk.term = map_term_exprs(blk.term, lambda e: substitute(e, sym, E))
                del blk.stmts[di]
                progress = changed = True
                break
            if progress:
                break
    return changed


def collapse_and_or(fn):
    """B: [.. res = X], cond(X) -> T:[res = Y] -> J  ==>  B: [.. res = X and Y] -> J."""
    changed = False
    preds = predecessors(fn)
    for b in list(fn.blocks):
        if b not in fn.blocks:
            continue
        blk = fn.blocks[b]
        if blk.term[0] != "cond" or not blk.stmts:
            continue
        c, tb, fb = blk.term[1], blk.term[2], blk.term[3]
        last = blk.stmts[-1]
        if not (isinstance(last, Assign) and len(last.targets) == 1 and len(last.exprs) == 1 and
                isinstance(last.targets[0], Name) and last.targets[0].sym is not None and
                last.targets[0].sym.attrs.get("var")):
            continue
        res = last.targets[0].sym
        X = last.exprs[0]
        if not (isinstance(c, Name) and c.sym is not None and
                ((isinstance(X, Name) and X.sym is c.sym) or c.sym is res)):
            continue
        for op, evalb, joinb in (("and", tb, fb), ("or", fb, tb)):
            if evalb == b or evalb not in fn.blocks:
                continue
            eb = fn.blocks[evalb]
            if preds[evalb] != [b] or eb.term[0] != "goto":
                continue
            j = eb.term[1]
            if j != joinb:
                jb = fn.blocks.get(joinb)
                # join may be reached through an empty block
                if jb is None or jb.stmts or jb.term != ("goto", j) or preds[joinb] != [b]:
                    continue
                empty = joinb
            else:
                empty = None
            if len(eb.stmts) != 1:
                continue
            st = eb.stmts[0]
            if not (isinstance(st, Assign) and len(st.targets) == 1 and len(st.exprs) == 1 and
                    isinstance(st.targets[0], Name) and st.targets[0].sym is res):
                continue
            Y = st.exprs[0]
            if is_multi(Y):
                Y = Paren(Y)
            last.exprs[0] = Bin(op, X, Y)
            blk.term = ("goto", j)
            del fn.blocks[evalb]
            if empty is not None:
                del fn.blocks[empty]
            changed = True
            preds = predecessors(fn)
            break
    return changed


def merge_linear(fn):
    """Merge B -> C when C has B as its only predecessor."""
    changed = False
    preds = predecessors(fn)
    for b in list(fn.blocks):
        if b not in fn.blocks:
            continue
        blk = fn.blocks[b]
        while blk.term[0] == "goto":
            c = blk.term[1]
            if c == b or c == fn.entry or preds.get(c) != [b]:
                break
            cb = fn.blocks[c]
            blk.stmts.extend(cb.stmts)
            blk.term = cb.term
            del fn.blocks[c]
            for s in cb.succs():
                preds[s] = [b if p == c else p for p in preds[s]]
            changed = True
    return changed


def skip_empty(fn):
    """Redirect jumps over empty `goto` blocks."""
    changed = False
    for _ in range(3):
        target = {}
        for b, blk in fn.blocks.items():
            if not blk.stmts and blk.term[0] == "goto" and blk.term[1] != b and b != fn.entry:
                target[b] = blk.term[1]

        def final(x, seen=None):
            seen = seen or set()
            while x in target and x not in seen:
                seen.add(x)
                x = target[x]
            return x
        any_ = False
        for blk in fn.blocks.values():
            t = blk.term
            if t[0] == "goto" and final(t[1]) != t[1]:
                blk.term = ("goto", final(t[1]))
                any_ = True
            elif t[0] == "cond" and (final(t[2]) != t[2] or final(t[3]) != t[3]):
                blk.term = ("cond", t[1], final(t[2]), final(t[3]))
                any_ = True
        if not any_:
            break
        changed = True
        reachable(fn)
    return changed


def fold_ir(fn):
    for blk in fn.blocks.values():
        for s in blk.stmts:
            map_stmt_exprs(s, fold.fold)
        blk.term = map_term_exprs(blk.term, fold.fold)
        t = blk.term
        if t[0] == "cond":
            c, v = fold.const_value(t[1])
            if c:
                blk.term = ("goto", t[2] if (v is not None and v is not False) else t[3])
            elif t[2] == t[3]:
                blk.term = ("goto", t[2])


def optimize(fn):
    for _ in range(50):
        fold_ir(fn)
        reachable(fn)
        c = propagate_constants(fn)
        c |= dead_code(fn)
        c |= inline_temps(fn)
        c |= collapse_and_or(fn)
        c |= skip_empty(fn)
        c |= merge_linear(fn)
        if not c:
            break


# ------------------------------------------------------------ liveness
def liveness(fn):
    """Live-in sets of variable symbols per block."""
    use, defn = {}, {}
    for b, blk in fn.blocks.items():
        u, d = set(), set()
        for i in range(len(blk.stmts) + 1):
            exprs = stmt_exprs(blk.stmts[i]) if i < len(blk.stmts) else term_exprs(blk.term)
            for e in exprs:
                for x in iter_expr(e):
                    if isinstance(x, Name) and x.sym is not None and x.sym.attrs.get("var") and x.sym not in d:
                        u.add(x.sym)
            if i < len(blk.stmts):
                d |= set(s for s in stmt_defs(blk.stmts[i]))
                s = blk.stmts[i]
                if isinstance(s, Assign):
                    for t in s.targets:
                        if isinstance(t, Name) and t.sym is not None and t.sym.attrs.get("var"):
                            d.add(t.sym)
        use[b], defn[b] = u, d
    live = dict((b, set()) for b in fn.blocks)
    changed = True
    while changed:
        changed = False
        for b, blk in fn.blocks.items():
            out = set()
            for s in blk.succs():
                out |= live[s]
            new = use[b] | (out - defn[b])
            if new != live[b]:
                live[b] = new
                changed = True
    return live


# ------------------------------------------------------------ structuring
class Structurer(object):
    def __init__(self, fn):
        self.fn = fn
        self.preds = predecessors(fn)
        self.order = rpo(fn)
        self.idom = dominators(self.order, fn.entry, self.preds)
        self.ipdom = postdominators(fn)
        self.rpo_index = dict((b, i) for i, b in enumerate(self.order))
        self.find_loops()

    def find_loops(self):
        fn = self.fn
        self.loops = {}
        for b in self.order:
            for s in fn.blocks[b].succs():
                if dominates(self.idom, s, b):
                    self.loops.setdefault(s, set()).add(b)
        self.body = {}
        self.follow = {}
        for h, latches in self.loops.items():
            body = set([h])
            stack = list(latches)
            while stack:
                n = stack.pop()
                if n in body:
                    continue
                body.add(n)
                stack.extend(self.preds[n])
            self.body[h] = body
        self.parent = {}
        for h in self.body:
            best = None
            for h2, b2 in self.body.items():
                if h2 != h and h in b2 and (best is None or len(b2) < len(self.body[best])):
                    best = h2
            self.parent[h] = best
        returns_only = self._returns_only()
        for h, body in self.body.items():
            exits = []
            for n in body:
                for s in self.fn.blocks[n].succs():
                    if s not in body and s not in exits:
                        exits.append(s)
            natural = [s for s in self.fn.blocks[h].succs() if s not in body]
            for latch in self.loops[h]:
                lt = self.fn.blocks[latch].term
                if lt[0] == "cond":
                    natural += [s for s in (lt[2], lt[3]) if s not in body and s not in natural]
            if natural:
                exits = [e for e in exits if e in natural] or exits
            else:
                exits = [e for e in exits if e not in returns_only]
            if not exits:
                self.follow[h] = None
            elif len(exits) == 1:
                self.follow[h] = exits[0]
            else:
                pd = self.ipdom.get(h)
                while pd is not None and pd != EXIT and pd in body:
                    pd = self.ipdom.get(pd)
                if pd in exits:
                    self.follow[h] = pd
                else:
                    # pick the exit that post-dominates the most other exits
                    best = None
                    for e in exits:
                        if all(e == o or self.postdom(e, o) for o in exits):
                            best = e
                    if best is None:
                        # the header's own exit is the natural loop exit
                        ht = self.fn.blocks[h].term
                        hs = [s for s in self.fn.blocks[h].succs() if s not in body]
                        best = hs[0] if hs else sorted(exits, key=lambda x: self.order.index(x))[0]
                    self.follow[h] = best

    def find_join(self, n, tb, fb, loop):
        join = self.ipdom.get(n)
        if join == EXIT:
            join = None
        if join is not None and (loop is None or join == loop or join in self.body[loop]):
            return join
        # some path leaves (return / break): use the first node reachable from both branches
        body = self.body[loop] if loop is not None else None

        def reach(x):
            seen, stack = set(), [x]
            while stack:
                y = stack.pop()
                if y in seen or y == loop or (body is not None and y not in body):
                    continue
                if y == n:
                    continue
                seen.add(y)
                stack.extend(self.fn.blocks[y].succs())
            return seen
        rt, rf = reach(tb), reach(fb)
        common = rt & rf
        if not common:
            return None
        pos = self.rpo_index
        return min(common, key=lambda x: pos.get(x, 1 << 30))

    def reach_from(self, n, loop):
        fl = self.follow.get(loop)
        seen, stack = set(), [n]
        while stack:
            x = stack.pop()
            if x in seen:
                continue
            seen.add(x)
            if x == fl or x in self.body[loop]:
                continue
            stack.extend(self.fn.blocks[x].succs())
        return seen

    def exits_only(self, n, loop):
        """True if every path from n ends in a return without re-entering the loop."""
        seen, stack = set(), [n]
        while stack:
            x = stack.pop()
            if x in seen:
                continue
            seen.add(x)
            if x in self.body[loop]:
                return False
            stack.extend(self.fn.blocks[x].succs())
        return True

    def _returns_only(self):
        """Blocks from which every path ends in a return without looping (DAG to returns)."""
        out = set()
        changed = True
        while changed:
            changed = False
            for b, blk in self.fn.blocks.items():
                if b in out:
                    continue
                ss = blk.succs()
                if blk.term[0] == "ret" or (ss and all(s in out for s in ss)):
                    out.add(b)
                    changed = True
        return out

    def postdom(self, a, b):
        while b is not None:
            if a == b:
                return True
            nb = self.ipdom.get(b)
            if nb == b:
                return False
            b = nb
        return False

    def run(self):
        self.emitted = set()
        return self.region(self.fn.entry, None, None)

    def region(self, n, stop, loop, first=False):
        out = []
        while n is not None and n != stop:
            if first:
                first = False
            elif loop is not None:
                if n == loop:
                    return out  # back edge -> end of iteration
                if n == self.follow.get(loop):
                    out.append(Break())
                    return out
                if n not in self.body[loop]:
                    fl = self.follow.get(loop)
                    if n not in self.emitted:
                        reach = self.reach_from(n, loop)
                        if not (reach & self.body[loop]):
                            # code on the way out of the loop (break / return / infinite loop)
                            out.extend(self.region(n, fl, self.parent.get(loop)))
                            if fl is not None and fl in reach and not (out and isinstance(out[-1], (Return, Break))):
                                out.append(Break())
                            return out
                    raise StructError("jump out of loop %r to %r" % (loop, n))
            if n in self.loops and n != loop and n not in self.emitted:
                stmt, n = self.make_loop(n)
                out.append(stmt)
                continue
            if n in self.emitted:
                raise StructError("block %r emitted twice (loop=%r stop=%r)" % (n, loop, stop))
            self.emitted.add(n)
            blk = self.fn.blocks[n]
            out.extend(blk.stmts)
            t = blk.term
            if t[0] == "ret":
                out.append(Return(t[1]))
                return out
            if t[0] == "goto":
                n = t[1]
                continue
            c, tb, fb = t[1], t[2], t[3]
            join = self.find_join(n, tb, fb, loop)
            then = self.region(tb, join if join is not None else stop, loop)
            els = self.region(fb, join if join is not None else stop, loop)
            out.append(make_if(c, then, els))
            if join is None:
                return out
            n = join
        return out

    def make_loop(self, h):
        body = self.body[h]
        follow = self.follow[h]
        blk = self.fn.blocks[h]
        t = blk.term
        outer_emitted = self.emitted
        if t[0] == "cond" and ((t[2] in body) != (t[3] in body)):
            inside = t[2] if t[2] in body else t[3]
            outside = t[3] if inside == t[2] else t[2]
            if outside == follow and inside == h:
                # single block loop: repeat <stmts> until <exit condition>
                self.emitted.add(h)
                cond = t[1] if outside == t[2] else negate(t[1])
                r = Repeat(list(blk.stmts), cond)
                r.loop_header = h
                return r, follow
            if outside == follow:
                cond = t[1] if inside == t[2] else negate(t[1])
                self.emitted.add(h)
                inner = self.region(inside, None, h)
                if blk.stmts:
                    stmts = list(blk.stmts) + [make_if(negate(cond), [Break()], [])] + inner
                    w = While(Bool(True), stmts)
                else:
                    w = While(cond, inner)
                w.loop_header = h
                return w, follow
        # repeat ... until: single latch with conditional exit
        latches = self.loops[h]
        if len(latches) == 1:
            u = next(iter(latches))
            ut = self.fn.blocks[u].term
            if u != h and ut[0] == "cond" and h in (ut[2], ut[3]) and (ut[2] if ut[3] == h else ut[3]) == follow:
                cond = ut[1] if ut[3] == h else negate(ut[1])
                body_stmts = self.region_until(h, u, h)
                r = Repeat(body_stmts, cond)
                r.loop_header = h
                return r, follow
        inner = self.region(h, None, h, first=True)
        w = While(Bool(True), inner)
        w.loop_header = h
        return w, follow

    def region_until(self, start, latch, loop):
        # like region() but stops after emitting latch statements (its terminator is the until)
        saved = self.fn.blocks[latch].term
        sentinel = "__latch_end__"
        self.fn.blocks[latch].term = ("goto", sentinel)
        self.body[loop].add(sentinel)
        try:
            out = self.region(start, sentinel, loop, first=True)
        finally:
            self.fn.blocks[latch].term = saved
            self.body[loop].discard(sentinel)
        return out


def negate(c):
    if isinstance(c, Un) and c.op == "not":
        return c.expr
    if isinstance(c, Bin) and c.op in ("==", "~="):
        return Bin("~=" if c.op == "==" else "==", c.left, c.right)
    if isinstance(c, Bool):
        return Bool(not c.value)
    return Un("not", c)


def make_if(c, then, els):
    if not then and not els:
        return If(c, [], [])
    if not then:
        return If(negate(c), els, [])
    return If(c, then, els)


def dump(fn, out):
    from .printer import Printer
    p = Printer()
    for b in rpo(fn):
        blk = fn.blocks[b]
        out.write("block %r:\n" % (b,))
        for s in blk.stmts:
            try:
                p.out = []
                p.level = 1
                p.stat(s)
                out.write("".join(p.out))
            except Exception as ex:
                out.write("    <%s>\n" % type(s).__name__)
        t = blk.term
        if t[0] == "cond":
            try:
                c = p.expr(t[1])
            except Exception:
                c = "?"
            out.write("    -> cond %s ? %r : %r\n" % (c, t[2], t[3]))
        else:
            out.write("    -> %s %r\n" % (t[0], t[1] if t[0] == "goto" else len(t[1])))


def fallback_dispatch(fn, new_var):
    """Unstructurable CFG: emit an explicit state machine."""
    pc = new_var(None)
    order = rpo(fn)
    num = dict((b, i + 1) for i, b in enumerate(order))
    chain = []
    for b in order:
        blk = fn.blocks[b]
        stmts = list(blk.stmts)
        t = blk.term
        if t[0] == "goto":
            stmts.append(Assign([Name(pc.name, pc)], [Number(float(num[t[1]]))]))
        elif t[0] == "cond":
            stmts.append(If(t[1], [Assign([Name(pc.name, pc)], [Number(float(num[t[2]]))])],
                            [Assign([Name(pc.name, pc)], [Number(float(num[t[3]]))])]))
        else:
            stmts.append(Return(t[1]))
        chain.append((Bin("==", Name(pc.name, pc), Number(float(num[b]))), stmts))
    tree = []
    for cond, stmts in reversed(chain):
        tree = [If(cond, stmts, tree)]
    return [Local([pc], [Number(1.0)]), While(Bool(True), tree)]


# ---------------------------------------------------------- declarations
def declare_locals(body, syms, live):
    """Insert `local` declarations for the variable symbols `syms` used in `body`.

    Each variable is declared in the innermost statement list containing all of
    its occurrences, but never inside a loop whose header has it live-in.
    """
    occ = {}

    def scan_list(lst, path):
        for i, s in enumerate(lst):
            p = path + [(lst, i)]
            for n in _walk_all(_stmt_all_exprs(s)):
                if isinstance(n, Name) and n.sym is not None and n.sym in syms:
                    occ.setdefault(n.sym, []).append(p)
            for sub, extra in _sub_lists(s):
                scan_list(sub, p)
                if extra is not None:
                    pp = p + [(sub, len(sub))]
                    for n in _walk_all([extra]):
                        if isinstance(n, Name) and n.sym is not None and n.sym in syms:
                            occ.setdefault(n.sym, []).append(pp)

    scan_list(body, [])
    inserts = {}
    for sym, paths in occ.items():
        k = 0
        while all(len(p) > k + 1 for p in paths) and \
                all(p[k][0] is paths[0][k][0] and p[k][1] == paths[0][k][1] for p in paths) and \
                all(p[k + 1][0] is paths[0][k + 1][0] for p in paths):
            k += 1
        # adjust for loops carrying the value
        while k > 0:
            lst, i = paths[0][k - 1]
            stmt = lst[i]
            h = getattr(stmt, "loop_header", None)
            if h is not None and sym in live.get(h, ()):
                k -= 1
                continue
            break
        lst = paths[0][k][0]
        idx = min(p[k][1] for p in paths)
        inserts.setdefault(id(lst), (lst, {}))[1].setdefault(idx, []).append(sym)
    for lid, (lst, items) in inserts.items():
        for idx in sorted(items, reverse=True):
            group = sorted(items[idx], key=lambda s: s.id)
            gset = set(group)
            if idx < len(lst):
                s = lst[idx]
                if isinstance(s, Assign) and all(isinstance(t, Name) and t.sym in gset for t in s.targets) and \
                        len(set(t.sym for t in s.targets)) == len(s.targets) and \
                        not (_syms_in(s.exprs) & set(t.sym for t in s.targets)):
                    tsyms = [t.sym for t in s.targets]
                    lst[idx] = Local(tsyms, s.exprs)
                    rest = [x for x in group if x not in tsyms]
                    if rest:
                        lst.insert(idx, Local(rest, []))
                    continue
            lst.insert(idx, Local(group, []))


def _syms_in(exprs):
    out = set()
    for e in exprs:
        for x in _walk_all([e]):
            if isinstance(x, Name) and x.sym is not None:
                out.add(x.sym)
    return out


def _walk_all(lst):
    stack = list(lst)
    while stack:
        x = stack.pop()
        if not isinstance(x, Node):
            continue
        yield x
        for f in x.fields:
            v = getattr(x, f)
            if isinstance(v, Node):
                stack.append(v)
            elif isinstance(v, list):
                stack.extend(y for y in v if isinstance(y, Node))


def _stmt_all_exprs(s):
    if isinstance(s, Assign):
        return list(s.targets) + list(s.exprs)
    if isinstance(s, (Local,)):
        return list(s.exprs) + [Name(x.name, x) for x in s.syms]
    if isinstance(s, CallStat):
        return [s.call]
    if isinstance(s, Return):
        return list(s.exprs)
    if isinstance(s, If):
        return [s.cond]
    if isinstance(s, While):
        return [s.cond]
    if isinstance(s, NumFor):
        return [x for x in (s.start, s.stop, s.step) if x is not None]
    if isinstance(s, GenFor):
        return list(s.exprs)
    if isinstance(s, LocalFunc):
        return [s.func]
    if isinstance(s, FuncStat):
        return [s.target, s.func]
    return []


def _sub_lists(s):
    if isinstance(s, If):
        return [(s.body, None), (s.orelse, None)]
    if isinstance(s, (While, Do, NumFor, GenFor)):
        return [(s.body, None)]
    if isinstance(s, Repeat):
        return [(s.body, s.cond)]
    return []


# -------------------------------------------------------------- driver
def lower_pseudo(stmts):
    """Turn remaining pseudo expressions (tuples / spreads) into plain Lua."""

    def expand(x):
        """Lower x; returns a list of expressions when x is a spread of a tuple."""
        if isinstance(x, Spread) and isinstance(x.expr, TupleE):
            return lower_list(x.expr.exprs)
        return [lower(x)]

    def lower_list(lst):
        out = []
        for i, y in enumerate(lst):
            if isinstance(y, Node) and not isinstance(y, Stat) and not isinstance(y, TItem):
                r = expand(y)
                if i == len(lst) - 1:
                    out.extend(r)
                else:
                    out.append(_single(r))
            else:
                out.append(lower(y))
        return out

    def lower(x):
        if not isinstance(x, Node):
            return x
        if isinstance(x, Spread):
            if isinstance(x.expr, TupleE):
                return _single(lower_list(x.expr.exprs))
            inner = lower(x.expr)
            return Call(Name("unpack", None), [inner, Number(1.0), Index(clone(inner), String("n"))])
        if isinstance(x, Index) and isinstance(x.obj, TupleE) and isinstance(x.key, Number):
            es = lower_list(x.obj.exprs)
            k = int(x.key.value)
            if len(es) == 1 and isinstance(es[0], Vararg):
                if k == 1:
                    return Paren(Vararg())
                return Paren(Call(Name("select", None), [Number(float(k)), Vararg()]))
            if all(not is_multi(y) for y in es):
                return es[k - 1] if 0 < k <= len(es) else Nil()
            return Paren(Call(Name("select", None), [Number(float(k))] + es))
        if isinstance(x, TupleE):
            es = lower_list(x.exprs)
            if not getattr(x, "need_n", False):
                return Table([TItem(None, y) for y in es])
            if es and is_multi(es[-1]):
                # pack(...) without evaluating the values twice
                packer = Func([], True, [Return([Table([TItem(String("n"), Call(Name("select", None),
                                                                                    [String("#"), Vararg()])),
                                                        TItem(None, Vararg())])])])
                return Call(Paren(packer), es)
            return Table([TItem(String("n"), Number(float(len(es))))] + [TItem(None, y) for y in es])
        if isinstance(x, Table):
            items = []
            for i, it in enumerate(x.items):
                if it.key is None:
                    r = expand(it.value)
                    if i == len(x.items) - 1:
                        items.extend(TItem(None, v) for v in r)
                    else:
                        items.append(TItem(None, _single(r)))
                else:
                    items.append(TItem(lower(it.key), lower(it.value)))
            x.items = items
            return x
        if isinstance(x, Func):
            x.body = lower_list(x.body)
            return x
        for f in x.fields:
            v = getattr(x, f)
            if isinstance(v, list):
                if f in ("args", "exprs"):
                    setattr(x, f, lower_list(v))
                else:
                    setattr(x, f, [lower(y) for y in v])
            elif isinstance(v, Node):
                setattr(x, f, lower(v))
        return x

    # tuples whose element count matters (they are spread later) keep an `n` field
    spread = set()
    for n in _walk_all(stmts):
        if isinstance(n, Spread) and isinstance(n.expr, Name) and n.expr.sym is not None:
            spread.add(n.expr.sym)
    for n in _walk_all(stmts):
        if isinstance(n, (Assign, Local)):
            tg = n.targets if isinstance(n, Assign) else [Name(s.name, s) for s in n.syms]
            for t, e in zip(tg, n.exprs):
                if isinstance(t, Name) and t.sym in spread and isinstance(e, TupleE):
                    e.need_n = True
    return [lower(s) for s in stmts]


def _single(lst):
    if not lst:
        return Nil()
    e = lst[0]
    return Paren(e) if is_multi(e) else e
