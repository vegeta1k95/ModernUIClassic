-- MUI_FocusManager: kind-aware focus state shared across the addon.
--
-- Focus is a single (kind, key) tuple persisted to MUI_DB.settings.focus.
-- "kind" is a short string identifying the focusable type ("quest",
-- "flightmaster", future "gathernode" etc.). "key" is the kind's stable
-- identifier — questId for quests, taxi nodeID for flight masters, etc.
--
-- Each kind registers an adapter via RegisterKind. Generic consumers
-- (the on-screen nav compass, the minimap edge arrow, tooltip dispatch)
-- query the manager for the current focus, ask the adapter for tiered
-- candidate world points, and project. Quest-specific cluster math stays
-- inside the quest adapter; cross-continent transport reroute lives in
-- the consuming widgets where it can be applied uniformly.
--
-- Adapter contract (per kind):
--   GetTargetPoints(self, key) -> tiers | nil
--     tiers = {
--       { points = {{wx, wy, hull = optional}, ...},
--         continent = N,
--         allowTransportReroute = true | false }, -- default true
--       -- ... fallback tiers, walker stops at first non-empty
--     }
--     Return nil when the key has no useful target right now (widget
--     hides). Don't return empty tiers — distinguishing "no data" from
--     "all tiers exhausted" requires nil.
--   FillTooltip(self, key, mode)   -- mode = "title" | "full"
--
-- Listener signature:
--   fn(prevKind, prevKey, newKind, newKey)

object "FocusManager" : extends "Module" {
    __init = function(self)
        Module.__init(self, "FocusManager")
        self._kinds     = {}   -- kind -> adapter
        self._listeners = {}   -- list of fn
    end;

    OnEnable = function(self)
        -- Generic widgets are owned by the manager and constructed once.
        -- They poll FocusManager:GetFocus each tick, so they Just Work
        -- across focus changes without explicit listener wiring.
        -- Single-init is enforced by the Module dispatcher in MUI_Core.
        self.arrow = FocusedTargetArrow("MUI_FocusedTargetArrow", 14)
        self.nav   = FocusNavigation("MUI_FocusNavigation")
    end;

    -- ---- focus state ----------------------------------------------------

    GetFocus = function(self)
        local f = MUI_DB and MUI_DB.settings and MUI_DB.settings.focus
        if not f or not f.kind then return nil, nil end
        return f.kind, f.key
    end;

    -- SetFocus(nil) clears. SetFocus(kind, key) replaces. No-op when the
    -- new (kind, key) matches the current — listeners don't re-fire.
    SetFocus = function(self, kind, key)
        if kind == nil then key = nil end
        local f = MUI_DB.settings.focus
        local prevKind, prevKey = f.kind, f.key
        if prevKind == kind and prevKey == key then return end
        f.kind = kind
        f.key  = key
        for _, fn in ipairs(self._listeners) do
            local ok, err = pcall(fn, prevKind, prevKey, kind, key)
            if not ok then
                MUI.Print("|cffff4040MUI_FocusManager|r listener error: " .. tostring(err))
            end
        end
    end;

    IsFocused = function(self, kind, key)
        local f = MUI_DB and MUI_DB.settings and MUI_DB.settings.focus
        if not f then return false end
        return f.kind == kind and f.key == key
    end;

    Clear = function(self)
        self:SetFocus(nil)
    end;

    RegisterChangeListener = function(self, fn)
        table.insert(self._listeners, fn)
    end;

    -- ---- kind registry --------------------------------------------------

    RegisterKind = function(self, kind, adapter)
        self._kinds[kind] = adapter
    end;

    GetAdapter = function(self, kind)
        return self._kinds[kind]
    end;

    -- Convenience for the generic widgets. Returns the adapter for the
    -- currently-focused kind, or nil if nothing focused / kind not
    -- registered yet.
    GetFocusedAdapter = function(self)
        local kind = self:GetFocus()
        if not kind then return nil end
        return self._kinds[kind]
    end;

    -- Pick the nearest world target to point/aim at.
    --
    --   PickTarget()                — current focus, with cross-continent
    --                                 transport reroute. Use this for
    --                                 wayfinding consumers (focus arrow
    --                                 on the minimap, on-screen compass)
    --                                 — they guide the player TOWARD the
    --                                 next step, which for cross-continent
    --                                 means the boat / zeppelin dock on
    --                                 the player's side.
    --   PickTarget(kind, key)       — same as above but for an explicit
    --                                 kind+key (e.g. a tracked-but-not-
    --                                 focused quest).
    --   PickTarget(kind, key, true) — skip transport reroute. Use this
    --                                 for stationary consumers (world-map
    --                                 POI placement, click-to-navigate)
    --                                 — they mark or open the ACTUAL
    --                                 target location, even if it's on
    --                                 a different continent.
    --
    -- Returns
    --   { wx, wy, hull|nil, continent, playerY, playerX, kind, key } on success
    --   nil when nothing is focused / no adapter / no candidates / no player
    --   position / cross-continent with no bridge (reroute path only).
    -- `continent` is the picked candidate's continent (tier.continent if not
    -- rerouted; player's continent if rerouted to a transport endpoint).
    PickTarget = function(self, kind, key, noReroute)
        if kind == nil then
            kind, key = self:GetFocus()
        end
        if not kind then return nil end
        local adapter = self._kinds[kind]
        if not adapter or not adapter.GetTargetPoints then return nil end
        local tiers = adapter:GetTargetPoints(key)
        if not tiers then return nil end

        local playerY, playerX, _, playerCont = UnitPosition("player")
        if not playerX or not playerY then return nil end

        -- First non-empty tier wins.
        local tier
        for _, t in ipairs(tiers) do
            if t.points and #t.points > 0 then
                tier = t
                break
            end
        end
        if not tier then return nil end

        local candidates      = tier.points
        local pickedContinent = tier.continent

        if not noReroute
                and (tier.allowTransportReroute ~= false)
                and playerCont and tier.continent
                and playerCont ~= tier.continent then
            local endpoints = MUI_TransportDB
                    and MUI_TransportDB:FindEndpointsToContinent(playerCont, tier.continent)
            if not endpoints or #endpoints == 0 then return nil end
            candidates = {}
            for _, ep in ipairs(endpoints) do
                candidates[#candidates + 1] = { ep.wx, ep.wy }
            end
            pickedContinent = playerCont
        end

        local best, bestD2 = nil, math.huge
        for _, p in ipairs(candidates) do
            local dns = p[1] - playerY
            local dew = p[2] - playerX
            local d2  = dns * dns + dew * dew
            if d2 < bestD2 then
                bestD2 = d2
                best   = p
            end
        end
        if not best then return nil end

        return {
            wx        = best[1],
            wy        = best[2],
            hull      = best.hull,
            continent = pickedContinent,
            playerY   = playerY,
            playerX   = playerX,
            kind      = kind,
            key       = key,
        }
    end;
}
