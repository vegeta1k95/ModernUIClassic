"""
Extract Questie enum tables as a flat evaluation env for the Lua parser.

Output: one dict where the keys are dotted paths like "questKeys.name",
"zoneIDs.DUSKWOOD", etc. Each maps to the integer (or similar) the identifier
resolves to. The parser's identifier-chain resolution then walks these paths.
"""

from __future__ import annotations
import re
from pathlib import Path

from lua_parser import parse_lua_table


# Hardcoded per Modules/Expansions.lua (expansionOrderLookup maps WOW_PROJECT_ID
# to 1..5; on Classic Era WOW_PROJECT_CLASSIC=2 which looks up to 1).
EXPANSIONS = {
    "Era":     1,
    "Classic": 1,  # alias some code uses
    "Tbc":     2,
    "Wotlk":   3,
    "Cata":    4,
    "MoP":     5,
    "Current": 1,  # We're targeting Classic Era; Current == Era
}

# raceKeys / classKeys / specialFlags contain IIFE branches dependent on the
# running client's expansion flag. Hardcode the Classic Era resolution rather
# than teach the parser Lua function-call semantics.
#
# ALL_ALLIANCE / ALL_HORDE / ALL_CLASSES all take the Classic-Era branch.
# ALL_CLASSES depends on the player's faction — corrections that use it are
# already faction-duplicated (separate rows per faction) so we pick the
# Alliance value; the Horde variant is unused in classic fixes.
RACE_KEYS = {
    "ALL_ALLIANCE": 77,
    "ALL_HORDE":    178,
    "NONE":         0,
    "HUMAN":        1,
    "ORC":          2,
    "DWARF":        4,
    "NIGHT_ELF":    8,
    "UNDEAD":       16,
    "TAUREN":       32,
    "GNOME":        64,
    "TROLL":        128,
    "GOBLIN":       256,
    "BLOOD_ELF":    512,
    "DRAENEI":      1024,
    "WORGEN":       2097152,
    "PANDAREN":     8388608,
    "PANDAREN_ALLIANCE": 16777216,
    "PANDAREN_HORDE":    33554432,
}

CLASS_KEYS = {
    "ALL_CLASSES":  1439,  # alliance side on Classic; horde 1501. See comment above.
    "NONE":         0,
    "WARRIOR":      1,
    "PALADIN":      2,
    "HUNTER":       4,
    "ROGUE":        8,
    "PRIEST":       16,
    "DEATH_KNIGHT": 32,
    "SHAMAN":       64,
    "MAGE":         128,
    "WARLOCK":      256,
    "MONK":         512,
    "DRUID":        1024,
}

SPECIAL_FLAGS = {
    "NONE":       0,
    "REPEATABLE": 1,
}


def _extract_table_after(source: str, lhs_pattern: str) -> str:
    """Find `<lhs> = { ... }` and return the body including the braces.

    `lhs_pattern` is a regex matching the left-hand side of the assignment.
    We then balance braces to find the matching `}`.
    """
    m = re.search(lhs_pattern + r"\s*=\s*\{", source)
    if not m:
        raise RuntimeError(f"enum definition not found for pattern {lhs_pattern!r}")
    start = m.end() - 1  # points at the opening `{`
    depth = 0
    i = start
    in_str = False
    str_q = ""
    in_long_str = False
    long_close = ""
    in_line_comment = False
    in_block_comment = False
    block_close = ""
    while i < len(source):
        c = source[i]
        # state: line comment
        if in_line_comment:
            if c == "\n":
                in_line_comment = False
            i += 1; continue
        # state: block comment
        if in_block_comment:
            if source.startswith(block_close, i):
                i += len(block_close); in_block_comment = False
                continue
            i += 1; continue
        # state: long string
        if in_long_str:
            if source.startswith(long_close, i):
                i += len(long_close); in_long_str = False
                continue
            i += 1; continue
        # state: quoted string
        if in_str:
            if c == "\\":
                i += 2; continue
            if c == str_q:
                in_str = False
            i += 1; continue
        # not-in-any-state:
        # comment start?
        if c == "-" and source[i + 1:i + 2] == "-":
            if source[i + 2:i + 3] == "[":
                # Possibly long-bracket comment
                j = i + 3; eq = 0
                while j < len(source) and source[j] == "=":
                    j += 1; eq += 1
                if j < len(source) and source[j] == "[":
                    block_close = "]" + "=" * eq + "]"
                    in_block_comment = True
                    i = j + 1; continue
            in_line_comment = True
            i += 2; continue
        # long string start?
        if c == "[":
            j = i + 1; eq = 0
            while j < len(source) and source[j] == "=":
                j += 1; eq += 1
            if j < len(source) and source[j] == "[":
                long_close = "]" + "=" * eq + "]"
                in_long_str = True
                i = j + 1; continue
        # quoted string?
        if c in ("\"", "'"):
            in_str = True; str_q = c
            i += 1; continue
        # braces
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return source[start:i + 1]
        i += 1
    raise RuntimeError(f"unbalanced braces after match of {lhs_pattern!r}")


def _parse_table_assignment(source: str, lhs_pattern: str, env: dict | None = None) -> dict:
    body = _extract_table_after(source, lhs_pattern)
    return parse_lua_table(body, env or {})


