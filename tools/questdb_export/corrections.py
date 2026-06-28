"""
Parse Questie's correction files.

Each file defines a module `QuestieXxxFixes` with several methods:
    - `:Load()`             — returns the main override table
    - `:LoadFactionFixes()` — returns either `questFixesHorde` or
                              `questFixesAlliance` based on UnitFactionGroup
    - `:LoadMissingQuests()` — mutates QuestieDB.questData directly
                              (adds empty placeholder entries)

We need to extract the actual patch tables as Python dicts without executing
Lua. Strategy:

1. Locate the method body by scanning for `function <Module>:<Name>() ... end`
   with brace+keyword balancing.
2. Extract `local <name> = <value>` bindings from inside the function. The
   RHS is either an identifier chain (alias) or a table literal.
3. Extract the final `return <expr>` — or for faction-specific methods,
   extract the named local tables (`questFixesHorde`, `questFixesAlliance`).

All identifier references (`[questKeys.X]`, `sortKeys.WARLOCK`, etc.) resolve
through the env built by enums.build_env, augmented by the function-local
bindings.
"""

from __future__ import annotations
import re
from pathlib import Path

from lua_parser import parse_lua_table, tokenize, Parser, LuaParseError


_FUNC_RE = re.compile(
    r"^function\s+\w+\s*:\s*(\w+)\s*\(\s*(\w+)?\s*\)\s*$",
    re.MULTILINE,
)


def _find_function_body(source: str, method_name: str) -> str:
    """Return the body text of `function Module:<method_name>(...)` ... `end`,
    exclusive of the `function ...)` line and final `end`. Uses Lua keyword
    nesting (function/if/for/while/do...end) to balance matching `end`s."""
    # Find the declaring line
    for m in re.finditer(r"^function\s+\w+\s*:\s*(\w+)\s*\(([^)]*)\)\s*$",
                         source, flags=re.MULTILINE):
        if m.group(1) == method_name:
            start = m.end()
            # Walk from here balancing `end` keywords
            return _extract_until_matching_end(source, start)
    raise RuntimeError(f"function :{method_name}() not found")


def _extract_until_matching_end(source: str, start: int) -> str:
    """Scan forward from `start`, tracking Lua block-opening keywords (if,
    for, while, do, function) vs. block-closing `end`. Return the substring
    from `start` up to (but not including) the closing `end` at depth 0.

    Robust against:  strings, line comments, block comments, long-bracket
    strings. It counts keyword tokens only, not arbitrary `end` substrings
    inside identifiers.
    """
    toks = tokenize(source[start:])
    depth = 1  # we're inside the function
    # Token offsets are relative to start; we'll use them to slice the source.
    for idx, t in enumerate(toks):
        if t.kind == "kw":
            if t.value in ("function", "if", "for", "while", "do"):
                depth += 1
            elif t.value == "end":
                depth -= 1
                if depth == 0:
                    # `end` is at offset start + t.pos; return source up to there.
                    return source[start:start + t.pos]
    raise RuntimeError("no matching `end` found")


def _extract_local_bindings(body: str, outer_env: dict) -> dict:
    """Walk top-level `local <name> = <value>` at the start of the function
    body (before the first non-local statement). Returns dict mapping local
    names to resolved values. Supports RHS = identifier chain or table literal.
    Stops at the first line that isn't a `local ... = ...` assignment."""
    locals_env: dict = {}
    i = 0
    n = len(body)
    while i < n:
        # Skip whitespace / comments
        while i < n and body[i] in " \t\r\n":
            i += 1
        if i >= n: break
        if body[i:i + 2] == "--":
            # skip to end of line
            j = body.find("\n", i)
            i = j + 1 if j != -1 else n
            continue
        # Match `local NAME = ` ?
        m = re.match(r"local\s+(\w+)\s*=\s*", body[i:])
        if not m:
            break
        name = m.group(1)
        rhs_start = i + m.end()
        # Determine RHS kind
        # Skip whitespace (already handled by the \s* in the regex)
        c = body[rhs_start] if rhs_start < n else ""
        if c == "{":
            # Table literal — find matching }
            end = _find_matching_brace(body, rhs_start)
            table_src = body[rhs_start:end + 1]
            env = {**outer_env, **locals_env}
            value = parse_lua_table(table_src, env)
            locals_env[name] = value
            i = end + 1
        else:
            # Identifier chain or literal; parse as expression until newline/statement boundary
            # Try to parse greedily using the Lua parser and let it stop at EOL.
            # Simpler: scan for end-of-statement heuristic (newline or `;`).
            j = rhs_start
            while j < n and body[j] not in "\n;":
                j += 1
            expr_src = body[rhs_start:j].strip()
            # Strip trailing comment if any
            comment_at = expr_src.find("--")
            if comment_at != -1:
                expr_src = expr_src[:comment_at].strip()
            env = {**outer_env, **locals_env}
            value = parse_lua_table(expr_src, env)
            locals_env[name] = value
            i = j + 1
    return locals_env


