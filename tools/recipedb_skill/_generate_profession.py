"""Generate a full profession block in MUI_RecipeDB.lua from playjournals data.

Pulls reagents, output (creates), skillrange (color_level_1..4) from
profession_skills.json, and source from spells.json + items.json + npcs.json
using the same mapping logic as _patch_ench_sources.py.

Usage:
    py tools/recipedb_skill/_generate_profession.py COOKING 185 --category Consumable
    py tools/recipedb_skill/_generate_profession.py FIRST_AID 129

Profession `type` IDs (Classic Era):
    129  First Aid          164 Blacksmithing      165 Leatherworking
    171  Alchemy            185 Cooking            186 Mining (Smelting)
    197  Tailoring          202 Engineering        333 Enchanting
"""

from __future__ import annotations
import argparse
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "MUI_DB" / "MUI_RecipeDB.lua"
TMP = os.environ.get("TEMP") or os.environ.get("TMP") or "/tmp"

ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument("prof_key", help='Profession key in MUI_RecipeDB (e.g. "COOKING")')
ap.add_argument("prof_type", type=int, help="Profession type ID in profession_skills.json")
ap.add_argument("--category", default=None,
                help='Stamp every emitted entry with this category (e.g. "Consumable")')
ap.add_argument("--auto-category", action="store_true",
                help="Derive each entry's category from the output item's class.subclass "
                     "(Plate / Mail / Sword / Axe / Stone / ...). Overrides --category "
                     "for entries whose output item maps to a known type.")
args = ap.parse_args()

PROF_KEY  = args.prof_key
PROF_TYPE = args.prof_type
CATEGORY  = args.category
AUTO_CAT  = args.auto_category


# Output item class.subclass → display category. Verified against blacksmithing
# samples (Big Black Mace=2.4, Blight polearm=2.6, Bronze Poniard dagger=2.15,
# Coarse Weightstone=0.-3, Iron Shield Spike=0.6, ...).
CATEGORY_BY_TYPE = {
    # Armor (class 4). Negative subclasses are playjournals' encoding for
    # the special inventory slots that don't have an own subclass in WoW's
    # ItemSubClass table (Back, Shirt, Trinket-engineering, etc.).
    "4.-8": "Shirt",          # Body slot (cloth shirts, tabards)
    "4.-6": "Cloak",          # Back slot
    "4.-4": "Engineered Item", # Trinket-slot engineering items
    "4.-3": "Engineered Item", # Head-slot engineering trinkets (goggles, etc.)
    "4.0":  "Misc Armor",     # Dresses, holiday outfits
    "4.1":  "Cloth Armor",
    "4.2":  "Leather Armor",
    "4.3":  "Mail Armor",
    "4.4":  "Plate Armor",
    "4.6":  "Shield",
    # Weapons (class 2)
    "2.0":  "Axe",         "2.1":  "Axe",         # one- and two-handed
    "2.2":  "Bow",
    "2.3":  "Gun",
    "2.4":  "Mace",        "2.5":  "Mace",
    "2.6":  "Polearm",
    "2.7":  "Sword",       "2.8":  "Sword",
    "2.10": "Staff",
    "2.13": "Fist Weapon",
    "2.15": "Dagger",
    "2.16": "Thrown",
    "2.18": "Crossbow",
    "2.19": "Wand",
    "2.20": "Fishing Pole",
    # Consumables (class 0) — finer split for Alchemy + BS weapon coatings.
    "0.-3":  "Weapon Coating",     # Sharpening Stones (BS) + Shadow/Frost Oils (Alchemy)
    "0.0":   "Oil",                # Oil of Immolation
    "0.1":   "Potion",
    "0.2":   "Elixir",
    "0.2.1": "Elixir",             # Battle Elixir variant
    "0.2.2": "Elixir",             # Guardian Elixir variant
    "0.3":   "Flask",
    "0.6":   "Item Enhancement",   # Shield Spikes
    # Trade Goods (class 7). 7.10 (Elemental essences) are crafting reagents
    # for further transmutes/enchants — split off from the generic bucket.
    "7.0":   "Trade Goods",
    "7.7":   "Trade Goods",
    "7.10":  "Reagent",
    "7.11":  "Trade Goods",
    "7.12":  "Trade Goods",
    # Miscellaneous / quest items
    "12.0":  "Other",
    "15.1":  "Reagent",            # Stonescale Oil etc.
}

