"""Export NewEra's achievement definitions into MUI_DB/MUI_AchievementDB.lua.

Source: ../NewEra/Generated/Achievements/Data.lua (NE_ACH_DATA), evaluated
with lupa. We keep its ids (they live in SavedVariables) and emit our object
form: the categories, the list, and the lookup tables the engine's
evaluators need (quest zones, zone continents, explore baselines, Darkmoon
tickets and decks, PvP and dungeon sets).

Two things are ours on top of NewEra's data:
  - A zone quest achievement ("Westfall Quests") whose zone has story
    chapters in MUI_DB/MUI_StorylineDB.lua asks for every chapter instead
    of NewEra's quest count: crit `qstory`, retail's wording. A continent's
    Loremaster is then a meta of its zone quest achievements, as retail's,
    instead of NewEra's continent quest count. The Alliance gets Hillsbrad
    Foothills, which NewEra keeps for the Horde, and an achievement for
    Alterac Mountains, which NewEra has none for: it has chapters in both.
  - `account = true` marks the achievements retail draws with the blue
    account-wide header (ACHIEVEMENT_FLAGS_ACCOUNT) rather than the red
    character one. Retail's split, from its Achievement table: quests,
    exploration, reputation, world events, honor and duels, the metas, and
    the lifestyle ones (books, food and drink, companions, critters) are
    account-wide; levels, skills, dungeon and raid kills, professions, loot,
    battlegrounds, ranks and class deeds are the character's.
  - A kill target carries `quests`: the quests that require that kill
    (creature and kill-credit objectives, and quest items, armor and
    weapons only that creature drops), from the quest and item databases.
    A character who
    finished one of them before the addon gets the kill credited.
  - OURS adds the achievements picked from the candidates document (ids
    5001 and up): retail ones that fit Era and Era-only ideas. Their item,
    quest and creature ids are spelled out below; the Dungeon Set 2 pieces
    come from the ItemSet table, the instance zones from MUI_DungeonDB.
  - `noHardcore = true` marks what a Hardcore realm rules out, and the
    engine drops those there: all of Player vs. Player (no battlegrounds,
    honor or duels to speak of), dying as the deed (the elements, a hundred
    deaths, Hogger, one's own engineering), the battleground reputations,
    and casting a resurrection (Reincarnation, Rebirth), which Hardcore
    disables.

    python tools/achievements/export.py
"""
import os
import re

from lupa import LuaRuntime, lua_type

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(os.path.dirname(ROOT), "NewEra", "Generated", "Achievements", "Data.lua")
STORY = os.path.join(ROOT, "MUI_DB", "MUI_StorylineDB.lua")
QUESTS_LUA = os.path.join(ROOT, "MUI_DB", "MUI_QuestDB.lua")
ITEMS_LUA = os.path.join(ROOT, "MUI_DB", "MUI_ItemDB.lua")
OUT = os.path.join(ROOT, "MUI_DB", "MUI_AchievementDB.lua")
ICONS = os.path.join(ROOT, "assets", "textures", "achievementicons")

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(SRC, encoding="utf-8").read())
D = lua.globals().NE_ACH_DATA

story = LuaRuntime(unpack_returned_tuples=True)
story.execute('object = function(name) return function(t) _G[name] = t end end')
story.execute(open(STORY, encoding="utf-8").read())
STORY_ZONES = {int(k) for k in story.globals().StorylineDB._data.keys()}

# npc -> the quests that require killing it: creature objectives, kill
# credits, and items only this creature drops that cannot be bought instead
# (quest items, and the bind-on-pickup armor and weapons a boss drops)
world = LuaRuntime(unpack_returned_tuples=True)
world.execute('object = function(name) return function(t) _G[name] = t end end')
world.execute(open(QUESTS_LUA, encoding="utf-8").read())
world.execute(open(ITEMS_LUA, encoding="utf-8").read())
ITEMS = world.globals().ItemDB._data
KILL_QUESTS = {}


def entries(t):
    return list(t.values()) if t else []


def add_kill_quest(npc, qid):
    if isinstance(npc, (int, float)):
        KILL_QUESTS.setdefault(int(npc), set()).add(int(qid))


for qid, q in world.globals().QuestDB._data.items():
    o = q.objectives
    if not o:
        continue
    for e in entries(o[1]):
        add_kill_quest(e[1], qid)
    for e in entries(o[5]):
        if lua_type(e[1]) == "table":
            for n in entries(e[1]):
                add_kill_quest(n, qid)
        else:
            add_kill_quest(e[1], qid)
    for e in entries(o[3]):
        item = ITEMS[e[1]]
        drops = entries(item.npcDrops) if item and item.npcDrops else []
        if item and item["class"] in (2, 4, 12) and len(drops) == 1:
            add_kill_quest(drops[0], qid)


