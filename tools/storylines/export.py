"""
Bake the hand-written zone story chapters (chapters.py) into
MUI_DB/MUI_StorylineDB.lua.

    python tools/storylines/export.py            # write the DB + print the report
    python tools/storylines/export.py --report   # report only
    python tools/storylines/export.py 44 10      # report only, these zones

Needs lupa: the generated MUI_*DB.lua files are evaluated to resolve quest
names, chains and quest-giver positions. Each chapter entry in chapters.py
is a quest name ("Blackrock Bounty": every zone quest with that name), a
chain ("+Sven's Revenge": that quest plus everything linked to it through
prerequisite / follow-up / exclusive links inside the zone), a hub
(HUB(x, y): every quest left over whose giver stands within `r` map
percent of the point, with its chain) or a quest id (166: a quest the
quest log sorts under another zone, such as a dungeon's last step of a
zone's story). A chapter named None claims its quests without showing
them: for a world-spanning chain a town hub would otherwise sweep up. Entries claim quests in order, so
a story chapter listed before the town hub keeps its quests out of it. A
quest that starts from a dropped item and has no prerequisite / follow-up
inside the zone is a one-shot nobody's story tells: it is never put in a
chapter, even when named. A hub likewise passes over a lone quest that is
not the town's business: one far above the hub's level, one handed in
outside the zone (a "Supplies to Nethergarde" errand to another zone), one
whose work all lies in other zones (Gadgetzan's "Hunting for Ectoplasm"), or
a bare "go speak to" quest with nothing to do ("Rest and Relaxation", a
commission handed over on the spot), a reputation unlock sold by the
faction's quartermaster ("Mantles of the Dawn"), one locked behind a
profession ("The Family and the Fishing Pole") — and over a whole chain
of bare deliveries, the flight-path tutorials ("Flight to Auberdine",
"Ride to Thunder Bluff") that take a trip out of the zone, as well as the
delivery out of the zone that ends a chain ("Shipment to Stormwind");
a town's own errand chain ("A Free Lunch") stays.

Output per zone: chapters sorted by their lowest quest level, each a list
of steps in prerequisite order. Same-named quests in a chapter fold into
one step (a 13-part "The Legend of Stalvan" is one step with 13 ids; the
runtime numbers the parts). A step whose ids exclude each other
(exclusiveTo) is marked `any = true`: finishing one finishes the step —
that covers same-named faction variants as well as two single quests that
rule each other out ("Escape Through Stealth" / "Escape Through Force"),
which fold into one step too. Whole chains that exclude one another (the
three Scepter paths) stay separate; the runtime hides the ones a finished
quest has ruled out.
"""
import math
import os
import re
import sys
from collections import defaultdict

