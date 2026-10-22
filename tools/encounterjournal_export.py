"""
Port NewEra's Adventure Guide dataset into MUI_DB/MUI_EncounterJournalDB.lua
and copy the journal art it ships into assets/textures/skin/adventureguide/.

    python tools/encounterjournal_export.py <db2 dir> [path to NewEra]
                                            [--retail <dir> --era <dir>]

<db2 dir> holds CSV exports of the client build's tables (wago.tools/db2, the
build in .build.info): SpellEffect, SpellMisc, SpellDuration, SpellRadius,
SpellRange, SpellAuraOptions, SpellTargetRestrictions, ItemSparse,
CreatureDisplayInfo, CreatureModelData.

With --retail and --era (folders of <lang>/<Table>.csv of a retail build:
JournalInstance, JournalEncounter, JournalEncounterSection,
JournalEncounterCreature; and of the Era build: SpellName, GlobalStrings,
ItemSparse) it also writes the journal's text in every client language into
MUI_DB/Locale (the end of this file).

Needs lupa (the source files are Lua and are evaluated, not parsed).

What changes on the way:
  * NewEra's overlays (vanilla abilities, generated portraits) are merged
    into the data;
  * every creature gets the model viewer's camera for it, from the size of
    its model (see camera());
  * a boss's sections go from sibling / child ids to nested lists;
  * the ability texts are retail's, with $<spell><variable> placeholders the
    client fills in from its spell data. Era's client has no journal to do
    that, so they are filled in here from Era's own spell tables (nearly all
    of the spells are vanilla ones). Where Era has no value the phrase goes;
  * each instance gets its MUI_DungeonMapDB map and MUI_DungeonDB area, the
    dungeons their continent, the raids their size;
  * the classic raids, which retail's journal leaves without a description,
    get the ones of Blizzard's original Game Guide (RAID_DESCRIPTIONS);
  * the loot keeps NewEra's drop chances and gets its item names and
    qualities, so a list reads before the client has the items cached.

One texture is not NewEra's: instances-bg.blp is retail's tier background
sheet (file 2175177, tools/casc/casc-extract.ps1), which NewEra replaces with
the low-resolution file of the older journal.
"""
import csv
import os
import re
import shutil
import sys

from lupa.lua51 import LuaRuntime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARGS = sys.argv[1:]
LOCALIZE = {}
for flag in ("--retail", "--era"):
    if flag in ARGS:
        at = ARGS.index(flag)
        LOCALIZE[flag[2:]] = ARGS[at + 1]
        del ARGS[at:at + 2]
if not ARGS:
    sys.exit(__doc__)
DB2 = ARGS[0]
NEWERA = ARGS[1] if len(ARGS) > 1 else os.path.join(os.path.dirname(ROOT), "NewEra")
SRC = os.path.join(NEWERA, "EncounterJournal")
SRC_ART = os.path.join(NEWERA, "Art", "EncounterJournal")
OUT = os.path.join(ROOT, "MUI_DB", "MUI_EncounterJournalDB.lua")
ART_OUT = os.path.join(ROOT, "assets", "textures", "skin", "adventureguide")

DEFAULT_PORTRAIT = 521744
QUESTION_MARK = 134400

# Journal instance -> { MUI_DungeonMapDB code, the floor its map opens on,
# MUI_DungeonDB area }.
MAPS = {
    226: ("RFC", 1, 2437), 240: ("WC", 1, 718), 63: ("DM", 1, 1581), 64: ("SFK", 1, 209),
    227: ("BFD", 1, 719), 231: ("Gnomer", 1, 721), 238: ("Stocks", 1, 717), 234: ("RFK", 1, 491),
    316: ("SM", 5, 796), 239: ("Ulda", 1, 1337), 233: ("RFD", 1, 722), 232: ("Mara", 1, 2100),
    241: ("ZF", 1, 1176), 246: ("Scholo", 1, 2057), 228: ("BRD", 1, 1584), 237: ("ST", 1, 1477),
    229: ("LBRS", 1, 1583), 230: ("DM2", 2, 2557), 1276: ("DM2", 5, 2557), 1277: ("DM2", 1, 2557),
    236: ("Strat", 1, 2017), 1292: ("Strat", 2, 2017),
    76: ("ZG", 1, 1977), 741: ("MC", 1, 2717), 742: ("BWL", 1, 2677), 743: ("AQ20", 1, 3429),
    744: ("AQ40", 2, 3428), 754: ("Nax", 5, 3456), 760: ("Onyxia", 1, 2159),
}
KALIMDOR = {226, 240, 227, 234, 233, 232, 241, 230, 1276, 1277}
KALIMDOR_MAP, EASTERN_KINGDOMS_MAP = 1414, 1415          # world map ids
# The raids in the order they are progressed through, and their size.
RAIDS = [(741, 40), (760, 40), (742, 40), (76, 20), (743, 20), (744, 40), (754, 40)]