def kill_quests(npcs):
    return sorted(set().union(*(KILL_QUESTS.get(int(n), set()) for n in npcs)))


def num(v):
    if isinstance(v, float) and v.is_integer():
        return int(v)
    return v


def to_py(v):
    if lua_type(v) == "table":
        keys = [num(k) for k in v.keys()]
        if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
            return [to_py(v[k]) for k in range(1, len(keys) + 1)]
        return {k: to_py(v[k]) for k in keys}
    return num(v)


IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def lua_val(v, order=None):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v) if isinstance(v, float) else str(v)
    if isinstance(v, str):
        return lua_str(v)
    if isinstance(v, list):
        return "{ " + ", ".join(lua_val(x) for x in v) + " }"
    if isinstance(v, dict):
        keys = sorted(v.keys(), key=lambda k: (0, order.index(k)) if order and k in order else (1, str(k)))
        parts = []
        for k in keys:
            if isinstance(k, str) and IDENT.match(k):
                parts.append("%s = %s" % (k, lua_val(v[k])))
            else:
                parts.append("[%s] = %s" % (lua_val(k), lua_val(v[k])))
        return "{ " + ", ".join(parts) + " }"
    raise TypeError(repr(v))


categories = to_py(D.CATEGORIES)
# Exploration gets a continent under it each, as Quests has
EXPLORATION = next(i for i, c in enumerate(categories) if c["id"] == 3)
categories[EXPLORATION + 1:EXPLORATION + 1] = [{"id": 31, "name": "Eastern Kingdoms", "parent": 3},
                                               {"id": 32, "name": "Kalimdor", "parent": 3}]
# Dropped: "Making Good Time" (level 60 under 15 days played) is out of reach
# for any character already past it, and "Fully Trained" (every trainer rank
# known) has no reliable source for what the trainers teach.
defs = [d for d in to_py(D.LIST) if d["crit"]["t"] not in ("played", "fullyTrained")]
quests = to_py(D.QUESTS)
explore = to_py(D.EXPLORE_BASE)
dmf = to_py(D.DMF)
decks = to_py(D.DMF_DECKS)
pvpsets = to_py(D.PVPSET)
dungeonsets = to_py(D.DS1)

# ---- ours: storyline criteria, the account-wide flag, the Hardcore exclusions ------
ACCOUNT_CATEGORIES = {2, 21, 22, 3, 6, 11}
ACCOUNT_CRITS = {"meta", "hk", "kb", "duel", "book", "use", "companions", "emoteLove", "hugSet"}
PVP_CATEGORY = 9
DEATH_CRITS = {"envDeath", "envDeathAll", "deathCount", "selfKill", "slainBy"}
BG_FACTIONS = {509, 510, 729, 730, 889, 890}   # Arathor, Defilers, Frostwolf, Stormpike, Outriders, Silverwing
RESURRECTION = re.compile(r"Reincarnation|Rebirth|Resurrection|Redemption|Ancestral Spirit", re.I)


def rep_factions(c):
    if c["t"] in ("rep", "repAndItem"):
        return {c["fid"]}
    if c["t"] == "repAll":
        return {e["fid"] for e in c["list"]}
    if c["t"] == "repAny":
        return set(c["fids"])
    return set()


def no_hardcore(d):
    c = d["crit"]
    if d["cat"] == PVP_CATEGORY or c["t"] in DEATH_CRITS:
        return True
    if rep_factions(c) & BG_FACTIONS:
        return True
    return c["t"] in ("castSpell", "castCount", "healOther") and bool(RESURRECTION.search(c["label"]))


CONTINENT = {"EK": (21, "Eastern Kingdoms"), "KA": (22, "Kalimdor")}   # sub-category, name
OVERKILL = {100: 100, 1000: 500, 5000: 1000}

# ---- ours: the additions picked from the candidates document ----------------------
DUNGEONS_LUA = os.path.join(ROOT, "MUI_DB", "MUI_DungeonDB.lua")
dungeons = LuaRuntime(unpack_returned_tuples=True)
dungeons.execute('object = function(name) return function(t) _G[name] = t end end')
dungeons.execute(open(DUNGEONS_LUA, encoding="utf-8").read())
dungeons.execute('DungeonDB.__init(DungeonDB)')
INSTANCE_ZONES = sorted(int(k) for k in dungeons.globals().DungeonDB._dungeons.keys())