# Fallback by item class when the subclass isn't in the table above.
CATEGORY_BY_CLASS = {
    "0":  "Consumable",
    "1":  "Bag",         # Bags / Soul Bags / Herb Bags / Quivers
    "2":  "Weapon",
    "4":  "Armor",
    "7":  "Trade Goods",
    "13": "Other",
    "15": "Other",
}


def category_for(skill: dict) -> str | None:
    creates = skill.get("creates") or {}
    iid = creates.get("item_id")
    if not iid: return None
    it = item_by_id.get(iid)
    if not it: return None
    t = it.get("type") or ""
    if t in CATEGORY_BY_TYPE:
        return CATEGORY_BY_TYPE[t]
    cls = t.split(".", 1)[0]
    return CATEGORY_BY_CLASS.get(cls)

SKILLS  = json.load(open(os.path.join(TMP, "pj_skills2.json"), encoding="utf-8"))
SPELLS  = json.load(open(os.path.join(TMP, "pj_spells.json"),  encoding="utf-8"))
ITEMS   = json.load(open(os.path.join(TMP, "pj_items.json"),   encoding="utf-8"))
NPCS    = json.load(open(os.path.join(TMP, "pj_npcs.json"),    encoding="utf-8"))
OBJECTS = json.load(open(os.path.join(TMP, "pj_objects.json"), encoding="utf-8"))
STATIC  = json.load(open(os.path.join(TMP, "pj_static.json"),  encoding="utf-8"))

spell_by_id  = {int(s["id"]): s for s in SPELLS}
item_by_id   = {int(i["id"]): i for i in ITEMS}
npc_by_id    = {int(n["id"]): n for n in NPCS}
object_by_id = {int(o["id"]): o for o in OBJECTS}

# id → name lookups from static.json. Empty strings if the data file isn't
# present — the rep branch falls back to REP_NPCS in that case.
FACTION_NAME  = {f["id"]: f["name"] for f in (STATIC.get("factions") or [])}
STANDING_NAME = {s["id"]: s["name"] for s in (STATIC.get("reputationStandings") or [])}


def item_reputation(item: dict):
    """Returns (faction_name, standing_name) when the item carries a
    `requires_faction` field, else None. This is the authoritative source
    when present — overrides the REP_NPCS NPC→default-standing fallback."""
    rf = item.get("requires_faction")
    if not rf: return None
    fid, rid = rf.get("faction_id"), rf.get("reputation_id")
    fac = FACTION_NAME.get(fid)
    sta = STANDING_NAME.get(rid)
    if not fac or not sta: return None
    return fac, sta


# Curated overrides for items whose rep gate is on the vendor entry rather
# than the item itself (playjournals' items.json doesn't capture vendor-level
# rep). Each entry: itemId -> (faction, standing).
ITEM_REP_OVERRIDES = {
    # Master *smith specialization plans, sold by Lokhtos Darkbargainer.
    # All require Exalted with Thorium Brotherhood AND the BS specialization.
    19208: ("Thorium Brotherhood", "Exalted"),  # Plans: Black Amnesty
    19209: ("Thorium Brotherhood", "Exalted"),  # Plans: Blackfury
    19210: ("Thorium Brotherhood", "Exalted"),  # Plans: Ebon Hand
    19211: ("Thorium Brotherhood", "Exalted"),  # Plans: Blackguard
    19212: ("Thorium Brotherhood", "Exalted"),  # Plans: Nightfall
}


# ---- Source resolution (mirrors _patch_ench_sources.py) ----

ZONE_ALIASES = {3429: 3428}

