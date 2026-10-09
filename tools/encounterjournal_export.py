"""
Port NewEra's Adventure Guide dataset into MUI_DB/MUI_EncounterJournalDB.lua
and copy the journal art it ships into assets/textures/skin/adventureguide/.

    python tools/encounterjournal_export.py <db2 dir> [path to NewEra]

<db2 dir> holds CSV exports of the client build's tables (wago.tools/db2, the
build in .build.info): SpellEffect, SpellMisc, SpellDuration, SpellRadius,
SpellRange, SpellAuraOptions, SpellTargetRestrictions, ItemSparse,
CreatureDisplayInfo, CreatureModelData.

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
if len(sys.argv) < 2:
    sys.exit(__doc__)
DB2 = sys.argv[1]
NEWERA = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(ROOT), "NewEra")
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
        stats["dropped"] += 1
        return GAP
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
            node = {"id": sid, "title": s.title, "text": fill(s.body), "icon": icon(s),
                    "flags": int(s.flags or 0), "display": display,
                    "cam": camera(display) if display else None,
                    "sub": chain(s.child)}
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
        encounters.append({
            "id": int(e.id), "name": e.name, "desc": fill(e.desc),
            "portrait": portrait(e.creatures[1]),
            "creatures": creatures, "loot": loot(e), "sections": section_tree(e),
        })
    art("buttons", f"{inst.buttonFDID}.blp", "", button_source(inst.buttonFDID))
    art("lore", f"{inst.loreFDID}.blp", "Lore", f"{inst.loreFDID}.blp")
    art("backdrops", f"{inst.bgFDID}.blp", "Backdrops", f"{inst.bgFDID}.blp")
    instances.append({
        "id": int(inst.id), "name": inst.name, "raid": bool(inst.isRaid), "desc": fill(inst.desc),
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