# Dungeon Set 2 (ItemSet 511-519), by class
DUNGEON_SETS_2 = {
    "WARRIOR": ("Battlegear of Heroism", [21994, 21995, 21996, 21997, 21998, 21999, 22000, 22001]),
    "ROGUE": ("Darkmantle Armor", [22002, 22003, 22004, 22005, 22006, 22007, 22008, 22009]),
    "DRUID": ("Feralheart Raiment", [22106, 22107, 22108, 22109, 22110, 22111, 22112, 22113]),
    "PRIEST": ("Vestments of the Virtuous", [22078, 22079, 22080, 22081, 22082, 22083, 22084, 22085]),
    "HUNTER": ("Beastmaster Armor", [22010, 22011, 22061, 22013, 22015, 22016, 22017, 22060]),
    "PALADIN": ("Soulforge Armor", [22086, 22087, 22088, 22089, 22090, 22091, 22092, 22093]),
    "MAGE": ("Sorcerer's Regalia", [22062, 22063, 22064, 22065, 22066, 22067, 22068, 22069]),
    "WARLOCK": ("Deathmist Raiment", [22070, 22071, 22072, 22073, 22074, 22075, 22076, 22077]),
    "SHAMAN": ("The Five Thunders", [22095, 22096, 22097, 22098, 22099, 22100, 22101, 22102]),
}

# Era's pests (retail's Pest Control roster, the ones that live here)
PESTS = [("Adder", 3300), ("Fire Beetle", 9699), ("Larva", 16068), ("Maggot", 16030), ("Moccasin", 4953),
         ("Mouse", 6271), ("Rat", 4075), ("Black Rat", 2110), ("Roach", 4076), ("Cockroach", 7395),
         ("Snake", 2914), ("Spider", 14881), ("Toad", 1420), ("Huge Toad", 6653), ("Beetle", 15475), ("Frog", 13321)]

# every fish a line can land in Era (contest rares, clams and junk aside)
FISH = [(6291, "Raw Brilliant Smallfish"), (6303, "Raw Slitherskin Mackerel"), (6289, "Raw Longjaw Mud Snapper"),
        (6317, "Raw Loch Frenzy"), (6308, "Raw Bristle Whisker Catfish"), (6361, "Raw Rainbow Fin Albacore"),
        (6362, "Raw Rockscale Cod"), (8365, "Raw Mithril Head Trout"), (4603, "Raw Spotted Yellowtail"),
        (13758, "Raw Redgill"), (13760, "Raw Sunscale Salmon"), (13759, "Raw Nightfin Snapper"),
        (13756, "Raw Summer Bass"), (13889, "Raw Whitescale Salmon"), (13754, "Raw Glossy Mightfish"),
        (21071, "Raw Sagefish"), (21153, "Raw Greater Sagefish"), (8959, "Raw Spinefin Halibut"),
        (6358, "Oily Blackmouth"), (6359, "Firefin Snapper"), (13422, "Stonescale Eel"), (13757, "Lightning Eel"),
        (13890, "Plated Armorfish"), (13888, "Darkclaw Lobster"), (13755, "Winter Squid"), (6522, "Deviate Fish")]

EKO = [(12430, "Frostsaber E'ko"), (12431, "Winterfall E'ko"), (12432, "Shardtooth E'ko"), (12433, "Wildkin E'ko"),
       (12434, "Chillwind E'ko"), (12435, "Ice Thistle E'ko"), (12436, "Frostmaul E'ko")]

WORLD_BUFFS = ["Rallying Cry of the Dragonslayer", "Warchief's Blessing", "Spirit of Zandalar", "Songflower Serenade",
               "Fengus' Ferocity", "Mol'dar's Moxie", "Slip'kik's Savvy"]

# the end bosses of every dungeon: the kill targets filed under Dungeons
END_BOSSES = sorted({n for d in defs if d["cat"] == 4 and d["crit"]["t"] in ("kill", "killAll")
                     for e in ([d["crit"]] if d["crit"]["t"] == "kill" else d["crit"]["list"]) for n in e["npc"]})

