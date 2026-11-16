"""Pretty printer for the AST (produces valid Lua 5.1)."""

import math
import re

from .luaast import (Nil, Bool, Number, String, Vararg, Name, Index, Call, Method, Func, Table, Bin, Un, Paren,
                     Local, Assign, CallStat, Do, While, Repeat, If, NumFor, GenFor, LocalFunc, FuncStat, Return,
                     Break, Chunk)
from .parser import KEYWORDS, BINPRI, UNARY_PRI

IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def is_ident(s):
    return isinstance(s, str) and bool(IDENT.match(s)) and s not in KEYWORDS


def fmt_number(v):
    if v != v:
        return "(0/0)"
    if v == math.inf:
        return "(1/0)"
    if v == -math.inf:
        return "(-1/0)"
    if v == int(v) and abs(v) < 2 ** 63:
        if v == 0 and math.copysign(1, v) < 0:
            return "(-0)"
        return str(int(v))
    r = repr(float(v))
    if "e" in r or "E" in r:
        m, e = r.lower().split("e")
        r = "%se%d" % (m, int(e))
    return r


def fmt_string(s):
    out = ['"']
    for ch in s:
        o = ord(ch)
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\t":
            out.append("\\t")
        elif ch == "\r":
            out.append("\\r")
        elif 32 <= o < 127:
            out.append(ch)
        else:
            out.append("\\%03d" % (o & 255))
    out.append('"')
    return "".join(out)


def _pri(e):
    if isinstance(e, Bin):
        return BINPRI[e.op]
    if isinstance(e, Un):
        return (UNARY_PRI, UNARY_PRI)
    if isinstance(e, Number) and (e.value < 0 or (e.value == 0 and math.copysign(1, e.value) < 0)):
        return (UNARY_PRI, UNARY_PRI)
    return None


def sym_name(n):
    return n.sym.name if n.sym is not None else n.name


