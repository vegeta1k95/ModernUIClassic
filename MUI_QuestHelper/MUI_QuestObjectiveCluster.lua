-- QuestObjectiveCluster: thin wrapper around precomputed cluster data
-- shipped in MUI_QuestClustersDB (generated offline by
-- tools/questdb_export/clusters.py — that's where the single-linkage
-- union-find / merge-small / convex-hull math lives). The runtime just
-- materializes world-yard coords lazily from the normalized values.
--
-- DB row shape per questId:
--   objectives = {
--     { kind, name,
--       clusters = { {uiMapId, hull = {{nx,ny},...},
--                     centroid = {nx,ny}, count}, ... },
--       stray    = { {uiMapId, normX, normY}, ... } },
--     ...                              -- one row per quest target
--   },
--   finisher = { {uiMapId, normX, normY}, ... }
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
-- Output (via GetClusters / GetPoints / GetFinisherPoints) matches what
-- the previous runtime-clustering implementation produced — same shape,
-- same world-yard convention — so existing consumers (focus arrow,
-- on-screen compass, minimap area overlay) need no changes. Every
-- cluster and stray point carries its continent (a required source item
-- can sit across the sea from the rest of the quest); the accessors take
-- an optional continentId filter and GetContinents lists what's present.

-- Maps our target `kind` to the quest log leaderboard `type` string.
-- Stable across locales — Blizzard's leaderboard `type` is fixed
-- regardless of the client language.
local _KIND_TO_LEADER_TYPE = {
    ["npc"]     = "monster",
    ["object"]  = "object",
    ["item"]    = "item",
    ["trigger"] = "event",
}

-- Vertex count of the circle polygon GetStrayHulls draws around each stray point.
local STRAY_CIRCLE_VERTICES = 12

class "QuestObjectiveCluster" {
    __init = function(self)
        self._clusters       = {}     -- list of { hull, centroid, count }
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
        local boards = {}
        if not allDone and entry and entry.objectives then
            for _, o in ipairs(entry.objectives) do
                if o and o.type then
                    local arr = boards[o.type]
                    if not arr then arr = {}; boards[o.type] = arr end
                    arr[#arr + 1] = o
                end
            end
        end

        if not allDone and precomputed.objectives then
            -- Per-type counter advances each time we see a target of
            -- that kind — that counter IS the leaderboard slot index
            -- within the type.
            local typeIdx = {}
            for _, target in ipairs(precomputed.objectives) do
                local include = false
                if target.kind == "sourceitem" then
                    -- Required source item: no leaderboard line, done once
                    -- the item is in the bags.
                    include = target.itemId ~= nil
                          and C_Item.GetItemCount(target.itemId) == 0
                else
                    local typeStr = _KIND_TO_LEADER_TYPE[target.kind]
                    if typeStr then
                        typeIdx[typeStr] = (typeIdx[typeStr] or 0) + 1
                        local pos      = target.pos or typeIdx[typeStr]
                        local board    = boards[typeStr]
                        local boardEnt = board and board[pos]
                        include = not (boardEnt and boardEnt.finished)
                    end
                end
                if include then
                    if target.clusters then
                        for _, c in ipairs(target.clusters) do
                            local rec = self:_ConvertCluster(c)
                            if rec then
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
                                self._points[#self._points + 1] = { wx, wy, cont }
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

    -- Convert one precomputed cluster (uiMap + normalized centroid + hull
    -- vertices) into a world-yard record. Returns nil when the API can't
    -- resolve the uiMap or the hull collapses to < 3 verts after
    -- conversion (degenerate; shouldn't happen with valid data).
    --
    -- The exporter's convex-hull pass produces vertices in CCW order in
    -- NORMALIZED map coords, where the +Y axis is DOWN (top-of-map = 0).
    -- When the same vertices project through to (east_right, north_up)
    -- the +Y axis flips, and a normalized-CCW hull becomes screen-CW.
    -- The IsMouseOver point-in-polygon test in MinimapQuestObjectiveArea
    -- assumes CCW; reverse the hull during conversion to keep that
    -- invariant.
    _ConvertCluster = function(self, c)
        if not c.uiMapId or not c.centroid then return nil end
        local cwx, cwy, cont = MUI_MapMath:MapToWorld(
            c.uiMapId, c.centroid[1], c.centroid[2])
        if not cwx or not cwy then return nil end
        local hull = {}
        if c.hull then
            local n = #c.hull
            for i = n, 1, -1 do
                local v = c.hull[i]
                local wx, wy = MUI_MapMath:MapToWorld(c.uiMapId, v[1], v[2])
                if wx and wy then
                    hull[#hull + 1] = { wx, wy }
                end
            end
        end
        if #hull < 3 then return nil end
        return {
            hull       = hull,
            centroid   = { cwx, cwy },
            count      = c.count,
            _continent = cont,
        }
    end;

    -- Stray points as small CCW circle polygons (world yards) for the area
    -- renderers: a target with too few spawns for a hull still gets a clearly
    -- localised marker. Radius is a per-surface legibility choice, not geography.
    GetStrayHulls = function(self, radiusYards, continentId)
        local hulls = {}
        local step = 2 * math.pi / STRAY_CIRCLE_VERTICES
        for _, p in ipairs(self:GetPoints(continentId)) do
            local hull = {}
            for v = 1, STRAY_CIRCLE_VERTICES do
                local a = (v - 1) * step
                hull[v] = { p[1] + radiusYards * math.cos(a), p[2] + radiusYards * math.sin(a) }
            end
            hulls[#hulls + 1] = hull
        end
        return hulls
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
