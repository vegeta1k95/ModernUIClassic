"""
Lua table-literal + expression parser for the Questie-data subset.

Supports what Questie's DB / corrections / blacklist files actually use:
    - Table literals: { val, val, [key]=val, name=val, ... }, trailing separators
    - String literals: "...", '...', [[...]], [=[...]=]
    - Numbers: int, float, hex, negative
    - Booleans (true/false), nil
    - Identifier chains: foo.bar.baz (resolved through an environment)
    - Comparisons: ==, ~=, <, <=, >, >=
    - Logical: and, or, not
    - Parenthesized expressions
    - Comments: --line, --[[block]], --[=[block]=]

Does NOT support (because Questie data doesn't use it):
    - Function calls  (e.g. `someFunc()` in a value position)
    - Arithmetic expressions
    - Full Lua statements, loops, conditionals

Usage:
    env = {"questKeys": {"name": 1, "startedBy": 2, ...},
           "Expansions": {"Era": 1, "Tbc": 2, ...},
           "Expansions.Current": 1}
    table = parse_lua_table(source_text, env)
"""

from __future__ import annotations
from dataclasses import dataclass
from typing import Any


class LuaParseError(Exception):
    pass


# ---------------------------------------------------------------- tokenizer --

@dataclass
class Token:
    kind: str   # 'num', 'str', 'ident', 'kw', 'punct', 'op', 'eof'
    value: Any
    pos: int    # byte offset for error messages


_KEYWORDS = {"true", "false", "nil", "and", "or", "not", "return",
             "function", "local", "end", "if", "then", "else", "elseif"}


def tokenize(source: str) -> list[Token]:
    i, n = 0, len(source)
    toks: list[Token] = []

    def error(msg: str, p: int) -> None:
        line = source.count("\n", 0, p) + 1
        raise LuaParseError(f"line {line} (offset {p}): {msg}")

    while i < n:
        c = source[i]
        # Whitespace
        if c in " \t\r\n":
            i += 1; continue

        # Comments
        if c == "-" and i + 1 < n and source[i + 1] == "-":
            i += 2
            # Long comment?  --[==[...]==]
            if i < n and source[i] == "[":
                j = i + 1
                eq = 0
                while j < n and source[j] == "=":
                    j += 1; eq += 1
                if j < n and source[j] == "[":
                    close = "]" + "=" * eq + "]"
                    end = source.find(close, j + 1)
                    if end == -1: error("unterminated long comment", i)
                    i = end + len(close)
                    continue
            # Line comment
            while i < n and source[i] != "\n":
                i += 1
            continue

        # Long-bracket string  [==[...]==]
        if c == "[" and (i + 1 < n and source[i + 1] in "[="):
            j = i + 1
            eq = 0
            while j < n and source[j] == "=":
                j += 1; eq += 1
            if j < n and source[j] == "[":
                close = "]" + "=" * eq + "]"
                start = j + 1
                # Lua swallows a leading newline immediately inside long brackets
                if start < n and source[start] == "\n":
                    start += 1
                end = source.find(close, start)
                if end == -1: error("unterminated long string", i)
                toks.append(Token("str", source[start:end], i))
                i = end + len(close)
                continue

        # Quoted string
        if c in "\"'":
            quote = c
            j = i + 1
            out = []
            while j < n:
                ch = source[j]
                if ch == "\\":
                    if j + 1 >= n: error("bad escape at end of file", j)
                    nxt = source[j + 1]
                    out.append({"n": "\n", "t": "\t", "r": "\r",
                                "\\": "\\", "'": "'", '"': '"',
                                "a": "\a", "b": "\b", "f": "\f", "v": "\v",
                                "0": "\0"}.get(nxt, nxt))
                    j += 2
                elif ch == quote:
                    toks.append(Token("str", "".join(out), i))
                    i = j + 1
                    break
                else:
                    out.append(ch); j += 1
            else:
                error("unterminated string", i)
            continue

        # Number (including leading minus handled elsewhere — here only unsigned)
        if c.isdigit() or (c == "." and i + 1 < n and source[i + 1].isdigit()):
            j = i
            is_hex = False
            if c == "0" and i + 1 < n and source[i + 1] in "xX":
                is_hex = True
                j += 2
                while j < n and (source[j].isdigit() or source[j] in "abcdefABCDEF"):
                    j += 1
            else:
                seen_dot = False; seen_e = False
                while j < n:
                    ch = source[j]
                    if ch.isdigit():
                        j += 1
                    elif ch == "." and not seen_dot and not seen_e:
                        seen_dot = True; j += 1
                    elif ch in "eE" and not seen_e:
                        seen_e = True; j += 1
                        if j < n and source[j] in "+-":
                            j += 1
                    else:
                        break
            text = source[i:j]
            value = int(text, 16) if is_hex else (float(text) if "." in text or "e" in text or "E" in text else int(text))
            toks.append(Token("num", value, i))
            i = j
            continue

        # Identifier / keyword
        if c.isalpha() or c == "_":
            j = i + 1
            while j < n and (source[j].isalnum() or source[j] == "_"):
                j += 1
            text = source[i:j]
            if text in _KEYWORDS:
                toks.append(Token("kw", text, i))
            else:
                toks.append(Token("ident", text, i))
            i = j
            continue

        # Multi-char operators
        if i + 1 < n:
            two = source[i:i + 2]
            if two in ("==", "~=", "<=", ">=", "::"):
                toks.append(Token("op", two, i))
                i += 2
                continue

        # Single-char operators / punctuation
        if c in "{}[](),;=.<>:+-*/%#":
            # `.` is an operator (field access / number separator).
            toks.append(Token("op" if c in "=<>+-*/%#." else "punct", c, i))
            i += 1
            continue

        error(f"unexpected character {c!r}", i)

    toks.append(Token("eof", None, n))
    return toks


