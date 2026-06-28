"""
MUI_DB exporter — offline, repeatable port of Questie's Classic Era
database into ModernUI's own format. Each generated file is a singleton
class declaration (`object "Name" { ... }`) that bundles the accessors
and the data table together — there is no separate "data global".

Usage:
    python export.py                         # use vendored Questie, default out
    python export.py --questie PATH --out PATH
    python export.py --check-keys            # only verify key stability

Writes:
    <out>/MUI_QuestDB.lua
    <out>/MUI_NpcDB.lua
    <out>/MUI_ObjectDB.lua
    <out>/MUI_ItemDB.lua
    <out>/MUI_ZoneDB.lua
    <out>/MUI_QuestXPDB.lua
    <out>/MUI_QuestClustersDB.lua
"""

from __future__ import annotations
import argparse
import re
import sys
import time
from pathlib import Path

# Local imports (we live alongside these modules).
sys.path.insert(0, str(Path(__file__).parent))

from enums import build_env
from base_db import load_all as load_base
from corrections import load_classic_corrections
from blacklists import load_all as load_blacklists
from zones import load_all as load_zones
from quest_xp import load as load_quest_xp
from emit import (
    apply_corrections, add_missing, drop_blacklisted,
    apply_faction_autopatch, positional_to_named,
    build_objective_reverse_index, mark_repeatable_turn_ins,
    serialize_singleton,
)

# The expected field-index map. Frozen at the pinned Questie version. If a new
# Questie release shuffles these positions, --check-keys fails and the port
# needs human review before proceeding.
EXPECTED_QUEST_KEYS = {
    "name": 1, "startedBy": 2, "finishedBy": 3, "requiredLevel": 4,
    "questLevel": 5, "requiredRaces": 6, "requiredClasses": 7,
    "objectivesText": 8, "triggerEnd": 9, "objectives": 10,
    "sourceItemId": 11, "preQuestGroup": 12, "preQuestSingle": 13,
    "childQuests": 14, "inGroupWith": 15, "exclusiveTo": 16,
    "zoneOrSort": 17, "requiredSkill": 18, "requiredMinRep": 19,
    "requiredMaxRep": 20, "requiredSourceItems": 21, "nextQuestInChain": 22,
    "questFlags": 23, "specialFlags": 24, "parentQuest": 25,
    "reputationReward": 26, "breadcrumbForQuestId": 27, "breadcrumbs": 28,
    "extraObjectives": 29, "requiredSpell": 30, "requiredSpecialization": 31,
    "requiredMaxLevel": 32, "availableUntilCompleted": 33,
    "availableStartingWith": 34, "requiredRanks": 35,
}

EXPECTED_NPC_KEYS = {
    "name": 1, "minLevelHealth": 2, "maxLevelHealth": 3, "minLevel": 4,
    "maxLevel": 5, "rank": 6, "spawns": 7, "waypoints": 8, "zoneID": 9,
    "questStarts": 10, "questEnds": 11, "factionID": 12,
    "friendlyToFaction": 13, "subName": 14, "npcFlags": 15,
}

EXPECTED_OBJECT_KEYS = {
    "name": 1, "questStarts": 2, "questEnds": 3, "spawns": 4, "zoneID": 5,
    "factionID": 6, "waypoints": 7,
}

EXPECTED_ITEM_KEYS = {
    "name": 1, "npcDrops": 2, "objectDrops": 3, "itemDrops": 4,
    "startQuest": 5, "questRewards": 6, "flags": 7, "foodType": 8,
    "itemLevel": 9, "requiredLevel": 10, "ammoType": 11, "class": 12,
    "subClass": 13, "vendors": 14, "relatedQuests": 15,
}