OURS = [
    {"id": 5001, "cat": 1, "name": "Level 10", "desc": "Reach level 10.", "pts": 5, "icon": 236562,
     "crit": {"t": "level", "n": 10}},
    {"id": 5002, "cat": 1, "name": "Dual Talent Specialization", "desc": "Activate your Dual Talent Specialization.",
     "pts": 10, "icon": 236544, "crit": {"t": "talentGroups"}},
    {"id": 5003, "cat": 8, "name": "Superior", "desc": "Equip a Superior or better item in every slot.", "pts": 10,
     "icon": 132885, "crit": {"t": "epicSlots", "q": 3}},
    {"id": 5004, "cat": 1, "name": "Represent", "desc": "Equip a tabard.", "pts": 5, "icon": 135026,
     "crit": {"t": "flag", "key": "tabardWorn", "label": "Wear a tabard"}},
    {"id": 5005, "cat": 1, "name": "Pest Control", "desc": "Slay the following pests.", "pts": 10, "icon": 132196,
     "crit": {"t": "killAll", "list": [{"label": label, "npc": [npc]} for label, npc in PESTS]}},
    {"id": 5006, "cat": 1, "name": "Make Love, Not Warcraft", "desc": "Emote /hug on a dead enemy before they release corpse.",
     "pts": 10, "icon": 135767, "noHardcore": True,
     "crit": {"t": "flag", "key": "hugDeadEnemy", "label": "Hug a dead enemy player"}},
    {"id": 5007, "cat": 1, "name": "Buffed to the Gills",
     "desc": "Carry Rallying Cry of the Dragonslayer, Warchief's Blessing, Spirit of Zandalar, Songflower Serenade and the three Gordok tribute buffs at once.",
     "pts": 25, "icon": 132352, "crit": {"t": "flag", "key": "worldBuffs", "label": "Every world buff at once", "auras": WORLD_BUFFS}},
    {"id": 5008, "cat": 1, "name": "Chronoboon", "desc": "Store your world buffs in a Chronoboon Displacer.", "pts": 10,
     "icon": 133713, "crit": {"t": "inv", "any": [184938], "label": "Hold a Supercharged Chronoboon Displacer"}},
    {"id": 5009, "cat": 1, "name": "Hardcore Sixty", "desc": "Reach level 60 on a Hardcore realm.", "pts": 100,
     "icon": 236567, "hardcoreOnly": True, "crit": {"t": "level", "n": 60}},
    {"id": 5010, "cat": 1, "name": "Old-Timer", "desc": "Play for 30 days.", "pts": 10, "icon": 133785,
     "crit": {"t": "playedDays", "n": 30}},
    {"id": 5011, "cat": 1, "name": "Timeworn", "desc": "Play for 100 days.", "pts": 25, "icon": 133785, "prev": 5010,
     "crit": {"t": "playedDays", "n": 100}},
    {"id": 5012, "cat": 7, "name": "500 Fish", "desc": "Fish up 500 items.", "pts": 10, "icon": 237301, "prev": 714,
     "crit": {"t": "fish", "n": 500}},
    {"id": 5013, "cat": 1, "name": "Changed My Mind", "desc": "Reset your talents 10 times.", "pts": 10, "icon": 236325,
     "crit": {"t": "count", "key": "respecs", "n": 10, "label": "Talent resets"}},
    {"id": 5014, "cat": 1, "name": "Frequent Flyer", "desc": "Take 100 flights.", "pts": 10, "icon": 132225,
     "crit": {"t": "count", "key": "flights", "n": 100, "label": "Flights taken"}},
    {"id": 5015, "cat": 1, "name": "Seasoned Traveler", "desc": "Take 500 flights.", "pts": 25, "icon": 132225, "prev": 5014,
     "crit": {"t": "count", "key": "flights", "n": 500, "label": "Flights taken"}},
    {"id": 5016, "cat": 3, "name": "Eastern Kingdoms Skyways", "desc": "Discover every flight path of the Eastern Kingdoms.",
     "pts": 10, "icon": 236776, "crit": {"t": "taxiAll", "maps": [1415], "labels": ["Eastern Kingdoms flight paths"]}},
    {"id": 5017, "cat": 3, "name": "Kalimdor Skyways", "desc": "Discover every flight path of Kalimdor.",
     "pts": 10, "icon": 236776, "crit": {"t": "taxiAll", "maps": [1414], "labels": ["Kalimdor flight paths"]}},
    {"id": 5018, "cat": 1, "name": "Stable Keeper", "desc": "Own 5 mounts.", "pts": 10, "icon": 132254,
     "crit": {"t": "mountCount", "n": 5}},
    {"id": 5019, "cat": 1, "name": "Leading the Cavalry", "desc": "Own 10 mounts.", "pts": 25, "icon": 132254, "prev": 5018,
     "crit": {"t": "mountCount", "n": 10}},
    {"id": 5020, "cat": 1, "name": "Tabard Collector", "desc": "Own 5 tabards.", "pts": 10, "icon": 132671,
     "crit": {"t": "setCount", "set": "tabards", "n": 5, "label": "Tabards owned"}},
    {"id": 5021, "cat": 8, "name": "Shopaholic", "desc": "Spend 1,000 gold at vendors.", "pts": 10, "icon": 133789,
     "crit": {"t": "money", "key": "goldSpentVendor", "n": 1000 * 10000, "label": "Gold spent at vendors"}},
    {"id": 5022, "cat": 8, "name": "Auction Tycoon", "desc": "Earn 1,000 gold from auctions and post 100 of them.", "pts": 25,
     "icon": 133787, "crit": {"t": "countAll", "list": [
         {"label": "Gold earned from auctions", "key": "goldAuction", "n": 1000 * 10000, "money": True},
         {"label": "Auctions posted", "key": "auctionsPosted", "n": 100}]}},
    {"id": 5023, "cat": 7, "name": "Angler of Azeroth", "desc": "Catch every kind of fish in Azeroth.", "pts": 25, "icon": 133916,
     "crit": {"t": "setHas", "set": "fishKinds", "items": [{"id": i, "label": n} for i, n in FISH]}},
    {"id": 5024, "cat": 4, "name": "Lone Wolf", "desc": "Defeat a dungeon end boss alone at level 60.", "pts": 25, "icon": 132148,
     "crit": {"t": "soloKill", "npcs": END_BOSSES}},
    {"id": 5025, "cat": 5, "name": "Raid Tourist", "desc": "Set foot in every raid of Azeroth.", "pts": 10, "icon": 133176,
     "crit": {"t": "visitInstance", "names": ["Molten Core", "Onyxia's Lair", "Blackwing Lair", "Zul'Gurub",
                                              "Ruins of Ahn'Qiraj", "Ahn'Qiraj", "Naxxramas"]}},
    {"id": 5026, "cat": 5, "name": "Attuned", "desc": "Hold every raid attunement.", "pts": 25, "icon": 135921,
     "crit": {"t": "meta", "ids": [501, 502, 503, 504]}},
    {"id": 5027, "cat": 5, "name": "Qiraji Battle Tanks", "desc": "Own the red, blue, green and yellow Qiraji battle tanks.",
     "pts": 50, "icon": 132188, "crit": {"t": "invAll", "list": [
         {"label": "Red Qiraji Battle Tank", "any": [21321]}, {"label": "Blue Qiraji Battle Tank", "any": [21218]},
         {"label": "Green Qiraji Battle Tank", "any": [21323]}, {"label": "Yellow Qiraji Battle Tank", "any": [21324]}]}},
    {"id": 5028, "cat": 4, "name": "Dungeon Set 2", "desc": "Own all 8 pieces of your class's Dungeon Set 2.", "pts": 50,
     "icon": 133440, "crit": {"t": "ds2"}},
    {"id": 5029, "cat": 4, "name": "Tribute Collector", "desc": "Receive Fengus' Ferocity, Mol'dar's Moxie and Slip'kik's Savvy.",
     "pts": 10, "icon": 133201, "crit": {"t": "auraAll", "list": [
         {"label": "Fengus' Ferocity", "spells": [22817]}, {"label": "Mol'dar's Moxie", "spells": [22818]},
         {"label": "Slip'kik's Savvy", "spells": [22820]}]}},
    {"id": 5030, "cat": 1, "name": "Well-Fed", "desc": "Have a Well Fed meal on 7 different days.", "pts": 10, "icon": 237329,
     "crit": {"t": "setCount", "set": "wellFedDays", "n": 7, "label": "Days well fed"}},
    {"id": 5031, "cat": 2, "name": "Night Shift", "desc": "Turn in 25 quests between midnight and 6 AM server time.", "pts": 10,
     "icon": 132765, "crit": {"t": "count", "key": "nightTurnIns", "n": 25, "label": "Night turn-ins"}},
    {"id": 5032, "cat": 1, "name": "Summoner", "desc": "Be summoned 50 times.", "pts": 10, "icon": 236309,
     "crit": {"t": "count", "key": "summons", "n": 50, "label": "Summons accepted"}},
    {"id": 5033, "cat": 1, "name": "Mailman", "desc": "Send 100 mails.", "pts": 10, "icon": 133921,
     "crit": {"t": "count", "key": "mailsSent", "n": 100, "label": "Mails sent"}},
    {"id": 5034, "cat": 8, "name": "Bottomless", "desc": "Equip four bags of 16 slots or more.", "pts": 10, "icon": 132594,
     "crit": {"t": "bags16"}},
    {"id": 5035, "cat": 2, "name": "5 Dungeon Quests Completed", "desc": "Complete 5 dungeon quests.", "pts": 10, "icon": 236668,
     "crit": {"t": "qdungeon", "n": 5}},
    {"id": 5036, "cat": 2, "name": "20 Dungeon Quests Completed", "desc": "Complete 20 dungeon quests.", "pts": 10, "icon": 236670,
     "prev": 5035, "crit": {"t": "qdungeon", "n": 20}},
    {"id": 5037, "cat": 2, "sub": 22, "name": "E'ko Madness", "desc": "Obtain E'ko from the creatures of Winterspring.", "pts": 10,
     "icon": 237404, "crit": {"t": "lootAll", "list": [{"label": n, "item": [i]} for i, n in EKO]}},
    {"id": 5038, "cat": 3, "name": "Relics of a Fallen Empire", "desc": "Deliver a Hakkari Bijou to Zanza the Restless on Yojamba Isle.",
     "pts": 10, "icon": 132528, "crit": {"t": "quest", "any": [8240], "label": "A Bijou for Zanza"}},
    {"id": 5039, "cat": 7, "name": "The Fishing Diplomat", "desc": "Fish something up in Orgrimmar and in Stormwind City.", "pts": 10,
     "icon": 133146, "crit": {"t": "setHas", "set": "fishedZones", "keys": ["Orgrimmar", "Stormwind City"]}},
    {"id": 5040, "cat": 7, "name": "Accomplished Angler", "desc": "Complete the fishing achievements listed below.", "pts": 25,
     "icon": 4620674, "crit": {"t": "meta", "ids": [706, 714, 5012, 715, 713, 716, 731, 733, 5039, 5023]}},
    {"id": 5041, "cat": 6, "name": "Cartel Connections", "desc": "Earn Exalted reputation with Booty Bay, Everlook, Gadgetzan and Ratchet.",
     "pts": 25, "icon": 236687, "crit": {"t": "repAll", "standing": 8, "list": [
         {"label": "Booty Bay", "fid": 21}, {"label": "Everlook", "fid": 577}, {"label": "Gadgetzan", "fid": 369},
         {"label": "Ratchet", "fid": 470}]}},
    {"id": 5042, "cat": 2, "sub": 21, "name": "Alterac Mountains Quests",
     "desc": "Complete the Alterac Mountains storylines listed below.", "pts": 10, "icon": 236711, "facOnly": "A",
     "crit": {"t": "qstory", "zos": 36}},
]
defs.extend(OURS)
by_name = {d["name"]: d for d in defs}
# Southshore's storylines. NewEra's zone list is retail's, where Hillsbrad is
# the Horde's and Alterac no zone of its own; in Era the Alliance has three
# chapters in each. Hillsbrad's achievement is both sides', and Alterac's
# (whose chapters are all the Alliance's) stands after it in the list.
del by_name["Hillsbrad Foothills Quests"]["facOnly"]
defs.remove(by_name["Alterac Mountains Quests"])
defs.insert(defs.index(by_name["Hillsbrad Foothills Quests"]) + 1, by_name["Alterac Mountains Quests"])
# The legendaries only some classes can earn: the piece that starts each is
# class-bound in the item data (Bindings of the Windseeker, Splinter of Atiesh).
by_name["Thunderfury, Blessed Blade of the Windseeker"]["classOnly"] = ["WARRIOR", "PALADIN", "HUNTER", "ROGUE"]
by_name["Atiesh, Greatstaff of the Guardian"]["classOnly"] = ["PRIEST", "MAGE", "WARLOCK", "DRUID"]
by_name["Level 20"]["prev"] = 5001          # Level 10 heads the chain
by_name["1000 Fish"]["prev"] = 5012         # 100, 500, 1000
by_name["Decked Out"]["prev"] = 5003        # Superior, then Epic
# A category lists its achievements in this order. One of ours that a chain
# of NewEra's goes on from stands right before its successor there, not at
# the end with the rest of ours.
ours = {d["id"] for d in OURS}
for d in list(defs):
    if d["id"] not in ours and d.get("prev") in ours:
        first = next(x for x in defs if x["id"] == d["prev"])
        defs.remove(first)
        defs.insert(defs.index(d), first)

