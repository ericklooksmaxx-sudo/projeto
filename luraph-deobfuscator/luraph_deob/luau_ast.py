"""Minimal but complete Luau lexer, parser and pretty printer.

Covers the subset of Luau emitted by Luraph v15.x: all Lua 5.1 syntax plus
compound assignment (+= -= *= /= //= %= ^= ..=), `continue`, integer
division `//`, interpolated-free strings with long brackets, hex/binary
numbers with underscores, and if-expressions (`if a then b else c`).
Type annotations are parsed and discarded.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, List, Optional

# --------------------------------------------------------------------------
# AST nodes
# --------------------------------------------------------------------------


class Node:
    __slots__ = ()

    def children(self):
        for name in self.__slots__:
            v = getattr(self, name)
            if isinstance(v, Node):
                yield v
            elif isinstance(v, list):
                for x in v:
                    if isinstance(x, Node):
                        yield x
                    elif isinstance(x, tuple):
                        for y in x:
                            if isinstance(y, Node):
                                yield y


def _node(name, fields):
    def __init__(self, *args, **kw):
        for f, a in zip(fields, args):
            setattr(self, f, a)
        for f in fields[len(args):]:
            setattr(self, f, kw.get(f))

    def __repr__(self):
        return "%s(%s)" % (name, ", ".join("%s=%r" % (f, getattr(self, f)) for f in fields))

    return type(name, (Node,), {"__slots__": tuple(fields), "__init__": __init__, "__repr__": __repr__})


# expressions
Nil = _node("Nil", [])
TrueE = _node("TrueE", [])
FalseE = _node("FalseE", [])
Vararg = _node("Vararg", [])
Number = _node("Number", ["value"])
String = _node("String", ["value"])  # value: bytes
Name = _node("Name", ["name"])
Index = _node("Index", ["obj", "key"])  # obj[key]; key is expr
Call = _node("Call", ["func", "args"])
MethodCall = _node("MethodCall", ["obj", "name", "args"])
Function = _node("Function", ["params", "is_vararg", "body", "name"])
Table = _node("Table", ["items"])  # items: list of (kind, key, value) kind in pos/named/expr
BinOp = _node("BinOp", ["op", "left", "right"])
UnOp = _node("UnOp", ["op", "operand"])
Paren = _node("Paren", ["expr"])
IfExpr = _node("IfExpr", ["cond", "then", "orelse"])

# statements
Local = _node("Local", ["names", "values"])
LocalFunction = _node("LocalFunction", ["name", "func"])
Assign = _node("Assign", ["targets", "values"])
CompoundAssign = _node("CompoundAssign", ["op", "target", "value"])
CallStat = _node("CallStat", ["call"])
Do = _node("Do", ["body"])
While = _node("While", ["cond", "body"])
Repeat = _node("Repeat", ["body", "cond"])
If = _node("If", ["clauses", "orelse"])  # clauses: list of (cond, body)
NumericFor = _node("NumericFor", ["var", "start", "stop", "step", "body"])
GenericFor = _node("GenericFor", ["names", "exprs", "body"])
FunctionStat = _node("FunctionStat", ["target", "func", "is_method", "method"])
Return = _node("Return", ["values"])
Break = _node("Break", [])
Continue = _node("Continue", [])
Comment = _node("Comment", ["text"])
Block = _node("Block", ["body"])
Goto = _node("Goto", ["label"])  # synthetic, for lifted code
Label = _node("Label", ["name"])  # synthetic


# --------------------------------------------------------------------------
# Lexer
# --------------------------------------------------------------------------

KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "if", "in", "local", "nil", "not", "or", "repeat", "return", "then",
    "true", "until", "while",
}

_SYMBOLS = sorted(
    [
        "...", "..=", "//=", "==", "~=", "<=", ">=", "..", "+=", "-=", "*=",
        "/=", "%=", "^=", "//", "::", "->", "+", "-", "*", "/", "%", "^", "#",
        "<", ">", "=", "(", ")", "{", "}", "[", "]", ";", ":", ",", ".", "?",
        "|", "&",
    ],
    key=len,
    reverse=True,
)

_ws_re = re.compile(rb"[ \t\r\n\f\v]+")
_name_re = re.compile(rb"[A-Za-z_][A-Za-z0-9_]*")
_num_re = re.compile(
    # underscores are permitted as digit separators almost anywhere, including
    # between the leading 0 and the base letter (e.g. `0_b1000_1`, seen in LPS)
    rb"0[_]*[xX][0-9A-Fa-f_]+|0[_]*[bB][01_]+|(?:[0-9][0-9_]*(?:\.[0-9_]*)?|\.[0-9][0-9_]*)(?:[eE][+-]?[0-9_]+)?"
)
_longbr_re = re.compile(rb"\[(=*)\[")


class LexError(Exception):
    pass


@dataclass
class Tok:
    kind: str  # name, kw, num, str, sym, eof
    value: Any
    pos: int


def _parse_number(raw: bytes):
    s = raw.replace(b"_", b"").decode()
    if s[:2] in ("0x", "0X"):
        return int(s, 16)
    if s[:2] in ("0b", "0B"):
        return int(s[2:], 2)
    if any(c in s for c in ".eE"):
        v = float(s)
        if v.is_integer() and abs(v) < 2**53:
            return int(v) if "." not in s and "e" not in s.lower() else v
        return v
    return int(s)


_ESC = {
    ord("n"): b"\n", ord("t"): b"\t", ord("r"): b"\r", ord("a"): b"\a",
    ord("b"): b"\b", ord("f"): b"\f", ord("v"): b"\v", ord("\\"): b"\\",
    ord('"'): b'"', ord("'"): b"'", ord("\n"): b"\n",
}


def tokenize(src: bytes) -> List[Tok]:
    toks: List[Tok] = []
    i, n = 0, len(src)
    while i < n:
        m = _ws_re.match(src, i)
        if m:
            i = m.end()
            continue
        c = src[i]
        if src.startswith(b"--", i):
            m = _longbr_re.match(src, i + 2)
            if m:
                close = b"]" + m.group(1) + b"]"
                j = src.find(close, m.end())
                i = n if j < 0 else j + len(close)
            else:
                j = src.find(b"\n", i)
                i = n if j < 0 else j + 1
            continue
        if c in b"\"'":
            q = c
            j = i + 1
            out = bytearray()
            while True:
                if j >= n:
                    raise LexError("unterminated string at %d" % i)
                ch = src[j]
                if ch == q:
                    j += 1
                    break
                if ch == 92:  # backslash
                    j += 1
                    e = src[j]
                    if e in _ESC:
                        out += _ESC[e]
                        j += 1
                    elif 48 <= e <= 57:
                        k = j
                        while k < j + 3 and k < n and 48 <= src[k] <= 57:
                            k += 1
                        out.append(int(src[j:k]) & 0xFF)
                        j = k
                    elif e == ord("x"):
                        out.append(int(src[j + 1:j + 3], 16))
                        j += 3
                    elif e == ord("z"):
                        j += 1
                        while j < n and src[j] in b" \t\r\n\f\v":
                            j += 1
                    elif e == ord("u"):
                        k = src.index(b"}", j)
                        out += chr(int(src[j + 2:k], 16)).encode("utf-8")
                        j = k + 1
                    elif e == 13:
                        j += 1
                        if j < n and src[j] == 10:
                            j += 1
                        out += b"\n"
                    else:
                        out.append(e)  # Lua 5.1: unknown escape yields the character itself
                        j += 1
                    continue
                out.append(ch)
                j += 1
            toks.append(Tok("str", bytes(out), i))
            i = j
            continue
        if c == ord("["):
            m = _longbr_re.match(src, i)
            if m:
                close = b"]" + m.group(1) + b"]"
                j = src.find(close, m.end())
                if j < 0:
                    raise LexError("unterminated long string at %d" % i)
                body = src[m.end():j]
                if body.startswith(b"\r\n"):
                    body = body[2:]
                elif body.startswith(b"\n"):
                    body = body[1:]
                toks.append(Tok("str", body, i))
                i = j + len(close)
                continue
        if 48 <= c <= 57 or (c == ord(".") and i + 1 < n and 48 <= src[i + 1] <= 57):
            m = _num_re.match(src, i)
            toks.append(Tok("num", _parse_number(m.group()), i))
            i = m.end()
            continue
        m = _name_re.match(src, i)
        if m:
            w = m.group().decode()
            toks.append(Tok("kw" if w in KEYWORDS else "name", w, i))
            i = m.end()
            continue
        for s in _SYMBOLS:
            if src.startswith(s.encode(), i):
                toks.append(Tok("sym", s, i))
                i += len(s)
                break
        else:
            raise LexError("unexpected char %r at %d" % (chr(c), i))
    toks.append(Tok("eof", None, n))
    return toks


# --------------------------------------------------------------------------
# Parser
# --------------------------------------------------------------------------

BINPRI = {
    "or": (1, 1), "and": (2, 2),
    "<": (3, 3), ">": (3, 3), "<=": (3, 3), ">=": (3, 3), "~=": (3, 3), "==": (3, 3),
    "..": (5, 4),  # right assoc
    "+": (6, 6), "-": (6, 6),
    "*": (7, 7), "/": (7, 7), "//": (7, 7), "%": (7, 7),
    "^": (10, 9),  # right assoc
}
UNARY_PRI = 8
COMPOUND = {"+=", "-=", "*=", "/=", "//=", "%=", "^=", "..="}


class ParseError(Exception):
    pass


class Parser:
    def __init__(self, src):
        if isinstance(src, str):
            src = src.encode("latin-1")
        self.toks = tokenize(src)
        self.p = 0

    # helpers
    def peek(self, k=0):
        return self.toks[self.p + k]

    def next(self):
        t = self.toks[self.p]
        self.p += 1
        return t

    def check(self, kind, value=None):
        t = self.toks[self.p]
        return t.kind == kind and (value is None or t.value == value)

    def accept(self, kind, value=None):
        if self.check(kind, value):
            return self.next()
        return None

    def expect(self, kind, value=None):
        t = self.next()
        if t.kind != kind or (value is not None and t.value != value):
            raise ParseError("expected %s %r got %s %r at %d" % (kind, value, t.kind, t.value, t.pos))
        return t

    def sym(self, s):
        return self.check("sym", s)

    def kw(self, s):
        return self.check("kw", s)

    # entry
    def parse_chunk(self):
        body = self.block()
        self.expect("eof")
        return Block(body)

    def block_end(self):
        t = self.peek()
        return t.kind == "eof" or (t.kind == "kw" and t.value in ("end", "else", "elseif", "until"))

    def block(self):
        stmts = []
        while not self.block_end():
            if self.accept("sym", ";"):
                continue
            if self.kw("return"):
                self.next()
                vals = []
                if not self.block_end() and not self.sym(";"):
                    vals = self.exprlist()
                self.accept("sym", ";")
                stmts.append(Return(vals))
                break
            stmts.append(self.statement())
        return stmts

    # types are skipped with a crude balanced scan
    def skip_type(self):
        depth = 0
        while True:
            t = self.peek()
            if t.kind == "eof":
                return
            if t.kind == "sym" and t.value in ("(", "{", "<"):
                depth += 1
            elif t.kind == "sym" and t.value in (")", "}", ">"):
                if depth == 0:
                    return
                depth -= 1
            elif depth == 0 and (
                (t.kind == "sym" and t.value in (",", "=", ";"))
                or (t.kind == "kw" and t.value not in ("nil", "function"))
            ):
                return
            self.next()

    def statement(self):
        t = self.peek()
        if t.kind == "kw":
            v = t.value
            if v == "local":
                self.next()
                if self.accept("kw", "function"):
                    name = self.expect("name").value
                    f = self.funcbody(name)
                    return LocalFunction(name, f)
                names = [self.localname()]
                while self.accept("sym", ","):
                    names.append(self.localname())
                vals = []
                if self.accept("sym", "="):
                    vals = self.exprlist()
                return Local(names, vals)
            if v == "if":
                self.next()
                clauses = []
                c = self.expr()
                self.expect("kw", "then")
                clauses.append((c, self.block()))
                orelse = None
                while True:
                    if self.accept("kw", "elseif"):
                        c = self.expr()
                        self.expect("kw", "then")
                        clauses.append((c, self.block()))
                    elif self.accept("kw", "else"):
                        orelse = self.block()
                        self.expect("kw", "end")
                        break
                    else:
                        self.expect("kw", "end")
                        break
                return If(clauses, orelse)
            if v == "while":
                self.next()
                c = self.expr()
                self.expect("kw", "do")
                b = self.block()
                self.expect("kw", "end")
                return While(c, b)
            if v == "do":
                self.next()
                b = self.block()
                self.expect("kw", "end")
                return Do(b)
            if v == "for":
                self.next()
                n1 = self.localname()
                if self.accept("sym", "="):
                    start = self.expr()
                    self.expect("sym", ",")
                    stop = self.expr()
                    step = None
                    if self.accept("sym", ","):
                        step = self.expr()
                    self.expect("kw", "do")
                    b = self.block()
                    self.expect("kw", "end")
                    return NumericFor(n1, start, stop, step, b)
                names = [n1]
                while self.accept("sym", ","):
                    names.append(self.localname())
                self.expect("kw", "in")
                exprs = self.exprlist()
                self.expect("kw", "do")
                b = self.block()
                self.expect("kw", "end")
                return GenericFor(names, exprs, b)
            if v == "repeat":
                self.next()
                b = self.block()
                self.expect("kw", "until")
                c = self.expr()
                return Repeat(b, c)
            if v == "function":
                self.next()
                n = self.expect("name").value
                target = Name(n)
                full = n
                is_method = False
                method = None
                while True:
                    if self.accept("sym", "."):
                        k = self.expect("name").value
                        target = Index(target, String(k.encode()))
                        full += "." + k
                    elif self.accept("sym", ":"):
                        k = self.expect("name").value
                        is_method = True
                        method = k
                        full += ":" + k
                        break
                    else:
                        break
                f = self.funcbody(full, is_method)
                if is_method:
                    target = Index(target, String(method.encode()))
                return FunctionStat(target, f, is_method, method)
            if v == "break":
                self.next()
                return Break()
        if t.kind == "name" and t.value == "continue":
            nt = self.peek(1)
            if nt.kind in ("eof", "kw") or (nt.kind == "sym" and nt.value == ";") or nt.kind == "name":
                if not (nt.kind == "sym" and nt.value in ("=", ".", "[", ":", "(")):
                    self.next()
                    return Continue()
        if t.kind == "name" and t.value == "type" and self.peek(1).kind == "name":
            # type alias: skip to next statement heuristically
            self.next()
            self.next()
            self.expect("sym", "=")
            self.skip_type()
            return Do([])
        # expression statement
        e = self.suffixedexpr()
        if self.sym("=") or self.sym(","):
            targets = [e]
            while self.accept("sym", ","):
                targets.append(self.suffixedexpr())
            self.expect("sym", "=")
            vals = self.exprlist()
            return Assign(targets, vals)
        t = self.peek()
        if t.kind == "sym" and t.value in COMPOUND:
            self.next()
            v = self.expr()
            return CompoundAssign(t.value[:-1], e, v)
        if not isinstance(e, (Call, MethodCall)):
            raise ParseError("syntax error near %r at %d" % (t.value, t.pos))
        return CallStat(e)

    def localname(self):
        n = self.expect("name").value
        if self.accept("sym", ":"):
            self.skip_type()
        if self.accept("sym", "<"):  # attribs <const>
            self.expect("name")
            self.expect("sym", ">")
        return n

    def funcbody(self, name=None, is_method=False):
        self.expect("sym", "(")
        params = ["self"] if is_method else []
        vararg = False
        if not self.sym(")"):
            while True:
                if self.accept("sym", "..."):
                    vararg = True
                    if self.accept("sym", ":"):
                        self.skip_type()
                    break
                params.append(self.localname())
                if not self.accept("sym", ","):
                    break
        self.expect("sym", ")")
        if self.accept("sym", ":"):
            self.skip_type()
        body = self.block()
        self.expect("kw", "end")
        return Function(params, vararg, body, name)

    def exprlist(self):
        es = [self.expr()]
        while self.accept("sym", ","):
            es.append(self.expr())
        return es

    def primaryexpr(self):
        t = self.next()
        if t.kind == "name":
            return Name(t.value)
        if t.kind == "sym" and t.value == "(":
            e = self.expr()
            self.expect("sym", ")")
            return Paren(e)
        raise ParseError("unexpected %s %r at %d" % (t.kind, t.value, t.pos))

    def suffixedexpr(self):
        e = self.primaryexpr()
        while True:
            t = self.peek()
            if t.kind == "sym":
                if t.value == ".":
                    self.next()
                    e = Index(e, String(self.expect("name").value.encode()))
                    continue
                if t.value == "[":
                    self.next()
                    k = self.expr()
                    self.expect("sym", "]")
                    e = Index(e, k)
                    continue
                if t.value == ":":
                    self.next()
                    n = self.expect("name").value
                    e = MethodCall(e, n, self.callargs())
                    continue
                if t.value in ("(", "{"):
                    e = Call(e, self.callargs())
                    continue
            if t.kind == "str":
                e = Call(e, self.callargs())
                continue
            return e

    def callargs(self):
        t = self.peek()
        if t.kind == "str":
            self.next()
            return [String(t.value)]
        if t.kind == "sym" and t.value == "{":
            return [self.table()]
        self.expect("sym", "(")
        if self.accept("sym", ")"):
            return []
        a = self.exprlist()
        self.expect("sym", ")")
        return a

    def table(self):
        self.expect("sym", "{")
        items = []
        while not self.sym("}"):
            if self.accept("sym", "["):
                k = self.expr()
                self.expect("sym", "]")
                self.expect("sym", "=")
                items.append(("expr", k, self.expr()))
            elif self.check("name") and self.peek(1).kind == "sym" and self.peek(1).value == "=":
                k = self.next().value
                self.next()
                items.append(("named", String(k.encode()), self.expr()))
            else:
                items.append(("pos", None, self.expr()))
            if not (self.accept("sym", ",") or self.accept("sym", ";")):
                break
        self.expect("sym", "}")
        return Table(items)

    def simpleexpr(self):
        t = self.peek()
        if t.kind == "num":
            self.next()
            return Number(t.value)
        if t.kind == "str":
            self.next()
            return String(t.value)
        if t.kind == "kw":
            if t.value == "nil":
                self.next()
                return Nil()
            if t.value == "true":
                self.next()
                return TrueE()
            if t.value == "false":
                self.next()
                return FalseE()
            if t.value == "function":
                self.next()
                return self.funcbody()
            if t.value == "if":
                self.next()
                c = self.expr()
                self.expect("kw", "then")
                a = self.expr()
                if self.accept("kw", "elseif"):
                    # desugar elseif chain
                    self.p -= 1
                    self.toks[self.p] = Tok("kw", "if", self.toks[self.p].pos)
                    b = self.simpleexpr()
                    return IfExpr(c, a, b)
                self.expect("kw", "else")
                b = self.expr()
                return IfExpr(c, a, b)
        if t.kind == "sym":
            if t.value == "...":
                self.next()
                return Vararg()
            if t.value == "{":
                return self.table()
        return self.suffixedexpr()

    def expr(self, limit=0):
        t = self.peek()
        if (t.kind == "kw" and t.value == "not") or (t.kind == "sym" and t.value in ("-", "#")):
            self.next()
            operand = self.expr(UNARY_PRI)
            e = UnOp(t.value, operand)
        else:
            e = self.simpleexpr()
        while True:
            t = self.peek()
            op = t.value if t.kind in ("sym", "kw") else None
            if op in BINPRI and BINPRI[op][0] > limit:
                self.next()
                r = self.expr(BINPRI[op][1])
                e = BinOp(op, e, r)
            elif t.kind == "sym" and t.value == "::":  # type assertion
                self.next()
                self.skip_type()
            else:
                return e


def parse(src) -> Block:
    return Parser(src).parse_chunk()


# --------------------------------------------------------------------------
# Pretty printer
# --------------------------------------------------------------------------

_ident_re = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def quote_bytes(b: bytes) -> str:
    out = ['"']
    for c in b:
        if c == 34:
            out.append('\\"')
        elif c == 92:
            out.append("\\\\")
        elif c == 10:
            out.append("\\n")
        elif c == 13:
            out.append("\\r")
        elif c == 9:
            out.append("\\t")
        elif 32 <= c < 127:
            out.append(chr(c))
        else:
            out.append("\\%d" % c)
    out.append('"')
    return "".join(out)


def fmt_number(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if v != v:
        return "(0/0)"
    if v == float("inf"):
        return "math.huge"
    if v == float("-inf"):
        return "-math.huge"
    if v.is_integer() and abs(v) < 2**63:
        return str(int(v))
    r = repr(v)
    return r


OP_PRI = {k: v[0] for k, v in BINPRI.items()}


class Printer:
    def __init__(self, indent="    "):
        self.ind = indent
        self.lines: List[str] = []

    def emit(self, depth, s):
        self.lines.append(self.ind * depth + s)

    def block(self, stmts, depth):
        for s in stmts:
            self.stat(s, depth)

    def stat(self, s, d):
        t = type(s)
        if t is Local:
            if s.values:
                self.emit(d, "local %s = %s" % (", ".join(s.names), self.exprlist(s.values, d)))
            else:
                self.emit(d, "local %s" % ", ".join(s.names))
        elif t is LocalFunction:
            self.funcstat("local function " + s.name, s.func, d)
        elif t is Assign:
            self.emit(d, "%s = %s" % (self.exprlist(s.targets, d), self.exprlist(s.values, d)))
        elif t is CompoundAssign:
            self.emit(d, "%s %s= %s" % (self.expr(s.target, d), s.op, self.expr(s.value, d)))
        elif t is CallStat:
            self.emit(d, self.expr(s.call, d))
        elif t is Do:
            self.emit(d, "do")
            self.block(s.body, d + 1)
            self.emit(d, "end")
        elif t is While:
            self.emit(d, "while %s do" % self.expr(s.cond, d))
            self.block(s.body, d + 1)
            self.emit(d, "end")
        elif t is Repeat:
            self.emit(d, "repeat")
            self.block(s.body, d + 1)
            self.emit(d, "until %s" % self.expr(s.cond, d))
        elif t is If:
            for i, (c, b) in enumerate(s.clauses):
                self.emit(d, "%s %s then" % ("if" if i == 0 else "elseif", self.expr(c, d)))
                self.block(b, d + 1)
            if s.orelse:
                self.emit(d, "else")
                self.block(s.orelse, d + 1)
            self.emit(d, "end")
        elif t is NumericFor:
            h = "for %s = %s, %s" % (s.var, self.expr(s.start, d), self.expr(s.stop, d))
            if s.step is not None:
                h += ", " + self.expr(s.step, d)
            self.emit(d, h + " do")
            self.block(s.body, d + 1)
            self.emit(d, "end")
        elif t is GenericFor:
            self.emit(d, "for %s in %s do" % (", ".join(s.names), self.exprlist(s.exprs, d)))
            self.block(s.body, d + 1)
            self.emit(d, "end")
        elif t is FunctionStat:
            name = self.funcname(s)
            f = s.func
            if s.is_method:
                f = Function(f.params[1:], f.is_vararg, f.body, f.name)
            self.funcstat("function " + name, f, d)
        elif t is Return:
            self.emit(d, ("return " + self.exprlist(s.values, d)) if s.values else "return")
        elif t is Break:
            self.emit(d, "break")
        elif t is Continue:
            self.emit(d, "continue")
        elif t is Comment:
            for ln in s.text.split("\n"):
                self.emit(d, "-- " + ln)
        elif t is Goto:
            self.emit(d, "goto %s" % s.label)
        elif t is Label:
            self.emit(d, "::%s::" % s.name)
        elif t is Block:
            self.block(s.body, d)
        else:
            raise TypeError("unknown stat %r" % s)

    def funcname(self, s):
        parts = []
        tgt = s.target
        if s.is_method:
            tgt = tgt.obj
        while isinstance(tgt, Index):
            parts.append(tgt.key.value.decode())
            tgt = tgt.obj
        parts.append(tgt.name)
        name = ".".join(reversed(parts))
        if s.is_method:
            name += ":" + s.method
        return name

    def params(self, f):
        p = list(f.params)
        if f.is_vararg:
            p.append("...")
        return ", ".join(p)

    def funcstat(self, head, f, d):
        self.emit(d, "%s(%s)" % (head, self.params(f)))
        self.block(f.body, d + 1)
        self.emit(d, "end")

    def exprlist(self, es, d):
        return ", ".join(self.expr(e, d) for e in es)

    def expr(self, e, d, pri=0):
        t = type(e)
        if t is Nil:
            return "nil"
        if t is TrueE:
            return "true"
        if t is FalseE:
            return "false"
        if t is Vararg:
            return "..."
        if t is Number:
            s = fmt_number(e.value)
            if s.startswith("-") and pri > 0:
                return "(" + s + ")"
            return s
        if t is String:
            return quote_bytes(e.value)
        if t is Name:
            return e.name
        if t is Index:
            o = self.prefix(e.obj, d)
            k = e.key
            if isinstance(k, String):
                try:
                    ks = k.value.decode("ascii")
                except UnicodeDecodeError:
                    ks = None
                if ks and _ident_re.match(ks) and ks not in KEYWORDS:
                    return "%s.%s" % (o, ks)
            return "%s[%s]" % (o, self.expr(k, d))
        if t is Call:
            return "%s(%s)" % (self.prefix(e.func, d), self.exprlist(e.args, d))
        if t is MethodCall:
            return "%s:%s(%s)" % (self.prefix(e.obj, d), e.name, self.exprlist(e.args, d))
        if t is Paren:
            return "(" + self.expr(e.expr, d) + ")"
        if t is Function:
            sub = Printer(self.ind)
            sub.block(e.body, d + 1)
            if not sub.lines:
                return "function(%s) end" % self.params(e)
            return "function(%s)\n%s\n%send" % (self.params(e), "\n".join(sub.lines), self.ind * d)
        if t is Table:
            if not e.items:
                return "{}"
            parts = []
            for kind, k, v in e.items:
                if kind == "pos":
                    parts.append(self.expr(v, d + 1))
                elif kind == "named" or (
                    isinstance(k, String) and _ident_re.match(k.value.decode("latin-1")) and k.value.decode("latin-1") not in KEYWORDS
                ):
                    parts.append("%s = %s" % (k.value.decode("latin-1"), self.expr(v, d + 1)))
                else:
                    parts.append("[%s] = %s" % (self.expr(k, d + 1), self.expr(v, d + 1)))
            one = "{" + ", ".join(parts) + "}"
            if len(one) <= 100 and "\n" not in one:
                return one
            inner = (",\n" + self.ind * (d + 1)).join(parts)
            return "{\n%s%s\n%s}" % (self.ind * (d + 1), inner, self.ind * d)
        if t is BinOp:
            lp, rp = BINPRI[e.op]
            s = "%s %s %s" % (self.expr(e.left, d, lp), e.op, self.expr(e.right, d, rp + (0 if lp != rp else 1)))
            if lp <= pri:
                return "(" + s + ")"
            return s
        if t is UnOp:
            inner = self.expr(e.operand, d, UNARY_PRI)
            if e.op == "not":
                s = "not " + inner
            elif e.op == "-" and inner.startswith("-"):
                s = "- " + inner
            else:
                s = e.op + inner
            if UNARY_PRI < pri:
                return "(" + s + ")"
            return s
        if t is IfExpr:
            s = "if %s then %s else %s" % (self.expr(e.cond, d), self.expr(e.then, d), self.expr(e.orelse, d))
            return "(" + s + ")" if pri > 0 else s
        if hasattr(e, "label"):
            return "<%s>" % e.label
        raise TypeError("unknown expr %r" % e)

    def prefix(self, e, d):
        if isinstance(e, (Name, Index, Call, MethodCall, Paren)):
            return self.expr(e, d)
        return "(" + self.expr(e, d) + ")"


def to_source(node, indent="    ") -> str:
    p = Printer(indent)
    if isinstance(node, Block):
        p.block(node.body, 0)
    elif isinstance(node, list):
        p.block(node, 0)
    elif isinstance(node, Node) and type(node).__name__ in (
        "Local", "LocalFunction", "Assign", "CompoundAssign", "CallStat", "Do", "While",
        "Repeat", "If", "NumericFor", "GenericFor", "FunctionStat", "Return", "Break",
        "Continue", "Comment", "Goto", "Label",
    ):
        p.stat(node, 0)
    else:
        return p.expr(node, 0)
    return "\n".join(p.lines) + "\n"


def walk(node):
    """Pre-order traversal over all nodes."""
    stack = list(reversed(node)) if isinstance(node, list) else [node]
    while stack:
        n = stack.pop()
        yield n
        if isinstance(n, Node):
            ch = list(_iter_children(n))
            stack.extend(reversed(ch))


def _iter_children(n):
    t = type(n)
    if t is Table:
        for _, k, v in n.items:
            if k is not None:
                yield k
            yield v
        return
    if t is If:
        for c, b in n.clauses:
            yield c
            yield from b
        if n.orelse:
            yield from n.orelse
        return
    for name in n.__slots__:
        v = getattr(n, name)
        if isinstance(v, Node):
            yield v
        elif isinstance(v, list):
            for x in v:
                if isinstance(x, Node):
                    yield x