# The classic raids have no description in retail's journal, nor in any other
# table of the game: theirs are those of Blizzard's original Game Guide
# (2004-06), as warcraft.wiki.gg/wiki/Game_Guide/Raid_Areas keeps them, with
# the guide's "Nefarion" spelled right.
RAID_DESCRIPTIONS = {
    741: ("The Molten Core lies at the very bottom of Blackrock Depths. It is the heart of Blackrock "
          "Mountain and the exact spot where, long ago in a desperate bid to turn the tide of the dwarven "
          "civil war, Emperor Thaurissan summoned the elemental Firelord, Ragnaros, into the world. Though "
          "the fire lord is incapable of straying far from the blazing Core, it is believed that his "
          "elemental minions command the Dark Iron dwarves, who are in the midst of creating armies out of "
          "living stone. The burning lake where Ragnaros lies sleeping acts as a rift connecting to the "
          "plane of fire, allowing the malicious elementals to pass through. Chief among Ragnaros' agents "
          "is Majordomo Executus - for this cunning elemental is the only one capable of calling the "
          "Firelord from his slumber."),
    760: ("Onyxia is the daughter of the mighty dragon Deathwing, and sister of the scheming Nefarian Lord "
          "of Blackrock Spire. It is said that Onyxia delights in corrupting the mortal races by meddling "
          "in their political affairs. To this end it is believed that she takes on various humanoid forms "
          "and uses her charm and power to influence delicate matters between the different races. Some "
          "believe that Onyxia has even assumed an alias once used by her father - the title of the royal "
          "House Prestor. When not meddling in mortal concerns, Onyxia resides in a fiery cave below the "
          "Dragonmurk, a dismal swamp located within Dustwallow Marsh. There she is guarded by her kin, "
          "the remaining members of the insidious Black Dragon Flight."),
    742: ("Blackwing Lair can be found at the very height of Blackrock Spire. It is there in the dark "
          "recesses of the mountain's peak that Nefarian has begun to unfold the final stages of his plan "
          "to destroy Ragnaros once and for all and lead his army to undisputed supremacy over all the "
          "races of Azeroth."),
    743: ("During the final hours of the War of the Shifting Sands, the combined forces of the night elves "
          "and the four dragonflights drove the battle to the very heart of the qiraji empire, to the "
          "fortress city of Ahn'Qiraj. Yet at the city gates, the armies of Kalimdor encountered a "
          "concentration of silithid war drones more massive than any they had encountered before. "
          "Ultimately the silithid and their qiraji masters were not defeated, but merely imprisoned "
          "inside a magical barrier, and the war left the cursed city in ruins. A thousand years have "
          "passed since that day, but the qiraji forces have not been idle. A new and terrible army has "
          "been spawned from the hives, and the ruins of Ahn'Qiraj are teeming once again with swarming "
          "masses of silithid and qiraji. This threat must be eliminated, or else all of Azeroth may fall "
          "before the terrifying might of the new qiraji army."),
    744: ("At the heart of Ahn'Qiraj lies an ancient temple complex. Built in the time before recorded "
          "history, it is both a monument to unspeakable gods and a massive breeding ground for the qiraji "
          "army. Since the War of the Shifting Sands ended a thousand years ago, the Twin Emperors of the "
          "qiraji empire have been trapped inside their temple, barely contained behind the magical "
          "barrier erected by the bronze dragon Anachronos and the night elves. Now that the Scepter of "
          "the Shifting Sands has been reassembled and the seal has been broken, the way into the inner "
          "sanctum of Ahn'Qiraj is open. Beyond the crawling madness of the hives, beneath the Temple of "
          "Ahn'Qiraj, legions of qiraji prepare for invasion. They must be stopped at all costs before "
          "they can unleash their voracious insectoid armies on Kalimdor once again, and a second War of "
          "the Shifting Sands breaks loose!"),
    754: ("Floating above the Plaguelands, the necropolis known as Naxxramas serves as the seat of one of "
          "the Lich King's most powerful officers, the dreaded lich Kel'Thuzad. Horrors of the past and "
          "new terrors yet to be unleashed are gathering inside the necropolis as the Lich King's servants "
          "prepare their assault. Soon the Scourge will march again..."),
}

ART = [
    ("522972-ui-encounterjournaltextures.blp", "journal.blp"),
    ("522973-ui-encounterjournaltextures-tile.blp", "journal-tile.blp"),
    ("521750-ui-ej-journalbg.blp", "journal-bg.blp"),
    ("527422-ui-ej-lorebg-default.blp", "lore-default.blp"),
    ("527690-ui-ej-bossmodelpaperframe.blp", "model-frame.blp"),
    ("521743-ui-ej-background-default.blp", "model-bg-default.blp"),
    ("521744-ui-ej-boss-default.blp", "boss-default.blp"),
    ("521753-ui-ej-portraiticon.blp", "portrait.blp"),
    ("7494373-uicombattimelinewarningicons.blp", "flags.blp"),
]