for d in defs:
    c = d["crit"]
    if c["t"] == "qzone" and c["zos"] in STORY_ZONES:
        zone = re.search(r" in (.+)\.$", d["desc"]).group(1)
        d["desc"] = "Complete the %s storylines listed below." % zone
        d["crit"] = {"t": "qstory", "zos": c["zos"]}
    elif c["t"] == "qcont":
        sub, name = CONTINENT[c["cont"]]
        d["desc"] = "Complete the %s quest achievements listed below." % name
        d["crit"] = {"t": "meta", "ids": [z["id"] for z in defs if z.get("sub") == sub]}
    if c["t"] == "explore":
        # Era's Eastern Kingdoms zone maps are 1415-1437, Kalimdor's 1411-1414 and 1438-1452
        d["sub"] = 31 if 1415 <= c["map"] <= 1437 else 32
    if c["t"] == "mount":
        d["desc"] = d["desc"].replace(" ground mount", " mount")   # every Era mount is one
    if c["t"] == "speed":
        # NewEra's 220%: an epic mount with every riding boost reaches about
        # 218% in Era, so ask for the mount plus any one boost
        c["mult"] = 2.02
        d["pts"] = 25
        d["desc"] = ("Ride faster than an epic mount: 100% riding speed plus a Carrot on a Stick, "
                     "Mithril Spurs or a Riding Skill enchant.")
    if c["t"] == "qzone" and c["zos"] == 2557:
        # Dire Maul: 15 of its 33 quests needs the class books or the Dungeon Set 2 chain
        c["n"] = {"A": 10, "H": 10}
        d["desc"] = d["desc"].replace("15 quests", "10 quests")
    if c["t"] == "recipes" and c["n"] == 100:
        # Era's cookbook holds about 95 recipes, many faction- or holiday-bound
        c["n"] = 75
        d["desc"] = d["desc"].replace("100", "75")
    if c["t"] == "questMoney":
        # NewEra's 1,000 gold from quest rewards is beyond an Era character; 200 is a real goal
        c["n"] = 200 * 10000
        d["desc"] = "Earn 200 gold from quest rewards."
    if c["t"] == "critterHit":
        # NewEra's 100 / 1,000 / 5,000: no Era class hits for 5,000, and a
        # paladin or priest barely reaches 1,000, so 100 / 500 / 1,000
        new = OVERKILL[c["n"]]
        d["desc"] = d["desc"].replace("{:,}".format(c["n"]), "{:,}".format(new))
        c["n"] = new
    if c["t"] == "kill":
        qs = kill_quests(c["npc"])
        if qs:
            c["quests"] = qs
    elif c["t"] in ("killAll", "killAnyCount"):
        for e in c["list"]:
            qs = kill_quests(e["npc"])
            if qs:
                e["quests"] = qs
    if d["cat"] in ACCOUNT_CATEGORIES or c["t"] in ACCOUNT_CRITS:
        d["account"] = True
    if no_hardcore(d):
        d["noHardcore"] = True

