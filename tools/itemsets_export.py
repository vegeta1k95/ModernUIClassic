"""
Build MUI_DB/MUI_ItemSetDB.lua, the armour sets the Collections window shows,
from the Era client's own tables.

    python tools/itemsets_export.py <db2 dir>

<db2 dir> holds CSV exports of the client build's tables (wago.tools/db2, the
build in .build.info): ItemSet, ItemSparse, Item, AreaTable, SkillLine.

What goes in, and how:
  * Era's ItemSet table also holds Season of Discovery's sets (one client
    runs both); their items are numbered from 200000 and they are left out;
  * a set needs two pieces of armour a model can wear: sets of weapons or of
    jewellery are left out. The Ruins of Ahn'Qiraj sets, a class's weapon,
    cloak and ring from the Cenarion Circle, are in for the two they show;
  * so are the sets no Era character can have: the rare PvP sets as they
    were before patch 1.11 (the vendors sell their successors) and a set of
    test items;
  * a set is for the classes its pieces are limited to. The two dungeon sets
    are not limited in the data and are given here; any other set is for the
    classes that wear nothing heavier than its armour at the level its pieces
    need (mail under level 40 is a warrior's and a paladin's);
  * where a set comes from is an area or a profession, which the client
    names in its own language, or plain text. Every set needs one: a set this
    script does not know stops it;
  * the PvP and Arathi Basin sets are one faction's, told by their names;
  * a set's pieces are listed a weapon first, then as worn, head to feet,
    jewellery last; the first is the set's icon.
"""
import csv
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if len(sys.argv) < 2:
    sys.exit(__doc__)
DB2 = sys.argv[1]
OUT = os.path.join(ROOT, "MUI_DB", "MUI_ItemSetDB.lua")

csv.field_size_limit(10 ** 9)

SEASONAL_ITEMS = 200000

# ChrClasses ids as the bits of an item's AllowableClass.
WARRIOR, PALADIN, HUNTER, ROGUE, PRIEST, SHAMAN, MAGE, WARLOCK, DRUID = 1, 2, 4, 8, 16, 64, 128, 256, 1024
EVERYONE = WARRIOR | PALADIN | HUNTER | ROGUE | PRIEST | SHAMAN | MAGE | WARLOCK | DRUID

ARMOUR_CLASS = 4
CLOTH, LEATHER, MAIL, PLATE = 1, 2, 3, 4            # Item.SubclassID of armour

# InventoryType: what a model wears, in the order the pieces are listed, and
# what it does not show.
HEAD, NECK, SHOULDER, SHIRT, CHEST, WAIST, LEGS, FEET, WRIST, HANDS, FINGER, TRINKET = range(1, 13)
CLOAK, TABARD, ROBE = 16, 19, 20
WORN = [HEAD, SHOULDER, CLOAK, CHEST, ROBE, WRIST, HANDS, WAIST, LEGS, FEET]
JEWELLERY = [NECK, FINGER, TRINKET]
WEAPON = [21, 13, 17, 22, 14, 23, 15, 26, 25]       # main hand, one hand, two hands, off hand, shield, held, ranged, thrown

# The Ruins of Ahn'Qiraj sets: one piece of armour, the cloak, and with it a
# weapon to show.
WITH_WEAPON = {494, 495, 498, 500, 502, 504, 506, 508, 510}

# Sets no Era character can have.
EXCLUDED = {
    221,                                              # Garb of Thero-shan: test items
    # The rare PvP sets of before patch 1.11.
    281, 282, 301, 341, 342, 343, 344, 345, 346, 347, 348, 361, 362, 381, 382, 401,
}

# Dungeon Set 1 and 2, whose pieces any class can put on.
DUNGEON_SET_CLASS = {
    181: MAGE, 182: PRIEST, 183: WARLOCK, 184: ROGUE, 185: DRUID, 186: HUNTER, 187: SHAMAN,
    188: PALADIN, 189: WARRIOR,
    511: WARRIOR, 512: ROGUE, 513: DRUID, 514: PRIEST, 515: HUNTER, 516: PALADIN, 517: MAGE,
    518: WARLOCK, 519: SHAMAN,
}
# Twilight Trappings: the cultist disguise every class wears.
FOR_EVERYONE = {492}

ALLIANCE_NAMES = ("Lieutenant Commander's ", "Field Marshal's ", "The Highlander's ")
HORDE_NAMES = ("Champion's ", "Warlord's ", "The Defiler's ")


def area(area_id, name):
    return ("area", area_id, name)


def skill(skill_id, name):
    return ("skill", skill_id, name)


def text(label):
    return ("label", label, label)