def _check_keys(env: dict) -> list[str]:
    """Compare extracted key tables against our expected positions. Return
    list of divergence messages; empty list = all good."""
    problems: list[str] = []
    for name, expected in [
        ("questKeys",  EXPECTED_QUEST_KEYS),
        ("npcKeys",    EXPECTED_NPC_KEYS),
        ("objectKeys", EXPECTED_OBJECT_KEYS),
        ("itemKeys",   EXPECTED_ITEM_KEYS),
    ]:
        got = env[name]
        for k, v in expected.items():
            if got.get(k) != v:
                problems.append(f"{name}.{k}: expected {v}, got {got.get(k)!r}")
        # Any new keys?  Flag but don't fail (we just ignore them on export).
        extra = sorted(set(got.keys()) - set(expected.keys()))
        if extra:
            problems.append(f"{name}: new keys not in expected set: {extra}")
    return problems


HEADER = (
    "-- {filename}  (AUTO-GENERATED — do not edit)\n"
    "-- Derived from Questie v{ver} (GPLv3). See ModernUI/ATTRIBUTION.md.\n"
    "-- Regenerate via: python tools/questdb_export/export.py"
)


# ---- Method-body templates -------------------------------------------------
# Each generated singleton has its accessors inlined into the emitted file.
# Indentation matches what the body sits under inside `object "X" { ... }`.

_STD_DB_METHODS = """\
    Get = function(self, id)
        return self._data and self._data[id]
    end;

    GetAll = function(self)
        return self._data
    end;

    Count = function(self)
        if not self._data then return 0 end
        local c = 0
        for _ in pairs(self._data) do c = c + 1 end
        return c
    end;"""

_QUEST_METHODS = """\
    Get = function(self, id)
        return self._data and self._data[id]
    end;

    GetAll = function(self)
        return self._data
    end;

    LocalizeQuestName = function(self, id)
        local q = self._data and self._data[id]
        if not q then return nil end
        if self._localeNames then
            local override = self._localeNames[id]
            if override then return override end
        end
        return q.name
    end;

    Count = function(self)
        if not self._data then return 0 end
        local c = 0
        for _ in pairs(self._data) do c = c + 1 end
        return c
    end;"""

_ZONE_METHODS = """\
    GetByName = function(self, name)
        return self._data.byName and self._data.byName[name]
    end;

    GetUiMapForArea = function(self, areaId)
        return self._data.areaToUi and self._data.areaToUi[areaId]
    end;

    GetAreaForUiMap = function(self, uiMapId)
        return self._data.uiToArea and self._data.uiToArea[uiMapId]
    end;

    GetParent = function(self, subAreaId)
        return self._data.subToPar and self._data.subToPar[subAreaId]
    end;"""


