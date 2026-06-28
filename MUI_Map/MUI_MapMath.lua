-- MUI_MapMath: map / world coordinate helpers for Classic Era.
--
-- Classic Era 1.15 has no C_Map.GetMapWorldSize, but it does expose
--   C_Map.GetWorldPosFromMapPos(uiMapId, Vector2D) -> continentId, Vector2D
-- so we can derive any zone's world size by probing the (0,0) and (1,1)
-- corners and taking the difference.
--
-- World coords returned are in yards, anchored per continent. Two pins on
-- the same continent can be subtracted directly. Pins on different
-- continents can't (SameContinent can gate this).

-- Cosmic / world parent of every continent in Classic Era. Children
-- with mapType == Continent (2) hang off this. Stable across game
-- patches; hardcoding avoids walking up from an arbitrary uiMap.
local AZEROTH_WORLD_MAP_ID = 947

object "MapMath" {

    __init = function(self)
        self._sizeCache = {}  -- uiMapId -> {w, h, originX, originY, continentId}
        -- continent INSTANCE id (0=EK, 1=Kalimdor in Classic Era) ->
        -- continent uiMapId. Lazily populated by probing each continent's
        -- centre with GetWorldPosFromMapPos; that API correctly returns
        -- the continent instance even when GetMapPosFromWorldPos is unreliable.
        self._continentUiMap = nil
        -- continent uiMapId -> { {mapID, minX, maxX, minY, maxY}, ... }
        -- World rects of every zone child, computed once.
        self._zoneRectCache = {}
        -- uiMapId -> { tlX, tlY, brX, brY, continentId } — generic per-map
        -- world bounds cache used by WorldToMap. Populated lazily on first
        -- query for any uiMap (zone OR continent).
        self._mapBoundsCache = {}
    end;

    -- Return (worldX, worldY, continentId) for a point at normalised (nx, ny)
    -- on the given map, or nil if the API can't resolve it.
    MapToWorld = function(self, uiMapId, nx, ny)
        if not uiMapId then return nil end
        local cont, pos = C_Map.GetWorldPosFromMapPos(uiMapId, CreateVector2D(nx, ny))
        if not pos then return nil end
        return pos.x, pos.y, cont
    end;

    -- Find the zone-level uiMap that contains the given world point on
    -- the given continent. Returns the zone uiMapID, or nil.
    --
    -- C_Map.GetMapPosFromWorldPos's overrideUiMapID is unreliable in
    -- Classic Era (it falls back to the continent uiMap), so we can't
    -- ask the API for the zone directly. Instead: enumerate the
    -- continent's zone children, project the world point into each
    -- zone's normalised [0,1] space, and pick the zone where the point
    -- is most clearly inside.
    --
    -- "Most clearly inside" = highest min-distance from the four [0,1]
    -- edges. Bounding boxes of WoW zones overlap heavily at borders
    -- (Barrens reaches into Durotar's bbox; Dustwallow's bbox bleeds
    -- into Southern Barrens). A first-match scan picks the wrong zone
    -- in those cases. Picking the zone where the projected point is
    -- furthest from the boundary cleanly resolves the tie.
    GetBestMapForWorld = function(self, continentId, worldX, worldY)
        local contMap = self:_GetContinentUiMap(continentId)
        if not contMap then return nil end
        local zones = self:_GetZoneRects(contMap)
        if not zones then return nil end

        local best, bestCentr = nil, -math.huge
        for _, z in ipairs(zones) do
            -- Vector2D convention: .x = N-S (+north), .y = E-W (+west).
            -- Our `worldX` is N-S, `worldY` is E-W.
            local widthEW  = z.tlY - z.brY
            local heightNS = z.tlX - z.brX
            if widthEW > 0 and heightNS > 0 then
                local nx = (z.tlY - worldY) / widthEW
                local ny = (z.tlX - worldX) / heightNS
                if nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1 then
                    local centeredness = math.min(nx, 1 - nx, ny, 1 - ny)
                    if centeredness > bestCentr then
                        bestCentr = centeredness
                        best      = z.mapID
                    end
                end
            end
        end
        return best
    end;

    -- Lazy: continent INSTANCE id -> continent uiMapId. First call
    -- enumerates Azeroth's children and probes each to learn its
    -- instance.
    _GetContinentUiMap = function(self, continentId)
        if not self._continentUiMap then
            self._continentUiMap = {}
            local continents = C_Map.GetMapChildrenInfo(AZEROTH_WORLD_MAP_ID, 2)
            if continents then
                for _, c in ipairs(continents) do
                    local inst = C_Map.GetWorldPosFromMapPos(c.mapID, CreateVector2D(0.5, 0.5))
                    if inst then self._continentUiMap[inst] = c.mapID end
                end
            end
        end
        return self._continentUiMap[continentId or 0]
    end;

