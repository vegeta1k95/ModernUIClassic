"""
Build MUI_DB/MUI_MountDB.lua, the mounts the Collections window lists, from
the Era client's own tables.

    python tools/mounts_export.py <db2 dir>

<db2 dir> holds CSV exports of the client build's tables (wago.tools/db2, the
build in .build.info): ItemEffect, SpellEffect, SpellName, ItemSparse,
CreatureDisplayInfo, CreatureModelData, AreaTable; and, in <db2 dir>/retail,
retail's Mount and MountXDisplay (the same site, no build given). Needs lupa
(MUI_ItemDB and MUI_NpcDB are read for where a mount comes from).

Era has no mount journal: a mount is an item in the bags (two classes cast
theirs). What goes in, and how:
  * the items whose spell puts the mount aura on the caster, and the Black
    Qiraji Resonating Crystal, whose spell does it by script;
  * only those somebody sells, drops or rewards (MUI_ItemDB, from Questie):
    Era's tables are full of mounts that were renamed, replaced or never
    released, and of Season of Discovery's;
  * the paladin's and the warlock's mounts, which are spells;
  * the name, the lore line and the creature display are retail's journal's
    for the same spell. Retail gave a few new displays that Era's client does
    not have: those are given here;
  * each mount gets the model viewer's camera, from the size of its model
    (see camera());
  * a mount of one faction is told by the races that can ride it, or, with
    no such limit, by who its vendors serve;
  * where it comes from: a vendor (the first one listed) with its price, or
    what drops it, each with its area, which the client names in its own
    language; or the quest's reward; or the class.
"""
import csv
import os
import sys

from lupa import LuaRuntime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if len(sys.argv) < 2:
    sys.exit(__doc__)
DB2 = sys.argv[1]
OUT = os.path.join(ROOT, "MUI_DB", "MUI_MountDB.lua")

csv.field_size_limit(10 ** 9)

MOUNT_AURA = 78                   # SPELL_AURA_MOUNTED
SEASONAL_ITEMS = 200000

# AllowableRace bits of the two sides (the later races' bits are set too).
ALLIANCE_RACES = 1 | 4 | 8 | 64
HORDE_RACES = 2 | 16 | 32 | 128

# item -> its spell, where the spell mounts by script; and the auras that
# spell ends in (one inside Ahn'Qiraj, one outside).
SCRIPTED = {21176: 26656}
AURAS = {26656: [25863, 26655]}

# spell, class: the mounts that are spells.
CLASS_MOUNTS = [(13819, "PALADIN"), (23214, "PALADIN"), (5784, "WARLOCK"), (23161, "WARLOCK")]

# Displays retail has replaced, as Era has them: the blue and black battle
# tanks, the paladin's charger.
ERA_DISPLAY = {25953: 15678, 26656: 15677, 23214: 14584}
# Models whose box is padded round them (a cube, or one that takes their
# flames in): sized as another model of their kind. The charger as the
# warhorse, the skeletal warhorse as the skeletal horse, the felsteed as the
# horse, the dreadsteed as the swift horse.
SIZED_AS = {1952: 1191, 1511: 491, 215: 216, 1951: 1917}

# The model viewer's camera for a mount: how far in front of it and how high,
# by the Adventure Guide's rule (tools/encounterjournal_export.py), which
# frames a creature well in a pane of its shape. The journal writes over the
# top of its pane: the model's frame starts under that, and is that shape
# (MUI_CollectionsMountDisplay).
CAMERA_DISTANCE = 1.5
CAMERA_HEIGHT = 0.25
FIT_WIDTH = 0.8


