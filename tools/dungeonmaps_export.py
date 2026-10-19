"""
Port ClassicDungeonMaps' data tables into MUI_DB/MUI_DungeonMapDB.lua and copy
the custom map tiles it ships (dungeons whose client tiles show a later
remake) into assets/textures/dungeonmaps/.

    python tools/dungeonmaps_export.py [path to ClassicDungeonMaps]

Needs lupa (the source file is Lua and is evaluated, not parsed).
Vanilla instances only; the TBC entries are dropped.

A boss pin gets its boss's level from MUI_DB/MUI_NpcDB.lua (Questie's NPCs,
tools/questdb_export), found by name.
"""
import os
import re
import shutil
import sys

from lupa import LuaRuntime, lua_type

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(ROOT), "ClassicDungeonMaps")
OUT = os.path.join(ROOT, "MUI_DB", "MUI_DungeonMapDB.lua")
NPC_DB = os.path.join(ROOT, "MUI_DB", "MUI_NpcDB.lua")
TILES_OUT = os.path.join(ROOT, "assets", "textures", "dungeonmaps")

TBC = {"BF", "MT", "Ramps", "SP", "UB"}
CDM_MEDIA = "interface\\addons\\classicdungeonmaps\\media\\dungeons\\"
OUR_MEDIA = "Interface\\AddOns\\ModernUI\\assets\\textures\\dungeonmaps\\"

# The source's boss names that are not the NPC's: misspelt or shortened.
NPC_NAMES = {
    "High Interragator Gerstahn": "High Interrogator Gerstahn",
    "Razorgore": "Razorgore the Untamed",
    "Vaelastrasz": "Vaelastrasz the Corrupt",   # "Vaelastrasz" is a friendly NPC
    "Warmaster Voone": "War Master Voone",
    "Agethelos the Raging": "Agathelos the Raging",
    "Lord Illucia Barov": "Lady Illucia Barov",
    "Dark Master Gandling": "Darkmaster Gandling",
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
            pin = {"x": p.X, "y": p.Y, "text": p.text}
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
w("-- _subzones[name] / _instances[name] = { code, floor }: minimap subzone text")
w("-- and instance name with the spaces removed (enUS).")
w("")
w('object "DungeonMapDB" {')
w("    GetFloors = function(self, code)")
w("        return self._maps[code]")
w("    end;")
w("")
w("    -- code, floor for a minimap subzone name / an instance name; nil when unknown.")
w("    FindBySubzone = function(self, name)")
w("        local hit = self._subzones[string.gsub(name or \"\", \"%s+\", \"\")]")
w("        if hit then return hit[1], hit[2] end")
w("    end;")
w("")
w("    FindByInstance = function(self, name)")
w("        local hit = self._instances[string.gsub(name or \"\", \"%s+\", \"\")]")
w("        if hit then return hit[1], hit[2] end")
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
for name, table in (("_subzones", subzones), ("_instances", instances)):
    w("")
    w("        self.%s = {" % name)
    for key in sorted(table):
        w("            [%s] = { %s, %d }," % (lua_str(key), lua_str(table[key][0]), table[key][1]))
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
      "subzones:", len(subzones), "instances:", len(instances))