# ---- checks ---------------------------------------------------------------------
ids = {d["id"] for d in defs}
assert len(ids) == len(defs), "duplicate achievement ids"
have_icons = {int(f.split(".")[0]) for f in os.listdir(ICONS) if f.split(".")[0].isdigit()}
for d in defs:
    assert d["icon"] in have_icons, "icon %d missing for %s" % (d["icon"], d["name"])
    if d.get("prev") is not None:
        assert d["prev"] in ids, "prev %s of %s" % (d["prev"], d["name"])
    if d["crit"]["t"] == "meta":
        for m in d["crit"]["ids"]:
            assert m in ids, "meta member %s of %s" % (m, d["name"])

# ---- emit -----------------------------------------------------------------------
DEF_ORDER = ["id", "cat", "sub", "name", "desc", "pts", "icon", "prev", "facOnly", "classOnly", "reward", "account", "noHardcore", "hardcoreOnly", "crit"]
CRIT_ORDER = ["t"]


def def_line(d):
    d = dict(d)
    crit = d.pop("crit")
    fields = [k for k in DEF_ORDER if k in d and k != "crit"]
    body = ", ".join("%s = %s" % (k, lua_val(d[k])) for k in fields)
    return "            { %s,\n              crit = %s }," % (body, lua_val(crit, CRIT_ORDER))


