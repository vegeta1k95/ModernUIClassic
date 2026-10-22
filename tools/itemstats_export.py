"""
Build MUI_DB/MUI_ItemStatDB.lua: what an item, an enchantment and a random
property ("of the Bear") give the character wearing them, by id, for the
item comparison in MUI_TooltipCompare.

    python tools/itemstats_export.py <db2 dir>

<db2 dir> holds CSV exports of the client build's tables (wago.tools/db2, the
build in .build.info): ItemSparse, ItemEffect, SpellEffect, SpellShapeshift,
SpellItemEnchantment, ItemRandomProperties.

Era's client has no function that gives an item's stats, and its tooltip
lines are in the client's language. What goes in, and how:
  * the items a character wears or wields (not bags, quivers or ammunition),
    those that give nothing too, so that the addon can tell an item it does
    not know; Season of Discovery's (numbered from 200000) are left out;
  * an item's stats: its base stats, armour and resistances, the damage per
    second of a weapon as the tooltip gives it (one decimal), and what its
    "Equip:" spells give (AURAS below; anything else an equip spell does,
    procs, talents' modifiers, damage against a creature type, is left out);
  * an enchantment's: added weapon damage, armour or resistance, a stat, or
    the spell it puts on the wearer, read the same way as an equip spell;
  * a random property's: those of its enchantments;
  * a weapon skill (or Fishing, Herbalism ...) is SKILL<skill line id>, and
    has to be one MUI_SkillLineDB names: any other stops the script;
  * a shield's block value is in none of the client's tables: the addon
    reads it off the tooltip.
"""
import collections
import csv
import os
import re
import sys
import textwrap

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if len(sys.argv) < 2:
    sys.exit(__doc__)
DB2 = sys.argv[1]
OUT = os.path.join(ROOT, "MUI_DB", "MUI_ItemStatDB.lua")
SKILL_LINES = os.path.join(ROOT, "MUI_DB", "MUI_SkillLineDB.lua")

csv.field_size_limit(10 ** 9)

SEASONAL_ITEMS = 200000

# InventoryType: armour, jewellery, weapons, shields, held in off hand,
# tabards, relics (not bags 18, ammunition 24, quivers 27).
WORN = set(range(1, 18)) | {19, 20, 21, 22, 23, 25, 26, 28}
WORN.discard(18)

ON_EQUIP = "1"                    # ItemEffect.TriggerType
APPLY_AURA = "6"                  # SpellEffect.Effect

# The order keys are written in.
KEYS = ["ARMOR", "DPS", "WDMG", "STR", "AGI", "STA", "INT", "SPI", "HEALTH", "MANA",
        "AP", "RAP", "FERALAP", "HIT", "CRIT", "HASTE", "SPELLDMG", "HEAL",
        "DMG_ARCANE", "DMG_FIRE", "DMG_FROST", "DMG_HOLY", "DMG_NATURE", "DMG_SHADOW",
        "SPELLHIT", "SPELLCRIT", "SPELLPEN", "MP5", "HP5", "DEFENSE", "DODGE", "PARRY",
        "BLOCKCHANCE", "BLOCK", "RES_ARCANE", "RES_FIRE", "RES_FROST", "RES_NATURE", "RES_SHADOW"]

# Item stat types (ItemSparse.StatModifier_bonusStat, an enchantment's stat).
ITEM_MOD = {0: "MANA", 1: "HEALTH", 3: "AGI", 4: "STR", 5: "INT", 6: "SPI", 7: "STA"}
# Resistance columns (ItemSparse.Resistances, an enchantment's resistance);
# holy (1) has no key.
RESISTANCES = {0: "ARMOR", 2: "RES_FIRE", 3: "RES_NATURE", 4: "RES_FROST", 5: "RES_SHADOW", 6: "RES_ARCANE"}
# Spell school bits (an aura's misc value): resistances and spell damage.
SCHOOL_RESISTANCE = {1: "ARMOR", 4: "RES_FIRE", 8: "RES_NATURE", 16: "RES_FROST", 32: "RES_SHADOW", 64: "RES_ARCANE"}
SCHOOL_DAMAGE = {1: "WDMG", 2: "DMG_HOLY", 4: "DMG_FIRE", 8: "DMG_NATURE", 16: "DMG_FROST",
                 32: "DMG_SHADOW", 64: "DMG_ARCANE", 126: "SPELLDMG"}
MAGIC = 126                       # every school but physical
MAGIC_BUT_HOLY = 124
# SPELL_AURA_MOD_STAT's misc value; -1 is every stat.
STAT = {0: "STR", 1: "AGI", 2: "STA", 3: "INT", 4: "SPI"}
DEFENSE = 95                      # skill line

