"""One-shot patcher: rewrite the ENCHANTING block in MUI_RecipeDB.lua
with `source` fields derived from playjournals' spells.json + items.json.

Source-type mapping (playjournals → our schema):

  spell.sources[].type = 0  (recipe item)        → look up the item:
      item.sources[].type = 1 (world drop)        → worldDrop
      item.sources[].type = 2 (NPC drop)          → drop, npc = npc_id
      item.sources[].type = 3 (vendor)            → vendor, npc = npc_id
                                                    (caller refines to "reputation" by hand
                                                    for the known faction quartermasters)
      item.sources[].type = 7 (contained in item) → drop, item = item_id
  spell.sources[].type = 1, many npc_ids                → trainer  (taught by any trainer)
  spell.sources[].type = 1, single npc_id               → vendor, npc = npc_id
  spell.sources[].type = 3 (quest reward)               → quest, quest = quest_id
  spell.sources[].type = 4 (auto-learned)               → trainer

Reagents and skillrange are NOT touched here — _patch_ench.py already did
that from profession_skills.json.
"""

from __future__ import annotations
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "MUI_DB" / "MUI_RecipeDB.lua"
TMP = os.environ.get("TEMP") or os.environ.get("TMP") or "/tmp"

SPELLS = json.load(open(os.path.join(TMP, "pj_spells.json"), encoding="utf-8"))
ITEMS  = json.load(open(os.path.join(TMP, "pj_items.json"),  encoding="utf-8"))
NPCS   = json.load(open(os.path.join(TMP, "pj_npcs.json"),   encoding="utf-8"))

spell_by_id = {int(s["id"]): s for s in SPELLS}
item_by_id  = {int(i["id"]): i for i in ITEMS}
npc_by_id   = {int(n["id"]): n for n in NPCS}


# Same-family zone aliasing. Some content spans multiple distinct area-ids
# that players conceptually treat as one place (AQ20 + AQ40 = "Ahn'Qiraj").
# Map every related id onto a single canonical id; the renderer overrides
# the canonical's display name to the family label.
ZONE_ALIASES: dict[int, int] = {
    3429: 3428,  # Ruins of Ahn'Qiraj  → Ahn'Qiraj  (canonical = AQ40 id)
}


def npc_zones(npc_id: int) -> set[int]:
    n = npc_by_id.get(npc_id)
    if not n: return set()
    raw = {l.get("zone_id") for l in (n.get("locations") or []) if l.get("zone_id")}
    return {ZONE_ALIASES.get(z, z) for z in raw}


def npc_faction(npc_id: int) -> str:
    """'alliance' | 'horde' | 'neutral' from the NPC's react flags."""
    n = npc_by_id.get(npc_id) or {}
    a, h = n.get("react_to_alliance", 0), n.get("react_to_horde", 0)
    if a is None: a = 0
    if h is None: h = 0
    if a > 0 and h < 0: return "alliance"
    if a < 0 and h > 0: return "horde"
    return "neutral"


def pick_vendor(vendors: list[dict]) -> dict:
    """From a list of {npc_id, ...} vendor sources, return either:
      { npc = <neutral-id> }                — any neutral vendor exists
      { npcA = <id>, npcH = <id> }          — clean A/H split, no neutral
      { npc = <id> }                        — only one faction-locked vendor
    """
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
    # All faction info missing — fall back to first entry.
    return {"npc": vendors[0].get("npc_id")}


# Known reputation quartermasters (NPC ID → (faction name, required standing)).
# Used to upgrade plain "vendor" sources to "reputation" when the seller is
# a faction quartermaster.
REP_NPCS = {
    10856: ("Argent Dawn", "Honored"),         # Argent Quartermaster Hasana (EPL)
    10857: ("Argent Dawn", "Honored"),         # Argent Quartermaster Lightspark (WPL)
    12944: ("Thorium Brotherhood", "Honored"), # Lokhtos Darkbargainer (BRD)
    11536: ("Cenarion Circle", "Honored"),     # Quartermaster Miranda Breechlock (Silithus)
    15191: ("Cenarion Circle", "Honored"),     # Logistics Officer Silas Briarwater (Silithus)
    14723: ("Zandalar Tribe", "Friendly"),     # Vinchaxa (ZG)
    14722: ("Zandalar Tribe", "Friendly"),     # Mishi (ZG)
    14724: ("Zandalar Tribe", "Friendly"),     # other ZG vendor
    12777: ("Hydraxian Waterlords", "Honored"), # Duke Hydraxis
}


