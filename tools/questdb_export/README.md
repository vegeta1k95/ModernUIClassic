# questdb_export — Questie → MUI_DB porting tool

Offline pure-Python script that reads a vendored Questie checkout and emits
self-contained singleton-class Lua files into `../../MUI_DB/` — one file
per `MUI_*DB` singleton, each bundling its accessor methods and its data
table in a single `object "XDB" { ... }` declaration. Runs in ~3 seconds.

## Run it

```sh
# From the ModernUI root:
python tools/questdb_export/export.py              # full export to MUI_DB/
python tools/questdb_export/export.py --check-keys # verify Questie field
                                                   # positions are unchanged
python tools/questdb_export/export.py --questie X --out Y   # custom paths
```

## Pinned upstream

The exporter treats the Questie checkout at `../vendor/Questie/` as its input.
See `MUI_DB/README.md` for the currently-vendored version.

## When Questie ships a new release

1. Drop the new release into `tools/vendor/Questie/` (replace the folder).
2. `python tools/questdb_export/export.py --check-keys` — if field-index
   positions shifted, this aborts with a diff; update `EXPECTED_*_KEYS` in
   `export.py` before proceeding.
3. `python tools/questdb_export/export.py` — regenerates `MUI_DB/MUI_*DB.lua`.
4. Bump `Version currently vendored` in `MUI_DB/README.md`.
5. Commit the regenerated files.

## Module layout

| Module | Role |
|---|---|
| `lua_parser.py` | Tokenizer + recursive-descent parser for the Lua subset Questie uses: table literals, strings, numbers, nil/true/false, identifier chains resolved through an env, arithmetic / comparison / logical operators, comments. |
| `enums.py` | Extracts all the enum tables Questie corrections reference (`questKeys`, `npcKeys`, `zoneIDs`, `raceKeys`, `classKeys`, `sortKeys`, `Phasing.phases`, `Questie.ICON_TYPE_*`, etc.) into a single env dict. |
| `base_db.py` | Reads `classic{Quest,Npc,Object,Item}DB.lua` — extracts the `[[return {...}]]` payload and parses it. |
| `corrections.py` | Parses `classic{Quest,NPC,Object,Item}Fixes.lua` + `Automatic/classicQuestReputationFixes.lua`. Handles the `function ... :Load()` / `:LoadFactionFixes()` / `:LoadMissingQuests()` entry points, extracting either a single `return {...}` table or the faction-specific local tables. |
| `blacklists.py` | Parses `Questie{Quest,NPC,Item}Blacklist.lua`. Evaluates `Expansions.Current == Expansions.Era`-style conditionals to decide whether each ID is blacklisted for Classic Era. |
| `zones.py` | Parses `Zones/data/{zoneIds,areaIdToUiMapId,uiMapIdToAreaId,subZoneToParentZone}.lua`. |
| `quest_xp.py` | Parses `QuestXP/DB/xpDB-classic.lua`. |
| `emit.py` | Merges base DB + corrections + faction fixes, applies the faction auto-patch (assign `requiredRaces` from starter NPC faction), drops blacklisted IDs, converts positional arrays to named-field dicts, and serializes as Lua table literals. |
| `export.py` | CLI entry — wires the whole pipeline together. Also holds the pinned `EXPECTED_*_KEYS` layout for the key-stability check. |

## Known limitations

- **enUS only**. Locale overlays are a future extension (see
  `MUI_DB/locale/` folder stub).
- **Alliance-side faction fixes baked in**. Horde-only overrides for ~20
  quest/NPC pairs aren't yet applied; Horde players will see the base values.
  Follow-up: emit a separate `MUI_QuestsHordeDB.lua` overlay file and
  have the runtime apply it based on `UnitFactionGroup("player")`.
- **No Anniversary phase-gating**. Per the plan, Anniversary content-phase
  blacklists are ignored — the addon ships with the full Classic DB and can
  filter at the UI layer if needed.
- **Automatic item-start fixes (QuestieItemStartFixes:LoadAutomaticQuestStarts)
  are not currently applied.** This is a minor secondary override pass. Adding
  it is a small follow-up if missing item-start rows are observed.

## Validation

The exporter prints row counts at each pipeline stage so unexpected drops
surface immediately. In-game, `/muiquestdb` runs the fixture assertions
(quest 5 has `breadcrumbs={163}`, quest 7 has `nextQuestInChain=15`, etc.).