# --------------------------------------------------------------- AST helpers --

class _Sentinel:
    """Marker for Lua `nil` so we can distinguish it from Python None when
    we want to embed nil placeholders in a positional list (e.g. {nil,nil,{x}})."""
    __slots__ = ()
    def __repr__(self) -> str: return "LUA_NIL"


LUA_NIL = _Sentinel()


# ------------------------------------------------------------------- parser --

class Parser:
    def __init__(self, tokens: list[Token], env: dict[str, Any] | None = None,
                 source: str = ""):
        self.toks = tokens
        self.i = 0
        self.env = env or {}
        self.source = source

    # ---- token helpers

    def _peek(self, off: int = 0) -> Token:
        return self.toks[self.i + off]

    def _eat(self, kind: str, value: Any = None) -> Token:
        t = self._peek()
        if t.kind != kind or (value is not None and t.value != value):
            self._err(f"expected {kind} {value!r}, got {t.kind} {t.value!r}")
        self.i += 1
        return t

    def _match(self, kind: str, value: Any = None) -> bool:
        t = self._peek()
        if t.kind == kind and (value is None or t.value == value):
            self.i += 1
            return True
        return False

    def _err(self, msg: str) -> None:
        t = self._peek()
        line = self.source.count("\n", 0, t.pos) + 1 if self.source else "?"
        raise LuaParseError(f"line {line} (tok {t.kind} {t.value!r}): {msg}")

    # ---- expression parsing (precedence: or < and < comparison < unary < primary)

    def parse_expression(self) -> Any:
        return self._parse_or()

    def _parse_or(self) -> Any:
        left = self._parse_and()
        while self._peek().kind == "kw" and self._peek().value == "or":
            self.i += 1
            right = self._parse_and()
            left = (left if left not in (False, None, LUA_NIL) else right)
        return left

    def _parse_and(self) -> Any:
        left = self._parse_cmp()
        while self._peek().kind == "kw" and self._peek().value == "and":
            self.i += 1
            right = self._parse_cmp()
            left = (right if left not in (False, None, LUA_NIL) else left)
        return left

    def _parse_cmp(self) -> Any:
        left = self._parse_additive()
        while self._peek().kind == "op" and self._peek().value in ("==", "~=", "<", "<=", ">", ">="):
            op = self._peek().value
            self.i += 1
            right = self._parse_additive()
            lv = None if left is LUA_NIL else left
            rv = None if right is LUA_NIL else right
            if op == "==": left = lv == rv
            elif op == "~=": left = lv != rv
            elif op == "<":  left = lv < rv
            elif op == "<=": left = lv <= rv
            elif op == ">":  left = lv > rv
            elif op == ">=": left = lv >= rv
        return left

    def _parse_additive(self) -> Any:
        # `+` and `-` — Questie corrections use these to OR-combine class /
        # race bitmasks (e.g. `classIDs.WARRIOR + classIDs.PALADIN`).
        left = self._parse_unary()
        while self._peek().kind == "op" and self._peek().value in ("+", "-"):
            op = self._peek().value
            self.i += 1
            right = self._parse_unary()
            if op == "+": left = left + right
            else:         left = left - right
        return left

    def _parse_unary(self) -> Any:
        if self._peek().kind == "kw" and self._peek().value == "not":
            self.i += 1
            v = self._parse_unary()
            return v in (False, None, LUA_NIL)
        # Unary minus for negative numbers
        if self._peek().kind == "op" and self._peek().value == "-":
            self.i += 1
            v = self._parse_unary()
            return -v
        return self._parse_primary()

    def _parse_primary(self) -> Any:
        t = self._peek()
        # Literals
        if t.kind == "num" or t.kind == "str":
            self.i += 1
            return t.value
        if t.kind == "kw" and t.value == "true":
            self.i += 1; return True
        if t.kind == "kw" and t.value == "false":
            self.i += 1; return False
        if t.kind == "kw" and t.value == "nil":
            self.i += 1; return LUA_NIL
        # Parenthesized
        if t.kind == "punct" and t.value == "(":
            self.i += 1
            v = self.parse_expression()
            self._eat("punct", ")")
            return v
        # Table literal
        if t.kind == "punct" and t.value == "{":
            return self.parse_table()
        # Identifier chain
        if t.kind == "ident":
            return self._parse_identifier_chain()
        self._err(f"unexpected token {t.kind} {t.value!r} at primary")

    def _parse_identifier_chain(self) -> Any:
        name = self._eat("ident").value
        parts = [name]
        while self._peek().kind == "op" and self._peek().value == ".":
            self.i += 1
            parts.append(self._eat("ident").value)
        # Resolve through env
        key_full = ".".join(parts)
        if key_full in self.env:
            return self.env[key_full]
        # Try stepping through nested tables
        cur = self.env.get(parts[0])
        if cur is None:
            self._err(f"unknown identifier: {key_full}")
        for part in parts[1:]:
            # Lua semantics: indexing a nil or a missing key returns nil silently,
            # not an error. This allows corrections to reference e.g. sortKeys
            # entries Questie never defined (treated as nil at runtime).
            if cur is None or cur is LUA_NIL:
                return LUA_NIL
            if not isinstance(cur, dict):
                self._err(f"cannot index {type(cur).__name__} in {key_full}")
            if part not in cur:
                return LUA_NIL
            cur = cur[part]
        return cur

    # ---- table parsing

    def parse_table(self) -> dict | list:
        self._eat("punct", "{")
        entries: list[tuple[Any | None, Any]] = []   # (key_or_None_for_array, value)
        while True:
            # Trailing / empty
            if self._peek().kind == "punct" and self._peek().value == "}":
                break
            # `[expr] = val`
            if self._peek().kind == "punct" and self._peek().value == "[":
                self.i += 1
                key = self.parse_expression()
                self._eat("punct", "]")
                self._eat("op", "=")
                val = self.parse_expression()
                entries.append((key, val))
            # `name = val`  (bare identifier followed by =)
            elif self._peek().kind == "ident" and self._peek(1).kind == "op" and self._peek(1).value == "=":
                key = self._eat("ident").value
                self._eat("op", "=")
                val = self.parse_expression()
                entries.append((key, val))
            # array-style value
            else:
                val = self.parse_expression()
                entries.append((None, val))
            # Separator
            if self._peek().kind == "punct" and self._peek().value in (",", ";"):
                self.i += 1
                continue
            break
        self._eat("punct", "}")
        return _to_python_table(entries)