def _find_matching_brace(source: str, start: int) -> int:
    """Return the index of the `}` matching the `{` at `start`. Respects
    strings and comments."""
    assert source[start] == "{"
    depth = 0
    i = start
    n = len(source)
    in_str = False
    str_q = ""
    in_long_str = False
    long_close = ""
    in_line_comment = False
    in_block_comment = False
    block_close = ""
    while i < n:
        c = source[i]
        if in_line_comment:
            if c == "\n": in_line_comment = False
            i += 1; continue
        if in_block_comment:
            if source.startswith(block_close, i):
                i += len(block_close); in_block_comment = False
                continue
            i += 1; continue
        if in_long_str:
            if source.startswith(long_close, i):
                i += len(long_close); in_long_str = False
                continue
            i += 1; continue
        if in_str:
            if c == "\\":
                i += 2; continue
            if c == str_q:
                in_str = False
            i += 1; continue
        # Comment?
        if c == "-" and source[i + 1:i + 2] == "-":
            if source[i + 2:i + 3] == "[":
                j = i + 3; eq = 0
                while j < n and source[j] == "=":
                    j += 1; eq += 1
                if j < n and source[j] == "[":
                    block_close = "]" + "=" * eq + "]"
                    in_block_comment = True
                    i = j + 1; continue
            in_line_comment = True
            i += 2; continue
        # Long string?
        if c == "[":
            j = i + 1; eq = 0
            while j < n and source[j] == "=":
                j += 1; eq += 1
            if j < n and source[j] == "[":
                long_close = "]" + "=" * eq + "]"
                in_long_str = True
                i = j + 1; continue
        # Quoted string?
        if c in "\"'":
            in_str = True; str_q = c
            i += 1; continue
        # Brace
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise RuntimeError("unbalanced brace")


def _extract_return_table(body: str, env: dict) -> dict | list:
    """Find the final `return <expr>` in the function body and parse the
    expression using env. The expr is usually a table literal or an identifier
    naming a previously-declared local."""
    # Find `return ` at the statement level (start of line). The last one is
    # the "main" return for single-path functions.
    matches = list(re.finditer(r"^\s*return\s+", body, flags=re.MULTILINE))
    if not matches:
        raise RuntimeError("no `return` statement found")
    m = matches[-1]
    rhs_start = m.end()
    c = body[rhs_start] if rhs_start < len(body) else ""
    if c == "{":
        end = _find_matching_brace(body, rhs_start)
        return parse_lua_table(body[rhs_start:end + 1], env)
    else:
        # Identifier chain
        # Grab the identifier(s) until end-of-line/statement
        j = rhs_start
        while j < len(body) and body[j] not in "\n;":
            j += 1
        expr = body[rhs_start:j].strip()
        comment_at = expr.find("--")
        if comment_at != -1:
            expr = expr[:comment_at].strip()
        return parse_lua_table(expr, env)


# ----------------------------------------------------- public entry points --

# `l10n("...")` is the only function call that appears in value positions in
# classic corrections; it wraps a localised string. For enUS-only exports we
# just take the quoted string as-is.
_L10N_CALL_RE = re.compile(
    r"l10n\s*\(\s*((?:\"(?:\\.|[^\"\\])*\")|(?:'(?:\\.|[^'\\])*'))\s*\)"
)


def _preprocess(src: str) -> str:
    """Apply text substitutions that the parser can't handle natively."""
    return _L10N_CALL_RE.sub(r"\1", src)


def load_simple(source_path: Path, method_name: str, env: dict) -> dict:
    """Parse a `function Module:<method_name>()` that ends in a single
    `return { ... }`, returning the Python dict of the table."""
    src = _preprocess(source_path.read_text(encoding="utf-8"))
    body = _find_function_body(src, method_name)
    locals_env = _extract_local_bindings(body, env)
    merged = {**env, **locals_env}
    table = _extract_return_table(body, merged)
    return table or {}