# Aura types, as Era 1.15.9 numbers them (some differ from 1.12's).
MOD_RESISTANCE = 22
MOD_STAT = 29
MOD_SKILL = 30
MOD_INCREASE_HEALTH = 34
MOD_INCREASE_ENERGY = 35
MOD_DAMAGE_DONE = 13
MOD_HEALING_DONE = 135
MOD_ATTACK_POWER = 99
MOD_RANGED_ATTACK_POWER = 124
MOD_HIT_CHANCE = 54
MOD_WEAPON_CRIT_PERCENT = 52
MOD_MELEE_HASTE = 138
MOD_SPELL_HIT_CHANCE = 55
MOD_SPELL_CRIT_CHANCE = 57
MOD_SPELL_CRIT_CHANCE_SCHOOL = 552
MOD_TARGET_RESISTANCE = 123
MOD_POWER_REGEN = 85
MOD_HEALTH_REGEN_IN_COMBAT = 161
PERIODIC_HEAL = 8
MOD_DODGE_PERCENT = 49
MOD_PARRY_PERCENT = 47
MOD_BLOCK_PERCENT = 51
MOD_SHIELD_BLOCK_VALUE = 564
SIMPLE = {MOD_HIT_CHANCE: "HIT", MOD_WEAPON_CRIT_PERCENT: "CRIT", MOD_MELEE_HASTE: "HASTE",
          MOD_SPELL_HIT_CHANCE: "SPELLHIT", MOD_SPELL_CRIT_CHANCE: "SPELLCRIT",
          MOD_HEALTH_REGEN_IN_COMBAT: "HP5", MOD_DODGE_PERCENT: "DODGE", MOD_PARRY_PERCENT: "PARRY",
          MOD_BLOCK_PERCENT: "BLOCKCHANCE", MOD_SHIELD_BLOCK_VALUE: "BLOCK",
          MOD_INCREASE_HEALTH: "HEALTH"}

# SpellItemEnchantment.Effect
ENCHANT_DAMAGE, ENCHANT_EQUIP_SPELL, ENCHANT_RESISTANCE, ENCHANT_STAT = 2, 3, 4, 5


