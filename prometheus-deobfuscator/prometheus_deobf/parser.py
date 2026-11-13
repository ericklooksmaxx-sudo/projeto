"""Lua 5.1 lexer + recursive-descent parser with lexical scope resolution."""

from .luaast import (Symbol, Nil, Bool, Number, String, Vararg, Name, Index, Call, Method, Func, TItem, Table,
                     Bin, Un, Paren, Local, Assign, CallStat, Do, While, Repeat, If, NumFor, GenFor, LocalFunc,
                     FuncStat, Return, Break, Chunk)

KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not",
    "or", "repeat", "return", "then", "true", "until", "while",
}


class LuaSyntaxError(Exception):
    pass


def _parse_number(text):
    t = text.lower()
    if t.startswith("0x"):
        if "." in t or "p" in t:
            return float.fromhex(t)
        return float(int(t, 16))
    if t.startswith("0b"):
        return float(int(t[2:], 2))
    return float(t)


def tokenize(src):
    toks = []
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c in " \t\r\f\v":
            i += 1
            continue
        if src.startswith("--", i):
            j = i + 2
            if j < n and src[j] == "[":
                k = j + 1
                while k < n and src[k] == "=":
                    k += 1
                if k < n and src[k] == "[":
                    close = "]" + "=" * (k - j - 1) + "]"
                    e = src.find(close, k + 1)
                    if e < 0:
                        raise LuaSyntaxError("unfinished long comment at line %d" % line)
                    line += src.count("\n", i, e)
                    i = e + len(close)
                    continue
            e = src.find("\n", i)
            i = n if e < 0 else e
            continue
        if c.isalpha() or c == "_":
            j = i + 1
            while j < n and (src[j].isalnum() or src[j] == "_"):
                j += 1
            w = src[i:j]
            toks.append(("kw" if w in KEYWORDS else "name", w, line))
            i = j
            continue
        if c.isdigit() or (c == "." and i + 1 < n and src[i + 1].isdigit()):
            j = i
            if src.startswith(("0x", "0X"), i):
                j += 2
                while j < n and (src[j] in "0123456789abcdefABCDEF._" or (src[j] in "pP") or
                                 (src[j] in "+-" and src[j - 1] in "pP")):
                    j += 1
            elif src.startswith(("0b", "0B"), i):
                j += 2
                while j < n and src[j] in "01_":
                    j += 1
            else:
                while j < n and (src[j].isdigit() or src[j] in "._eE" or (src[j] in "+-" and src[j - 1] in "eE")):
                    j += 1
            toks.append(("num", _parse_number(src[i:j].replace("_", "")), line))
            i = j
            continue
        if c in "\"'":
            j = i + 1
            buf = []
            while True:
                if j >= n:
                    raise LuaSyntaxError("unfinished string at line %d" % line)
                d = src[j]
                if d == c:
                    j += 1
                    break
                if d == "\n":
                    raise LuaSyntaxError("unfinished string at line %d" % line)
                if d == "\\":
                    j += 1
                    e = src[j]
                    simple = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v",
                              "\\": "\\", "\"": "\"", "'": "'", "\n": "\n"}
                    if e in simple:
                        buf.append(simple[e])
                        if e == "\n":
                            line += 1
                        j += 1
                    elif e.isdigit():
                        k = j
                        while k < n and k < j + 3 and src[k].isdigit():
                            k += 1
                        buf.append(chr(int(src[j:k]) & 255))
                        j = k
                    elif e == "x":
                        buf.append(chr(int(src[j + 1:j + 3], 16)))
                        j += 3
                    elif e == "z":
                        j += 1
                        while j < n and src[j] in " \t\r\n\f\v":
                            if src[j] == "\n":
                                line += 1
                            j += 1
                    else:
                        buf.append(e)
                        j += 1
                else:
                    buf.append(d)
                    j += 1
            toks.append(("str", "".join(buf), line))
            i = j
            continue
        if c == "[":
            k = i + 1
            while k < n and src[k] == "=":
                k += 1
            if k < n and src[k] == "[":
                close = "]" + "=" * (k - i - 1) + "]"
                e = src.find(close, k + 1)
                if e < 0:
                    raise LuaSyntaxError("unfinished long string at line %d" % line)
                s = src[k + 1:e]
                if s.startswith("\r\n"):
                    s = s[2:]
                elif s.startswith("\n"):
                    s = s[1:]
                toks.append(("str", s, line))
                line += src.count("\n", i, e)
                i = e + len(close)
                continue
        for op in ("...", "..", "==", "~=", "<=", ">=", "//", "+=", "-=", "*=", "/=", "%=", "^=", "::"):
            if src.startswith(op, i):
                toks.append(("op", op, line))
                i += len(op)
                break
        else:
            if c in "+-*/%^#<>=(){}[];:,.!":
                toks.append(("op", c, line))
                i += 1
            else:
                raise LuaSyntaxError("unexpected character %r at line %d" % (c, line))
    toks.append(("eof", None, line))
    return toks