    -- Lazy: continent uiMapId -> list of zone rects. Each rect carries
    -- mapID + the zone's normalised-(0,0) and (1,1) world coords (TL =
    -- north-west = max N-S + max E-W, BR = south-east). Used by
    -- GetBestMapForWorld to project a world point into each candidate
    -- zone's [0,1] space.
    _GetZoneRects = function(self, contMap)
        local cached = self._zoneRectCache[contMap]
        if cached then return cached end
        local zones = C_Map.GetMapChildrenInfo(contMap, 3)
        if not zones then return nil end
        local out = {}
        for _, z in ipairs(zones) do
            local _, tl = C_Map.GetWorldPosFromMapPos(z.mapID, CreateVector2D(0, 0))
            local _, br = C_Map.GetWorldPosFromMapPos(z.mapID, CreateVector2D(1, 1))
            if tl and br then
                out[#out + 1] = {
                    mapID = z.mapID,
                    tlX = tl.x, tlY = tl.y,    -- N-S, E-W of TL corner
                    brX = br.x, brY = br.y,    -- N-S, E-W of BR corner
                }
            end
        end
        self._zoneRectCache[contMap] = out
        return out
    end;

    -- Return (normX, normY) of a world point on the given map, or nil.
    --
    -- C_Map.GetMapPosFromWorldPos's overrideUiMapID is unreliable in
    -- Classic Era — for zone uiMaps the API falls back to continent
    -- coords, which would land pins at the wrong location on zone-level
    -- views. We project manually instead, by probing the map's TL/BR
    -- world corners with GetWorldPosFromMapPos (which IS reliable) and
    -- linear-interpolating. Returns nil when the map can't be resolved
    -- or when the requested continent doesn't match the map's continent.
    WorldToMap = function(self, uiMapId, worldX, worldY, continentId)
        local b = self:_GetMapBounds(uiMapId)
        if not b then return nil end
        if continentId and b.continentId
                and continentId ~= b.continentId then
            return nil
        end
        local widthEW  = b.tlY - b.brY
        local heightNS = b.tlX - b.brX
        if widthEW == 0 or heightNS == 0 then return nil end
        local nx = (b.tlY - worldY) / widthEW
        local ny = (b.tlX - worldX) / heightNS
        return nx, ny
    end;

    -- Probe the map's TL (vec00) and BR (vec11) corners to learn its
    -- world rect + continent. Cached per uiMapId. Vector2D convention:
    -- .x = N-S (+north), .y = E-W (+west) — top-left of the map is
    -- north-west, so tl has the LARGER .x and .y values.
    _GetMapBounds = function(self, uiMapId)
        if not uiMapId then return nil end
        local cached = self._mapBoundsCache[uiMapId]
        if cached then return cached end
        local cont, tl = C_Map.GetWorldPosFromMapPos(uiMapId, CreateVector2D(0, 0))
        local _,    br = C_Map.GetWorldPosFromMapPos(uiMapId, CreateVector2D(1, 1))
        if not tl or not br then return nil end
        local rec = {
            tlX = tl.x, tlY = tl.y,
            brX = br.x, brY = br.y,
            continentId = cont,
        }
        self._mapBoundsCache[uiMapId] = rec
        return rec
    end;

    -- Return (widthYards, heightYards, originX, originY, continentId) for a
    -- zone.  Probes world coords at two opposite corners and subtracts.
    GetMapWorldSize = function(self, uiMapId)
        if not uiMapId then return nil end
        local cached = self._sizeCache[uiMapId]
        if cached then
            return cached.w, cached.h, cached.originX, cached.originY, cached.continentId
        end
        local tlX, tlY, cont = self:MapToWorld(uiMapId, 0, 0)
        local brX, brY       = self:MapToWorld(uiMapId, 1, 1)
        if not tlX or not brX then return nil end
        local w = math.abs(brX - tlX)
        local h = math.abs(brY - tlY)
        local ox = math.min(tlX, brX)
        local oy = math.min(tlY, brY)
        self._sizeCache[uiMapId] = {w = w, h = h, originX = ox, originY = oy, continentId = cont}
        return w, h, ox, oy, cont
    end;

    -- Return yard distance between two normalised map positions on the same
    -- map (straight-line Euclidean, no instance check).
    DistanceYards = function(self, uiMapId, nx1, ny1, nx2, ny2)
        local x1, y1, c1 = self:MapToWorld(uiMapId, nx1, ny1)
        local x2, y2, c2 = self:MapToWorld(uiMapId, nx2, ny2)
        if not x1 or not x2 or c1 ~= c2 then return nil end
        local dx, dy = x2 - x1, y2 - y1
        return math.sqrt(dx * dx + dy * dy)
    end;

    -- Yard delta between two map positions, returned as (deltaX, deltaY) in
    -- world-yard coords (same sign convention as UnitPosition).  Useful for
    -- minimap pin projection — the minimap's radius is in yards, so we can
    -- scale the delta directly to screen pixels.
    DeltaYards = function(self, uiMapId, fromNx, fromNy, toNx, toNy)
        local x1, y1, c1 = self:MapToWorld(uiMapId, fromNx, fromNy)
        local x2, y2, c2 = self:MapToWorld(uiMapId, toNx, toNy)
        if not x1 or not x2 or c1 ~= c2 then return nil end
        return x2 - x1, y2 - y1
    end;

    SameContinent = function(self, aUiMapId, bUiMapId)
        local _, _, ca = self:MapToWorld(aUiMapId, 0.5, 0.5)
        local _, _, cb = self:MapToWorld(bUiMapId, 0.5, 0.5)
        return ca ~= nil and ca == cb
    end;
}
