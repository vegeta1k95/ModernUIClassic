"""
Extract the `QuestieDB.questData = [[return {...}]]` blocks from the classic
base DB files. Returns Python dicts keyed by entity ID; each value is a
positional list matching the corresponding *Keys field-index map.

`nil` values inside the positional list survive as lua_parser.LUA_NIL so that
slot numbering is preserved (e.g. `{nil, nil, {16305}}` in startedBy stays
positionally correct).
"""

from __future__ import annotations
import re
from pathlib import Path

from lua_parser import parse_return_table


# Each base file assigns its data to `QuestieDB.xxxData` as a long-bracket
# string. The generic extractor finds the `[[...]]` payload and returns the
# inner text (without the brackets).
_LONG_BRACKET_RE = re.compile(
    r"QuestieDB\.\w+Data\s*=\s*\[(=*)\[",
    re.MULTILINE,
)


def _extract_long_bracket_payload(source: str) -> str:
    m = _LONG_BRACKET_RE.search(source)
    if not m:
        raise RuntimeError("could not find `QuestieDB.xxxData = [[...]]` in source")
    eq = m.group(1)
    close = "]" + eq + "]"
    start = m.end()
    # Lua ignores a leading newline immediately after [[.
    if start < len(source) and source[start] == "\n":
        start += 1
    end = source.find(close, start)
    if end == -1:
        raise RuntimeError("unterminated long-bracket payload")
    return source[start:end]


def _parse_classic_db(source_path: Path) -> dict[int, list]:
    src = source_path.read_text(encoding="utf-8")
    payload = _extract_long_bracket_payload(src)
    table = parse_return_table(payload)
    # The payload evaluates to `{[id]=positional_list, ...}`. Lua-style
    # integer-keyed tables come out of the parser as Python dicts (because
    # the first entry is `[2]=...` which is a keyed entry).
    if not isinstance(table, dict):
        raise RuntimeError(f"{source_path.name}: expected a keyed table, got {type(table).__name__}")
    # Normalise: ensure keys are ints (they are already, but assert).
    out: dict[int, list] = {}
    for k, v in table.items():
        if not isinstance(k, int):
            raise RuntimeError(f"{source_path.name}: non-int entity ID {k!r}")
        if not isinstance(v, list):
            raise RuntimeError(f"{source_path.name}: entity {k}: expected positional list, got {type(v).__name__}")
        out[k] = v
    return out


def load_all(questie_root: Path) -> dict[str, dict[int, list]]:
    classic = questie_root / "Database" / "Classic"
    return {
        "quests":  _parse_classic_db(classic / "classicQuestDB.lua"),
        "npcs":    _parse_classic_db(classic / "classicNpcDB.lua"),
        "objects": _parse_classic_db(classic / "classicObjectDB.lua"),
        "items":   _parse_classic_db(classic / "classicItemDB.lua"),
    }


if __name__ == "__main__":
    import sys
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent / ".." / "vendor" / "Questie"
    data = load_all(root.resolve())
    for name, d in data.items():
        print(f"{name:>8}: {len(d)} rows")
    # Spot check a few
    q = data["quests"]
    print(f"quest[2] (Sharptalon's Claw): {q[2][0]!r}")
    print(f"quest[7] (Kobold Camp Cleanup): {q[7][0]!r}, requiredLevel={q[7][3]}, questLevel={q[7][4]}")
    n = data["npcs"]
    for nid in sorted(n.keys())[:3]:
        print(f"npc[{nid}]: {n[nid][0]!r}")