REP_NPCS = {
    10856: ("Argent Dawn", "Honored"),
    10857: ("Argent Dawn", "Honored"),
    12944: ("Thorium Brotherhood", "Honored"),
    11536: ("Cenarion Circle", "Honored"),
    15191: ("Cenarion Circle", "Honored"),
    14723: ("Zandalar Tribe", "Friendly"),
    14722: ("Zandalar Tribe", "Friendly"),
    14724: ("Zandalar Tribe", "Friendly"),
    12777: ("Hydraxian Waterlords", "Honored"),
}


def npc_zones(nid: int) -> set[int]:
    n = npc_by_id.get(nid)
    if not n: return set()
    raw = {l.get("zone_id") for l in (n.get("locations") or []) if l.get("zone_id")}
    return {ZONE_ALIASES.get(z, z) for z in raw}


def object_zones(oid: int) -> set[int]:
    o = object_by_id.get(oid)
    if not o: return set()
    raw = {l.get("zone_id") for l in (o.get("locations") or []) if l.get("zone_id")}
    return {ZONE_ALIASES.get(z, z) for z in raw}


def npc_faction(nid: int) -> str:
    n = npc_by_id.get(nid) or {}
    a, h = n.get("react_to_alliance", 0) or 0, n.get("react_to_horde", 0) or 0
    if a > 0 and h < 0: return "alliance"
    if a < 0 and h > 0: return "horde"
    return "neutral"


def pick_vendor(vendors):
    by_fac = {"alliance": [], "horde": [], "neutral": []}
    for v in vendors:
        nid = v.get("npc_id")
        if nid is None: continue
        by_fac[npc_faction(nid)].append(nid)
    if by_fac["neutral"]:
        return {"npc": by_fac["neutral"][0]}
    if by_fac["alliance"] and by_fac["horde"]:
        return {"npcA": by_fac["alliance"][0], "npcH": by_fac["horde"][0]}
    if by_fac["alliance"]:
        return {"npc": by_fac["alliance"][0]}
    if by_fac["horde"]:
        return {"npc": by_fac["horde"][0]}
    return {"npc": vendors[0].get("npc_id")}


def lua_source(table):
    keys = ["kind", "npc", "npcA", "npcH", "zone", "item",
            "quest", "faction", "standing", "event"]
    parts = []
    for k in keys:
        if k not in table: continue
        v = table[k]
        if isinstance(v, str):
            parts.append(f'{k} = "{v}"')
        else:
            parts.append(f"{k} = {v}")
    return "{ " + ", ".join(parts) + " }"