def load_faction_fixes(source_path: Path, env: dict) -> tuple[dict, dict]:
    """Parse `function Module:LoadFactionFixes()` — returns a tuple
    (alliance_dict, horde_dict). The function has two `local` table literals
    named like `<kind>FixesAlliance` and `<kind>FixesHorde`; we pick them out
    by suffix."""
    src = _preprocess(source_path.read_text(encoding="utf-8"))
    body = _find_function_body(src, "LoadFactionFixes")
    locals_env = _extract_local_bindings(body, env)
    alliance = {}
    horde = {}
    for name, value in locals_env.items():
        low = name.lower()
        if not isinstance(value, dict):
            continue
        if low.endswith("alliance"):
            alliance = value
        elif low.endswith("horde"):
            horde = value
    return alliance, horde


def load_missing_quests(source_path: Path) -> list[int]:
    """Parse `function QuestieQuestFixes:LoadMissingQuests()` which does
    `QuestieDB.questData[id] = {}` a bunch of times. Returns the list of IDs
    that should be added as empty placeholder rows before main Load() runs."""
    src = source_path.read_text(encoding="utf-8")
    body = _find_function_body(src, "LoadMissingQuests")
    ids = [int(m.group(1)) for m in re.finditer(
        r"QuestieDB\.questData\[(\d+)\]\s*=\s*\{\s*\}", body)]
    return ids


def load_classic_corrections(questie_root: Path, env: dict):
    """Run the classic-era correction pipeline and return a bundle of Python
    dicts ready to merge into the base DB. Also returns faction deltas kept
    separate so the runtime can apply the right one per player faction.
    """
    corr = questie_root / "Database" / "Corrections"

    quest_main = load_simple(corr / "classicQuestFixes.lua", "Load", env)
    npc_main   = load_simple(corr / "classicNPCFixes.lua",   "Load", env)
    obj_main   = load_simple(corr / "classicObjectFixes.lua","Load", env)
    item_main  = load_simple(corr / "classicItemFixes.lua",  "Load", env)

    rep_fixes  = load_simple(corr / "Automatic" / "classicQuestReputationFixes.lua",
                             "Load", env)

    missing_qs = load_missing_quests(corr / "classicQuestFixes.lua")

    quest_ally, quest_horde = load_faction_fixes(corr / "classicQuestFixes.lua", env)
    npc_ally,   npc_horde   = load_faction_fixes(corr / "classicNPCFixes.lua",   env)
    obj_ally,   obj_horde   = load_faction_fixes(corr / "classicObjectFixes.lua",env)
    item_ally,  item_horde  = load_faction_fixes(corr / "classicItemFixes.lua",  env)

    return {
        "quest_main":    quest_main,
        "quest_rep":     rep_fixes,
        "quest_missing": missing_qs,
        "npc_main":      npc_main,
        "obj_main":      obj_main,
        "item_main":     item_main,
        "quest_alliance": quest_ally,
        "quest_horde":    quest_horde,
        "npc_alliance":  npc_ally,
        "npc_horde":     npc_horde,
        "obj_alliance":  obj_ally,
        "obj_horde":     obj_horde,
        "item_alliance": item_ally,
        "item_horde":    item_horde,
    }


if __name__ == "__main__":
    import sys
    from enums import build_env
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent / ".." / "vendor" / "Questie"
    root = root.resolve()
    env = build_env(root)
    c = load_classic_corrections(root, env)
    print(f"quest_main: {len(c['quest_main'])} patches")
    print(f"  quest[5]: {c['quest_main'].get(5)}")
    print(f"  quest[7]: {c['quest_main'].get(7)}")
    print(f"quest_rep: {len(c['quest_rep'])} patches")
    print(f"quest_missing: {len(c['quest_missing'])} placeholder IDs, first 5: {c['quest_missing'][:5]}")
    print(f"npc_main: {len(c['npc_main'])} patches")
    print(f"  npc[300]: {c['npc_main'].get(300)}")
    print(f"obj_main: {len(c['obj_main'])} patches")
    print(f"item_main: {len(c['item_main'])} patches")
    print(f"quest_alliance: {len(c['quest_alliance'])} faction patches")
    print(f"quest_horde:    {len(c['quest_horde'])} faction patches")
