"""
Parse Questie blacklist files. Each file defines a module
`QuestieXxxBlacklist:Load()` returning `{ [id] = value, ... }` where:
    - `value == true`           → blacklist fully (we drop the row)
    - `value == "HIDE_ON_MAP"`  → keep the row but mark hidden (we keep it;
                                  hidden-on-map is a UI concern, not data)
    - `value == false / nil`    → not blacklisted (conditional expressions
                                  can evaluate to false for non-Era clients)

The AQ War Effort quests live in a separate top-level table
(`QuestieQuestBlacklist.AQWarEffortQuests`) which we also drop since those
NPCs only physically exist during the AQ pre-event — otherwise we'd spawn
ghost `!` pins on Stormwind/Orgrimmar war-effort recruiters etc.
"""

from __future__ import annotations
import re
from pathlib import Path

from corrections import load_simple, _preprocess
from lua_parser import parse_lua_table


def _load(path: Path, env: dict) -> set[int]:
    """Return the set of IDs that should be fully dropped from the DB.

    Values of `true` → drop. Everything else (`false`, `nil`, or a string like
    `"HIDE_ON_MAP"`) → keep in the data.
    """
    table = load_simple(path, "Load", env)
    return {int(k) for k, v in table.items() if v is True}


def _load_toplevel_table(path: Path, assignment_lhs: str, env: dict) -> set[int]:
    """Parse a `<assignment_lhs> = { ... }` at file scope and return the
    set of integer keys whose value is `true`. Used for the AQ War Effort
    blacklist which isn't wrapped in a :Load() method."""
    src = _preprocess(path.read_text(encoding="utf-8"))
    # Find the assignment; accept arbitrary whitespace around `=`.
    pattern = re.compile(r"^\s*" + re.escape(assignment_lhs) + r"\s*=\s*\{",
                         re.MULTILINE)
    match = pattern.search(src)
    if not match:
        return set()
    # Walk forward from the opening `{` and find the matching `}`.
    i = match.end() - 1  # position of `{`
    depth = 0
    n = len(src)
    start = i
    while i < n:
        ch = src[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                break
        i += 1
    if depth != 0:
        return set()
    literal = src[start:i + 1]
    table = parse_lua_table(literal, env)
    if not isinstance(table, dict):
        return set()
    return {int(k) for k, v in table.items() if v is True}


def load_all(questie_root: Path, env: dict) -> dict[str, set[int]]:
    corr = questie_root / "Database" / "Corrections"
    # The blacklist files reference a file-scope `local HIDE_ON_MAP =
    # "HIDE_ON_MAP"` which we pre-bind in the env. Same with some helper
    # calls (ContentPhases.*) that are only invoked inside Expansions-gated
    # `if` blocks we don't execute — since the base local table is assigned
    # before any conditional, our parser picks up the right value.
    bl_env = dict(env)
    bl_env["HIDE_ON_MAP"] = "HIDE_ON_MAP"
    # ContentPhases.* branches are unused on Classic Era (Anniversary phases
    # are ignored per plan); `Questie.IsSoD` / `Questie.IsSoM` / etc. are all
    # false. We still need them to evaluate; populate as needed.
    bl_env.setdefault("Questie", {}).update({
        "IsSoD": False, "IsSoM": False, "IsClassic": True,
        "IsTBC": False, "IsWotlk": False, "IsCata": False,
        "IsHardcore": False, "IsMoP": False,
    })
    quests = _load(corr / "QuestieQuestBlacklist.lua", bl_env)
    # Merge AQ War Effort quest list into the quest blacklist: the NPCs
    # that give these only exist during the (now-past / never-again) AQ
    # pre-event, so their starters would be false-positive `!` pins in
    # Stormwind / Orgrimmar recruiter hubs.
    aq = _load_toplevel_table(
        corr / "QuestieQuestBlacklist.lua",
        "QuestieQuestBlacklist.AQWarEffortQuests",
        bl_env,
    )
    quests |= aq
    return {
        "quests": quests,
        "npcs":   _load(corr / "QuestieNPCBlacklist.lua",   bl_env),
        "items":  _load(corr / "QuestieItemBlacklist.lua",  bl_env),
    }


if __name__ == "__main__":
    import sys
    from enums import build_env
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent / ".." / "vendor" / "Questie"
    root = root.resolve()
    env = build_env(root)
    bl = load_all(root, env)
    for name, ids in bl.items():
        print(f"{name:>7}: {len(ids)} blacklisted")
    print("quest 7462 blacklisted?", 7462 in bl["quests"])   # expect True (duplicate)
    print("quest 5 blacklisted?",    5 in bl["quests"])      # expect False