def map_source(spell_id: int) -> str | None:
    s = spell_by_id.get(spell_id)
    if not s: return None
    sources = s.get("sources") or []
    if not sources: return None

    t = sources[0].get("type")

    if t == 4:
        return lua_source({"kind": "trainer"})

    if t == 1:
        type1 = [x for x in sources if x.get("type") == 1]
        for x in type1:
            rep = REP_NPCS.get(x.get("npc_id"))
            if rep:
                return lua_source({"kind": "reputation",
                                   "faction": rep[0], "standing": rep[1]})
        # Many trainers → generic trainer; otherwise specific vendor / split.
        if len(type1) >= 3:
            return lua_source({"kind": "trainer"})
        pick = pick_vendor(type1)
        pick["kind"] = "vendor"
        return lua_source(pick)

    if t == 2:
        # Spell learned from clicking an in-world object (Tablet of Madness
        # in ZG, etc.). Emit as a drop in that object's zone — the closest
        # fit in our schema; renderer shows "Loot: creatures in <zone>".
        oid = sources[0].get("object_id")
        zones = object_zones(oid)
        if len(zones) == 1:
            (z,) = zones
            return lua_source({"kind": "drop", "zone": z})
        return lua_source({"kind": "drop"})

    if t == 3:
        return lua_source({"kind": "quest", "quest": sources[0].get("quest_id")})

    if t == 0:
        item_id = sources[0].get("item_id")
        item = item_by_id.get(item_id)
        if not item:
            return lua_source({"kind": "drop", "item": item_id})
        isrc = item.get("sources") or []
        if not isrc:
            return lua_source({"kind": "drop", "item": item_id})

        # Quest reward at the item level (the recipe item is given as a
        # reward when turning in some quest — Dig Rat Stew, Chimaerok Chops,
        # …). Take precedence over generic vendor/drop fallbacks.
        quests = [x for x in isrc if x.get("type") == 4 and x.get("quest_id")]
        if quests:
            return lua_source({"kind": "quest",
                               "quest": quests[0]["quest_id"],
                               "item": item_id})

        # Vendor / rep.
        vendors = [x for x in isrc if x.get("type") == 3]
        if vendors:
            # Authoritative #1: hand-curated overrides for items whose rep
            # gate lives on the vendor entry rather than the item itself.
            if item_id in ITEM_REP_OVERRIDES:
                fac, sta = ITEM_REP_OVERRIDES[item_id]
                return lua_source({"kind": "reputation",
                                   "faction": fac, "standing": sta,
                                   "item": item_id})
            # Authoritative #2: item carries an explicit requires_faction.
            irep = item_reputation(item)
            if irep:
                return lua_source({"kind": "reputation",
                                   "faction": irep[0], "standing": irep[1],
                                   "item": item_id})
            # Fallback: NPC is a known faction quartermaster — use the
            # NPC's default standing from REP_NPCS (less accurate; some
            # items on the same NPC require higher standings).
            for x in vendors:
                rep = REP_NPCS.get(x.get("npc_id"))
                if rep:
                    return lua_source({"kind": "reputation",
                                       "faction": rep[0], "standing": rep[1],
                                       "item": item_id})
            pick = pick_vendor(vendors)
            pick["kind"] = "vendor"
            pick["item"] = item_id
            return lua_source(pick)

        # World-drop tag wins over any specific NPC drops — when present,
        # the formula is broadly available from any same-level mob and the
        # named NPCs in type=2 entries are just high-rate examples.
        # (Without this, e.g. Plans: Radiant Circlet wrongly resolves to
        # "Loot: Azuregos" because Azuregos drops it at 3.22% even though
        # the formula is a generic level-51+ world drop.)
        if any(x.get("type") == 1 for x in isrc):
            return lua_source({"kind": "worldDrop", "item": item_id})

        # NPC drops.
        drops = [x for x in isrc if x.get("type") == 2 and x.get("npc_id")]
        if drops:
            npc_ids = [x["npc_id"] for x in drops]
            zones = set()
            for nid in npc_ids:
                zones.update(npc_zones(nid))
            if len(npc_ids) == 1:
                nid = npc_ids[0]
                z = next(iter(npc_zones(nid)), None)
                rec = {"kind": "drop", "npc": nid, "item": item_id}
                if z is not None: rec["zone"] = z
                return lua_source(rec)
            if len(zones) == 1:
                (z,) = zones
                return lua_source({"kind": "drop", "zone": z, "item": item_id})
            return lua_source({"kind": "worldDrop", "item": item_id})

        # Object containers (chests, plans, books etc. that sit in the world
        # rather than dropping from a creature). Same zone-coverage logic as
        # NPC drops — single zone collapses to "drop, zone=..." and the
        # renderer shows "Loot: creatures in <zone>" (close enough; the
        # player knows where to look).
        obj_drops = [x for x in isrc if x.get("type") == 8 and x.get("object_id")]
        if obj_drops:
            obj_ids = [x["object_id"] for x in obj_drops]
            zones = set()
            for oid in obj_ids:
                zones.update(object_zones(oid))
            if len(zones) == 1:
                (z,) = zones
                return lua_source({"kind": "drop", "zone": z, "item": item_id})
            if not zones:
                return lua_source({"kind": "drop", "item": item_id})
            return lua_source({"kind": "worldDrop", "item": item_id})

        # Contained-in-item (lootbox / holiday container).
        contained = [x for x in isrc if x.get("type") == 7 and x.get("item_id")]
        if contained:
            parent = item_by_id.get(contained[0]["item_id"])
            if parent:
                pname = (parent.get("name") or "").lower()
                if "winter veil" in pname or "smokywood pastures" in pname or "ticking present" in pname:
                    return lua_source({"kind": "worldDrop",
                                       "event": "Feast of Winter Veil",
                                       "item": item_id})
                qsrc = next((y for y in (parent.get("sources") or [])
                             if y.get("type") == 4 and y.get("quest_id")), None)
                if qsrc:
                    return lua_source({"kind": "quest", "quest": qsrc["quest_id"],
                                       "item": item_id})

        return lua_source({"kind": "drop", "item": item_id})

    return None


