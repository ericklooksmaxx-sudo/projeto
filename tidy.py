"""Readability pass for reconstructed Lua/Luau.

The dumper already emits one statement per line, but partial/invalid output
cannot always be parsed by darklua. This lexer-based formatter keeps every
token intact, fixes spacing and indentation, converts simple ["field"] accesses
to .field, and adds a few structural blank lines. It never executes or parses
the script, so it also works on recovered partial dumps.
"""

from __future__ import annotations

import re
from typing import List, Optional, Tuple

Token = Tuple[str, str]

KEYWORDS = {
    "and", "break", "continue", "do", "else", "elseif", "end", "export",
    "false", "for", "function", "if", "in", "local", "nil", "not", "or",
    "repeat", "return", "then", "true", "type", "until", "while",
}

# Longest first so "..=" wins over ".." and ".".
MULTI_OPS = (
    "...", "..=", "//=", "<<=", ">>=", "==", "~=", "<=", ">=", "::", "->",
    "+=", "-=", "*=", "/=", "%=", "^=", "//", "..", "<<", ">>", "&&", "||",
)
SINGLE_OPS = set("+-*/%^#=<>~&|?:.,;(){}[]")

OPENING = {"(", "[", "{"}
CLOSING = {")", "]", "}"}
TIGHT_BEFORE = {")", "]", "}", ",", ";", ":", ".", "::"}
TIGHT_AFTER = {"(", "[", "{", ".", ":", "::"}
BINARY_OPS = {
    "+", "-", "*", "/", "//", "%", "^", "..", "==", "~=", "<", ">", "<=",
    ">=", "=", "+=", "-=", "*=", "/=", "//=", "%=", "^=", "..=", "&", "|",
    "<<", ">>", "->", "&&", "||",
}
ATOM_KINDS = {"ident", "number", "string"}
UNARY_PREFIX = {
    None, "(", "[", "{", ",", ";", "=", "return", "then", "do", "else",
    "elseif", "in", "and", "or", "not", "+", "-", "*", "/", "//", "%", "^",
    "..", "==", "~=", "<", ">", "<=", ">=", "&", "|", "<<", ">>", "->",
}
MAX_INDENT_LEVELS = 10
# Formatting is optional polish: skip very large or minified outputs so a dump
# is never delayed by a quadratic layout pass.
MAX_FORMAT_BYTES = 1500 * 1024
MAX_FORMAT_LINE_LENGTH = 20000
MAX_LOOKAHEAD_TOKENS = 64


