"""
Parse Questie's quest XP DB: QuestXP/DB/xpDB-classic.lua

Entries: QuestXP.db = { [questId] = {level, xp}, ... } — plain Lua table,
not wrapped in [[...]].
"""

from __future__ import annotations
from pathlib import Path

from enums import _parse_table_assignment


def load(questie_root: Path) -> dict[int, tuple[int, int]]:
    src = (questie_root / "Database" / "QuestXP" / "DB" /
           "xpDB-classic.lua").read_text(encoding="utf-8")
    table = _parse_table_assignment(src, r"QuestXP\.db")
    out: dict[int, tuple[int, int]] = {}
    for qid, pair in table.items():
        if isinstance(pair, list) and len(pair) == 2:
            out[int(qid)] = (int(pair[0]), int(pair[1]))
    return out


if __name__ == "__main__":
    import sys
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent / ".." / "vendor" / "Questie"
    xp = load(root.resolve())
    print(f"quest XP rows: {len(xp)}")
    print(f"quest 2 XP = {xp.get(2)}")      # expect (30, 2450)
    print(f"quest 7 XP = {xp.get(7)}")      # expect (2, 170)