class Printer(object):
    def __init__(self, indent="    "):
        self.ind = indent
        self.out = []

    def expr(self, e, prec=0):
        if isinstance(e, Nil):
            return "nil"
        if isinstance(e, Bool):
            return "true" if e.value else "false"
        if isinstance(e, Number):
            return fmt_number(e.value)
        if isinstance(e, String):
            return fmt_string(e.value)
        if isinstance(e, Vararg):
            return "..."
        if isinstance(e, Name):
            return sym_name(e)
        if isinstance(e, Paren):
            return "(" + self.expr(e.expr) + ")"
        if isinstance(e, Index):
            base = self.prefix(e.obj)
            if isinstance(e.key, String) and is_ident(e.key.value):
                return base + "." + e.key.value
            return base + "[" + self.expr(e.key) + "]"
        if isinstance(e, Call):
            return self.prefix(e.func) + self.args(e.args)
        if isinstance(e, Method):
            return self.prefix(e.obj) + ":" + e.name + self.args(e.args)
        if isinstance(e, Func):
            return self.func(e)
        if isinstance(e, Table):
            return self.table(e)
        if isinstance(e, Bin):
            lp, rp = BINPRI[e.op]
            ls = self.expr(e.left)
            lpri = _pri(e.left)
            if lpri is not None and lp > lpri[1]:
                ls = "(" + ls + ")"
            rs = self.expr(e.right)
            rpri = _pri(e.right)
            assoc = e.op in ("and", "or") and isinstance(e.right, Bin) and e.right.op == e.op
            if rpri is not None and rpri[0] <= rp and not assoc:
                rs = "(" + rs + ")"
            return "%s %s %s" % (ls, e.op, rs)
        if isinstance(e, Un):
            inner = self.expr(e.expr)
            ip = _pri(e.expr)
            if ip is not None and ip[0] <= UNARY_PRI and not isinstance(e.expr, Un):
                inner = "(" + inner + ")"
            if e.op == "not":
                return "not " + inner
            if e.op == "-" and inner.startswith("-"):
                return "-(" + inner + ")"
            return e.op + inner
        raise TypeError("cannot print %r" % (e,))

    def prefix(self, e):
        if isinstance(e, (Name, Index, Call, Method, Paren)):
            return self.expr(e)
        return "(" + self.expr(e) + ")"

    def args(self, args):
        return "(" + ", ".join(self.expr(a) for a in args) + ")"

    def table(self, t):
        if not t.items:
            return "{}"
        parts = []
        for it in t.items:
            if it.key is None:
                parts.append(self.expr(it.value))
            elif isinstance(it.key, String) and is_ident(it.key.value):
                parts.append("%s = %s" % (it.key.value, self.expr(it.value)))
            else:
                parts.append("[%s] = %s" % (self.expr(it.key), self.expr(it.value)))
        one = "{" + ", ".join(parts) + "}"
        if len(one) <= 100 and "\n" not in one:
            return one
        pad = self.ind * (self.level + 1)
        return "{\n" + ",\n".join(pad + p for p in parts) + "\n" + self.ind * self.level + "}"

    def func(self, f, name=None):
        ps = [p.name for p in f.params]
        if f.vararg:
            ps.append("...")
        head = "function" + ((" " + name) if name else "") + "(" + ", ".join(ps) + ")"
        if not f.body:
            return head + " end"
        sub = Printer(self.ind)
        sub.level = self.level + 1
        sub.block(f.body)
        return head + "\n" + "".join(sub.out) + self.ind * self.level + "end"

    def line(self, s):
        self.out.append(self.ind * self.level + s + "\n")

    def block(self, stats):
        for i, s in enumerate(stats):
            self.stat(s, stats[i + 1] if i + 1 < len(stats) else None)

    def stat(self, s, nxt=None):
        if isinstance(s, Local):
            names = ", ".join(x.name for x in s.syms)
            if s.exprs:
                self.line("local %s = %s" % (names, ", ".join(self.expr(e) for e in s.exprs)) + self.semi(nxt))
            else:
                self.line("local " + names)
        elif isinstance(s, Assign):
            self.line("%s = %s" % (", ".join(self.expr(t) for t in s.targets),
                                   ", ".join(self.expr(e) for e in s.exprs)) + self.semi(nxt))
        elif isinstance(s, CallStat):
            self.line(self.expr(s.call) + self.semi(nxt))
        elif isinstance(s, Do):
            self.line("do")
            self.sub(s.body)
            self.line("end")
        elif isinstance(s, While):
            self.line("while %s do" % self.expr(s.cond))
            self.sub(s.body)
            self.line("end")
        elif isinstance(s, Repeat):
            self.line("repeat")
            self.sub(s.body)
            self.line("until " + self.expr(s.cond))
        elif isinstance(s, If):
            self.line("if %s then" % self.expr(s.cond))
            self.sub(s.body)
            orelse = s.orelse
            while len(orelse) == 1 and isinstance(orelse[0], If):
                self.line("elseif %s then" % self.expr(orelse[0].cond))
                self.sub(orelse[0].body)
                orelse = orelse[0].orelse
            if orelse:
                self.line("else")
                self.sub(orelse)
            self.line("end")
        elif isinstance(s, NumFor):
            rng = "%s, %s" % (self.expr(s.start), self.expr(s.stop))
            if s.step is not None and not (isinstance(s.step, Number) and s.step.value == 1):
                rng += ", " + self.expr(s.step)
            self.line("for %s = %s do" % (s.sym.name, rng))
            self.sub(s.body)
            self.line("end")
        elif isinstance(s, GenFor):
            self.line("for %s in %s do" % (", ".join(x.name for x in s.syms), ", ".join(self.expr(e) for e in s.exprs)))
            self.sub(s.body)
            self.line("end")
        elif isinstance(s, LocalFunc):
            self.line("local " + self.func(s.func, s.sym.name))
        elif isinstance(s, FuncStat):
            if s.method:
                name = self.expr(s.target.obj) + ":" + s.target.key.value
                f = s.func
                inner = Func(f.params[1:], f.vararg, f.body)
                self.line(self.func(inner, name))
            else:
                self.line(self.func(s.func, self.expr(s.target)))
        elif isinstance(s, Return):
            if s.exprs:
                self.line("return " + ", ".join(self.expr(e) for e in s.exprs))
            else:
                self.line("return")
        elif isinstance(s, Break):
            self.line("break")
        else:
            raise TypeError("cannot print statement %r" % (s,))

    def semi(self, nxt):
        # avoid ambiguity "a = b\n(f)()" -> needs ';'
        if nxt is not None and isinstance(nxt, (CallStat, Assign)):
            first = nxt.call if isinstance(nxt, CallStat) else nxt.targets[0]
            while isinstance(first, (Call, Method, Index)):
                first = first.func if isinstance(first, Call) else first.obj
            if isinstance(first, Paren) or not isinstance(first, Name):
                return ";"
        return ""

    def sub(self, stats):
        self.level += 1
        self.block(stats)
        self.level -= 1

    level = 0


def to_source(chunk):
    p = Printer()
    p.block(chunk.body if isinstance(chunk, Chunk) else chunk)
    return "".join(p.out)