from lupa import LuaRuntime, lua_type

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from chapters import ZONES  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DB_DIR = os.path.join(ROOT, "MUI_DB")
OUT = os.path.join(DB_DIR, "MUI_StorylineDB.lua")

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
CAP = {}
object = function(name) return function(t) CAP[name] = t end end
""")
for f in ("MUI_QuestDB", "MUI_NpcDB", "MUI_ObjectDB", "MUI_ZoneDB", "MUI_QuestClustersDB"):
    lua.execute(open(os.path.join(DB_DIR, f + ".lua"), encoding="utf-8").read())
cap = lua.globals().CAP
QUESTS = cap.QuestDB._data
NPCS = cap.NpcDB._data
OBJECTS = cap.ObjectDB._data
ZONE = cap.ZoneDB._data
CLUSTERS = cap.QuestClustersDB._data


def tbl(t):
    return [t[i] for i in range(1, len(t) + 1)] if t is not None else []


def ids(t):
    out = []
    for v in tbl(t):
        if lua_type(v) == "table":
            out.append(v[1])
        elif v is not None:
            out.append(v)
    return out


def quest_zone(q):
    z = q.zoneOrSort if q.zoneOrSort is not None else 0
    if ZONE.subToPar[z] is not None:
        z = ZONE.subToPar[z]
    return z


def norm(name):
    return re.sub(r"\s+", " ", name).strip().lower()


def start_pos(q, zoneId):
    if q.startedBy is None:
        return None
    for npcId in ids(q.startedBy[1]):
        n = NPCS[npcId]
        if n is not None and n.spawns is not None and n.spawns[zoneId] is not None:
            pts = [(p[1], p[2]) for p in tbl(n.spawns[zoneId])]
            if pts:
                return sum(x for x, _ in pts) / len(pts), sum(y for _, y in pts) / len(pts)
    for objId in ids(q.startedBy[2]):
        o = OBJECTS[objId]
        if o is not None and o.spawns is not None and o.spawns[zoneId] is not None:
            pts = [(p[1], p[2]) for p in tbl(o.spawns[zoneId])]
            if pts:
                return sum(x for x, _ in pts) / len(pts), sum(y for _, y in pts) / len(pts)
    return None


class Zone:
    def __init__(self, zoneId):
        self.id = zoneId
        self.ui = ZONE.areaToUi[zoneId]
        self.quests = {}
        for qid, q in QUESTS.items():
            if quest_zone(q) != zoneId or q.requiredClasses or (q.specialFlags or 0) % 2 == 1:
                continue
            self.quests[qid] = q
        self.by_name = defaultdict(list)
        for qid, q in self.quests.items():
            self.by_name[norm(q.name)].append(qid)
        self.links = defaultdict(set)       # undirected, within the zone (variants included)
        self.chain_links = defaultdict(set) # the same without exclusiveTo: a quest's story ties
        self.prereq = defaultdict(set)      # qid -> quests that must come before it
        for qid, q in self.quests.items():
            before = ids(q.preQuestSingle) + ids(q.preQuestGroup)
            for other in before:
                other = abs(other)
                if other in self.quests:
                    self.prereq[qid].add(other)
            for other in before + ids(q.exclusiveTo) + ids(q.inGroupWith) + ids(q.childQuests):
                other = abs(other)
                if other in self.quests:
                    self.links[qid].add(other)
                    self.links[other].add(qid)
                    if other not in ids(q.exclusiveTo):
                        self.chain_links[qid].add(other)
                        self.chain_links[other].add(qid)
            for other in (q.nextQuestInChain, q.breadcrumbForQuestId, q.parentQuest):
                if other and other in self.quests:
                    self.links[qid].add(other)
                    self.links[other].add(qid)
                    self.chain_links[qid].add(other)
                    self.chain_links[other].add(qid)
                    if other == q.nextQuestInChain or other == q.breadcrumbForQuestId:
                        self.prereq[other].add(qid)
                    else:
                        self.prereq[qid].add(other)
        self.pos = {qid: start_pos(q, zoneId) for qid, q in self.quests.items()}
        self.taken = set()
        self.loners = set()
        for qid, q in self.quests.items():
            sb = q.startedBy
            if sb is not None and ids(sb[3]) and not ids(sb[1]) and not ids(sb[2]) and not self.links[qid]:
                self.loners.add(qid)

    def has_objectives(self, qid):
        q = self.quests[qid]
        if q.triggerEnd is not None:
            return True
        objs = q.objectives
        return objs is not None and any(objs[i] is not None and tbl(objs[i]) for i in range(1, 7))

    def same_giver_and_taker(self, qid):
        q = self.quests[qid]
        if q.startedBy is None or q.finishedBy is None:
            return False
        return bool(set(ids(q.startedBy[1])) & set(ids(q.finishedBy[1])))

    def min_rep(self, qid):
        rep = tbl(self.quests[qid].requiredMinRep)
        return rep[1] if len(rep) > 1 and rep[1] else 0

    def works_here(self, qid):
        """Whether any of the quest's located objectives lie on this zone's
        map. True as well when nothing is located (a delivery)."""
        c = CLUSTERS[qid]
        if c is None or c.objectives is None:
            return True
        seen = False
        for o in tbl(c.objectives):
            for group in (o.clusters, o.stray):
                for pt in tbl(group):
                    seen = True
                    if pt.uiMapId == self.ui:
                        return True
        return not seen

    def finishes_here(self, qid):
        fb = self.quests[qid].finishedBy
        if fb is None:
            return True
        npcs, objects = ids(fb[1]), ids(fb[2])
        if not npcs and not objects:
            return True
        for npcId in npcs:
            n = NPCS[npcId]
            if n is not None and n.spawns is not None and n.spawns[self.id] is not None:
                return True
        for objId in objects:
            o = OBJECTS[objId]
            if o is not None and o.spawns is not None and o.spawns[self.id] is not None:
                return True
        return False

    def adopt(self, qid):
        """Bring a quest sorted under another zone into this one, for a
        chapter that names it by id; its prerequisites among our quests
        keep it in order."""
        q = QUESTS[qid]
        if q is None:
            raise SystemExit("zone %d: no quest with id %d" % (self.id, qid))
        if qid in self.quests:
            return
        self.quests[qid] = q
        self.by_name[norm(q.name)].append(qid)
        for other in ids(q.preQuestSingle) + ids(q.preQuestGroup):
            if abs(other) in self.quests:
                self.prereq[qid].add(abs(other))
        self.pos[qid] = None

    def component(self, seed):
        out, stack = set(), [seed]
        while stack:
            x = stack.pop()
            if x in out or x in self.taken or x in self.loners:
                continue
            out.add(x)
            stack.extend(self.links[x])
        return out

    def resolve(self, chapter_name, entries):
        got = set()
        for entry in entries:
            if isinstance(entry, tuple) and entry[0] == "hub":
                _, hx, hy, r = entry
                near = [qid for qid, p in self.pos.items()
                        if p and qid not in self.taken and math.hypot(p[0] - hx, p[1] - hy) <= r]
                levels = sorted(self.quests[qid].questLevel or 0 for qid in near)
                median = levels[len(levels) // 2] if levels else 0
                for qid in near:
                    q = self.quests[qid]
                    if not self.chain_links[qid]:
                        why = None
                        if (q.questLevel or 0) > median + 10:
                            why = "far above the hub's level"
                        elif not self.finishes_here(qid):
                            why = "handed in elsewhere"
                        elif not self.works_here(qid):
                            why = "done elsewhere"
                        elif not self.has_objectives(qid):
                            why = "nothing to do in it"
                        elif self.same_giver_and_taker(qid) and self.min_rep(qid) > 0:
                            why = "a reputation unlock"
                        elif q.requiredSkill is not None:
                            why = "locked behind a profession"
                        if why:
                            print("  . %r: hub leaves out %r (L%d, lone, %s)" % (chapter_name, q.name, q.questLevel or 0, why))
                            continue
                    else:
                        comp = self.component(qid)
                        if comp and not any(self.has_objectives(m) for m in comp) and not all(self.finishes_here(m) for m in comp):
                            print("  . %r: hub leaves out the courier run %r (%d quests)" % (chapter_name, q.name, len(comp)))
                            continue
                        if comp and min(self.quests[m].questLevel or 0 for m in comp) > median + 10:
                            print("  . %r: hub leaves out %r (%d quests, far above the hub's level)" % (chapter_name, q.name, len(comp)))
                            continue
                        if comp and sum(1 for m in comp if self.works_here(m)) * 2 < len(comp):
                            print("  . %r: hub leaves out %r (%d quests, mostly done elsewhere)" % (chapter_name, q.name, len(comp)))
                            continue
                        # the chain's "now carry this to another zone" tail is not the town's story
                        for m in sorted(comp):
                            if not self.has_objectives(m) and not self.finishes_here(m):
                                print("  . %r: hub leaves out %r (a delivery out of the zone)" % (chapter_name, self.quests[m].name))
                                self.taken.add(m)
                    got |= self.component(qid)
                    self.taken |= got
                continue
            if isinstance(entry, int):
                self.adopt(entry)
                got.add(entry)
                self.taken.add(entry)
                continue
            expand = entry.startswith("+")
            name = entry[1:] if expand else entry
            matches = self.by_name.get(norm(name))
            if not matches:
                raise SystemExit("zone %d, chapter %r: no quest named %r" % (self.id, chapter_name, name))
            fresh = [m for m in matches if m not in self.taken]
            if any(m in self.loners for m in fresh):
                print("  ! %r: %r starts from a dropped item with no chain, left out" % (chapter_name, name))
                fresh = [m for m in fresh if m not in self.loners]
            if not fresh:
                print("  ! %r: %r already claimed by an earlier chapter" % (chapter_name, name))
            for m in fresh:
                got |= self.component(m) if expand else {m}
                self.taken |= got
        return got

    def steps(self, members):
        # prerequisite order, then level, then id
        members = set(members)
        order, done = [], set()
        pending = sorted(members, key=lambda m: ((self.quests[m].questLevel or 0), m))
        while pending:
            progress = False
            for m in list(pending):
                if all(p in done or p not in members for p in self.prereq[m]):
                    order.append(m)
                    done.add(m)
                    pending.remove(m)
                    progress = True
                    break
            if not progress:   # cycle (exclusive variants pointing at each other)
                m = pending.pop(0)
                order.append(m)
                done.add(m)
        steps, index = [], {}
        for m in order:
            key = norm(self.quests[m].name)
            if key in index:
                steps[index[key]]["ids"].append(m)
            else:
                index[key] = len(steps)
                steps.append({"name": self.quests[m].name, "ids": [m]})
        # single quests that rule each other out, whatever their names, are one step
        excl_of = {m: set(abs(x) for x in ids(self.quests[m].exclusiveTo)) for m in members}

        def alts(idlist):   # every quest in the step rules out every other one
            return all(x in excl_of[y] and y in excl_of[x] for x in idlist for y in idlist if x != y)

        merged = True
        while merged:
            merged = False
            for i in range(len(steps)):
                for j in range(i + 1, len(steps)):
                    a, b = steps[i]["ids"], steps[j]["ids"]
                    if alts(a) and alts(b) and all(x in excl_of[y] and y in excl_of[x] for x in a for y in b):
                        steps[i]["ids"] += steps[j]["ids"]
                        steps[i]["name"] += " / " + steps[j]["name"]
                        steps[i]["any"] = True
                        del steps[j]
                        merged = True
                        break
                if merged:
                    break
        for st in steps:
            if len(st["ids"]) > 1 and "any" not in st:
                st["any"] = all(m in excl_of[m2] for m in st["ids"] for m2 in st["ids"] if m2 != m)
        return steps


def build(zoneId, name, spec):
    z = Zone(zoneId)
    chapters = []
    for chapter_name, entries in spec:
        members = z.resolve(chapter_name, entries)
        if chapter_name is None:     # claimed to keep a hub from sweeping them up, no chapter
            continue
        if not members:
            print("  ! chapter %r is empty" % chapter_name)
            continue
        chapters.append({
            "name": chapter_name,
            "steps": z.steps(members),
            "minLevel": min(z.quests[m].questLevel or 0 for m in members),
            "count": len(members),
        })
    chapters.sort(key=lambda c: c["minLevel"])
    unassigned = sorted((m for m in z.quests if m not in z.taken),
                        key=lambda m: ((z.quests[m].questLevel or 0), m))
    return z, chapters, unassigned


def report(z, name, chapters, unassigned):
    print("=== %s (%d): %d quests, %d chapters, %d unassigned" % (
        name, z.id, len(z.quests), len(chapters), len(unassigned)))
    for ch in chapters:
        print("  [%s]  %d quests, %d steps, from L%d" % (ch["name"], ch["count"], len(ch["steps"]), ch["minLevel"]))
        for st in ch["steps"]:
            extra = ""
            if len(st["ids"]) > 1:
                extra = " x%d%s" % (len(st["ids"]), " (any)" if st.get("any") else "")
            lv = z.quests[st["ids"][0]].questLevel or 0
            print("      L%-2d %s%s" % (lv, st["name"], extra))
    if unassigned:
        print("  unassigned: " + "; ".join("%s (L%d)" % (z.quests[m].name, z.quests[m].questLevel or 0) for m in unassigned))


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def emit(all_zones):
    lines = [
        "-- MUI_StorylineDB.lua  (AUTO-GENERATED — do not edit)",
        "-- Zone story chapters, hand-curated in tools/storylines/chapters.py.",
        "-- Regenerate via: python tools/storylines/export.py",
        'object "StorylineDB" {',
        "",
        "    -- Chapters of a zone (QuestDB area id), in story order:",
        "    --   { name, steps = { {questId, ...}, ... } }",
        "    -- A step lists the ids of same-named quests (a multi-part chain or",
        "    -- exclusive variants); `any = true` means one of them is enough.",
        "    GetChapters = function(self, areaId)",
        "        return self._data[areaId]",
        "    end;",
        "",
        "    _data = {",
    ]
    for zoneId, name, chapters in all_zones:
        lines.append("        [%d] = {  -- %s" % (zoneId, name))
        for ch in chapters:
            lines.append("            { name = %s, steps = {" % lua_str(ch["name"]))
            for st in ch["steps"]:
                body = ", ".join(str(i) for i in st["ids"])
                if st.get("any"):
                    body += ", any = true"
                lines.append("                { %s },  -- %s" % (body, st["name"]))
            lines.append("            } },")
        lines.append("        },")
    lines += ["    },", "}", ""]
    return "\n".join(lines)


def main():
    args = sys.argv[1:]
    only = [int(a) for a in args if a.isdigit()]
    write = not only and "--report" not in args
    all_zones = []
    for zoneId, (name, spec) in ZONES.items():
        if only and zoneId not in only:
            continue
        z, chapters, unassigned = build(zoneId, name, spec)
        report(z, name, chapters, unassigned)
        all_zones.append((zoneId, name, chapters))
    if write:
        text = emit(all_zones)
        with open(OUT, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("\nwrote %s (%d zones)" % (OUT, len(all_zones)))


if __name__ == "__main__":
    main()
