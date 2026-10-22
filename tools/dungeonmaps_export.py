"""
Port ClassicDungeonMaps' data tables into MUI_DB/MUI_DungeonMapDB.lua and copy
the custom map tiles it ships (dungeons whose client tiles show a later
remake) into assets/textures/dungeonmaps/.

    python tools/dungeonmaps_export.py <db2 dir> [path to ClassicDungeonMaps] [--localize --retail <dir>]

<db2 dir> holds a folder per language (enUS, deDE, esES, esMX, frFR, ptBR,
ruRU, koKR, zhCN, zhTW), each with WMOAreaTable.csv and AreaTable.csv of the
Era build in .build.info (wago.tools/db2, with &locale=<language>).

Needs lupa (the source file is Lua and is evaluated, not parsed).

With --localize it also writes the pins' text in every client language into
MUI_DB/Locale (the end of this file); --retail is a folder of <lang>/<Table>.csv
of a retail build (JournalEncounter, JournalEncounterCreature) for the bosses'
names.
Vanilla instances only; the TBC entries are dropped.

A boss pin gets its boss's level from MUI_DB/MUI_NpcDB.lua (Questie's NPCs,
tools/questdb_export), found by name.

The source finds a floor by the minimap's subzone text, and an instance's
first floor by its name, both in English. The client gives them in its own
language: a subzone is written out in every language, from the areas of that
English name (a building's rooms are WMOAreaTable's, the rest AreaTable's;
a name no area has never shows on Era and is dropped), and an instance is
found by GetInstanceInfo's instance id instead.
"""
import csv
import os
import re
import shutil
import sys

from lupa import LuaRuntime, lua_type

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARGV = sys.argv[1:]
RETAIL = None
if "--retail" in ARGV:
    at = ARGV.index("--retail")
    RETAIL = ARGV[at + 1]
    del ARGV[at:at + 2]
ARGS = [a for a in ARGV if a != "--localize"]
if not ARGS:
    sys.exit(__doc__)