class _Scanner:
    def __init__(self, source: str):
        self.src = source
        self.n = len(source)
        self.i = 0

    def _long_bracket(self, pos: int) -> Optional[Tuple[int, str]]:
        if pos >= self.n or self.src[pos] != "[":
            return None
        j = pos + 1
        while j < self.n and self.src[j] == "=":
            j += 1
        if j >= self.n or self.src[j] != "[":
            return None
        closing = "]" + ("=" * (j - pos - 1)) + "]"
        end = self.src.find(closing, j + 1)
        if end == -1:
            return self.n, None
        return end + len(closing), closing

    def tokens(self) -> List[Token]:
        out: List[Token] = []
        src, n = self.src, self.n
        while self.i < n:
            c = src[self.i]

            if c in " \t\f\v":
                self.i += 1
                continue
            if c == "\r" or c == "\n":
                if c == "\r" and self.i + 1 < n and src[self.i + 1] == "\n":
                    self.i += 1
                out.append(("newline", "\n"))
                self.i += 1
                continue

            if src.startswith("--", self.i):
                start = self.i
                self.i += 2
                long = self._long_bracket(self.i)
                if long:
                    end, _ = long
                    self.i = end
                else:
                    while self.i < n and src[self.i] not in "\r\n":
                        self.i += 1
                out.append(("comment", src[start:self.i]))
                continue

            if c == "[":
                long = self._long_bracket(self.i)
                if long:
                    end, _ = long
                    out.append(("string", src[self.i:end]))
                    self.i = end
                    continue

            if c in "\"'`":
                start = self.i
                quote = c
                self.i += 1
                while self.i < n:
                    ch = src[self.i]
                    if ch == "\\":
                        self.i += 2
                        continue
                    if ch == quote:
                        self.i += 1
                        break
                    if ch in "\r\n" and quote != "`":
                        break
                    self.i += 1
                out.append(("string", src[start:min(self.i, n)]))
                continue

            if c.isdigit() or (c == "." and self.i + 1 < n and src[self.i + 1].isdigit()):
                start = self.i
                if c == "0" and self.i + 1 < n and src[self.i + 1] in "xXbB":
                    self.i += 2
                    while self.i < n and (src[self.i].isalnum() or src[self.i] == "_"):
                        self.i += 1
                else:
                    if c == ".":
                        self.i += 1
                    while self.i < n and (src[self.i].isdigit() or src[self.i] == "_"):
                        self.i += 1
                    # A single decimal point, but never the start of "..".
                    if (
                        self.i < n
                        and src[self.i] == "."
                        and not src.startswith("..", self.i)
                    ):
                        self.i += 1
                        while self.i < n and (src[self.i].isdigit() or src[self.i] == "_"):
                            self.i += 1
                    if self.i < n and src[self.i] in "eE":
                        self.i += 1
                        if self.i < n and src[self.i] in "+-":
                            self.i += 1
                        while self.i < n and (src[self.i].isdigit() or src[self.i] == "_"):
                            self.i += 1
                out.append(("number", src[start:self.i]))
                continue

            if c.isalpha() or c == "_":
                start = self.i
                while self.i < n and (src[self.i].isalnum() or src[self.i] == "_"):
                    self.i += 1
                word = src[start:self.i]
                out.append(("keyword" if word in KEYWORDS else "ident", word))
                continue

            matched = False
            for op in MULTI_OPS:
                if src.startswith(op, self.i):
                    out.append(("op", op))
                    self.i += len(op)
                    matched = True
                    break
            if matched:
                continue

            out.append(("punct", c))
            self.i += 1

        return out


def _string_key(token: Token) -> Optional[str]:
    if token[0] != "string":
        return None
    raw = token[1]
    if len(raw) < 2 or raw[0] not in "\"'":
        return None
    inner = raw[1:-1]
    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", inner) and inner not in KEYWORDS:
        return inner
    return None


def _field_access(tokens: List[Token]) -> List[Token]:
    """Turn x["field"] into x.field and ["field"] = v into field = v."""
    out: List[Token] = []
    brace_depth = 0
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok == ("punct", "{"):
            brace_depth += 1
        elif tok == ("punct", "}"):
            brace_depth = max(0, brace_depth - 1)

        if (
            tok == ("punct", "[")
            and i + 2 < len(tokens)
            and tokens[i + 2] == ("punct", "]")
        ):
            key = _string_key(tokens[i + 1])
            if key:
                prev = next(
                    (t for t in reversed(out[-MAX_LOOKAHEAD_TOKENS:])
                     if t[0] not in {"comment", "newline"}),
                    None,
                )
                nxt = None
                for candidate in tokens[i + 3:i + 3 + MAX_LOOKAHEAD_TOKENS]:
                    if candidate[0] not in {"comment", "newline"}:
                        nxt = candidate
                        break
                if (
                    nxt is not None
                    and nxt[1] == "="
                    and brace_depth > 0
                    and prev is not None
                    and prev[1] in {"{", ",", ";"}
                ):
                    out.append(("ident", key))
                else:
                    out.append(("op", "."))
                    out.append(("ident", key))
                i += 3
                continue
        out.append(tok)
        i += 1
    return out