def _icon_types(questie_lua: str) -> dict:
    """Questie.ICON_TYPE_X = N assignments — scan line by line."""
    out: dict = {}
    for m in re.finditer(r"^Questie\.(ICON_TYPE_\w+)\s*=\s*(\d+)\s*$",
                         questie_lua, flags=re.MULTILINE):
        out[m.group(1)] = int(m.group(2))
    if not out:
        raise RuntimeError("no ICON_TYPE_* constants found in Questie.lua")
    return out


def build_env(questie_root: Path) -> dict:
    db = questie_root / "Database"

    q_src = (db / "Classic" / "classicQuestDB.lua").read_text(encoding="utf-8")
    n_src = (db / "Classic" / "classicNpcDB.lua").read_text(encoding="utf-8")
    o_src = (db / "Classic" / "classicObjectDB.lua").read_text(encoding="utf-8")
    i_src = (db / "Classic" / "classicItemDB.lua").read_text(encoding="utf-8")
    zone_src = (db / "Zones" / "data" / "zoneIds.lua").read_text(encoding="utf-8")
    qdb_src = (db / "QuestieDB.lua").read_text(encoding="utf-8")
    questdb_src = (db / "questDB.lua").read_text(encoding="utf-8")
    const_src = (db / "Constants.lua").read_text(encoding="utf-8")
    prof_src = (questie_root / "Modules" / "QuestieProfessions.lua").read_text(encoding="utf-8")
    phase_src = (questie_root / "Modules" / "Phasing.lua").read_text(encoding="utf-8")
    qmain_src = (questie_root / "Questie.lua").read_text(encoding="utf-8")

    question_keys = _parse_table_assignment(q_src, r"QuestieDB\.questKeys")
    npc_keys      = _parse_table_assignment(n_src, r"QuestieDB\.npcKeys")
    object_keys   = _parse_table_assignment(o_src, r"QuestieDB\.objectKeys")
    item_keys     = _parse_table_assignment(i_src, r"QuestieDB\.itemKeys")
    zone_ids      = _parse_table_assignment(zone_src, r"ZoneDB\.zoneIDs")
    # raceKeys/classKeys/specialFlags are hardcoded — see module-top comments.
    race_keys     = dict(RACE_KEYS)
    class_keys    = dict(CLASS_KEYS)
    special_flags = dict(SPECIAL_FLAGS)
    faction_ids   = _parse_table_assignment(questdb_src, r"QuestieDB\.factionIDs")
    sort_keys     = _parse_table_assignment(const_src, r"QuestieDB\.sortKeys")
    prof_keys     = _parse_table_assignment(prof_src, r"QuestieProfessions\.professionKeys")

    # specializationKeys cross-references professionKeys, so evaluate under a
    # mini-env that exposes it.
    spec_env = {"QuestieProfessions": {"professionKeys": prof_keys}}
    spec_keys = _parse_table_assignment(prof_src, r"QuestieProfessions\.specializationKeys",
                                        env=spec_env)
    # Phasing.phases is bound as `local phases = { ... }` then re-exported as
    # `Phasing.phases = phases` — parse the local-literal form.
    phases = _parse_table_assignment(phase_src, r"local\s+phases")

    icon_types = _icon_types(qmain_src)

    env: dict = {
        # Key maps used by corrections  (e.g. `[questKeys.preQuestSingle]`)
        "questKeys":  question_keys,
        "npcKeys":    npc_keys,
        "objectKeys": object_keys,
        "itemKeys":   item_keys,
        "zoneIDs":    zone_ids,
        "raceIDs":    race_keys,   # corrections use `raceIDs` as local alias
        "raceKeys":   race_keys,
        "classIDs":   class_keys,
        "classKeys":  class_keys,
        "factionIDs": faction_ids,
        "sortKeys":   sort_keys,
        "specialFlags": special_flags,
        "profKeys":   prof_keys,
        "specKeys":   spec_keys,

        # Nested shorthand so `QuestieDB.questKeys` and `ZoneDB.zoneIDs` resolve.
        "QuestieDB": {
            "questKeys":  question_keys,
            "npcKeys":    npc_keys,
            "objectKeys": object_keys,
            "itemKeys":   item_keys,
            "raceKeys":   race_keys,
            "classKeys":  class_keys,
            "factionIDs": faction_ids,
            "sortKeys":   sort_keys,
            "specialFlags": special_flags,
        },
        "ZoneDB": {"zoneIDs": zone_ids},
        "QuestieProfessions": {"professionKeys": prof_keys,
                               "specializationKeys": spec_keys},
        "Phasing": {"phases": phases},

        # Icon constants — referenced as `Questie.ICON_TYPE_EVENT` in corrections.
        "Questie": dict(icon_types),

        # Expansions enum for blacklists.
        "Expansions": dict(EXPANSIONS),
    }
    return env


if __name__ == "__main__":
    # Quick sanity: print a few resolved values when invoked directly.
    import sys
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent / ".." / "vendor" / "Questie"
    env = build_env(root.resolve())
    print("questKeys.name =", env["questKeys"]["name"])
    print("questKeys.breadcrumbs =", env["questKeys"]["breadcrumbs"])
    print("zoneIDs.DUSKWOOD =", env["zoneIDs"]["DUSKWOOD"])
    print("Questie.ICON_TYPE_EVENT =", env["Questie"]["ICON_TYPE_EVENT"])
    print("Expansions.Era =", env["Expansions"]["Era"])
    print("raceKeys keys:", list(env["raceKeys"].keys())[:5])
    print("specKeys.ALCHEMY_POTION =", env["specKeys"]["ALCHEMY_POTION"])
