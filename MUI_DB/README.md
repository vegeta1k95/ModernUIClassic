# MUI_DB

Read-only static databases for ModernUI on WoW Classic Era 1.15.x. The
quest-helper data tables are **derived from
[Questie](https://github.com/Questie/Questie)** (GPLv3) by an offline
exporter; see [`../tools/questdb_export/`](../tools/questdb_export/) and
[`../ATTRIBUTION.md`](../ATTRIBUTION.md). The hand-written single-file DBs
(`MUI_TransportDB`, `MUI_DungeonDB`, `MUI_QuestHubDB`) are maintained inline.

## Pinned upstream

- **Questie**: `v11.25.0` (see `../tools/vendor/Questie/Questie-Classic.toc`)

## Public API (in-game Lua)

One singleton per entity type — each file is a self-contained `object "<X>DB"`
that bundles accessors and data together. Use method (`:`) syntax:

```lua
-- Quests
MUI_QuestDB:Get(questId)                    -- { name=..., startedBy=..., ... }
MUI_QuestDB:GetAll()                        -- raw table for iteration
MUI_QuestDB:LocalizeQuestName(questId)      -- honours optional locale overlay
MUI_QuestDB:Count()                         -- row count

-- NPCs / game objects / items / quest-XP / quest-clusters
MUI_NpcDB:Get(id)            -- { name=..., spawns=..., ... }
MUI_ObjectDB:Get(id)         -- { name=..., spawns=..., ... }
MUI_ItemDB:Get(id)           -- { name=..., npcDrops=..., ... }
MUI_QuestXPDB:Get(id)        -- {level, xpReward}
MUI_QuestClustersDB:Get(id)  -- precomputed spawn clusters
-- All of the above also support :GetAll() and :Count().

-- Zones
MUI_ZoneDB:GetByName("DUSKWOOD")            -- areaId
MUI_ZoneDB:GetUiMapForArea(areaId)          -- uiMapId
MUI_ZoneDB:GetAreaForUiMap(uiMapId)         -- areaId
MUI_ZoneDB:GetParent(subAreaId)             -- parent areaId

-- Recipes (hand-written; per-profession metadata keyed by spellID)
MUI_RecipeDB:Get("ENCHANTING")              -- { [spellId] = { category=... }, ... }
```

## Files

Each generated singleton ships its accessors and `_data` table in a single
file; there is no separate "data global" sibling file.

| File | Purpose |
|---|---|
| `MUI_QuestDB.lua`         | Quests singleton (GENERATED). |
| `MUI_NpcDB.lua`           | NPCs singleton (GENERATED). |
| `MUI_ObjectDB.lua`        | Game objects singleton (GENERATED). |
| `MUI_ItemDB.lua`          | Items singleton (GENERATED). |
| `MUI_ZoneDB.lua`          | Zone lookup tables singleton (GENERATED). |
| `MUI_QuestXPDB.lua`       | Quest-XP reward singleton (GENERATED). |
| `MUI_QuestClustersDB.lua` | Per-quest objective spawn cluster singleton (GENERATED). |
| `MUI_TransportDB.lua`     | Transport-network DB (hand-written). |
| `MUI_DungeonDB.lua`       | Dungeon-entrance DB (hand-written). |
| `MUI_QuestHubDB.lua`      | Quest-hub DB (hand-written). |
| `MUI_RecipeDB.lua`        | Per-profession recipe metadata, keyed by spellID (hand-written). |

## Regenerating the DB

```sh
# From the ModernUI folder:
python tools/questdb_export/export.py --check-keys       # key-stability check
python tools/questdb_export/export.py                    # full export

# If Questie has a new release:
#   1. Drop it into tools/vendor/Questie/
#   2. Re-run the export
#   3. Commit the regenerated MUI_DB/MUI_*DB.lua files
```

The accessor method bodies are templated inside `tools/questdb_export/export.py`
(`_STD_DB_METHODS` / `_QUEST_METHODS` / `_ZONE_METHODS`). Edit them there if
you want to change how the singletons expose their data.

## In-game smoke test

`/muiquestdb` runs a handful of fixture assertions against the loaded DB and
prints PASS / FAIL to the default chat frame.

## Licence

GPL-3.0-or-later — inherited from Questie's raw data. See the top-level
`ModernUI/LICENSE` and `ModernUI/ATTRIBUTION.md`.