def pairs_block(table, per_line, indent="            "):
    items = sorted(table.items())
    lines = []
    for i in range(0, len(items), per_line):
        chunk = items[i:i + per_line]
        lines.append(indent + " ".join("[%s] = %s," % (lua_val(k), lua_val(v)) for k, v in chunk))
    return "\n".join(lines)


out = []
out.append('''-- MUI_AchievementDB.lua  (AUTO-GENERATED — do not edit)
-- Derived from NewEra's Generated/Achievements/Data.lua. See ATTRIBUTION.md.
-- Regenerate via: python tools/achievements/export.py
--
-- An achievement: { id, cat, sub?, name, desc, pts, icon, prev?, facOnly?,
-- classOnly?, reward?, account?, noHardcore?, crit }. `crit.t` names the
-- evaluator in MUI_AchievementEngine; the other fields are its parameters.
-- `prev` chains a progressive achievement to the one before it, `sub`
-- files it under a sub-category, `facOnly` ("A" / "H"), `classOnly` (class
-- file name, or a list of them), `noHardcore` (ruled out on a Hardcore realm) and
-- `hardcoreOnly` hide it from characters it can't apply to, `account` gives it retail's blue
-- account-wide header instead of the red one. Ids are stable (they live in
-- SavedVariables): never reuse one. `icon` is a retail FileDataID shipped
-- as assets/textures/achievementicons/<id>.blp.

object "AchievementDB" {
    __init = function(self)
        self._categories = {''')