def table(name, sub=""):
    with open(os.path.join(DB2, sub, name + ".csv"), encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def seq(t):
    return list(t.values()) if t else []


world = LuaRuntime(unpack_returned_tuples=True)
world.execute('object = function(name) return function(t) _G[name] = t end end')
for name in ("MUI_ItemDB.lua", "MUI_NpcDB.lua"):
    world.execute(open(os.path.join(ROOT, "MUI_DB", name), encoding="utf-8").read())
ITEM_SOURCES, NPCS = world.globals().ItemDB._data, world.globals().NpcDB._data

SPARSE = {int(r["ID"]): r for r in table("ItemSparse")}
SPELL_NAMES = {int(r["ID"]): r["Name_lang"] for r in table("SpellName")}
AREAS = {int(r["ID"]): r["AreaName_lang"] for r in table("AreaTable")}
DISPLAYS = {int(r["ID"]): int(r["ModelID"]) for r in table("CreatureDisplayInfo")}
MODELS = {int(r["ID"]): [float(r[f"GeoBox_{i}"]) for i in range(6)] for r in table("CreatureModelData")}
MOUNT_SPELLS = {int(r["SpellID"]) for r in table("SpellEffect") if int(r["EffectAura"]) == MOUNT_AURA}
RETAIL = {int(r["SourceSpellID"]): r for r in table("Mount", "retail")}
RETAIL_DISPLAYS = {}
for r in table("MountXDisplay", "retail"):
    RETAIL_DISPLAYS.setdefault(int(r["MountID"]), []).append(int(r["CreatureDisplayInfoID"]))


def camera(display):
    """Distance and eye height that frame a display's model."""
    model = DISPLAYS[display]
    box = MODELS[SIZED_AS.get(model, model)]
    width = max(box[3] - box[0], box[4] - box[1])
    base = max(box[2], 0)
    height = box[5] - base
    fit = max(height, FIT_WIDTH * min(width, 3 * height))
    return round(CAMERA_DISTANCE * fit, 1), round(base + CAMERA_HEIGHT * height, 2)


def display_of(spell):
    if spell in ERA_DISPLAY:
        return ERA_DISPLAY[spell]
    mount = RETAIL.get(spell)
    for display in RETAIL_DISPLAYS.get(int(mount["ID"]), []) if mount else []:
        if display in DISPLAYS:
            return display
    return None


def name_of(spell):
    if spell in RETAIL:
        return RETAIL[spell]["Name_lang"]
    name = SPELL_NAMES[spell]
    return name[7:] if name.startswith("Summon ") else name


def npc_area(npc):
    area = NPCS[npc].zoneID if NPCS[npc] else None
    return area if area in AREAS else None


def source_of(item):
    """vendor / drop / quest fields of an item, or None when nothing gives it."""
    entry = ITEM_SOURCES[item]
    if not entry:
        return None
    vendors, drops, quests = seq(entry.vendors), seq(entry.npcDrops), seq(entry.questRewards)
    if vendors:
        npc = vendors[0]
        return {"vendor": NPCS[npc].name, "area": npc_area(npc), "cost": int(SPARSE[item]["BuyPrice"])}
    if drops:
        # one keeper is named; a mount that anything in a place may drop is the place's
        source = {"area": npc_area(drops[0])}
        if len(drops) <= 2:
            source["drop"] = NPCS[drops[0]].name
        else:
            source["zoneDrop"] = True
        return source
    if quests:
        return {"quest": True}
    return None


def faction_of(item):
    races = int(SPARSE[item]["AllowableRace_0"])
    if races != -1:
        alliance, horde = races & ALLIANCE_RACES, races & HORDE_RACES
        if alliance and not horde:
            return "Alliance"
        if horde and not alliance:
            return "Horde"
        return None
    sides = {NPCS[n].friendlyToFaction for n in seq(ITEM_SOURCES[item].vendors) if NPCS[n]}
    if sides == {"A"}:
        return "Alliance"
    if sides == {"H"}:
        return "Horde"
    return None


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


item_spells = dict(SCRIPTED)
for r in table("ItemEffect"):
    item, spell = int(r["ParentItemID"]), int(r["SpellID"])
    if spell in MOUNT_SPELLS and item < SEASONAL_ITEMS and item in SPARSE:
        item_spells.setdefault(item, spell)

mounts, unsourced, unseen = [], 0, []
for item, spell in sorted(item_spells.items()):
    source = source_of(item)
    if not source:
        unsourced += 1
        continue
    display = display_of(spell)
    if not display:
        unseen.append(SPARSE[item]["Display_lang"])
        continue
    mounts.append({"spell": spell, "item": item, "display": display, "faction": faction_of(item), **source})
for spell, cls in CLASS_MOUNTS:
    mounts.append({"spell": spell, "class": cls, "display": display_of(spell)})
if unseen:
    sys.exit("no display in this build for: " + ", ".join(unseen) + " (add them to ERA_DISPLAY)")
if len({m["spell"] for m in mounts}) != len(mounts):
    sys.exit("two mounts share a spell")

for m in mounts:
    m["name"] = name_of(m["spell"])
    m["lore"] = RETAIL[m["spell"]]["Description_lang"] if m["spell"] in RETAIL else ""
    m["dist"], m["eye"] = camera(m["display"])
mounts.sort(key=lambda m: m["name"])

HEADER = '''-- MountDB: Era's mounts, for the Collections window (MUI_Collections).
-- GENERATED by tools/mounts_export.py from the client's item and spell tables,
-- retail's mount journal (names, lore, displays) and MUI_ItemDB (sources) -
-- don't edit by hand.
--
-- mount = { spell, item?, class?, name, display, dist, eye, faction?,
--           vendor?, cost?, drop?, zoneDrop?, quest?, area?, auras?, lore }
--   spell     the spell that mounts: what a mount is known by here
--   item      the item that casts it; none for a class's own mount, which
--   class       is that class's spell
--   name      enUS, retail's journal's
--   display   creature display id; dist, eye: the model viewer's camera
--   faction   "Alliance" / "Horde" for a mount one side rides
--   vendor    who sells it (enUS) for `cost` copper, or
--   drop        who drops it (enUS), or `zoneDrop`: anything in the area may,
--   quest       or a quest rewards it; `area`: the area id of the place
--               (C_Map.GetAreaInfo)
--   auras     the auras that mean it is being ridden, when not `spell`
--   lore      retail's line about it (enUS)

object "MountDB" {
    -- Every mount, by name.
    GetMounts = function(self)
        return self._mounts
    end;

    -- A mount's icon: its item's, or its spell's.
    GetIcon = function(self, mount)
        if mount.item then return C_Item.GetItemIconByID(mount.item) end
        return C_Spell.GetSpellTexture(mount.spell)
    end;

    __init = function(self)
        self._mounts = {
'''

FOOTER = '''        }
    end;
}
'''

ORDER = ["spell", "item", "class", "name", "display", "dist", "eye", "faction", "vendor", "cost", "drop", "zoneDrop",
         "quest", "area"]
lines = []
for m in mounts:
    fields = []
    for key in ORDER:
        value = m.get(key)
        if value is None:
            continue
        if isinstance(value, bool):
            fields.append(f"{key} = true")
        elif isinstance(value, str):
            fields.append(f"{key} = {lua_str(value)}")
        else:
            fields.append(f"{key} = {value}")
    if m["spell"] in AURAS:
        fields.append("auras = { %s }" % ", ".join(str(a) for a in AURAS[m["spell"]]))
    lines.append("            { " + ", ".join(fields) + ",")
    lines.append("              lore = " + lua_str(m["lore"]) + " },")

with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write(HEADER + "\n".join(lines) + "\n" + FOOTER)

sides = {None: 0, "Alliance": 0, "Horde": 0}
for m in mounts:
    sides[m.get("faction")] += 1
print(f"{len(mounts)} mounts -> {OUT}")
print(f"  {sides['Alliance']} Alliance, {sides['Horde']} Horde, {sides[None]} either's; "
      f"{len(CLASS_MOUNTS)} class spells; {unsourced} mount items left out: nothing gives them")
print("  no lore:", [m["name"] for m in mounts if not m["lore"]])
print("  cameras:", ", ".join(f"{m['name']} {m['dist']}/{m['eye']}" for m in mounts if m["display"] in
                              (2404, 14584, 10718, 15678, 12246, 14339, 14372, 6080, 2327)))
