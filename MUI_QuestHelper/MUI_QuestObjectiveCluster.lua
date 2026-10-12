-- QuestObjectiveCluster: thin wrapper around precomputed cluster data
-- shipped in MUI_QuestClustersDB (generated offline by
-- tools/questdb_export/clusters.py — that's where the single-linkage
-- union-find / merge-small math lives, and outline.py next to it works out
-- each cluster's area). The runtime just materializes world-yard coords
-- lazily from the normalized values.
--
-- DB row shape per questId:
--   objectives = {
--     { kind, name,
--       clusters = { {uiMapId, rings = {packed, ...}, tris = packed,
--                     centroid = {nx,ny}, count}, ... },
--       stray    = { {uiMapId, normX, normY}, ... } },
--     ...                              -- one row per quest target
--   },
--   finisher = { {uiMapId, normX, normY}, ... }
--
-- A cluster's area is its `rings` (the outlines of its parts and of the
-- holes in them; a point inside an odd number of them is inside the area)
-- and the triangles `tris` that fill it, both packed into strings as
-- clusters.py describes. Unpacked, the area is a "shape": rings as flat
-- world-yard runs {wx, wy, wx, wy, ...}, tris as indices into the rings'
-- points taken together, and the box {minX, minY, maxX, maxY} round it
-- (MUI_BlobOutline has the geometry).
--
-- `kind` ∈ {"npc", "object", "item", "sourceitem", "trigger"}. `name` is
-- kept for tooltip / debug; runtime filtering uses position-within-type
-- matching (locale-safe — no string comparison against the localised
-- quest log). "sourceitem" rows (required source items — never a
-- leaderboard line) carry `itemId` and are filtered by bag contents.
--
-- Filtering: target rows are emitted in the same nested order Blizzard
-- walks q.objectives, so the Nth row of `kind="npc"` corresponds to the
-- Nth leaderboard entry of `type="monster"`. SetData walks `precomputed`
-- and `entry.objectives` in lockstep by type-position, dropping targets
-- whose leaderboard entry has `finished == true`. An objective without
-- any spawn data has no row (the Silk Cloth of "Items of Some
-- Consequence"), which would shift every later row of its kind one slot
-- up; such rows carry their real slot as `pos`. This stays accurate
-- for "kill X, Y, Z" quests as individual targets complete (the others'
-- clusters keep contributing; finished targets drop out).
--
-- Output (via GetClusters / GetPoints / GetFinisherPoints) is in world
-- yards, the convention the consumers (focus arrow, on-screen compass,
-- minimap and world-map area overlays) share. Every
-- cluster and stray point carries its continent (a required source item
-- can sit across the sea from the rest of the quest); the accessors take
-- an optional continentId filter and GetContinents lists what's present.
-- Every shape and stray point also names its target, for a tooltip over its
-- area: `objective`, the line's index in entry.objectives, or `itemId` for
-- a required source item. Clusters and stray points carry `target` too, the
-- row they come from: a target with stray points and no cluster is a lone
-- spot (GetLonePoints), where a clustered target's stray points are only
-- its outlying spawns.

-- Maps our target `kind` to the quest log leaderboard `type` string.
-- Stable across locales — Blizzard's leaderboard `type` is fixed
-- regardless of the client language.
local _KIND_TO_LEADER_TYPE = {
    ["npc"]     = "monster",
    ["object"]  = "object",
    ["item"]    = "item",
    ["trigger"] = "event",
}

-- Vertex count of the circle GetLoneShapes draws around each lone point.
local STRAY_CIRCLE_VERTICES = 24

-- How clusters.py packs an area: base-57 digits from "#" on, most significant
-- first. A coordinate is three of them, counting steps from COORD_LOW.
local DIGIT_FIRST  = 35
local DIGIT_BASE   = 57
local COORD_DIGITS = 3
local COORD_LOW    = -0.25
local COORD_STEP   = 1.5 / (DIGIT_BASE ^ COORD_DIGITS - 1)

-- The normalized coordinate packed at position `i` of `packed`.
local function _Coord(packed, i)
    local a, b, c = string.byte(packed, i, i + 2)
    return COORD_LOW + (((a - DIGIT_FIRST) * DIGIT_BASE + b - DIGIT_FIRST) * DIGIT_BASE
                        + c - DIGIT_FIRST) * COORD_STEP
end

-- The packed triangle indices of an area of `count` points, counted from 1.
local function _Indices(packed, count)
    local width = 1
    while DIGIT_BASE ^ width < count do width = width + 1 end
    local out = {}
    for i = 1, #packed, width do
        local v = 0
        for k = i, i + width - 1 do
            v = v * DIGIT_BASE + string.byte(packed, k) - DIGIT_FIRST
        end
        out[#out + 1] = v + 1
    end
    return out
end

-- Unpacked clusters by their DB row: an area is unpacked once.
local _converted = {}

class "QuestObjectiveCluster" {
    __init = function(self)
        self._clusters       = {}     -- list of { shape, centroid, count }
        self._points         = {}     -- flat stray points (world yards)
        self._continent      = nil
        self._finisherPoints = {}     -- world yards
        self._finisherCont   = nil
    end;

    -- Populate from a precomputed DB row, filtering out finished targets
    -- by walking entry.objectives leaderboard in lockstep — see file
    -- header for the type-position matching rule. `entry` is the watcher
    -- entry (or nil to include every target unfiltered).
    SetData = function(self, precomputed, entry)
        self._clusters       = {}
        self._points         = {}
        self._continent      = nil
        self._finisherPoints = {}
        self._finisherCont   = nil
        if not precomputed then return end

        -- isComplete short-circuits to "everything done" so the focus
        -- arrow drops the objective tier and falls through to finishers.
        local allDone = entry and entry.isComplete and true or false

        -- Bucket leaderboard entries by `type` for O(1) per-position
        -- lookup. Skip entirely when the quest is complete (we won't
        -- consult the buckets) or when no entry was passed.
        local boards, lineOf = {}, {}
        if not allDone and entry and entry.objectives then
            for i, o in ipairs(entry.objectives) do
                if o and o.type then
                    local arr = boards[o.type]
                    if not arr then arr = {}; boards[o.type] = arr end
                    arr[#arr + 1] = o
                    lineOf[o] = i
                end
            end
        end

        if not allDone and precomputed.objectives then
            -- Per-type counter advances each time we see a target of
            -- that kind — that counter IS the leaderboard slot index
            -- within the type.
            local typeIdx = {}
            for row, target in ipairs(precomputed.objectives) do
                local include = false
                local objective, itemId
                if target.kind == "sourceitem" then
                    -- Required source item: no leaderboard line, done once
                    -- the item is in the bags.
                    include = target.itemId ~= nil
                          and C_Item.GetItemCount(target.itemId) == 0
                    itemId = target.itemId
                else
                    local typeStr = _KIND_TO_LEADER_TYPE[target.kind]
                    if typeStr then
                        typeIdx[typeStr] = (typeIdx[typeStr] or 0) + 1
                        local pos      = target.pos or typeIdx[typeStr]
                        local board    = boards[typeStr]
                        local boardEnt = board and board[pos]
                        include = not (boardEnt and boardEnt.finished)
                        objective = boardEnt and lineOf[boardEnt]
                    end
                end
                if include then
                    if target.clusters then
                        for _, c in ipairs(target.clusters) do
                            local rec = self:_ConvertCluster(c)
                            if rec then
                                rec.target = row
                                rec.shape.objective, rec.shape.itemId = objective, itemId
                                self._clusters[#self._clusters + 1] = rec
                                self._continent = self._continent or rec._continent
                            end
                        end
                    end
                    if target.stray then
                        for _, s in ipairs(target.stray) do
                            local wx, wy, cont = MUI_MapMath:MapToWorld(
                                s.uiMapId, s.normX, s.normY)
                            if wx and wy then
                                self._points[#self._points + 1] =
                                    { wx, wy, cont, target = row, objective = objective, itemId = itemId }
                                self._continent = self._continent or cont
                            end
                        end
                    end
                end
            end
        end

        if precomputed.finisher then
            for _, f in ipairs(precomputed.finisher) do
                local wx, wy, cont = MUI_MapMath:MapToWorld(f.uiMapId, f.normX, f.normY)
                if wx and wy then
                    self._finisherPoints[#self._finisherPoints + 1] = { wx, wy }
                    self._finisherCont = self._finisherCont or cont
                end
            end
        end
    end;

    -- One precomputed cluster (uiMap + normalized centroid + packed area) as
    -- a world-yard record. Returns nil when the API can't resolve the uiMap.
    --
    -- A map's world position is linear in its normalized coordinates, so the
    -- world positions of two corners place every point: north-south runs
    -- down the map (with normalized y), east-west across it (with x).
    _ConvertCluster = function(self, c)
        local rec = _converted[c]
        if rec then return rec end
        if not c.uiMapId or not c.centroid or not c.rings then return nil end
        local x0, y0, cont = MUI_MapMath:MapToWorld(c.uiMapId, 0, 0)
        local x1, y1 = MUI_MapMath:MapToWorld(c.uiMapId, 1, 1)
        if not x0 or not x1 then return nil end
        local sx, sy = x1 - x0, y1 - y0

        local rings, count = {}, 0
        for r, packed in ipairs(c.rings) do
            local ring = {}
            for i = 1, #packed, 2 * COORD_DIGITS do
                ring[#ring + 1] = x0 + _Coord(packed, i + COORD_DIGITS) * sx
                ring[#ring + 1] = y0 + _Coord(packed, i) * sy
            end
            rings[r] = ring
            count = count + #ring / 2
        end
        rec = {
            shape = {
                rings = rings,
                tris  = _Indices(c.tris, count),
                box   = { MUI_BlobOutline:Bounds(rings) },
            },
            centroid   = { x0 + c.centroid[2] * sx, y0 + c.centroid[1] * sy },
            count      = c.count,
            _continent = cont,
        }
        _converted[c] = rec
        return rec
    end;

    -- The lone points as small circles (shapes of one ring, no triangles)
    -- for the minimap's area renderer: a target with too few spawns for an
    -- area still gets a clearly localised marker there. Radius is a
    -- legibility choice, not geography.
    GetLoneShapes = function(self, radiusYards, continentId)
        local shapes = {}
        local step = 2 * math.pi / STRAY_CIRCLE_VERTICES
        for _, p in ipairs(self:GetLonePoints(continentId)) do
            local ring = {}
            for v = 1, STRAY_CIRCLE_VERTICES do
                local a = (v - 1) * step
                ring[2 * v - 1] = p[1] + radiusYards * math.cos(a)
                ring[2 * v]     = p[2] + radiusYards * math.sin(a)
            end
            shapes[#shapes + 1] = {
                rings = { ring },
                box   = { p[1] - radiusYards, p[2] - radiusYards,
                          p[1] + radiusYards, p[2] + radiusYards },
                objective = p.objective,
                itemId    = p.itemId,
            }
        end
        return shapes
    end;

    -- ---- accessors ------------------------------------------------------
    -- continentId (optional) restricts clusters / points to one continent.

    GetClusters = function(self, continentId)
        if not continentId then return self._clusters end
        local out = {}
        for _, c in ipairs(self._clusters) do
            if c._continent == continentId then out[#out + 1] = c end
        end
        return out
    end;

    GetPoints = function(self, continentId)
        if not continentId then return self._points end
        local out = {}
        for _, p in ipairs(self._points) do
            if p[3] == continentId then out[#out + 1] = p end
        end
        return out
    end;

    -- The stray points of the targets that have no cluster (on
    -- `continentId`, when given): the spots of an objective found in one
    -- place or two. The outlying spawns of a clustered target are left out.
    GetLonePoints = function(self, continentId)
        local clustered = {}
        for _, c in ipairs(self:GetClusters(continentId)) do
            clustered[c.target] = true
        end
        local out = {}
        for _, p in ipairs(self:GetPoints(continentId)) do
            if not clustered[p.target] then out[#out + 1] = p end
        end
        return out
    end;

    -- Distinct continents carrying objective data, `firstContinent` moved
    -- to the front when present.
    GetContinents = function(self, firstContinent)
        local seen, out = {}, {}
        local function add(cont)
            if not cont or seen[cont] then return end
            seen[cont] = true
            if cont == firstContinent then
                table.insert(out, 1, cont)
            else
                out[#out + 1] = cont
            end
        end
        for _, c in ipairs(self._clusters) do add(c._continent) end
        for _, p in ipairs(self._points) do add(p[3]) end
        return out
    end;

    GetContinent         = function(self) return self._continent end;
    GetFinisherPoints    = function(self) return self._finisherPoints end;
    GetFinisherContinent = function(self) return self._finisherCont end;
    HasClusters          = function(self) return #self._clusters > 0 end;
    Count                = function(self) return #self._clusters end;

    -- True when there's no geographic data at all: no clusters, no stray
    -- objective points, no finisher points. Consumers (FocusedTargetArrow,
    -- FocusNavigation, MapQuestPoiManager) hide when this returns true.
    IsEmpty = function(self)
        return #self._clusters == 0
           and #self._points == 0
           and #self._finisherPoints == 0
    end;
}