# ---- Emit ----

def format_entry(skill):
    sid = skill["id"]
    parts = []
    cat = (AUTO_CAT and category_for(skill)) or CATEGORY
    if cat:
        parts.append(f'category = "{cat}"')
    parts.append("source = " + (map_source(sid) or "nil"))

    creates = skill.get("creates") or {}
    if creates.get("item_id"):
        cnt = creates.get("item_count") or 1
        if cnt == 0: cnt = 1
        parts.append(f"output = {{ {creates['item_id']}, {cnt} }}")

    reagents = skill.get("reagents") or []
    if reagents:
        r = ", ".join(f"{{{r['item_id']}, {r['item_count']}}}" for r in reagents)
        parts.append(f"reagents = {{ {r} }}")

    o = skill.get("color_level_1")
    y = skill.get("color_level_2")
    g = skill.get("color_level_3")
    t = skill.get("color_level_4")
    if any(v is not None for v in (o, y, g, t)):
        o = o if o is not None else (y if y is not None else 1)
        y = y if y is not None else o
        g = g if g is not None else (y + t) // 2 if t is not None else y
        t = t if t is not None else g
        parts.append(f"skillrange = {{ {o:>3}, {y:>3}, {g:>3}, {t:>3} }}")

    name = skill.get("name") or "?"
    return f"        [{sid:>6}] = {{ {', '.join(parts)} }},  -- {name}"


prof_skills = [s for s in SKILLS
               if s.get("type") == PROF_TYPE
               and (s.get("reagents") or s.get("creates"))]   # skip rank-up stubs
prof_skills.sort(key=lambda s: s.get("learned_at_rank") or 0)
print(f"Generating {PROF_KEY} block: {len(prof_skills)} recipes", file=sys.stderr)

lines = [
    f"    {PROF_KEY:<15} = {{",
    "",
    "        -- Reagents, output, skillrange and source harvested by",
    "        -- tools/recipedb_skill/_generate_profession.py from",
    "        -- wow.playjournals.com profession_skills + spells + items + npcs.",
    "        -- Sorted by `learned_at_rank` ascending.",
    "",
]
for s in prof_skills:
    lines.append(format_entry(s))
lines.append("")
lines.append("    },")

block = "\n".join(lines) + "\n"

# Patch into MUI_RecipeDB.lua, replacing the existing profession block.
with open(DB, encoding="utf-8") as f:
    text = f.read()

# Replace the existing profession block. Two shapes to handle:
#   1.  PROF_KEY = {},                     (empty single-line placeholder)
#   2.  PROF_KEY = {\n        ...\n    },  (multi-line body)
# The non-greedy multi-line pattern would otherwise gobble up empty
# single-line blocks PLUS following multi-line blocks until the next
# `    },` line — that's how an earlier run ate FIRST_AID. Try the
# empty-block pattern first; only fall back to multi-line if needed.
empty_pat = re.compile(
    rf"^    {re.escape(PROF_KEY)}\s*=\s*\{{\s*\}},?\s*\r?\n",
    re.MULTILINE,
)
multi_pat = re.compile(
    rf"^    {re.escape(PROF_KEY)}\s*=\s*\{{(?:(?!^    \}},?\r?\n).)*?^    \}},?\r?\n",
    re.MULTILINE | re.DOTALL,
)
new_text, n = empty_pat.subn(block, text, count=1)
if n == 0:
    new_text, n = multi_pat.subn(block, text, count=1)
if n == 0:
    print(f"ERROR: no {PROF_KEY} block found in {DB}", file=sys.stderr)
    sys.exit(2)

with open(DB, "w", encoding="utf-8") as f:
    f.write(new_text)

print(f"Patched {PROF_KEY}: {len(prof_skills)} recipes -> {DB}", file=sys.stderr)