# Where each set comes from.
SOURCES = [
    (area(2717, "Molten Core"), range(201, 210)),
    (area(2677, "Blackwing Lair"), range(210, 219)),
    (area(3428, "Ahn'Qiraj"), (493, 496, 497, 499, 501, 503, 505, 507, 509)),
    (area(3429, "Ruins of Ahn'Qiraj"), sorted(WITH_WEAPON)),
    (area(3456, "Naxxramas"), (521, 523, 524, 525, 526, 527, 528, 529, 530)),
    (area(1977, "Zul'Gurub"), range(474, 483)),
    (area(3358, "Arathi Basin"), (*range(467, 474), *range(483, 489))),
    (text("Dungeon Set 1"), range(181, 190)),
    (text("Dungeon Set 2"), range(511, 520)),
    (text("PvP Rank 10"), (522, *range(537, 552))),
    (text("PvP Rank 13"), (383, 384, *range(386, 399), 402)),
    (text("Dungeons"), (520,)),
    (text("Argent Dawn"), range(533, 537)),
    (area(1581, "The Deadmines"), (161,)),
    (area(718, "Wailing Caverns"), (162,)),
    (area(796, "Scarlet Monastery"), (163,)),
    (area(1584, "Blackrock Depths"), (1,)),
    (area(2017, "Stratholme"), (81,)),
    (area(2057, "Scholomance"), range(121, 125)),
    (area(1377, "Silithus"), (492,)),
    (skill(165, "Leatherworking"), (141, 142, 143, 144, 441, 442, 489, 490, 491)),
    (skill(164, "Blacksmithing"), (321, 443, 444)),
    (skill(197, "Tailoring"), (421,)),
]


