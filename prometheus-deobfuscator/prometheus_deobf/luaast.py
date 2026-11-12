"""Minimal Lua 5.1 AST used by the deobfuscator.

Local variables are bound to ``Symbol`` objects at parse time, so every pass can
reason about identity instead of (mangled, possibly shadowed) names.  Globals are
``Name`` nodes whose ``sym`` is ``None``.
"""

import itertools

_ids = itertools.count(1)


class Symbol(object):
    __slots__ = ("name", "id", "hint", "attrs")

    def __init__(self, name=None, hint=None):
        self.id = next(_ids)
        self.name = name or ("_s%d" % self.id)
        self.hint = hint
        self.attrs = {}

    def __repr__(self):
        return "<Sym %s#%d>" % (self.name, self.id)


class Node(object):
    fields = ()

    def __init__(self, *args, **kw):
        for f, a in zip(self.fields, args):
            setattr(self, f, a)
        for f in self.fields[len(args):]:
            setattr(self, f, kw.pop(f, None))
        for k, v in kw.items():
            setattr(self, k, v)

    def __repr__(self):
        return "%s(%s)" % (type(self).__name__, ", ".join("%s=%r" % (f, getattr(self, f)) for f in self.fields))

    def copy(self):
        n = object.__new__(type(self))
        n.__dict__.update(self.__dict__)
        return n


# ---------------------------------------------------------------- expressions
class Expr(Node):
    pass


class Nil(Expr):
    fields = ()


class Bool(Expr):
    fields = ("value",)


class Number(Expr):
    fields = ("value",)


class String(Expr):
    fields = ("value",)  # python str, one char per byte (latin-1)


class Vararg(Expr):
    fields = ()


class Name(Expr):
    fields = ("name", "sym")


class Index(Expr):
    fields = ("obj", "key")


class Call(Expr):
    fields = ("func", "args")


class Method(Expr):
    fields = ("obj", "name", "args")


class Func(Expr):
    fields = ("params", "vararg", "body")


class TItem(Node):
    fields = ("key", "value")  # key None => positional


class Table(Expr):
    fields = ("items",)


class Bin(Expr):
    fields = ("op", "left", "right")


class Un(Expr):
    fields = ("op", "expr")


class Paren(Expr):
    fields = ("expr",)


# ----------------------------------------------------------------- statements
class Stat(Node):
    pass


class Local(Stat):
    fields = ("syms", "exprs")


class Assign(Stat):
    fields = ("targets", "exprs")


class CallStat(Stat):
    fields = ("call",)


class Do(Stat):
    fields = ("body",)


class While(Stat):
    fields = ("cond", "body")


class Repeat(Stat):
    fields = ("body", "cond")


class If(Stat):
    fields = ("cond", "body", "orelse")  # orelse: list of statements


class NumFor(Stat):
    fields = ("sym", "start", "stop", "step", "body")


class GenFor(Stat):
    fields = ("syms", "exprs", "body")


class LocalFunc(Stat):
    fields = ("sym", "func")


class FuncStat(Stat):
    fields = ("target", "func", "method")  # target: Name/Index chain


class Return(Stat):
    fields = ("exprs",)


class Break(Stat):
    fields = ()


class Chunk(Node):
    fields = ("body",)


# ------------------------------------------------------------------- helpers
def is_multi(e):
    """Expressions that can yield multiple values in a tail position."""
    return isinstance(e, (Call, Method, Vararg))


def children(n):
    """Yield child nodes / lists in evaluation order."""
    for f in n.fields:
        v = getattr(n, f)
        if isinstance(v, Node):
            yield v
        elif isinstance(v, list):
            for x in v:
                if isinstance(x, Node):
                    yield x


def walk(n):
    """Pre-order walk over every node (including statements inside functions)."""
    stack = [n]
    while stack:
        x = stack.pop()
        yield x
        ch = list(children(x))
        ch.reverse()
        stack.extend(ch)


def transform(n, fn):
    """Post-order rewrite. ``fn(node)`` returns a replacement node or None.

    For statement lists ``fn`` may return a list to splice.
    """
    for f in n.fields:
        v = getattr(n, f)
        if isinstance(v, Node):
            r = transform(v, fn)
            if isinstance(r, list):
                raise ValueError("list returned for scalar field")
            setattr(n, f, r)
        elif isinstance(v, list):
            out = []
            for x in v:
                if isinstance(x, Node):
                    r = transform(x, fn)
                    if isinstance(r, list):
                        out.extend(r)
                    else:
                        out.append(r)
                else:
                    out.append(x)
            setattr(n, f, out)
    r = fn(n)
    return n if r is None else r


def deepcopy(n, symmap=None):
    """Copy a subtree. Symbols declared inside are re-created (fresh)."""
    if symmap is None:
        symmap = {}

    def cs(s):
        if s is None:
            return None
        return symmap.get(s, s)

    def rec(x):
        if isinstance(x, list):
            return [rec(y) for y in x]
        if not isinstance(x, Node):
            return x
        # declare fresh symbols first
        if isinstance(x, Func):
            for p in x.params:
                symmap[p] = Symbol(p.name, p.hint)
        elif isinstance(x, Local):
            pass
        y = object.__new__(type(x))
        y.__dict__.update(x.__dict__)
        if isinstance(x, Local):
            y.exprs = rec(x.exprs)
            for s in x.syms:
                symmap[s] = Symbol(s.name, s.hint)
            y.syms = [cs(s) for s in x.syms]
            return y
        if isinstance(x, LocalFunc):
            symmap[x.sym] = Symbol(x.sym.name, x.sym.hint)
            y.sym = cs(x.sym)
            y.func = rec(x.func)
            return y
        if isinstance(x, NumFor):
            y.start, y.stop, y.step = rec(x.start), rec(x.stop), rec(x.step)
            symmap[x.sym] = Symbol(x.sym.name, x.sym.hint)
            y.sym = cs(x.sym)
            y.body = rec(x.body)
            return y
        if isinstance(x, GenFor):
            y.exprs = rec(x.exprs)
            for s in x.syms:
                symmap[s] = Symbol(s.name, s.hint)
            y.syms = [cs(s) for s in x.syms]
            y.body = rec(x.body)
            return y
        for f in x.fields:
            v = getattr(x, f)
            if f == "params":
                setattr(y, f, [cs(p) for p in v])
            elif f == "sym":
                setattr(y, f, cs(v))
            else:
                setattr(y, f, rec(v))
        return y

    return rec(n)