def rows(name):
    with open(os.path.join(DB2, name), encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


skill_lines = {int(x) for x in re.findall(r"^        \[(\d+)\] = \{ cat", open(SKILL_LINES, encoding="utf-8").read(), re.M)}

effects = collections.defaultdict(list)
for r in rows("SpellEffect.csv"):
    if r["DifficultyID"] == "0" and r["Effect"] == APPLY_AURA:
        effects[int(r["SpellID"])].append(r)
shapeshift = {int(r["SpellID"]) for r in rows("SpellShapeshift.csv")
              if r["ShapeshiftMask_0"] != "0" or r["ShapeshiftMask_1"] != "0"}


def add(stats, key, value):
    if value:
        stats[key] = stats.get(key, 0) + value


def spell_stats(stats, spell):
    """Add what an aura spell gives its bearer."""
    auras = {int(e["EffectAura"]) for e in effects[spell]}
    for e in effects[spell]:
        aura, misc = int(e["EffectAura"]), int(e["EffectMiscValue_0"])
        value = int(float(e["EffectBasePoints"])) + (1 if int(e["EffectDieSides"]) >= 1 else 0)
        if aura == MOD_STAT:
            for stat, key in STAT.items():
                if misc in (stat, -1):
                    add(stats, key, value)
        elif aura == MOD_RESISTANCE:
            for bit, key in SCHOOL_RESISTANCE.items():
                if misc & bit:
                    add(stats, key, value)
        elif aura == MOD_DAMAGE_DONE and misc in SCHOOL_DAMAGE:
            add(stats, SCHOOL_DAMAGE[misc], value)
        elif aura == MOD_HEALING_DONE and misc == MAGIC:
            add(stats, "HEAL", value)
        elif aura == MOD_ATTACK_POWER:
            add(stats, "FERALAP" if spell in shapeshift else "AP", value)
        elif aura == MOD_RANGED_ATTACK_POWER and MOD_ATTACK_POWER not in auras:
            add(stats, "RAP", value)
        elif aura == MOD_SPELL_CRIT_CHANCE_SCHOOL and misc == MAGIC:
            add(stats, "SPELLCRIT", value)
        elif aura == MOD_TARGET_RESISTANCE and misc == MAGIC_BUT_HOLY:
            add(stats, "SPELLPEN", -value)
        elif aura == MOD_POWER_REGEN and misc == 0:
            add(stats, "MP5", value)
        elif aura == MOD_INCREASE_ENERGY and misc == 0:
            add(stats, "MANA", value)
        elif aura == PERIODIC_HEAL and int(e["EffectAuraPeriod"]) > 0:
            add(stats, "HP5", round(value * 5000 / int(e["EffectAuraPeriod"])))
        elif aura == MOD_SKILL:
            if misc == DEFENSE:
                add(stats, "DEFENSE", value)
            elif misc in skill_lines:
                add(stats, "SKILL%d" % misc, value)
            else:
                sys.exit(f"spell {spell} raises skill line {misc}, which MUI_SkillLineDB does not name")
        elif aura in SIMPLE:
            add(stats, SIMPLE[aura], value)


def packed(stats):
    def order(key):
        return (KEYS.index(key), 0) if key in KEYS else (len(KEYS), int(key[5:]))
    parts = []
    for key in sorted(stats, key=order):
        value = stats[key]
        if value:
            parts.append(f"{key}={value:.1f}" if key == "DPS" else f"{key}={value}")
    return " ".join(parts)


# ---- items
sparse = {int(r["ID"]): r for r in rows("ItemSparse.csv")}
equip = collections.defaultdict(list)
for r in rows("ItemEffect.csv"):
    if r["TriggerType"] == ON_EQUIP:
        equip[int(r["ParentItemID"])].append(int(r["SpellID"]))

items = {}
for id, r in sparse.items():
    if id >= SEASONAL_ITEMS or int(r["InventoryType"]) not in WORN:
        continue
    stats = {}
    for k in range(10):
        stat, amount = int(r[f"StatModifier_bonusStat_{k}"]), int(r[f"StatModifier_bonusAmount_{k}"])
        if stat in ITEM_MOD:
            add(stats, ITEM_MOD[stat], amount)
    for k, key in RESISTANCES.items():
        add(stats, key, int(r[f"Resistances_{k}"]))
    delay = int(r["ItemDelay"])
    damage = sum(int(r[f"MinDamage_{k}"]) + int(r[f"MaxDamage_{k}"]) for k in range(5)) / 2
    if delay and damage:
        stats["DPS"] = float(f"{damage / (delay / 1000):.1f}")
    for spell in equip[id]:
        spell_stats(stats, spell)
    items[id] = packed(stats)

# ---- enchantments and random properties
enchants = {}
for r in rows("SpellItemEnchantment.csv"):
    stats = {}
    for k in range(3):
        kind, arg, points = int(r[f"Effect_{k}"]), int(r[f"EffectArg_{k}"]), int(r[f"EffectPointsMin_{k}"])
        if kind == ENCHANT_DAMAGE:
            add(stats, "WDMG", points)
        elif kind == ENCHANT_RESISTANCE and arg in RESISTANCES:
            add(stats, RESISTANCES[arg], points)
        elif kind == ENCHANT_STAT and arg in ITEM_MOD:
            add(stats, ITEM_MOD[arg], points)
        elif kind == ENCHANT_EQUIP_SPELL:
            spell_stats(stats, arg)
    if stats:
        enchants[int(r["ID"])] = stats

properties = {}
for r in rows("ItemRandomProperties.csv"):
    stats = {}
    for k in range(5):
        for key, value in enchants.get(int(r[f"Enchantment_{k}"]), {}).items():
            add(stats, key, value)
    text = packed(stats)
    if text:
        properties[int(r["ID"])] = text

enchants = {id: text for id, text in ((id, packed(s)) for id, s in enchants.items()) if text}


def table(name, comment, data):
    out = [f"    -- {comment}", f"    {name} = {{"]
    out += [f'        [{id}] = "{data[id]}",' for id in sorted(data)]
    out.append("    },")
    return out


out = [
    "-- MUI_ItemStatDB.lua  (AUTO-GENERATED — do not edit)",
    "-- Regenerate via: python tools/itemstats_export.py <db2 dir>",
    "--",
    "-- What an item gives the character wearing it, by id, for the item",
    "-- comparison: its own stats and \"Equip:\" effects, and those of the",
    "-- enchantment and the random property (\"of the Bear\") on it. Era has no",
    "-- function that gives an item's stats. A shield's block value is in none",
    "-- of the client's tables; the tooltip shows it.",
    "--",
    "--   MUI_ItemStatDB:GetStats(link)   stat key -> amount, for an item link;",
    "--                                   nil for an item it does not know",
    "--                                   (Season of Discovery's)",
    "--",
]
out += textwrap.wrap(" ".join(KEYS) + " SKILL<skill line id> (a weapon skill, Fishing ...)", 76,
                     initial_indent="-- Keys: ", subsequent_indent="--       ")
out += [
    'object "ItemStatDB" {',
    "    GetStats = function(self, link)",
    '        local item, enchant, property = link:match("item:(%d+):(%d*):%d*:%d*:%d*:%d*:(%-?%d*)")',
    "        local own = self._items[tonumber(item)]",
    "        if not own then return end",
    "        local stats = {}",
    "        self:_Add(stats, own)",
    "        self:_Add(stats, self._enchants[tonumber(enchant)])",
    "        self:_Add(stats, self._properties[tonumber(property)])",
    "        return stats",
    "    end;",
    "",
    "    _Add = function(self, stats, packed)",
    '        for key, value in (packed or ""):gmatch("(%S+)=(%S+)") do',
    "            stats[key] = (stats[key] or 0) + tonumber(value)",
    "        end",
    "    end;",
    "",
]
out += table("_items", "[item id] = \"KEY=amount ...\"", items)
out.append("")
out += table("_enchants", "[enchantment id] = \"KEY=amount ...\"", enchants)
out.append("")
out += table("_properties", "[random property id] = \"KEY=amount ...\"", properties)
out += ["}", ""]

with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out))
print(f"{len(items)} items, {len(enchants)} enchantments, {len(properties)} random properties"
      f" -> {os.path.relpath(OUT, ROOT)} ({os.path.getsize(OUT)} bytes)")