def table(name):
    with open(os.path.join(DB2, name + ".csv"), encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


SPARSE = {int(r["ID"]): r for r in table("ItemSparse")}
ITEMS = {int(r["ID"]): r for r in table("Item")}
AREAS = {int(r["ID"]): r["AreaName_lang"] for r in table("AreaTable")}
SKILLS = {int(r["ID"]): r["DisplayName_lang"] for r in table("SkillLine")}

SOURCE_OF = {}
for source, set_ids in SOURCES:
    kind, key, name = source
    known = AREAS if kind == "area" else SKILLS if kind == "skill" else None
    if known is not None and known.get(key) != name:
        sys.exit(f"{kind} {key} is {known.get(key)!r} in this build, not {name!r}")
    for set_id in set_ids:
        if set_id in SOURCE_OF:
            sys.exit(f"set {set_id} has two sources")
        SOURCE_OF[set_id] = source


def slot(item):
    return int(SPARSE[item]["InventoryType"])


def classes_of(set_id, items):
    """The classes a set is for, as AllowableClass bits."""
    limit = EVERYONE
    for item in items:
        allowed = int(SPARSE[item]["AllowableClass"])
        if allowed != -1:
            limit &= allowed
    if limit != EVERYONE:
        return limit
    if set_id in DUNGEON_SET_CLASS:
        return DUNGEON_SET_CLASS[set_id]
    if set_id in FOR_EVERYONE:
        return EVERYONE
    # No limit in the data: whoever wears nothing heavier at that level.
    armour = max(int(ITEMS[i]["SubclassID"]) for i in items
                 if int(ITEMS[i]["ClassID"]) == ARMOUR_CLASS and slot(i) in WORN and slot(i) != CLOAK)
    level = max(int(SPARSE[i]["RequiredLevel"]) for i in items)
    if armour == PLATE:
        return WARRIOR | PALADIN
    if armour == MAIL:
        return HUNTER | SHAMAN if level >= 40 else WARRIOR | PALADIN
    if armour == LEATHER:
        return ROGUE | DRUID if level >= 40 else ROGUE | DRUID | HUNTER | SHAMAN
    return PRIEST | MAGE | WARLOCK


def faction_of(name):
    if name.startswith(ALLIANCE_NAMES):
        return "Alliance"
    if name.startswith(HORDE_NAMES):
        return "Horde"
    return None


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


sets = []
skipped = {"seasonal": 0, "nothing to show": 0, "not on Era": 0, "empty": 0}
for row in table("ItemSet"):
    set_id = int(row["ID"])
    items = [int(row[f"ItemID_{i}"]) for i in range(17) if int(row[f"ItemID_{i}"])]
    if not items:
        skipped["empty"] += 1
        continue
    if max(items) >= SEASONAL_ITEMS:
        skipped["seasonal"] += 1
        continue
    if any(i not in SPARSE or i not in ITEMS for i in items):
        sys.exit(f"set {set_id} {row['Name_lang']}: an item is not in the item tables")
    if set_id in EXCLUDED:
        skipped["not on Era"] += 1
        continue
    if sum(1 for i in items if slot(i) in WORN) < 2 and set_id not in WITH_WEAPON:
        skipped["nothing to show"] += 1
        continue
    if set_id not in SOURCE_OF:
        sys.exit(f"set {set_id} {row['Name_lang']} has no source: add it to SOURCES (or EXCLUDED)")

    order = WEAPON + WORN + JEWELLERY
    items.sort(key=lambda i: (order.index(slot(i)) if slot(i) in order else len(order), i))
    sets.append({
        "id": set_id,
        "name": row["Name_lang"],
        "classes": classes_of(set_id, items),
        "level": max(int(SPARSE[i]["ItemLevel"]) for i in items),
        "quality": max(int(SPARSE[i]["OverallQualityID"]) for i in items),
        "source": SOURCE_OF[set_id],
        "faction": faction_of(row["Name_lang"]),
        "items": items,
    })

unused = set(SOURCE_OF) - {s["id"] for s in sets}
if unused:
    sys.exit(f"SOURCES names sets that are not exported: {sorted(unused)}")

sets.sort(key=lambda s: (-s["level"], s["source"][2], s["faction"] or "", s["name"]))

HEADER = '''-- ItemSetDB: Era's armour sets, for the Collections window (MUI_Collections).
-- GENERATED by tools/itemsets_export.py from the client's ItemSet and item
-- tables - don't edit by hand.
--
-- set = { id, name, classes, level, quality, label, area?, skill?, faction?, items }
--   name      enUS; :GetName gives the client's own
--   classes   the classes it is for: bit (class id - 1) of each
--   level     the highest item level among its pieces
--   quality   the best quality among them
--   label     where it comes from, enUS; with it the area's id or the
--   area        profession's skill line when it is one the client can name
--   skill       (:GetSource)
--   faction   "Alliance" / "Horde" for a set only one side can earn
--   items     its pieces' item ids: a weapon first, then as worn, head to
--               feet, jewellery last

object "ItemSetDB" {
    -- Every set, the highest item level first; those of one level by where
    -- they come from.
    GetSets = function(self)
        return self._sets
    end;

    GetSet = function(self, id)
        return self._byId[id]
    end;

    -- The sets an item is a piece of; nil when it is of none.
    GetSetsOfItem = function(self, itemId)
        return self._byItem[itemId]
    end;

    -- A set's name in the client's language.
    GetName = function(self, set)
        local name = C_Item.GetItemSetInfo(set.id)
        if name and name ~= "" then return name end
        return set.name
    end;

    -- Where a set comes from, in the client's language where it has the
    -- words, with the faction after a one-sided set's.
    GetSource = function(self, set)
        local source
        if set.area then
            source = C_Map.GetAreaInfo(set.area)
        elseif set.skill then
            source = C_TradeSkillUI.GetTradeSkillDisplayName(set.skill)
        end
        if not source or source == "" then source = set.label end
        if set.faction then
            source = source .. " (" .. (set.faction == "Alliance" and FACTION_ALLIANCE or FACTION_HORDE) .. ")"
        end
        return source
    end;

    __init = function(self)
        self._sets = {
'''

FOOTER = '''        }

        self._byId, self._byItem = {}, {}
        for _, set in ipairs(self._sets) do
            self._byId[set.id] = set
            for _, item in ipairs(set.items) do
                local sets = self._byItem[item]
                if not sets then
                    sets = {}
                    self._byItem[item] = sets
                end
                sets[#sets + 1] = set
            end
        end
    end;
}
'''

lines = []
for s in sets:
    kind, key, label = s["source"]
    source = f"label = {lua_str(label)}" + ("" if kind == "label" else f", {kind} = {key}")
    faction = f", faction = {lua_str(s['faction'])}" if s["faction"] else ""
    lines.append(f'            {{ id = {s["id"]}, name = {lua_str(s["name"])}, classes = {s["classes"]}, '
                 f'level = {s["level"]}, quality = {s["quality"]}, {source}{faction},')
    lines.append(f'              items = {{ {", ".join(str(i) for i in s["items"])} }} }},')

with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write(HEADER + "\n".join(lines) + "\n" + FOOTER)

CLASS_NAMES = {WARRIOR: "Warrior", PALADIN: "Paladin", HUNTER: "Hunter", ROGUE: "Rogue", PRIEST: "Priest",
               SHAMAN: "Shaman", MAGE: "Mage", WARLOCK: "Warlock", DRUID: "Druid"}
print(f"{len(sets)} sets, {sum(len(s['items']) for s in sets)} pieces -> {OUT}")
print("left out:", ", ".join(f"{n} {why}" for why, n in skipped.items()))
print("per class:", ", ".join(f"{name} {sum(1 for s in sets if s['classes'] & bit)}"
                              for bit, name in CLASS_NAMES.items()))
by_source = {}
for s in sets:
    by_source[s["source"][2]] = by_source.get(s["source"][2], 0) + 1
print("per source:", ", ".join(f"{name} {n}" for name, n in by_source.items()))