def _rename_call_variables(tokens: List[Token]) -> List[Token]:
    """Give generated _callN locals a meaningful method-based name.

    The dumper names every recovered call site _callN. Renaming _call12 to
    _MakeWindow12 is purely alpha-renaming: the numeric suffix keeps it unique
    and every occurrence is replaced together. Anything ambiguous is skipped.
    """
    def_count: dict = {}
    for i, tok in enumerate(tokens):
        if tok == ("keyword", "local") and i + 2 < len(tokens):
            name = tokens[i + 1][1]
            if tokens[i + 1][0] == "ident" and re.fullmatch(r"_call\d+", name):
                def_count[name] = def_count.get(name, 0) + 1

    used = {tok[1] for tok in tokens if tok[0] in {"ident", "keyword"}}
    mapping: dict = {}
    i = 0
    while i < len(tokens):
        if tokens[i] == ("keyword", "local") and i + 3 < len(tokens):
            name = tokens[i + 1][1]
            if (
                tokens[i + 1][0] == "ident"
                and re.fullmatch(r"_call\d+", name)
                and def_count.get(name) == 1
                and tokens[i + 2][1] == "="
            ):
                method = None
                k = i + 3
                line: List[Token] = []
                while k < len(tokens) and tokens[k][0] != "newline":
                    line.append(tokens[k])
                    k += 1
                for pos in range(len(line) - 2):
                    if (
                        line[pos][1] in {":", "."}
                        and line[pos + 1][0] == "ident"
                        and line[pos + 2][1] == "("
                    ):
                        method = line[pos + 1][1]
                if method and method != "call":
                    suffix = name[len("_call"):]
                    target = f"_{method}{suffix}"
                    if target not in used and target != name:
                        mapping[name] = target
                        used.add(target)
        i += 1

    if not mapping:
        return tokens
    return [
        ("ident", mapping[tok[1]]) if tok[0] == "ident" and tok[1] in mapping else tok
        for tok in tokens
    ]


def _is_atom_end(tok: Optional[Token]) -> bool:
    if tok is None:
        return False
    kind, value = tok
    return kind in ATOM_KINDS or kind == "keyword" and value in {"true", "false", "nil"} or value in CLOSING or value == "..."


def _is_atom_start(tok: Token) -> bool:
    kind, value = tok
    return kind in ATOM_KINDS or kind == "keyword" and value in {"true", "false", "nil", "function", "not"} or value == "..." or value == "#"


def _unary_operator(tokens: List[Token], idx: int) -> bool:
    value = tokens[idx][1]
    if value in {"not", "#"}:
        return True
    if value not in {"-", "+", "~"}:
        return False
    prev = tokens[idx - 1][1] if idx > 0 else None
    return prev in UNARY_PREFIX


def _space_before(tokens: List[Token], idx: int) -> bool:
    prev = tokens[idx - 1]
    cur = tokens[idx]
    pv, cv = prev[1], cur[1]

    if cur[0] == "comment":
        return True
    if cv in TIGHT_BEFORE or pv in TIGHT_AFTER:
        return False
    if pv in {",", ";"}:
        return True
    if pv in OPENING:
        return False
    if cv in CLOSING:
        return False
    if cv in {"(", "["}:
        if cv == "(" and pv in {"function", "type"}:
            return False
        return not _is_atom_end(prev)
    if cv == "{":
        return pv not in {"(", "[", "{"}
    if pv == "}":
        if cv in {"(", "[", ".", ":", ")", "]", "}", ",", ";"}:
            return False
        return True

    if cv in BINARY_OPS:
        if cv in {"-", "+", "~"} and _unary_operator(tokens, idx):
            return pv not in {"(", "[", "{", ",", ";", ".", ":"}
        return True
    if pv in BINARY_OPS:
        if pv in {"-", "+", "~"} and _unary_operator(tokens, idx - 1):
            return False
        return True
    if pv == "not":
        return True
    if cv == "not" or cv == "#":
        return True
    if pv == "#":
        return False
    if pv == "...":
        return False
    if cv == "...":
        return _is_atom_end(prev) or prev[0] == "keyword"

    if prev[0] == "keyword" or cur[0] == "keyword":
        return True
    return _is_atom_end(prev) and _is_atom_start(cur)


def _format_line(tokens: List[Token], indent: int) -> str:
    if not tokens:
        return ""
    if any("\n" in t[1] for t in tokens):
        # Keep long comments/strings exactly as written.
        return (" " * min(indent, MAX_INDENT_LEVELS) * 4) + "".join(
            ((" " if i > 0 and _space_before(tokens, i) else "") + t[1])
            for i, t in enumerate(tokens)
        )

    parts: List[str] = []
    for i, tok in enumerate(tokens):
        if i > 0 and _space_before(tokens, i):
            parts.append(" ")
        parts.append(tok[1])
    return (" " * (min(indent, MAX_INDENT_LEVELS) * 4)) + "".join(parts)


