# Attribution

ModernUI bundles raw quest / NPC / object / item data derived from the
[Questie](https://github.com/Questie/Questie) addon. Questie is released
under the **GNU General Public License, version 3 (GPL-3.0-or-later)**, and
as a consequence ModernUI is distributed under the same terms. See the
top-level `LICENSE` file for the full license text.

## Upstream

- **Project**: Questie — a Classic WoW quest helper
- **Repository**: https://github.com/Questie/Questie
- **Licence**: GPL-3.0-or-later
- **Version currently vendored**: `v11.25.0` (per
  `tools/vendor/Questie/Questie-Classic.toc`)
- **Authors** (from upstream `Questie-Classic.toc` line 3):
  Aero / Logon / Muehe / TheCrux (BreakBB) / Drejjmit / Dyaxler / Cheeq /
  TechnoHunter — and the wider Questie community who have contributed
  corrections, quest data, and maintenance over the years.

## What we use

Only the **Classic Era** raw data:

- `Database/Classic/classicQuestDB.lua`
- `Database/Classic/classicNpcDB.lua`
- `Database/Classic/classicObjectDB.lua`
- `Database/Classic/classicItemDB.lua`
- `Database/Corrections/classic{Quest,NPC,Item,Object}Fixes.lua`
- `Database/Corrections/Automatic/classicQuestReputationFixes.lua`
- `Database/Corrections/Questie{Quest,NPC,Item}Blacklist.lua`
- `Database/Zones/data/zoneIds.lua`, `areaIdToUiMapId.lua`,
  `uiMapIdToAreaId.lua`, `subZoneToParentZone.lua`
- `Database/QuestXP/DB/xpDB-classic.lua`

We use **none** of Questie's UI / logic / libraries / icons / localization.
The offline exporter (`tools/questdb_export/`) reads the files listed above,
applies Questie's own corrections pipeline, and emits our own named-field
Lua tables under `MUI_DB/`. Every generated file carries a header
comment pointing back to this attribution.

## Regenerating

See `MUI_DB/README.md` for the update workflow.

## Thank you

ModernUI's quest-helper module would not be possible without the years of
community effort the Questie team has sunk into curating, validating, and
correcting this data. If you use this addon and find the quest helper
useful, please consider also installing and supporting Questie itself.