def lua_source(table: dict) -> str:
    """Render a Lua table literal for our source schema."""
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

    first = sources[0]
    t = first.get("type")

    # Auto-learned with profession.
    if t == 4:
        return lua_source({"kind": "trainer"})

    # Multiple trainer-like vendors → generic trainer.
    if t == 1 and len(sources) >= 3:
        return lua_source({"kind": "trainer"})

    # Single vendor / trainer entry (or a faction-split pair).
    if t == 1:
        type1 = [s for s in sources if s.get("type") == 1]
        # Rep quartermaster always wins — single NPC overrides faction logic.
        for s in type1:
            rep = REP_NPCS.get(s.get("npc_id"))
            if rep:
                return lua_source({"kind": "reputation",
                                   "faction": rep[0], "standing": rep[1]})
        pick = pick_vendor(type1)
        pick["kind"] = "vendor"
        return lua_source(pick)

    # Direct quest reward.
    if t == 3:
        return lua_source({"kind": "quest", "quest": first.get("quest_id")})

    # Recipe item — look up the item's sources.
    if t == 0:
        item_id = first.get("item_id")
        item = item_by_id.get(item_id)
        if not item:
            return lua_source({"kind": "drop", "item": item_id})
        isrc = (item.get("sources") or [])
        if not isrc:
            return lua_source({"kind": "drop", "item": item_id})

        # Quest reward at the item level — the recipe item is given as a
        # quest reward (Dig Rat Stew, Chimaerok Chops, ...). Take precedence
        # over generic vendor/drop fallbacks.
        quests = [s for s in isrc if s.get("type") == 4 and s.get("quest_id")]
        if quests:
            return lua_source({"kind": "quest",
                               "quest": quests[0]["quest_id"],
                               "item": item_id})

        # Vendor sources: detect rep quartermasters first (their NPC is in
        # REP_NPCS), otherwise pick A/H split or neutral via pick_vendor.
        vendors = [s for s in isrc if s.get("type") == 3]
        if vendors:
            for s in vendors:
                rep = REP_NPCS.get(s.get("npc_id"))
                if rep:
                    return lua_source({"kind": "reputation",
                                       "faction": rep[0], "standing": rep[1],
                                       "item": item_id})
            pick = pick_vendor(vendors)
            pick["kind"] = "vendor"
            pick["item"] = item_id
            return lua_source(pick)

        # Drop sources — collect every NPC that drops the formula, then
        # decide based on zone coverage:
        #   1 NPC                    → drop, npc = id, zone = npc's zone (so the
        #                              renderer doesn't depend on MUI_NpcDB
        #                              having zoneID populated for instance NPCs)
        #   many NPCs, same zone     → drop, zone = id   ("creatures in <zone>")
        #   many NPCs, mixed zones   → worldDrop
        drops = [s for s in isrc if s.get("type") == 2 and s.get("npc_id")]
        if drops:
            npc_ids = [s["npc_id"] for s in drops]
            zones = set()
            for nid in npc_ids:
                zones.update(npc_zones(nid))
            if len(npc_ids) == 1:
                nid = npc_ids[0]
                z = next(iter(npc_zones(nid)), None)
                rec = {"kind": "drop", "npc": nid, "item": item_id}
                if z is not None:
                    rec["zone"] = z
                return lua_source(rec)
            if len(zones) == 1:
                (z,) = zones
                return lua_source({"kind": "drop", "zone": z, "item": item_id})
            # Multi-zone drop → world drop.
            return lua_source({"kind": "worldDrop", "item": item_id})

        # Pure world-drop entries in the data.
        if any(s.get("type") == 1 for s in isrc):
            return lua_source({"kind": "worldDrop", "item": item_id})

        # Contained-in-another-item only (no direct drops). Resolve via the
        # container's source so we can label holiday/event rewards properly.
        contained = [s for s in isrc if s.get("type") == 7 and s.get("item_id")]
        if contained:
            parent = item_by_id.get(contained[0]["item_id"])
            if parent:
                pname = (parent.get("name") or "").lower()
                if "winter veil" in pname or "smokywood pastures" in pname or "ticking present" in pname:
                    return lua_source({"kind": "worldDrop", "event": "Feast of Winter Veil", "item": item_id})
                # Other quest-reward containers: fall through to quest source.
                psrc = (parent.get("sources") or [])
                qsrc = next((s for s in psrc if s.get("type") == 4 and s.get("quest_id")), None)
                if qsrc:
                    return lua_source({"kind": "quest", "quest": qsrc["quest_id"], "item": item_id})

        return lua_source({"kind": "drop", "item": item_id})

    return None


# Read DB.
with open(DB, encoding="utf-8") as f:
    text = f.read()

start = text.index("ENCHANTING")
m = re.search(r"^    \},", text[start:], re.MULTILINE)
end = start + m.end()
block = text[start:end]

updated = 0
def update_line(line: str) -> str:
    global updated
    m_sid = re.search(r"\[\s*(\d+)\s*\]", line)
    if not m_sid: return line
    sid = int(m_sid.group(1))
    new_src = map_source(sid)
    if not new_src: return line
    # Replace existing `source = { ... }` block in this line.
    new_line, n = re.subn(r"source\s*=\s*\{[^}]*\}", f"source = {new_src}", line)
    if n: updated += 1
    return new_line

new_block = "\n".join(update_line(l) for l in block.split("\n"))
new_text = text[:start] + new_block + text[end:]

with open(DB, "w", encoding="utf-8") as f:
    f.write(new_text)

print(f"Updated {updated} source fields in {DB}", file=sys.stderr)