def _to_python_table(entries: list[tuple[Any | None, Any]]) -> Any:
    """Turn a list of (key, value) entries into a Python dict or list.

    Lua tables with only sequential integer keys starting at 1 become Python
    lists (1-based → 0-based). Tables with any non-integer-sequential key
    become Python dicts keyed by the Lua key. `nil` values in array slots are
    preserved as the LUA_NIL sentinel so positional meaning is retained.
    """
    # Fast path: all entries have None key (array style) — becomes a list.
    array_only = all(k is None for k, _ in entries)
    if array_only:
        return [v for _, v in entries]
    # Mixed or keyed: become a dict.
    d: dict[Any, Any] = {}
    array_idx = 1
    for k, v in entries:
        if k is None:
            d[array_idx] = v
            array_idx += 1
        else:
            d[k] = v
    return d


# ----------------------------------------------------------- entry points --

def parse_lua_table(source: str, env: dict[str, Any] | None = None) -> Any:
    """Parse a single Lua value (usually a table literal) from source. `env`
    is a mapping of top-level identifiers to Python values for chain resolution."""
    toks = tokenize(source)
    p = Parser(toks, env=env, source=source)
    v = p.parse_expression()
    if p._peek().kind != "eof":
        p._err("trailing input after expression")
    return v


def parse_return_table(source: str, env: dict[str, Any] | None = None) -> Any:
    """Parse a Lua fragment starting with `return <value>`. Used for the
    `[[return {...}]]` payload inside Questie DB files."""
    toks = tokenize(source)
    p = Parser(toks, env=env, source=source)
    p._eat("kw", "return")
    v = p.parse_expression()
    if p._peek().kind != "eof":
        p._err("trailing input after return value")
    return v