# ---------------------------------------------------------------------------
# sources
# ---------------------------------------------------------------------------
def table(name, key=None):
    path = os.path.join(DB2, name + ".csv")
    with open(path, encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    if key is None:
        return rows
    out = {}
    for row in rows:
        if row.get("DifficultyID", "0") == "0":
            out.setdefault(int(row[key]), row)
    return out


def seq(t):
    return [t[i] for i in range(1, len(t) + 1)] if t is not None else []


lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("NE = { ej = { Preload = function() end },"
            " tex = { localFiles = {}, RegisterLocal = function(key, path) NE.tex.localFiles[key] = path end } }")
for name in ("Data.lua", "PortraitOverrides.lua", "AbilitiesEra.lua"):
    with open(os.path.join(SRC, name), encoding="utf-8") as f:
        chunk = lua.globals().loadstring(f.read(), name)
    chunk()
ne = lua.globals().NE.ej

EFFECTS = {}
for row in table("SpellEffect"):
    if row["DifficultyID"] == "0":
        EFFECTS.setdefault(int(row["SpellID"]), {})[int(row["EffectIndex"]) + 1] = row
MISC = table("SpellMisc", "SpellID")
DURATION = {int(r["ID"]): int(r["Duration"]) for r in table("SpellDuration")}
RADIUS = {int(r["ID"]): float(r["Radius"]) for r in table("SpellRadius")}
RANGE = {int(r["ID"]): float(r["RangeMax_0"]) for r in table("SpellRange")}
AURA = table("SpellAuraOptions", "SpellID")
TARGETS = table("SpellTargetRestrictions", "SpellID")
ITEMS = {int(r["ID"]): r for r in table("ItemSparse")}
DISPLAYS = {int(r["ID"]): int(r["ModelID"]) for r in table("CreatureDisplayInfo")}
MODELS = {int(r["ID"]): [float(r[f"GeoBox_{i}"]) for i in range(6)] for r in table("CreatureModelData")}


# ---------------------------------------------------------------------------
# $<spell><variable> placeholders
# ---------------------------------------------------------------------------
def num(value):
    value = round(value, 1)
    return str(int(value)) if value == int(value) else str(value)


def effect(spell, index):
    return EFFECTS.get(spell, {}).get(int(index or 1))


def points(spell, index):
    """min, max of an effect's value; None where the tooltip's number would
    depend on the caster's level."""
    e = effect(spell, index)
    if not e or float(e["EffectRealPointsPerLevel"]) != 0:
        return None
    base, die = int(e["EffectBasePoints"]), int(e["EffectDieSides"])
    low = base + (1 if die >= 1 else 0)
    high = base + die
    return abs(low), abs(high)


def duration_ms(spell):
    m = MISC.get(spell)
    ms = m and DURATION.get(int(m["DurationIndex"]))
    return ms if ms and ms > 0 else None


def value(spell, var, index):
    """The number behind a placeholder, or None."""
    if var in "sSmM":
        p = points(spell, index)
        if not p or p[1] == 0:
            return None
        if var == "m":
            return p[0]
        if var == "M":
            return p[1]
        return p if p[0] != p[1] else p[0]
    if var == "d":
        ms = duration_ms(spell)
        return ms and ms / 1000.0
    if var in "tT":
        e = effect(spell, index)
        ms = e and int(e["EffectAuraPeriod"])
        return ms / 1000.0 if ms else None
    if var in "aA":
        e = effect(spell, index)
        if not e:
            return None
        order = ("EffectRadiusIndex_1", "EffectRadiusIndex_0") if var == "A" else ("EffectRadiusIndex_0", "EffectRadiusIndex_1")
        for column in order:
            r = RADIUS.get(int(e[column]))
            if r:
                return r
        return None
    if var == "x":
        e = effect(spell, index)
        return (e and int(e["EffectChainTargets"])) or None
    if var in "eE":
        e = effect(spell, index)
        return (e and float(e["EffectAmplitude"])) or None
    if var in "uU":
        a = AURA.get(spell)
        return (a and int(a["CumulativeAura"])) or None
    if var == "n":
        a = AURA.get(spell)
        return (a and int(a["ProcCharges"])) or None
    if var == "h":
        a = AURA.get(spell)
        chance = a and int(a["ProcChance"])
        return chance if chance and chance <= 100 else None
    if var == "i":
        t = TARGETS.get(spell)
        return (t and int(t["MaxTargets"])) or None
    if var == "r":
        m = MISC.get(spell)
        return (m and RANGE.get(int(m["RangeIndex"]))) or None
    if var == "o":
        p, ms = points(spell, index), duration_ms(spell)
        e = effect(spell, index)
        period = e and int(e["EffectAuraPeriod"])
        if not p or not ms or not period or p[0] != p[1]:
            return None
        return p[0] * (ms // period)
    return None


def duration_text(seconds):
    if seconds < 60:
        return num(seconds) + " sec"
    if seconds < 3600:
        return num(seconds / 60) + " min"
    hours = seconds / 3600
    return num(hours) + (" hour" if hours == 1 else " hrs")


TOKEN = re.compile(r"\$(\d+)([a-zA-Z])(\d*)")
EXPRESSION = re.compile(r"\$\{([^}]*)\}")
GAP = "\x00"                      # stands in for a placeholder with no value
stats = {"filled": 0, "dropped": 0}
token_log = None                  # while set: placeholder -> the value fill gave it (None: dropped)

# Retail has reworked some of these spells since: an effect that is a
# percentage or a damage amount in its text can be something else in Era's
# data. A number is only used where Era's effect is of the kind the words
# around the placeholder speak of.
AURA_EFFECTS = {6, 27, 35}
PERCENT_AURAS = {31, 32, 33, 47, 49, 51, 52, 54, 55, 57, 65, 71, 79, 80, 87, 88, 101, 110,
                 118, 129, 133, 137, 138, 140, 142, 166}
DAMAGE_EFFECTS = {2, 7, 9}
DAMAGE_AURAS = {3, 15, 43, 53}
ABSORB_AURA = 69


def fits(spell, index, before, after):
    e = effect(spell, index)
    if not e:
        return False
    kind, aura = int(e["Effect"]), int(e["EffectAura"])
    is_aura = kind in AURA_EFFECTS
    if after.startswith("%"):
        return is_aura and aura in PERCENT_AURAS
    if re.match(r"\s+(?:[A-Z][a-z]+\s+)?damage\b", after):
        if re.search(r"absorb\w*(?:\s+up\s+to)?\s*$", before):
            return is_aura and aura == ABSORB_AURA
        return kind in DAMAGE_EFFECTS or (is_aura and aura in DAMAGE_AURAS)
    return True


def fill_token(match, mismatched=()):
    spell, var, index = int(match.group(1)), match.group(2), match.group(3)
    v = value(spell, var, index)
    if v is not None and var in "sSmMo":
        text = match.string
        if spell in mismatched or not fits(spell, index, text[:match.start()], text[match.end():]):
            v = None
    if token_log is not None:
        token_log[spell, var, index] = v
    if v is None:
        stats["dropped"] += 1
        return GAP
    stats["filled"] += 1
    if var == "d":
        return duration_text(v)
    if isinstance(v, tuple):
        return f"{num(v[0])} to {num(v[1])}"
    return num(v)


def fill_expression(match):
    def operand(m):
        v = value(int(m.group(1)), m.group(2), m.group(3))
        if v is None or isinstance(v, tuple):
            raise ValueError
        return repr(float(v))

    try:
        source = TOKEN.sub(operand, match.group(1))
        if not re.fullmatch(r"[\d\s.+\-*/()]+", source):
            raise ValueError
        result = eval(source, {"__builtins__": {}})
    except (ValueError, SyntaxError, ZeroDivisionError):
        if token_log is not None:
            token_log["expr", match.group(1)] = None
        stats["dropped"] += 1
        return GAP
    if token_log is not None:
        token_log["expr", match.group(1)] = result
    stats["filled"] += 1
    return num(result)


# What to do with the words around a placeholder that has no value.
G = re.escape(GAP)
REWORD = [
    (rf"\s+for\s+{G}\s+or\s+until\b", " until"),
    (rf"\s+for\s+{G}\s+(?:[A-Z][a-z]+\s+)?damage\b", ""),
    (rf"\s+(?:that|which)\s+lasts\s+{G}", ""),
    (rf"\s+(?:for|lasting|lasts|over|for up to|for the next)\s+{G}(?=[\s.,;)]|$)", ""),
    (rf"\s+(?:every|each)\s+{G}\s+sec(?:onds?)?(?:\.(?=\s+[a-z]))?", ""),
    (rf"\s+after\s+{G}\s+sec(?:onds?)?(?:\.(?=\s+[a-z]))?", " after a while"),
    (rf"\s+within an area\s+{G}\s+yards wide", " in an area"),
    (rf"\s+within\s+{G}\s+(?:yards|yds\.?|yard)", " nearby"),
    (rf",?\s+affecting up to\s+{G}\s+\w+", ""),
    (rf"\bup to\s+{G}\s+", ""),
    (rf"\s+and\s+(?:an\s+)?additional\s+{G}\s+(?:[A-Z][a-z]+\s+)?damage\b", " and further damage"),
    (rf"\s+by\s+(?:an additional\s+)?{G}%?(?=[\s.,;)]|$)", ""),
    (rf"\s+(?:equal to|for|of)\s+{G}%\s+of\b", " for a part of"),
    (rf"\bheals\s+{G}%\s+health\b", "regains health"),
    (rf"{G}%\s+of\b", "part of"),
    (rf"{G}%?\s*", ""),
]


def fill(text):
    if not text:
        return ""
    text = EXPRESSION.sub(fill_expression, text)
    # A period the text speaks of that Era's effect does not have: the
    # spell's effects are not laid out as the text assumes.
    mismatched = {int(m.group(1)) for m in TOKEN.finditer(text)
                  if m.group(2) in "tT" and int(m.group(1)) in EFFECTS
                  and value(int(m.group(1)), m.group(2), m.group(3)) is None}
    text = TOKEN.sub(lambda m: fill_token(m, mismatched), text)
    if GAP in text:
        for pattern, replacement in REWORD:
            text = re.sub(pattern, replacement, text)
    assert "$" not in text, text
    text = re.sub(r"[ \t]{2,}", " ", text)
    text = re.sub(r"\s+([.,;])", r"\1", text)
    return text.strip()


def fill_logged(text):
    """fill(text), and what each of its placeholders came to."""
    global token_log
    token_log = {}
    try:
        return fill(text), token_log
    finally:
        token_log = None


# ---------------------------------------------------------------------------
# data
# ---------------------------------------------------------------------------
def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\r", "").replace("\n", "\\n") + '"'


art_files = {"buttons": set(), "lore": set(), "backdrops": set(), "bosses": set()}
missing_art = []


def art(kind, name, source_dir, source_name):
    """Note a texture for copying; False when NewEra does not ship it."""
    if not os.path.isfile(os.path.join(SRC_ART, source_dir, source_name)):
        missing_art.append(f"{kind}/{name}")
        return False
    art_files[kind].add((os.path.join(source_dir, source_name), name))
    return True


def button_source(fdid):
    for f in os.listdir(SRC_ART):
        if f.startswith(f"{fdid}-ejbutton-"):
            return f
    return f"{fdid}.blp"


def portrait(creature):
    file, display = creature.file, creature.display
    if file == display and art("bosses", f"d{display}.blp", "BossesGen", f"{display}.blp"):
        return f'"d{display}"'
    if file and file != DEFAULT_PORTRAIT and art("bosses", f"{file}.blp", "Bosses", f"{file}.blp"):
        return str(file)
    return None


# The model viewer looks at a creature level, CAMERA_HEIGHT of the way up it,
# from CAMERA_DISTANCE times what has to fit in the view: the model's height,
# or FIT_WIDTH of its width where that is more. The width is the larger of
# the two horizontal extents (the model can be turned), and counts as three
# times the height at most: a long flat creature would show too small
# otherwise.
# The height is taken from the ground up: what a box has under it is a tail
# or roots, or the padding of a box cut too large (Garr's is a cube).
#
# NewEra's own table (ModelCam.lua: 0.9 + 0.52 x the width, a seventh of the
# height up) stands closer and lower than this, and the closer the taller
# the creature is.
CAMERA_DISTANCE = 1.5
CAMERA_HEIGHT = 0.25
FIT_WIDTH = 0.8


def camera(display):
    """Distance and eye height of the model viewer's camera for a creature
    display, from its model's bounding box; None where the client's tables
    have no model for it."""
    box = MODELS.get(DISPLAYS.get(display))
    if not box:
        return None
    width = max(box[3] - box[0], box[4] - box[1])
    base = max(box[2], 0)
    height = box[5] - base
    fit = max(height, FIT_WIDTH * min(width, 3 * height))
    return round(CAMERA_DISTANCE * fit, 1), round(base + CAMERA_HEIGHT * height, 2)


icon_stats = {"spell": 0, "retail": 0, "none": 0}
# Icons of the retail data that are not in the Era client.
NOT_IN_ERA = {399040, 432002}


def icon(section):
    spell = int(section.spell or 0)
    retail = int(section.icon or 0)
    if retail and retail not in NOT_IN_ERA:
        icon_stats["retail"] += 1
        return retail
    m = MISC.get(spell)
    if m and int(m["SpellIconFileDataID"]) > 0:
        icon_stats["spell"] += 1
        return int(m["SpellIconFileDataID"])
    if retail or spell:
        icon_stats["none"] += 1
        return QUESTION_MARK
    return None


def section_tree(encounter):
    by_id = {int(s.id): s for s in seq(encounter.sections)}

    def chain(first):
        out, sid, seen = [], int(first or 0), set()
        while sid and sid in by_id and sid not in seen:
            seen.add(sid)
            s = by_id[sid]
            display = int(s.cdisp or 0)
            text, tokens = fill_logged(s.body)
            node = {"id": sid, "title": s.title, "text": text, "icon": icon(s),
                    "flags": int(s.flags or 0), "display": display,
                    "cam": camera(display) if display else None,
                    "sub": chain(s.child),
                    "raw": s.body or "", "tokens": tokens, "spell": int(s.spell or 0)}
            out.append(node)
            sid = int(s.sib or 0)
        return out

    tree = chain(encounter.rootSection)

    def count(nodes):
        return sum(1 + count(n["sub"]) for n in nodes)

    assert count(tree) == len(by_id), (encounter.name, count(tree), len(by_id))
    return tree


item_names = {}


def loot(encounter):
    out = []
    for entry in seq(encounter.loot):
        item = ITEMS.get(int(entry.id))
        if not item:
            continue            # not an item of this client
        item_names[int(entry.id)] = (item["Display_lang"], int(item["OverallQualityID"]))
        out.append((int(entry.id), float(entry.pct or 0)))
    return out


raid_order = {inst: i for i, (inst, _) in enumerate(RAIDS)}
raid_size = dict(RAIDS)
instances = []
for inst in seq(ne.DATA.instances):
    code, floor, area = MAPS[int(inst.id)]
    encounters = []
    for e in seq(inst.encounters):
        creatures = []
        for c in seq(e.creatures):
            creatures.append({"name": c.name, "display": int(c.display), "cam": camera(int(c.display))})
        desc, tokens = fill_logged(e.desc)
        encounters.append({
            "id": int(e.id), "name": e.name, "desc": desc,
            "portrait": portrait(e.creatures[1]),
            "creatures": creatures, "loot": loot(e), "sections": section_tree(e),
            "raw": e.desc or "", "tokens": tokens,
        })
    art("buttons", f"{inst.buttonFDID}.blp", "", button_source(inst.buttonFDID))
    art("lore", f"{inst.loreFDID}.blp", "Lore", f"{inst.loreFDID}.blp")
    art("backdrops", f"{inst.bgFDID}.blp", "Backdrops", f"{inst.bgFDID}.blp")
    raw = inst.desc or RAID_DESCRIPTIONS.get(int(inst.id), "")
    desc, tokens = fill_logged(raw)
    instances.append({
        "id": int(inst.id), "name": inst.name, "raid": bool(inst.isRaid),
        "desc": desc, "raw": raw, "tokens": tokens, "own_desc": not inst.desc,
        "map": code, "floor": floor, "area": area,
        "button": int(inst.buttonFDID), "lore": int(inst.loreFDID), "bg": int(inst.bgFDID),
        "encounters": encounters,
    })
instances.sort(key=lambda i: (i["raid"], raid_order.get(i["id"], 0)))


# ---------------------------------------------------------------------------
# output
# ---------------------------------------------------------------------------
def cam_fields(cam):
    return f"dist = {num(cam[0])}, eye = {round(cam[1], 2):g}"


def emit_sections(nodes, indent, out):
    pad = "    " * indent
    for n in nodes:
        fields = [f"id = {n['id']}", f"title = {lua_str(n['title'])}"]
        if n["icon"]:
            fields.append(f"icon = {n['icon']}")
        if n["display"]:
            fields.append(f"display = {n['display']}")
        if n["cam"]:
            fields.append(cam_fields(n["cam"]))
        if n["flags"]:
            fields.append(f"flags = {n['flags']}")
        if n["text"]:
            fields.append(f"text = {lua_str(n['text'])}")
        if n["sub"]:
            out.append(f"{pad}{{ {', '.join(fields)}, sub = {{")
            emit_sections(n["sub"], indent + 1, out)
            out.append(f"{pad}}} }},")
        else:
            out.append(f"{pad}{{ {', '.join(fields)} }},")


lines = []
for inst in instances:
    head = [f"id = {inst['id']}", f"name = {lua_str(inst['name'])}"]
    if inst["raid"]:
        head.append("raid = true")
        head.append(f"players = {raid_size[inst['id']]}")
    else:
        head.append(f"continent = {KALIMDOR_MAP if inst['id'] in KALIMDOR else EASTERN_KINGDOMS_MAP}")
    head.append(f"map = {lua_str(inst['map'])}, floor = {inst['floor']}, area = {inst['area']}")
    head.append(f"button = {inst['button']}, lore = {inst['lore']}, bg = {inst['bg']}")
    lines.append(f"            {{ {', '.join(head)},")
    lines.append(f"              desc = {lua_str(inst['desc'])},")
    lines.append("              encounters = {")
    for e in inst["encounters"]:
        fields = [f"id = {e['id']}", f"name = {lua_str(e['name'])}"]
        if e["portrait"]:
            fields.append(f"portrait = {e['portrait']}")
        lines.append(f"                {{ {', '.join(fields)},")
        if e["desc"]:
            lines.append(f"                  desc = {lua_str(e['desc'])},")
        creatures = []
        for c in e["creatures"]:
            cf = [f"name = {lua_str(c['name'])}", f"display = {c['display']}"]
            if c["cam"]:
                cf.append(cam_fields(c["cam"]))
            creatures.append("{ " + ", ".join(cf) + " }")
        lines.append(f"                  creatures = {{ {', '.join(creatures)} }},")
        if e["loot"]:
            pairs = ", ".join(f"{i}, {num(p)}" for i, p in e["loot"])
            lines.append(f"                  loot = {{ {pairs} }},")
        if e["sections"]:
            lines.append("                  sections = {")
            emit_sections(e["sections"], 5, lines)
            lines.append("                  },")
        lines.append("                },")
    lines.append("              },")
    lines.append("            },")

item_lines = []
row = []
for item_id in sorted(item_names):
    name, quality = item_names[item_id]
    row.append(f"[{item_id}] = {{ {lua_str(name)}, {quality} }},")
    if len(row) == 3:
        item_lines.append("            " + " ".join(row))
        row = []
if row:
    item_lines.append("            " + " ".join(row))

HEADER = '''-- EncounterJournalDB: the Adventure Guide's dungeons and raids, their bosses,
-- abilities and loot. Era's client has no journal data of its own.
-- GENERATED by tools/encounterjournal_export.py from NewEra's dataset (retail's
-- journal tables with vanilla ability lists and AtlasLoot's drop chances
-- added) - don't edit by hand.
--
-- instance  = { id, name, raid?, players? (raid size), continent? (a dungeon's:
--               its world map id),
--               map, floor (MUI_DungeonMapDB), area (MUI_DungeonDB),
--               button, lore, bg (texture ids under the module's art folder),
--               desc, encounters }
-- encounter = { id, name, desc?, portrait? (texture id, "d<display id>" for a
--               generated one; none: the default plate),
--               creatures = { { name, display, dist?, eye? (model camera) } },
--               loot = { item id, drop chance %, item id, ... },
--               sections = { section } }
-- section   = { id, title, text?, icon? (file id), display? (creature display
--               id, for a creature's header; dist?, eye? as a creature's),
--               flags? (bits: tank, damage,
--               healer, heroic, deadly, important, interruptible, magic,
--               curse, poison, disease, enrage, mythic, bleed), sub? }
-- _items[item id] = { name (enUS), quality }
-- MUI_DB/Locale puts the text in the client's language (Localize).

object "EncounterJournalDB" {
    -- The dungeons (raid = false) or the raids, in display order.
    GetInstances = function(self, raid)
        local out = {}
        for _, instance in ipairs(self._instances) do
            if (instance.raid or false) == raid then out[#out + 1] = instance end
        end
        return out
    end;

    GetInstance = function(self, id)
        return self._byId[id]
    end;

    -- instance, encounter of the boss a dungeon map shows with this creature
    -- display; nil when the journal has none on that map.
    FindByDisplay = function(self, mapCode, display)
        local hit = self._byDisplay[mapCode .. ":" .. display]
        if hit then return hit[1], hit[2] end
    end;

    -- name (enUS), quality of a loot item, known without asking the client.
    GetItem = function(self, itemId)
        local item = self._items[itemId]
        if item then return item[1], item[2] end
    end;

    -- The text in the client's language, from MUI_DB/Locale: instances[id]
    -- and encounters[id] = { name, desc, creatures = { [i] = name } },
    -- sections[id] = { title, text }, items[id] = name.
    Localize = function(self, text)
        local function localizeSections(list)
            for _, s in ipairs(list or {}) do
                local t = text.sections[s.id]
                if t then s.title, s.text = t.title or s.title, t.text or s.text end
                localizeSections(s.sub)
            end
        end
        for _, instance in ipairs(self._instances) do
            local t = text.instances[instance.id]
            if t then instance.name, instance.desc = t.name or instance.name, t.desc or instance.desc end
            for _, encounter in ipairs(instance.encounters) do
                t = text.encounters[encounter.id]
                if t then
                    encounter.name, encounter.desc = t.name or encounter.name, t.desc or encounter.desc
                    for i, name in pairs(t.creatures or {}) do encounter.creatures[i].name = name end
                end
                localizeSections(encounter.sections)
            end
        end
        for id, name in pairs(text.items) do
            if self._items[id] then self._items[id][1] = name end
        end
    end;

    __init = function(self)
        self._instances = {
'''

FOOTER = '''        }

        self._byId, self._byDisplay = {}, {}
        for _, instance in ipairs(self._instances) do
            self._byId[instance.id] = instance
            for _, encounter in ipairs(instance.encounters) do
                for _, creature in ipairs(encounter.creatures) do
                    local key = instance.map .. ":" .. creature.display
                    if not self._byDisplay[key] then
                        self._byDisplay[key] = { instance, encounter }
                    end
                end
            end
        end
    end;
}
'''

with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write(HEADER)
    f.write("\n".join(lines))
    f.write("\n        }\n\n        self._items = {\n")
    f.write("\n".join(item_lines))
    f.write("\n")
    f.write(FOOTER)

os.makedirs(ART_OUT, exist_ok=True)
copied = 0
for source, target in ART:
    shutil.copyfile(os.path.join(SRC_ART, source), os.path.join(ART_OUT, target))
    copied += 1
for kind, files in art_files.items():
    os.makedirs(os.path.join(ART_OUT, kind), exist_ok=True)
    for source, target in sorted(files):
        shutil.copyfile(os.path.join(SRC_ART, source), os.path.join(ART_OUT, kind, target))
        copied += 1

encounters = sum(len(i["encounters"]) for i in instances)
print(f"{len(instances)} instances, {encounters} encounters, {len(item_names)} loot items -> {OUT}")
print(f"placeholders: {stats['filled']} filled, {stats['dropped']} dropped")
print(f"section icons: {icon_stats}")
print(f"{copied} textures -> {ART_OUT}")
if missing_art:
    print("not shipped by NewEra:", ", ".join(sorted(set(missing_art))))


# ---------------------------------------------------------------------------
# the text in other languages (--retail, --era): MUI_DB/Locale/<lang>.lua
# ---------------------------------------------------------------------------
# Retail's journal rows give a text where its English is ours, with each
# placeholder the value the English got (numbers and durations as Era's
# client writes them in that language). Bosses and their creatures are named
# by retail's journal, loot by Era's ItemSparse, vanilla abilities by Era's
# spell names; Questie's lookups (which have mistakes) only name what those
# don't. A text whose
# English lost a placeholder, or that no language's row can give, is ours:
# tools/i18n/<lang>.json, listed with its English in
# tools/i18n/source/encounterjournal.json.
class Missing(Exception):
    pass


def russian_plural(n, forms):
    if n != int(n):
        return forms[min(1, len(forms) - 1)]
    n = int(n)
    if n % 10 == 1 and n % 100 != 11:
        return forms[0]
    if 2 <= n % 10 <= 4 and not 12 <= n % 100 <= 14:
        return forms[min(1, len(forms) - 1)]
    return forms[-1]


def localized(template, tokens, gs):
    """A language's journal text with the English text's values, or None."""
    sep = gs.get("DECIMAL_SEPERATOR") or "."

    def number(v):
        return num(v).replace(".", sep)

    def duration(seconds):
        if seconds < 60:
            n, fmt = seconds, gs["INT_SPELL_DURATION_SEC"]
        elif seconds < 3600:
            n, fmt = seconds / 60, gs["INT_SPELL_DURATION_MIN"]
        else:
            n, fmt = seconds / 3600, gs["INT_SPELL_DURATION_HOURS"]
        return fmt.replace("%d", number(n))

    def expression(m):
        v = tokens.get(("expr", m.group(1)))
        if v is None:
            raise Missing
        return number(v)

    def token(m):
        key = (int(m.group(1)), m.group(2), m.group(3))
        v = tokens.get(key)
        if v is None or isinstance(v, tuple):
            raise Missing
        return duration(v) if key[1] == "d" else number(v)

    def plural(m):
        before = re.findall(r"\d+(?:[.,]\d+)?", m.string[:m.start()])
        n = float(before[-1].replace(",", ".")) if before else 1
        return russian_plural(n, m.group(1).split(":"))

    try:
        text = EXPRESSION.sub(expression, template.replace("\r", ""))
        text = TOKEN.sub(token, text)
    except Missing:
        return None
    text = re.sub(r"\$l([^;]*);", plural, text)
    if "$" in text:
        return None
    return re.sub(r"[ \t]{2,}", " ", text).strip()


if LOCALIZE.get("retail") and LOCALIZE.get("era"):
    import json
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    sys.path.insert(0, os.path.join(ROOT, "tools", "questdb_export"))
    import locale_data
    import locale_export

    RETAIL, ERA = LOCALIZE["retail"], LOCALIZE["era"]
    QUESTIE = os.path.join(ROOT, "tools", "vendor", "Questie")
    I18N = os.path.join(ROOT, "tools", "i18n")

    def rows(folder, lang, name):
        with open(os.path.join(folder, lang, name + ".csv"), encoding="utf-8", newline="") as f:
            return {int(r["ID"]): r for r in csv.DictReader(f)}

    def era_strings(lang):
        with open(os.path.join(ERA, lang, "GlobalStrings.csv"), encoding="utf-8", newline="") as f:
            return {r["BaseTag"]: r["TagText_lang"] for r in csv.DictReader(f)}

    npc_english = {i: r.get("name") for i, r in locale_export.english("MUI_NpcDB.lua").items()}
    npc_by_name = {}
    for i, name in npc_english.items():
        if name:
            npc_by_name[name] = None if name in npc_by_name else i
    en_inst = rows(RETAIL, "enUS", "JournalInstance")
    en_enc = rows(RETAIL, "enUS", "JournalEncounter")
    en_sec = rows(RETAIL, "enUS", "JournalEncounterSection")
    en_creature = rows(RETAIL, "enUS", "JournalEncounterCreature")
    en_spell = {i: r["Name_lang"] for i, r in rows(ERA, "enUS", "SpellName").items()}

    def retail_encounter(instance_id, name, raw):
        """The retail encounter row of ours: same instance and name (or description)."""
        hits = [i for i, r in en_enc.items() if int(r["JournalInstanceID"]) == instance_id
                and (r["Name_lang"] == name or (raw and r["Description_lang"] == raw))]
        return hits[0] if hits else None

    def retail_creature(encounter_id, name):
        """The retail journal row of a creature of ours: same encounter and name."""
        hits = [i for i, r in en_creature.items() if int(r["JournalEncounterID"]) == encounter_id
                and r["Name_lang"] == name]
        return hits[0] if hits else None

    # each text: ("retail", table, id, column[, template, tokens]) | ("npc", id) | ("spell", id) | ours;
    # fallback: a second source, for a language the first has no text in
    plan, fallback, ours = {}, {}, {}

    def own(key, english, note):
        ours[key] = {"en": english, "note": note}

    for inst in instances:
        iid = inst["id"]
        if iid in en_inst and en_inst[iid]["Name_lang"] == inst["name"]:
            plan["i", iid, "name"] = ("retail", "JournalInstance", iid, "Name_lang")
        else:
            own(f"ej/instance/{iid}/name", inst["name"], "a dungeon or raid")
        if inst["desc"]:
            if not inst["own_desc"] and iid in en_inst and en_inst[iid]["Description_lang"] == inst["raw"]:
                plan["i", iid, "desc"] = ("retail", "JournalInstance", iid, "Description_lang", inst["tokens"])
            else:
                own(f"ej/instance/{iid}/desc", inst["desc"], f"the Adventure Guide's description of {inst['name']}")
        for e in inst["encounters"]:
            eid = e["id"]
            rid = retail_encounter(iid, e["name"], e["raw"])
            npc = eid if npc_english.get(eid) == e["name"] else npc_by_name.get(e["name"])
            # retail's journal names a boss; Questie's lookups only where it has no row
            if rid and en_enc[rid]["Name_lang"] == e["name"]:
                plan["e", eid, "name"] = ("retail", "JournalEncounter", rid, "Name_lang")
                if npc:
                    fallback["e", eid, "name"] = ("npc", npc)
            elif npc:
                plan["e", eid, "name"] = ("npc", npc)
            else:
                own(f"ej/encounter/{eid}/name", e["name"], f"a boss in {inst['name']}")
            if e["desc"]:
                if rid and e["raw"] and en_enc[rid]["Description_lang"] == e["raw"]:
                    plan["e", eid, "desc"] = ("retail", "JournalEncounter", rid, "Description_lang", e["tokens"])
                else:
                    own(f"ej/encounter/{eid}/desc", e["desc"], f"the story of {e['name']}, a boss in {inst['name']}")
            for n, c in enumerate(e["creatures"], 1):
                cid = rid and retail_creature(rid, c["name"])
                if cid:
                    plan["c", eid, n] = ("retail", "JournalEncounterCreature", cid, "Name_lang")
                    if npc_by_name.get(c["name"]):
                        fallback["c", eid, n] = ("npc", npc_by_name[c["name"]])
                elif c["name"] == e["name"] and ("e", eid, "name") in plan:
                    plan["c", eid, n] = plan["e", eid, "name"]
                    if ("e", eid, "name") in fallback:
                        fallback["c", eid, n] = fallback["e", eid, "name"]
                elif npc_by_name.get(c["name"]):
                    plan["c", eid, n] = ("npc", npc_by_name[c["name"]])
                elif c["name"] != e["name"]:
                    own(f"ej/encounter/{eid}/creature/{n}", c["name"], f"a creature of the boss fight {e['name']} in {inst['name']}")

            def walk(nodes):
                for s in nodes:
                    sid = s["id"]
                    where = f"an ability or phase of {e['name']}, a boss in {inst['name']}"
                    if sid in en_sec and en_sec[sid]["Title_lang"] == s["title"]:
                        plan["s", sid, "title"] = ("retail", "JournalEncounterSection", sid, "Title_lang")
                    elif s["spell"] and en_spell.get(s["spell"]) == s["title"]:
                        plan["s", sid, "title"] = ("spell", s["spell"])
                    else:
                        own(f"ej/section/{sid}/title", s["title"], f"the name of {where}")
                    if s["text"]:
                        lost = any(v is None for v in s["tokens"].values())
                        if not lost and sid in en_sec and en_sec[sid]["BodyText_lang"] == s["raw"]:
                            plan["s", sid, "text"] = ("retail", "JournalEncounterSection", sid, "BodyText_lang", s["tokens"])
                        # ours too where a language's row can't be filled (decided per language below)
                        if lost or ("s", sid, "text") not in plan:
                            own(f"ej/section/{sid}/text", s["text"], f"what {where} does (title: {s['title']})")
                    walk(s["sub"])

            walk(e["sections"])

    languages = list(locale_data.LANGUAGES)
    tables = {lang: {name: rows(RETAIL, lang, name) for name in
                     ("JournalInstance", "JournalEncounter", "JournalEncounterSection",
                      "JournalEncounterCreature")} for lang in languages}
    globals_by_lang = {lang: era_strings(lang) for lang in languages}
    os.makedirs(os.path.join(I18N, "source"), exist_ok=True)

    def english_of(key):
        kind, xid, field = key
        for inst in instances:
            if kind == "i" and inst["id"] == xid:
                return inst[field]
            for e in inst["encounters"]:
                if kind == "e" and e["id"] == xid:
                    return e[field]
                stack = list(e["sections"])
                while stack:
                    s = stack.pop()
                    if kind == "s" and s["id"] == xid:
                        return s[field]
                    stack.extend(s["sub"])

    # a retail text some language's row can't be filled for is ours as well
    for key, source in plan.items():
        if source[0] == "retail" and len(source) == 5:
            failing = [lang for lang in languages
                       if tables[lang][source[1]].get(source[2], {}).get(source[3])
                       and localized(tables[lang][source[1]][source[2]][source[3]], source[4], globals_by_lang[lang]) is None]
            if failing:
                kind, xid, field = key
                path = {"i": "instance", "e": "encounter", "s": "section"}[kind]
                own(f"ej/{path}/{xid}/{field}", english_of(key), f"journal text ({path} {xid})")
    with open(os.path.join(I18N, "source", "encounterjournal.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(ours, f, ensure_ascii=False, indent=1)
        f.write("\n")

    for lang in languages:
        gs = globals_by_lang[lang]
        spells = {i: r["Name_lang"] for i, r in rows(ERA, lang, "SpellName").items()}
        npcs = locale_export.npc_names(QUESTIE, RETAIL, lang, npc_english)
        # the client's own item names (Era's ItemSparse), Questie's for one it lacks
        items = {**locale_export.lookup(QUESTIE, "lookupItems", lang), **locale_export.item_names(ERA, lang)}
        mine = {}
        path = os.path.join(I18N, lang + ".json")
        if os.path.exists(path):
            mine = json.load(open(path, encoding="utf-8"))

        def source_text(source):
            if source and source[0] == "retail":
                template = tables[lang][source[1]].get(source[2], {}).get(source[3], "")
                if template:
                    return localized(template, source[4], gs) if len(source) == 5 else template.replace("\r", "").strip()
            elif source and source[0] == "npc":
                return npcs.get(source[1])
            elif source and source[0] == "spell":
                return spells.get(source[1])

        def text_for(key, own_key):
            return source_text(plan.get(key)) or source_text(fallback.get(key)) or mine.get(own_key)

        out = {"instances": {}, "encounters": {}, "sections": {}, "items": {}}
        missing = 0
        for inst in instances:
            iid = inst["id"]
            t = {}
            for field in ("name", "desc"):
                if inst[field]:
                    v = text_for(("i", iid, field), f"ej/instance/{iid}/{field}")
                    if v and v != inst[field]:
                        t[field] = v
                    elif not v:
                        missing += 1
            if t:
                out["instances"][iid] = t
            for e in inst["encounters"]:
                eid = e["id"]
                t = {}
                for field in ("name", "desc"):
                    if e[field]:
                        v = text_for(("e", eid, field), f"ej/encounter/{eid}/{field}")
                        if v and v != e[field]:
                            t[field] = v
                        elif not v:
                            missing += 1
                for n, c in enumerate(e["creatures"], 1):
                    v = text_for(("c", eid, n), f"ej/encounter/{eid}/creature/{n}")
                    if not v and c["name"] == e["name"]:
                        v = t.get("name")
                    if v and v != c["name"]:
                        t.setdefault("creatures", {})[n] = v
                if t:
                    out["encounters"][eid] = t
                stack = list(e["sections"])
                while stack:
                    s = stack.pop()
                    stack.extend(s["sub"])
                    t = {}
                    for field in ("title", "text"):
                        if s[field]:
                            v = text_for(("s", s["id"], field), f"ej/section/{s['id']}/{field}")
                            if v and v != s[field]:
                                t[field] = v
                            elif not v:
                                missing += 1
                    if t:
                        out["sections"][s["id"]] = t
        for item_id, (name, quality) in item_names.items():
            if isinstance(items.get(item_id), str) and items[item_id] != name:
                out["items"][item_id] = items[item_id]
        lines = [f"MUI_EncounterJournalDB:Localize({locale_data.loadstring(out)})"]
        locale_data.write_block(lang, "the Adventure Guide", "tools/encounterjournal_export.py", lines)
        print(f"{lang}: {len(out['sections'])} sections, {len(out['encounters'])} encounters, "
              f"{len(out['items'])} items in the language; {missing} texts still English")
    print(f"ours to translate: {len(ours)} (tools/i18n/source/encounterjournal.json)")