BINPRI = {
    "or": (1, 1), "and": (2, 2),
    "<": (3, 3), ">": (3, 3), "<=": (3, 3), ">=": (3, 3), "~=": (3, 3), "==": (3, 3),
    "..": (5, 4),  # right assoc
    "+": (6, 6), "-": (6, 6),
    "*": (7, 7), "/": (7, 7), "%": (7, 7),
    "^": (10, 9),  # right assoc
}
UNARY_PRI = 8


class Parser(object):
    def __init__(self, src):
        self.toks = tokenize(src)
        self.p = 0
        self.scopes = [{}]
        self.loop_depth = 0

    # -- token helpers
    def peek(self, k=0):
        return self.toks[self.p + k]

    def next(self):
        t = self.toks[self.p]
        self.p += 1
        return t

    def check(self, kind, val=None):
        t = self.toks[self.p]
        return t[0] == kind and (val is None or t[1] == val)

    def accept(self, kind, val=None):
        if self.check(kind, val):
            return self.next()
        return None

    def expect(self, kind, val=None):
        t = self.toks[self.p]
        if t[0] != kind or (val is not None and t[1] != val):
            raise LuaSyntaxError("line %d: expected %s but got %r" % (t[2], val or kind, t[1]))
        self.p += 1
        return t

    # -- scopes
    def push(self):
        self.scopes.append({})

    def pop(self):
        self.scopes.pop()

    def declare(self, name):
        s = Symbol(name)
        self.scopes[-1][name] = s
        return s

    def resolve(self, name):
        for sc in reversed(self.scopes):
            if name in sc:
                return Name(name, sc[name])
        return Name(name, None)

    # -- grammar
    def parse_chunk(self):
        body = self.block()
        self.expect("eof")
        return Chunk(body)

    def block_end(self):
        t = self.peek()
        return t[0] == "eof" or (t[0] == "kw" and t[1] in ("end", "else", "elseif", "until"))

    def block(self):
        stats = []
        while not self.block_end():
            if self.check("kw", "return"):
                self.next()
                exprs = []
                if not self.block_end() and not self.check("op", ";"):
                    exprs = self.exprlist()
                self.accept("op", ";")
                stats.append(Return(exprs))
                break
            if self.check("kw", "break"):
                self.next()
                self.accept("op", ";")
                stats.append(Break())
                continue
            st = self.statement()
            if st is not None:
                stats.append(st)
        return stats

    def scoped_block(self):
        self.push()
        b = self.block()
        self.pop()
        return b

    def statement(self):
        t = self.peek()
        if t[0] == "op" and t[1] == ";":
            self.next()
            return None
        if t[0] == "kw":
            k = t[1]
            if k == "if":
                self.next()
                return self.if_rest()
            if k == "while":
                self.next()
                cond = self.expr()
                self.expect("kw", "do")
                body = self.scoped_block()
                self.expect("kw", "end")
                return While(cond, body)
            if k == "do":
                self.next()
                body = self.scoped_block()
                self.expect("kw", "end")
                return Do(body)
            if k == "for":
                self.next()
                n1 = self.expect("name")[1]
                if self.accept("op", "="):
                    start = self.expr()
                    self.expect("op", ",")
                    stop = self.expr()
                    step = None
                    if self.accept("op", ","):
                        step = self.expr()
                    self.expect("kw", "do")
                    self.push()
                    sym = self.declare(n1)
                    body = self.block()
                    self.pop()
                    self.expect("kw", "end")
                    return NumFor(sym, start, stop, step, body)
                names = [n1]
                while self.accept("op", ","):
                    names.append(self.expect("name")[1])
                self.expect("kw", "in")
                exprs = self.exprlist()
                self.expect("kw", "do")
                self.push()
                syms = [self.declare(n) for n in names]
                body = self.block()
                self.pop()
                self.expect("kw", "end")
                return GenFor(syms, exprs, body)
            if k == "repeat":
                self.next()
                self.push()
                body = self.block()
                self.expect("kw", "until")
                cond = self.expr()
                self.pop()
                return Repeat(body, cond)
            if k == "function":
                self.next()
                n = self.expect("name")[1]
                target = self.resolve(n)
                method = False
                while self.check("op", ".") or self.check("op", ":"):
                    sep = self.next()[1]
                    key = self.expect("name")[1]
                    target = Index(target, String(key))
                    if sep == ":":
                        method = True
                        break
                f = self.funcbody(method)
                return FuncStat(target, f, method)
            if k == "local":
                self.next()
                if self.accept("kw", "function"):
                    n = self.expect("name")[1]
                    sym = self.declare(n)
                    f = self.funcbody(False)
                    return LocalFunc(sym, f)
                names = [self.expect("name")[1]]
                while self.accept("op", ","):
                    names.append(self.expect("name")[1])
                exprs = []
                if self.accept("op", "="):
                    exprs = self.exprlist()
                syms = [self.declare(n) for n in names]
                return Local(syms, exprs)
        # expression statement
        e = self.suffixedexp()
        if self.check("op", "=") or self.check("op", ","):
            targets = [e]
            while self.accept("op", ","):
                targets.append(self.suffixedexp())
            self.expect("op", "=")
            exprs = self.exprlist()
            for tg in targets:
                if not isinstance(tg, (Name, Index)):
                    raise LuaSyntaxError("line %d: cannot assign" % t[2])
            return Assign(targets, exprs)
        for cop in ("+=", "-=", "*=", "/=", "%=", "^="):
            if self.accept("op", cop):
                rhs = self.expr()
                return Assign([e], [Bin(cop[0], e.copy(), rhs)])
        if not isinstance(e, (Call, Method)):
            raise LuaSyntaxError("line %d: syntax error near %r" % (t[2], self.peek()[1]))
        return CallStat(e)

    def if_rest(self):
        cond = self.expr()
        self.expect("kw", "then")
        body = self.scoped_block()
        if self.accept("kw", "elseif"):
            return If(cond, body, [self.if_rest()])
        orelse = []
        if self.accept("kw", "else"):
            orelse = self.scoped_block()
        self.expect("kw", "end")
        return If(cond, body, orelse)

    def funcbody(self, method):
        self.expect("op", "(")
        self.push()
        params = []
        if method:
            params.append(self.declare("self"))
        vararg = False
        if not self.check("op", ")"):
            while True:
                if self.accept("op", "..."):
                    vararg = True
                    break
                params.append(self.declare(self.expect("name")[1]))
                if not self.accept("op", ","):
                    break
        self.expect("op", ")")
        body = self.block()
        self.pop()
        self.expect("kw", "end")
        return Func(params, vararg, body)

    def exprlist(self):
        l = [self.expr()]
        while self.accept("op", ","):
            l.append(self.expr())
        return l

    def primaryexp(self):
        t = self.peek()
        if t[0] == "name":
            self.next()
            return self.resolve(t[1])
        if self.accept("op", "("):
            e = self.expr()
            self.expect("op", ")")
            return Paren(e)
        raise LuaSyntaxError("line %d: unexpected symbol %r" % (t[2], t[1]))

    def suffixedexp(self):
        e = self.primaryexp()
        while True:
            t = self.peek()
            if t[0] == "op":
                if t[1] == ".":
                    self.next()
                    e = Index(e, String(self.expect("name")[1]))
                    e.line = t[2]
                    continue
                if t[1] == "[":
                    self.next()
                    k = self.expr()
                    self.expect("op", "]")
                    e = Index(e, k)
                    e.line = t[2]
                    continue
                if t[1] == ":":
                    self.next()
                    name = self.expect("name")[1]
                    e = Method(e, name, self.callargs())
                    e.line = t[2]
                    continue
                if t[1] in ("(", "{"):
                    e = Call(e, self.callargs())
                    e.line = t[2]
                    continue
            if t[0] == "str":
                e = Call(e, self.callargs())
                e.line = t[2]
                continue
            return e

    def callargs(self):
        t = self.peek()
        if t[0] == "str":
            self.next()
            return [String(t[1])]
        if t[0] == "op" and t[1] == "{":
            return [self.table()]
        self.expect("op", "(")
        if self.accept("op", ")"):
            return []
        a = self.exprlist()
        self.expect("op", ")")
        return a

    def table(self):
        self.expect("op", "{")
        items = []
        while not self.check("op", "}"):
            if self.check("op", "["):
                self.next()
                k = self.expr()
                self.expect("op", "]")
                self.expect("op", "=")
                items.append(TItem(k, self.expr()))
            elif self.check("name") and self.peek(1)[0] == "op" and self.peek(1)[1] == "=":
                k = self.next()[1]
                self.next()
                items.append(TItem(String(k), self.expr()))
            else:
                items.append(TItem(None, self.expr()))
            if not (self.accept("op", ",") or self.accept("op", ";")):
                break
        self.expect("op", "}")
        return Table(items)

    def simpleexp(self):
        t = self.peek()
        if t[0] == "num":
            self.next()
            return Number(t[1])
        if t[0] == "str":
            self.next()
            return String(t[1])
        if t[0] == "kw":
            if t[1] == "nil":
                self.next()
                return Nil()
            if t[1] == "true":
                self.next()
                return Bool(True)
            if t[1] == "false":
                self.next()
                return Bool(False)
            if t[1] == "function":
                self.next()
                return self.funcbody(False)
        if t[0] == "op":
            if t[1] == "...":
                self.next()
                return Vararg()
            if t[1] == "{":
                return self.table()
        return self.suffixedexp()

    def expr(self, limit=0):
        t = self.peek()
        if (t[0] == "kw" and t[1] == "not") or (t[0] == "op" and t[1] in ("-", "#", "!")):
            self.next()
            op = "not" if t[1] in ("not", "!") else t[1]
            e = Un(op, self.expr(UNARY_PRI))
            e.line = t[2]
        else:
            e = self.simpleexp()
        while True:
            t = self.peek()
            op = t[1] if t[0] in ("op", "kw") else None
            if op not in BINPRI or BINPRI[op][0] <= limit:
                return e
            self.next()
            r = self.expr(BINPRI[op][1])
            e = Bin(op, e, r)
            e.line = t[2]


def parse(src):
    return Parser(src).parse_chunk()
