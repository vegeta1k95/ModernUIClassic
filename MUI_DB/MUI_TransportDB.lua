-- TransportDB: hard-coded Classic Era ship / zeppelin routes. The
-- Questie-derived MUI_QuestDB doesn't carry these — transports are
-- client-side moving objects with no authored route data — and the focus
-- arrow needs them to aim sensibly at cross-continent objectives.
--
-- Coordinates are stored Questie-style: Questie AreaId + normalised 0-100
-- percent. We defer MapToWorld conversion to the first query via a lazy
-- cache (MUI_MapMath may not be populated at file-load time).
--
-- Ships / zeppelins are symmetric — either endpoint reaches the other.

object "TransportDB" {
    __init = function(self)
        -- Each route is a symmetric pair. `type` is informational for now
        -- (could drive an icon swap later). `name` is user-facing metadata.
        -- `faction` filters who can use the route: "A"=Alliance, "H"=Horde,
        -- "N"=Neutral. Opposite-faction transports are skipped entirely
        -- when resolving cross-continent endpoints, so an Alliance
        -- character is never routed via Orgrimmar's zeppelin to Grom'gol.
        self._routes = {
            -- Menethil Harbor ↔ Theramore Isle
            { type = "boat", faction = "A",
              a = { areaId = 11,   x = 8.5,  y = 62.4, name = "Menethil Harbor" },
              b = { areaId = 15,   x = 71.22, y = 56.01, name = "Theramore Isle" } },
            -- Menethil Harbor ↔ Auberdine
            { type = "boat", faction = "A",
              a = { areaId = 11,   x = 5.16,  y = 57.85, name = "Menethil Harbor" },
              b = { areaId = 148,  x = 32.22, y = 44.19, name = "Auberdine" } },
            -- Booty Bay ↔ Ratchet 
            { type = "boat", faction = "N",
              a = { areaId = 33,   x = 26.0, y = 73.20, name = "Booty Bay" },
              b = { areaId = 17,   x = 63.71, y = 38.74, name = "Ratchet" } },
            -- Teldrassil ↔ Auberdine
            { type = "boat", faction = "A",
              a = { areaId = 141,  x = 54.85, y = 96.66, name = "Rut'theran Village" },
              b = { areaId = 148,  x = 33.0,  y = 40.0,  name = "Auberdine" } },
            -- Orgrimmar ↔ Undercity. 
            { type = "zeppelin", faction = "H",
              a = { areaId = 14, x = 50.8, y = 12.6, name = "Orgrimmar" },
              b = { areaId = 85, x = 61.0, y = 59.0, name = "Undercity" } },
            -- Orgrimmar ↔ Grom'gol
            { type = "zeppelin", faction = "H",
              a = { areaId = 14, x = 50.8,  y = 14.6,  name = "Orgrimmar" },
              b = { areaId = 33, x = 31.5,  y = 29.6, name = "Grom'gol" } },
        }

        -- Lazy resolution cache. Key is a route index (1-based) in
        -- self._routes; value is {a = {wx, wy, continent}, b = {…}} or
        -- `false` if resolution failed (area id not in the DB yet, etc.).
        self._resolved = {}
    end;

    -- Returns list of world-yard endpoints on `fromCont` whose route's
    -- far side lands on `toCont`. Each entry: { wx, wy, name, type }.
    -- Lazy — resolves routes it hasn't seen yet; skips ones that fail.
    -- Opposite-faction routes are filtered out (an Alliance character
    -- never sees Horde zeppelin endpoints and vice versa); neutral
    -- routes (e.g. Booty Bay ↔ Ratchet) are visible to everyone.
    FindEndpointsToContinent = function(self, fromCont, toCont)
        local pf = UnitFactionGroup("player")
        local playerFaction = (pf == "Alliance" and "A")
                           or (pf == "Horde"    and "H")
                           or "N"
        local out = {}
        for i, route in ipairs(self._routes) do
            if route.faction == "N" or route.faction == playerFaction then
                local res = self:_resolve(i, route)
                if res then
                    if res.a[3] == fromCont and res.b[3] == toCont then
                        out[#out + 1] = {
                            wx = res.a[1], wy = res.a[2],
                            name = route.a.name, type = route.type,
                        }
                    elseif res.b[3] == fromCont and res.a[3] == toCont then
                        out[#out + 1] = {
                            wx = res.b[1], wy = res.b[2],
                            name = route.b.name, type = route.type,
                        }
                    end
                end
            end
        end
        return out
    end;

    -- Every transport endpoint located in the given Questie area. Each
    -- entry: { key, x, y, wx, wy, continent, name, otherName, otherAreaId,
    -- type, faction }. x/y are local endpoint coords as 0..100 percent;
    -- wx/wy/continent are the same point in world yards (resolved lazily,
    -- nil if the area can't be resolved yet). `key` is a stable
    -- "<routeIdx>_a" / "<routeIdx>_b" string usable as a focus identifier.
    -- Order is route-table order; both ends contribute when an area hosts
    -- the same route's a and b endpoints (rare).
    GetEndpointsAtArea = function(self, areaId)
        local out = {}
        for i, route in ipairs(self._routes) do
            local res = self:_resolve(i, route)
            if route.a.areaId == areaId then
                out[#out + 1] = {
                    key = i .. "_a",
                    x = route.a.x, y = route.a.y,
                    wx = res and res.a[1] or nil,
                    wy = res and res.a[2] or nil,
                    continent = res and res.a[3] or nil,
                    name = route.a.name,
                    otherName = route.b.name, otherAreaId = route.b.areaId,
                    type = route.type, faction = route.faction,
                }
            end
            if route.b.areaId == areaId then
                out[#out + 1] = {
                    key = i .. "_b",
                    x = route.b.x, y = route.b.y,
                    wx = res and res.b[1] or nil,
                    wy = res and res.b[2] or nil,
                    continent = res and res.b[3] or nil,
                    name = route.b.name,
                    otherName = route.a.name, otherAreaId = route.a.areaId,
                    type = route.type, faction = route.faction,
                }
            end
        end
        return out
    end;

    -- Lazy world-yard resolution for a single route. Returns a record
    -- { a = {wx, wy, cont}, b = {wx, wy, cont} }, or nil if either end
    -- can't be resolved (area not in DB, MUI_MapMath not ready).
    _resolve = function(self, idx, route)
        local cached = self._resolved[idx]
        if cached ~= nil then
            return cached or nil   -- `false` sentinel for failed routes
        end
        local function _world(ep)
            local uiMapId = MUI_ZoneDB and MUI_ZoneDB:GetUiMapForArea(ep.areaId)
            if not uiMapId then return nil end
            local wx, wy, wc = MUI_MapMath:MapToWorld(uiMapId, ep.x / 100, ep.y / 100)
            if not wx or not wc then return nil end
            return { wx, wy, wc }
        end
        local a = _world(route.a)
        local b = _world(route.b)
        if not a or not b then
            self._resolved[idx] = false
            return nil
        end
        local res = { a = a, b = b }
        self._resolved[idx] = res
        return res
    end;
}