def _split_lines(tokens: List[Token]) -> List[List[Token]]:
    lines: List[List[Token]] = []
    current: List[Token] = []
    for tok in tokens:
        if tok[0] == "newline":
            lines.append(current)
            current = []
        else:
            current.append(tok)
    if current:
        lines.append(current)
    return lines


def format_lua(source: str) -> str:
    if not source or len(source) > MAX_FORMAT_BYTES:
        return source
    if max((len(line) for line in source.splitlines()), default=0) > MAX_FORMAT_LINE_LENGTH:
        return source
    tokens = _field_access(_Scanner(source).tokens())
    tokens = _rename_call_variables(tokens)
    lines = _split_lines(tokens)

    rendered: List[str] = []
    indent = 0
    previous_indent = -1
    previous_text = ""
    bracket_stack: List[Tuple[str, bool]] = []

    for line in lines:
        if not line:
            if rendered and rendered[-1] != "":
                rendered.append("")
            previous_indent = -1
            previous_text = ""
            continue

        # Simulate the leading closers to find the indentation of this line.
        # A "(" directly followed by "{" shares the table's indentation level,
        # so the matching ")" must not pop a second level.
        simulated = list(bracket_stack)
        leading = 0
        for tok in line:
            if tok[0] == "comment":
                break
            value = tok[1]
            if value in {"end", "until", "else", "elseif"}:
                leading += 1
            elif value in CLOSING:
                if simulated and simulated[-1][0] == value:
                    _, shared = simulated.pop()
                    if value == "}" or not shared:
                        leading += 1
                else:
                    leading += 1
            else:
                break

        line_indent = max(0, indent - leading)
        text = _format_line(line, line_indent)

        delta = 0
        for pos, tok in enumerate(line):
            value = tok[1]
            if value in {"function", "then", "do", "repeat"}:
                delta += 1
            elif value == "elseif":
                delta -= 1
            elif value in {"end", "until"}:
                delta -= 1
            elif value in OPENING:
                shared = False
                if value == "(":
                    nxt = next((t[1] for t in line[pos + 1:] if t[0] != "comment"), None)
                    shared = nxt == "{"
                bracket_stack.append((")" if value == "(" else "]" if value == "[" else "}", shared))
                if not shared:
                    delta += 1
            elif value in CLOSING:
                if bracket_stack and bracket_stack[-1][0] == value:
                    _, shared = bracket_stack.pop()
                    if value == "}" or not shared:
                        delta -= 1
                else:
                    delta -= 1
        indent = max(0, indent + delta)

        stripped = text.strip()
        if (
            rendered
            and rendered[-1] != ""
            and line_indent == 0
            and (
                stripped.startswith("function ")
                or stripped.startswith("local function ")
                or stripped.startswith("--")
                or (
                    previous_indent == 0
                    and previous_text.strip() in {"end", "until"}
                    and not stripped.startswith(("end", "until"))
                )
            )
        ):
            rendered.append("")

        rendered.append(text)
        previous_indent = line_indent
        previous_text = text

    cleaned: List[str] = []
    for i, line in enumerate(rendered):
        if line == "":
            if cleaned and cleaned[-1] == "":
                continue
            nxt = rendered[i + 1].lstrip() if i + 1 < len(rendered) else ""
            if nxt.startswith(("end", "else", "elseif", "until", "}", ")", "]")):
                continue
        cleaned.append(line)
    while cleaned and cleaned[-1] == "":
        cleaned.pop()
    return "\n".join(cleaned) + ("\n" if cleaned else "")


if __name__ == "__main__":
    import sys

    if len(sys.argv) != 3:
        raise SystemExit("usage: python3 tidy.py <input> <output>")
    with open(sys.argv[1], "r", encoding="utf-8", errors="replace") as f:
        data = f.read()
    with open(sys.argv[2], "w", encoding="utf-8", newline="\n") as f:
        f.write(format_lua(data))