def main() -> int:
    ap = argparse.ArgumentParser(description="Export Questie's Classic Era DB into ModernUI's format.")
    here = Path(__file__).parent.resolve()
    ap.add_argument("--questie", type=Path,
                    default=(here / ".." / "vendor" / "Questie").resolve(),
                    help="Path to a Questie checkout.")
    ap.add_argument("--out", type=Path,
                    default=(here / ".." / ".." / "MUI_DB").resolve(),
                    help="Output directory for the generated Lua files.")
    ap.add_argument("--check-keys", action="store_true",
                    help="Verify field-index stability against pinned layout and exit.")
    args = ap.parse_args()

    print(f"Questie source: {args.questie}")
    print(f"Output dir:     {args.out}")

    t0 = time.time()
    env = build_env(args.questie)

    # ---- Key-stability check (always runs; --check-keys exits here) ---------
    probs = _check_keys(env)
    if probs:
        print("\n!!! FIELD-INDEX DIVERGENCE DETECTED !!!")
        for p in probs:
            print("   ", p)
        if args.check_keys:
            return 1
        # If non-extra divergences, abort; extras are warnings.
        hard = [p for p in probs if ": new keys" not in p]
        if hard:
            print("\nRefusing to emit: fix EXPECTED_*_KEYS in export.py first.")
            return 1
    else:
        print("Field-index check: OK")
        if args.check_keys:
            return 0

    # ---- Pinned version --------------------------------------------------------
    toc = (args.questie / "Questie-Classic.toc").read_text(encoding="utf-8")
    m = re.search(r"^## Version:\s*(\S+)", toc, flags=re.MULTILINE)
    ver = m.group(1) if m else "unknown"
    print(f"Questie version: v{ver}")

    # ---- Parse every input ---------------------------------------------------
    print("Loading base DBs...")
    base = load_base(args.questie)
    print(f"  quests={len(base['quests'])}, npcs={len(base['npcs'])},"
          f" objects={len(base['objects'])}, items={len(base['items'])}")

    print("Loading corrections...")
    c = load_classic_corrections(args.questie, env)
    print(f"  quest_main={len(c['quest_main'])}, quest_rep={len(c['quest_rep'])},"
          f" quest_missing={len(c['quest_missing'])}")
    print(f"  npc_main={len(c['npc_main'])}, obj_main={len(c['obj_main'])}, item_main={len(c['item_main'])}")
    print(f"  faction: quest A/H={len(c['quest_alliance'])}/{len(c['quest_horde'])},"
          f" npc A/H={len(c['npc_alliance'])}/{len(c['npc_horde'])}")

    print("Loading blacklists...")
    bl = load_blacklists(args.questie, env)
    print(f"  blacklisted: quests={len(bl['quests'])}, npcs={len(bl['npcs'])}, items={len(bl['items'])}")

    # ---- Apply the classic correction pipeline ------------------------------
    # Order matches QuestieCorrections:Initialize + MinimalInit.
    print("Applying corrections...")

    # 1. LoadMissingQuests (empty placeholders for patches to land on)
    add_missing(base["quests"], c["quest_missing"])

    # 2. Classic quest reputation fixes
    apply_corrections(base["quests"], c["quest_rep"])

    # 3. Main fixes (quest / npc / item / object)
    apply_corrections(base["quests"],  c["quest_main"])
    apply_corrections(base["npcs"],    c["npc_main"])
    apply_corrections(base["items"],   c["item_main"])
    apply_corrections(base["objects"], c["obj_main"])

    # 4. Faction auto-patch: set requiredRaces based on starter NPC faction
    #    for quests that don't already have it. Uses hardcoded Alliance=77,
    #    Horde=178 from enums.RACE_KEYS.
    from enums import RACE_KEYS
    patched = apply_faction_autopatch(
        base["quests"], base["npcs"],
        env["questKeys"], env["npcKeys"],
        RACE_KEYS["ALL_ALLIANCE"], RACE_KEYS["ALL_HORDE"],
    )
    print(f"  faction-autopatched {patched} quests")

    # 5. Faction-specific overrides (MinimalInit). We bake Alliance-side as
    #    the default; a future update can emit a separate Horde overlay file.
    apply_corrections(base["quests"],  c["quest_alliance"])
    apply_corrections(base["npcs"],    c["npc_alliance"])
    apply_corrections(base["items"],   c["item_alliance"])
    apply_corrections(base["objects"], c["obj_alliance"])

    # 6. Blacklist — drop rows entirely.
    dq = drop_blacklisted(base["quests"], bl["quests"])
    dn = drop_blacklisted(base["npcs"],   bl["npcs"])
    di = drop_blacklisted(base["items"],  bl["items"])
    print(f"  dropped via blacklist: quests={dq}, npcs={dn}, items={di}")

    # ---- Convert positional -> named-field -----------------------------------
    print("Converting positional -> named-field...")
    quests  = positional_to_named(base["quests"],  env["questKeys"])
    npcs    = positional_to_named(base["npcs"],    env["npcKeys"])
    objects = positional_to_named(base["objects"], env["objectKeys"])
    items   = positional_to_named(base["items"],   env["itemKeys"])

    print(f"  final: quests={len(quests)}, npcs={len(npcs)}, objects={len(objects)}, items={len(items)}")

    # ---- Objective reverse index (custom — not in Questie schema) ------------
    # Emits `questObjective = {questId, ...}` on NPC / Object records whose id
    # appears as a kill or interaction target of any quest. Lets runtime code
    # answer "is this NPC a target of any kill quest?" without scanning every
    # quest at load time. Items already carry Questie's `relatedQuests`.
    print("Building questObjective reverse indices...")
    n_patched, o_patched = build_objective_reverse_index(quests, npcs, objects, items)
    print(f"  NPCs with questObjective: {n_patched}, Objects: {o_patched}")

    # ---- Repeatable turn-in tagging (custom — not in Questie schema) -------
    # Tags pure-delivery repeatables ("Additional Runecloth", etc.) so
    # the runtime can pick a different icon / behaviour than for real
    # repeatables that have actual kill / interact gameplay.
    print("Tagging repeatable turn-in quests...")
    n_turnins = mark_repeatable_turn_ins(quests, items)
    print(f"  tagged: {n_turnins}")

    # ---- Zones + XP ---------------------------------------------------------
    print("Loading zones + quest XP...")
    zones = load_zones(args.questie)
    xp = load_quest_xp(args.questie)

    # ---- Quest cluster precomputation ---------------------------------------
    # Replaces the runtime clustering in MUI_QuestObjectiveCluster.lua —
    # the addon ships per-objective spawn clusters (centroid + convex hull
    # in normalized coords) and the runtime just wraps the lookup.
    print("Building quest clusters...")
    from clusters import build_all as build_clusters
    quest_clusters = build_clusters(quests, npcs, objects, items, zones["areaToUi"])
    n_with_clusters = sum(1 for q in quest_clusters.values()
                          if q.get("objectives"))
    n_with_finisher = sum(1 for q in quest_clusters.values()
                          if q.get("finisher"))
    print(f"  rows: {len(quest_clusters)} "
          f"(with objective clusters: {n_with_clusters}, "
          f"with finisher: {n_with_finisher})")

    # ---- Emit ---------------------------------------------------------------
    args.out.mkdir(parents=True, exist_ok=True)

    def write(name: str, body: str) -> None:
        p = args.out / name
        p.write_text(body, encoding="utf-8")
        print(f"  wrote {p.name} ({p.stat().st_size/1024:.1f} KB)")

    print("Emitting...")

    def emit_singleton(filename: str, class_name: str, methods: str, data) -> None:
        write(filename, serialize_singleton(
            class_name, methods, data,
            HEADER.format(filename=filename, ver=ver)))

    emit_singleton("MUI_QuestDB.lua",         "QuestDB",         _QUEST_METHODS,   quests)
    emit_singleton("MUI_NpcDB.lua",           "NpcDB",           _STD_DB_METHODS,  npcs)
    emit_singleton("MUI_ObjectDB.lua",        "ObjectDB",        _STD_DB_METHODS,  objects)
    emit_singleton("MUI_ItemDB.lua",          "ItemDB",          _STD_DB_METHODS,  items)
    emit_singleton("MUI_ZoneDB.lua",          "ZoneDB",          _ZONE_METHODS,    zones)
    emit_singleton("MUI_QuestClustersDB.lua", "QuestClustersDB", _STD_DB_METHODS,  quest_clusters)

    # Quest XP: `xp` is {id: (level, xp)} tuples — convert to lists so the
    # pretty-printer keeps each `[id] = {lvl, amt}` on one line via the
    # numeric-leaf-array rule.
    xp_data = {qid: [lvl, amt] for qid, (lvl, amt) in xp.items()}
    emit_singleton("MUI_QuestXPDB.lua",       "QuestXPDB",       _STD_DB_METHODS,  xp_data)

    dt = time.time() - t0
    print(f"\nDone in {dt:.1f}s.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