for c in categories:
    out.append("            %s," % lua_val(c, ["id", "name", "parent"]))
out.append("        }\n")
out.append("        self._list = {")
for d in defs:
    out.append(def_line(d))
out.append("        }\n")
out.append("        -- countable quest -> its zone (Questie zoneOrSort)")
out.append("        self._questZones = {")
out.append(pairs_block(quests, 12))
out.append("        }\n")
out.append("        -- uiMapID -> overlay textures revealed when fully explored")
out.append("        self._exploreBase = {")
out.append(pairs_block(explore, 10))
out.append("        }\n")
out.append("        -- Darkmoon Faire: prize quests weighted by ticket cost, deck turn-ins")
out.append("        self._darkmoonTickets = %s" % lua_val(dmf))
out.append("        self._darkmoonDecks = %s\n" % lua_val(decks))
out.append("        -- epic PvP sets by class and faction")
out.append("        self._pvpSets = {")
for cls in sorted(pvpsets):
    out.append("            %s = %s," % (cls, lua_val(pvpsets[cls], ["A", "H"])))
out.append("        }\n")
out.append("        -- the level-60 dungeon sets by class")
out.append("        self._dungeonSets = {")
for cls in sorted(dungeonsets):
    out.append("            %s = %s," % (cls, lua_val(dungeonsets[cls], ["name", "items"])))
out.append("        }\n")
out.append("        -- the upgraded dungeon sets by class")
out.append("        self._dungeonSets2 = {")
for cls in sorted(DUNGEON_SETS_2):
    name, ids = DUNGEON_SETS_2[cls]
    out.append("            %s = %s," % (cls, lua_val({"name": name, "items": ids}, ["name", "items"])))
out.append("        }\n")
out.append("        -- quest zones that are instances (dungeon quests)")
out.append("        self._instanceZones = { %s }" % ", ".join("[%d] = true" % z for z in INSTANCE_ZONES))
out.append('''    end;

    GetCategories = function(self) return self._categories end;
    GetAll = function(self) return self._list end;
    GetQuestZones = function(self) return self._questZones end;
    GetQuestZone = function(self, questId) return self._questZones[questId] end;
    GetExploreBase = function(self, uiMapId) return self._exploreBase[uiMapId] or 0 end;
    GetDarkmoonTickets = function(self, questId) return self._darkmoonTickets[questId] end;
    IsDarkmoonDeck = function(self, questId) return self._darkmoonDecks[questId] == true end;
    GetPvpSet = function(self, class, faction)
        local sets = self._pvpSets[class]
        return sets and sets[faction]
    end;
    GetDungeonSet = function(self, class) return self._dungeonSets[class] end;
    GetDungeonSet2 = function(self, class) return self._dungeonSets2[class] end;
    IsInstanceZone = function(self, zone) return self._instanceZones[zone] == true end;
}
''')
open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(out))
targets = [d["crit"] for d in defs if d["crit"]["t"] == "kill"] + [
    e for d in defs if d["crit"]["t"] in ("killAll", "killAnyCount") for e in d["crit"]["list"]]
print("kill targets with a quest fallback: %d of %d" % (sum(1 for t in targets if t.get("quests")), len(targets)))
print("wrote %s: %d categories, %d achievements, %d quests" % (OUT, len(categories), len(defs), len(quests)))