DB2 = ARGS[0]
SRC = ARGS[1] if len(ARGS) > 1 else os.path.join(os.path.dirname(ROOT), "ClassicDungeonMaps")
LANGUAGES = ["enUS", "deDE", "esES", "esMX", "frFR", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"]
# GetInstanceInfo's instance id (Map) for each instance name the source and
# the fallbacks below go by
INSTANCE_IDS = {"AhnQiraj": 531, "BlackfathomDeeps": 48, "BlackrockDepths": 230, "BlackrockSpire": 229,
                "BlackwingLair": 469, "Deadmines": 36, "TheDeadmines": 36, "DireMaul": 429, "Gnomeregan": 90,
                "HallofBlackhand": 229, "Maraudon": 349, "MoltenCore": 409, "Naxxramas": 533,
                "Onyxia'sLair": 249, "RagefireChasm": 389, "RazorfenDowns": 129, "RazorfenKraul": 47,
                "RuinsofAhn'Qiraj": 509, "ScarletMonastery": 189, "Scholomance": 289, "ShadowfangKeep": 33,
                "Stratholme": 329, "SunkenTemple": 109, "TheTempleofAtal'Hakkar": 109, "TheStockade": 34,
                "Uldaman": 70, "WailingCaverns": 43, "Zul'Farrak": 209, "Zul'Gurub": 309}
OUT = os.path.join(ROOT, "MUI_DB", "MUI_DungeonMapDB.lua")
NPC_DB = os.path.join(ROOT, "MUI_DB", "MUI_NpcDB.lua")
TILES_OUT = os.path.join(ROOT, "assets", "textures", "dungeonmaps")

TBC = {"BF", "MT", "Ramps", "SP", "UB"}
CDM_MEDIA = "interface\\addons\\classicdungeonmaps\\media\\dungeons\\"
OUR_MEDIA = "Interface\\AddOns\\ModernUI\\assets\\textures\\dungeonmaps\\"

# The source's misspelt labels, as the client spells them.
TEXT_FIXES = {
    "High Interragator Gerstahn": "High Interrogator Gerstahn",
    "Warmaster Voone": "War Master Voone",
    "Agethelos the Raging": "Agathelos the Raging",
    "Lord Illucia Barov": "Lady Illucia Barov",
    "Dark Master Gandling": "Darkmaster Gandling",
    "Silithis": "Silithus",
    "Warpood Quarter": "Warpwood Quarter",
    "Mauradon Outside Orange Side": "Maraudon Outside Orange Side",
    "Khaz'Gorath's Seat": "Khaz'goroth's Seat",
}
# The source's boss names that are not the NPC's, shortened.
NPC_NAMES = {
    "Razorgore": "Razorgore the Untamed",
    "Vaelastrasz": "Vaelastrasz the Corrupt",   # "Vaelastrasz" is a friendly NPC
}
# Event pins: the creatures the event brings.
EVENT_NPCS = {
    "Ring of Law Event": ("Anub'shiah", "Eviscerator", "Gorosh the Dervish", "Grizzle",
                          "Hedrum the Creeper", "Ok'thor the Breaker"),
    "Chest of the Seven Encounter": ("Anger'rel", "Doom'rel", "Dope'rel", "Gloom'rel",
                                     "Haterel", "Seeth'rel", "Vile'rel"),
    "Edge of Madness Event": ("Gri'lek", "Hazza'rah", "Renataki", "Wushoolay"),
}
BOSS_RANK = 3   # Questie's rank of a boss, whose level the game shows as "??"

text = open(os.path.join(SRC, "ClassicDungeonMapsDataDB.lua"), encoding="utf-8").read()
# Pin click handlers are closures; turn them into data before evaluating.
text = re.sub(r'funct\s*=\s*function\(\)\s*SetDungeonMapTextures\("([^"]+)",\s*"(\d+)"\)\s*end',
              r'link = {"\1", \2}', text)
text = re.sub(r'funct\s*=\s*function\(\)\s*ToggleDungeonMap\(\)\s*end', 'exit = true', text)
assert "funct" not in text, "unconverted pin handler"
# A pin written without its braces (Maraudon's purple door): evaluated as is,
# its fields land on the pin list itself and the pin is lost.
text = re.sub(r'^([ \t]*)(pinType\s*=.*?),?[ \t]*$', r'\1{\2},', text, flags=re.M)

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(text)
g = lua.globals()


def keys(t):
    return list(t.keys()) if t is not None else []


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def npc_key(name):
    # Case and quotes differ between the source and Questie (Edwin Vancleef, Eric "The Swift").
    return name.lower().replace('"', "")


def load_npcs(path):
    """npc_key(name) -> [{name, minLevel, maxLevel, rank}] of every NPC in MUI_NpcDB."""
    npcs, npc = {}, None
    for line in open(path, encoding="utf-8"):
        if re.match(r"^        \[\d+\] = \{$", line):
            npc = {}
        elif npc is not None and line.rstrip("\n") == "        },":
            if "name" in npc:
                npcs.setdefault(npc_key(npc["name"]), []).append(npc)
            npc = None
        elif npc is not None:
            m = re.match(r"^            (name|minLevel|maxLevel|rank) = (.+),$", line)
            if m:
                v = m.group(2)
                npc[m.group(1)] = re.sub(r"\\(.)", r"\1", v[1:-1]) if v[0] in "\"'" else int(v)
    return npcs


def boss_level(text, npcs):
    """minLevel, maxLevel of a boss pin's creature (an event's: of all it
    brings); -1, -1 for a boss rank; None when no NPC has the name. Of
    several NPCs of one name, the highest ranked."""
    found = []
    for name in EVENT_NPCS.get(text, (NPC_NAMES.get(text, text),)):
        same = npcs.get(npc_key(name))
        if same:
            found.append(max(same, key=lambda n: n.get("rank", 0)))
    if not found:
        return None
    if any(n.get("rank") == BOSS_RANK for n in found):
        return -1, -1
    return min(n["minLevel"] for n in found), max(n["maxLevel"] for n in found)


maps = {}
copied = set()
for code in keys(g.CDMmapData):
    if code in TBC:
        continue
    floors = {}
    for fid in keys(g.CDMmapData[code]):
        f = g.CDMmapData[code][fid]
        path = f.filePath
        if path.lower().startswith(CDM_MEDIA):
            folder = path[len(CDM_MEDIA):]
            path = OUR_MEDIA + folder
            copied.add(folder)
        pins = []
        for i in keys(f.pinData):
            p = f.pinData[i]
            if lua_type(p) != "table" or p.quest or p.texture is None:
                continue
            pin = {"x": p.X, "y": p.Y, "text": TEXT_FIXES.get(p.text, p.text)}
            if p.angle:
                pin["angle"] = p.angle
            if p.size:
                pin["size"] = p.size
            if isinstance(p.texture, (int, float)):
                pin["boss"] = int(p.texture)
            else:
                pin["atlas"] = p.texture
            if p.link:
                pin["link"] = (p.link[1], int(p.link[2]))
            elif p.exit:
                pin["exit"] = True
            pins.append(pin)
        floors[int(fid)] = {"name": f.name, "path": path + "\\" + f.fileName, "ext": f.fileType, "pins": pins}
    maps[code] = floors

# Links to a missing dungeon / floor are dropped (the pin stays, inert).
for code, floors in maps.items():
    for fid, f in floors.items():
        for pin in f["pins"]:
            link = pin.get("link")
            if link and (link[0] not in maps or link[1] not in maps[link[0]]):
                print("dropping dead link", code, fid, pin["text"], link)
                del pin["link"]

npcs = load_npcs(NPC_DB)
for code, floors in maps.items():
    for fid, f in floors.items():
        for pin in f["pins"]:
            if "boss" in pin:
                level = boss_level(pin["text"], npcs)
                if level:
                    pin["minLevel"], pin["maxLevel"] = level
                else:
                    print("no level for", code, fid, pin["text"])


def lookup(table, what):
    out = {}
    for code in keys(table):
        if code in TBC:
            continue
        target = code if code in maps else {"Naxx": "Nax"}.get(code)
        for fid in keys(table[code]):
            if target not in maps or int(fid) not in maps[target]:
                print("skipping", what, code, fid, "- no such map")
                continue
            for i in keys(table[code][fid]):
                name = table[code][fid][i]
                if name:    # the source has a stray empty name (it matched a blank subzone)
                    out[name] = (target, int(fid))
    return out


subzones = lookup(g.CDMdungeons, "subzone")
instances = lookup(g.CdmOnLoadDefaults, "instance")
# Single-map instances the source resolves by subzone only: give them an
# instance-name fallback too, for a subzone it doesn't list.
for name, code in (("MoltenCore", "MC"), ("Onyxia'sLair", "Onyxia"), ("RagefireChasm", "RFC"),
                   ("RazorfenDowns", "RFD"), ("RazorfenKraul", "RFK"), ("TheStockade", "Stocks"),
                   ("TheTempleofAtal'Hakkar", "ST"), ("SunkenTemple", "ST"), ("WailingCaverns", "WC"),
                   ("BlackrockSpire", "LBRS")):
    instances.setdefault(name, (code, 1))


def strip(name):
    return re.sub(r"\s+", "", name)


def area_names():
    """Every area a subzone text can be (Era's: Season of Discovery's ids
    start at 15000), by its enUS name without spaces: its names, the same
    way, in each language."""
    out = {}
    for table, below in (("WMOAreaTable", None), ("AreaTable", 15000)):
        rows = {}
        for lang in LANGUAGES:
            with open(os.path.join(DB2, lang, table + ".csv"), encoding="utf-8", newline="") as f:
                rows[lang] = {r["ID"]: r["AreaName_lang"] for r in csv.DictReader(f)}
        for id, name in rows["enUS"].items():
            if not name or (below and int(id) >= below):
                continue
            entry = out.setdefault(strip(name), {lang: set() for lang in LANGUAGES})
            for lang in LANGUAGES:
                if rows[lang].get(id):
                    entry[lang].add(strip(rows[lang][id]))
    return out


AREAS = area_names()
for name in sorted(n for n in subzones if n not in AREAS):
    print("no area named", name, "- dropped")
subzone_list = [(code, floor, AREAS[name]) for name, (code, floor) in subzones.items() if name in AREAS]
subzone_list.sort(key=lambda s: (s[0], s[1], sorted(s[2]["enUS"])))

instances_by_id = {}
for name, hit in instances.items():
    id = INSTANCE_IDS[name]
    assert instances_by_id.get(id, hit) == hit, "instance %d has two first floors" % id
    instances_by_id[id] = hit

L = []
w = L.append
w("-- DungeonMapDB: dungeon / raid maps for the world map's dungeon view.")
w("-- GENERATED by tools/dungeonmaps_export.py from the ClassicDungeonMaps addon's")
w("-- tables, the bosses' levels from MUI_NpcDB - don't edit by hand.")
w("--")
w("-- _maps[code][floor] = { name, path, ext, pins }: twelve 256px tiles")
w("-- <path><1..12><ext> in a 4x3 grid. Most are the client's own")
w("-- Interface\\Worldmap tiles; dungeons that were later remade ship their")
w("-- vanilla layout in assets/textures/dungeonmaps.")
w("-- pin = { x, y (0-1 across the map), text, angle?, size?,")
w("--         boss = creature display id | atlas = Blizzard atlas name,")
w("--         minLevel?, maxLevel? (a boss's; -1: a boss rank, shown \"??\"),")
w("--         link = { code, floor }? (click opens that floor), exit = true? }")
w("-- _subzones = { { code, floor, <language> = { text, ... } } }: the minimap")
w("-- subzone texts that show a floor, without their spaces, in every language.")
w("-- _instances[instance id] = { code, floor }: the floor an instance opens on.")
w("")
w('object "DungeonMapDB" {')
w("    GetFloors = function(self, code)")
w("        return self._maps[code]")
w("    end;")
w("")
w("    -- code, floor for the minimap's subzone text / GetInstanceInfo's instance")
w("    -- id; nil when unknown.")
w("    FindBySubzone = function(self, name)")
w("        local hit = self._bySubzone[string.gsub(name or \"\", \"%s+\", \"\")]")
w("        if hit then return hit[1], hit[2] end")
w("    end;")
w("")
w("    FindByInstance = function(self, id)")
w("        local hit = self._instances[id]")
w("        if hit then return hit[1], hit[2] end")
w("    end;")
w("")
w("    -- The pins' text in the client's language, from MUI_DB/Locale: English")
w("    -- text -> text.")
w("    Localize = function(self, texts)")
w("        for _, floors in pairs(self._maps) do")
w("            for _, floor in pairs(floors) do")
w("                for _, pin in ipairs(floor.pins) do")
w("                    pin.text = texts[pin.text] or pin.text")
w("                end")
w("            end")
w("        end")
w("    end;")
w("")
w("    __init = function(self)")
w("        self._maps = {")
for code in sorted(maps):
    w("            [%s] = {" % lua_str(code))
    for fid in sorted(maps[code]):
        f = maps[code][fid]
        w("                [%d] = { name = %s, path = %s, ext = %s, pins = {"
          % (fid, lua_str(f["name"]), lua_str(f["path"]), lua_str(f["ext"])))
        for p in f["pins"]:
            parts = ["x = %g" % p["x"], "y = %g" % p["y"], "text = " + lua_str(p["text"] or "")]
            if "boss" in p:
                parts.append("boss = %d" % p["boss"])
                if "minLevel" in p:
                    parts.append("minLevel = %d, maxLevel = %d" % (p["minLevel"], p["maxLevel"]))
            else:
                parts.append("atlas = " + lua_str(p["atlas"]))
            if "angle" in p:
                parts.append("angle = %g" % p["angle"])
            if "size" in p:
                parts.append("size = %g" % p["size"])
            if "link" in p:
                parts.append("link = { %s, %d }" % (lua_str(p["link"][0]), p["link"][1]))
            if "exit" in p:
                parts.append("exit = true")
            w("                    { " + ", ".join(parts) + " },")
        w("                } },")
    w("            },")
w("        }")
w("")
w("        self._subzones = {")
for code, floor, names in subzone_list:
    w("            { %s, %d," % (lua_str(code), floor))
    for lang in LANGUAGES:
        w("                %s = { %s }," % (lang, ", ".join(lua_str(n) for n in sorted(names[lang]))))
    w("            },")
w("        }")
w("        local language = GetLocale()")
w("        self._bySubzone = {}")
w("        for _, subzone in ipairs(self._subzones) do")
w("            for _, text in ipairs(subzone[language] or subzone.enUS) do")
w("                self._bySubzone[text] = subzone")
w("            end")
w("        end")
w("")
w("        self._instances = {")
for id in sorted(instances_by_id):
    w("            [%d] = { %s, %d }," % (id, lua_str(instances_by_id[id][0]), instances_by_id[id][1]))
w("        }")
w("    end;")
w("}")
open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")

for folder in sorted(copied):
    src = os.path.join(SRC, "Media", "Dungeons", folder)
    dst = os.path.join(TILES_OUT, folder)
    os.makedirs(dst, exist_ok=True)
    for name in os.listdir(src):
        if name.lower().endswith(".tga"):
            shutil.copyfile(os.path.join(src, name), os.path.join(dst, name))
    print("copied", folder, len(os.listdir(dst)), "tiles")

print("maps:", len(maps), "floors:", sum(len(f) for f in maps.values()),
      "subzones:", len(subzone_list), "instances:", len(instances_by_id))


# ---- the pins' text in other languages (--localize): MUI_DB/Locale/<lang>.lua
# A boss's name is its creature's (retail's journal, else Questie's lookups),
# a place's the area's of that English name (WMOAreaTable's rooms, AreaTable's
# areas); the rest is ours, tools/i18n/<lang>.json, listed in
# tools/i18n/source/dungeonmaps.json.
if "--localize" in sys.argv:
    if not RETAIL:
        sys.exit("--localize needs --retail <dir>")
    import json
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    sys.path.insert(0, os.path.join(ROOT, "tools", "questdb_export"))
    import locale_data
    import locale_export

    I18N = os.path.join(ROOT, "tools", "i18n")
    QUESTIE = os.path.join(ROOT, "tools", "vendor", "Questie")
    area_rows = {}
    for table in ("WMOAreaTable", "AreaTable"):
        for lang in LANGUAGES:
            with open(os.path.join(DB2, lang, table + ".csv"), encoding="utf-8", newline="") as f:
                area_rows[table, lang] = {r["ID"]: r["AreaName_lang"] for r in csv.DictReader(f)}
    npc_ids, npc_english = {}, {}
    for i, row in locale_export.english("MUI_NpcDB.lua").items():
        if row.get("name"):
            npc_ids.setdefault(npc_key(row["name"]), []).append(i)
            npc_english[i] = row["name"]

    plan, ours = {}, {}
    texts = sorted({p["text"] for floors in maps.values() for f in floors.values() for p in f["pins"] if p["text"]})
    bosses = {p["text"] for floors in maps.values() for f in floors.values() for p in f["pins"] if "boss" in p}
    for text in texts:
        ids = npc_ids.get(npc_key(NPC_NAMES.get(text, text))) if text in bosses else None
        area = next(((table, i) for table in ("WMOAreaTable", "AreaTable")
                     for i, name in area_rows[table, "enUS"].items() if name == text), None)
        if ids:
            plan[text] = ("npc", ids)
        elif area:
            plan[text] = ("area",) + area
        else:
            ours["dmap/" + text] = {"en": text, "note": "a label on a dungeon's map: a boss, a room, a way out or a note"}
    os.makedirs(os.path.join(I18N, "source"), exist_ok=True)
    with open(os.path.join(I18N, "source", "dungeonmaps.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(ours, f, ensure_ascii=False, indent=1)
        f.write("\n")
    for lang in locale_data.LANGUAGES:
        npcs = locale_export.npc_names(QUESTIE, RETAIL, lang, npc_english)
        path = os.path.join(I18N, lang + ".json")
        mine = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
        out, missing = {}, []
        for text in texts:
            source = plan.get(text)
            if source and source[0] == "npc":
                local = next((npcs[i] for i in source[1] if npcs.get(i)), None)
            elif source:
                local = area_rows[source[1], lang].get(source[2])
            else:
                local = mine.get("dmap/" + text)
            if local and local != text:
                out[text] = local
            elif not local:
                missing.append(text)
        lines = [f"MUI_DungeonMapDB:Localize({locale_data.loadstring(out)})"]
        locale_data.write_block(lang, "dungeon maps", "tools/dungeonmaps_export.py", lines)
        print(f"{lang}: {len(out)} of {len(texts)} pin texts in the language; {len(missing)} still English"
              + (" (" + ", ".join(missing[:5]) + ")" if missing else ""))
    print(f"ours to translate: {len(ours)} (tools/i18n/source/dungeonmaps.json)")
