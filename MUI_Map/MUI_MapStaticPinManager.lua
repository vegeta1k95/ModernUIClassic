-- MapStaticPinManager: owns static pins on the world map canvas.
--
-- First (and currently only) pin kind: FlightMaster, sourced from
-- C_TaxiMap.GetTaxiNodesForMap. That API returns every taxi node on a
-- given uiMap regardless of whether the taxi UI is open and gives us
-- nodeID + position + faction.
--
-- Discovery tracking — IMPORTANT QUIRK: in Classic Era, the
-- `isUndiscovered` field on the records returned by GetTaxiNodesForMap
-- is always false. Blizzard's own classic FlightPointDataProvider just
-- ignores it and renders every node. We have to capture discovery
-- ourselves by scanning C_TaxiMap.GetAllTaxiNodes at TAXIMAP_OPENED
-- (the only time `state` is populated correctly) and persisting the
-- nodeID set into MUI_DB.data.discoveredTaxiNodes.
--
-- Driven by:
--   * WorldMapFrame.OnMapChanged       — rebuild pins on map switch.
--   * TAXIMAP_OPENED                   — scan + rebuild.
--   * TAXI_NODE_STATUS_CHANGED         — scan + rebuild on discovery.
--
-- Only zone-level maps (mapType == 3) get pins; continent / world /
-- cosmic views show none. Opposite-faction flight masters are filtered
-- out (Alliance characters never see Horde nodes and vice versa);
-- neutral nodes are visible to everyone.

-- Enum.UIMapType.Zone == 3 (Cosmic=0, World=1, Continent=2, Zone=3, ...).
local ZONE_MAP_TYPE = 3
local CONTINENT_MAP_TYPE = 2

-- Enum.FlightPathFaction values per Classic Era's TaxiMapDocumentation:
--   Neutral = 0, Horde = 1, Alliance = 2.
local FACTION_NEUTRAL  = 0
local FACTION_HORDE    = 1
local FACTION_ALLIANCE = 2

local FACTION_ICON = {
    [FACTION_NEUTRAL]  = "FlightMasterNeutral",
    [FACTION_HORDE]    = "FlightMasterHorde",
    [FACTION_ALLIANCE] = "FlightMasterAlliance",
}

-- Transport endpoints (boats / zeppelins) use a different icon family
-- but the same per-faction colouring. Keyed by MUI_TransportDB's
-- single-letter faction code ("A"/"H"/"N").
local TRANSPORT_FACTION_ICON = {
    ["A"] = "TransportAlliance",
    ["H"] = "TransportHorde",
    ["N"] = "TransportNeutral",
}

-- Active transport-pin hover override. The native AreaLabel frame runs
-- an OnUpdate every frame that clears the AREA_NAME label, recomputes
-- from cursor position, then calls EvaluateLabels. So a one-shot SetText
-- on hover is wiped on the very next frame. We hooksecurefunc
-- EvaluateLabels to re-apply our override AFTER Blizzard's pass.
local _hoveredOverride = nil   -- "Boat to Ratchet (The Barrens)" or nil
local _evalHooked      = false

local function _EnsureLabelHook()
    if _evalHooked then return end
    if not MUI_ModuleMap or not MUI_ModuleMap.zoneLabel then return end
    local nativeLabel = MUI_ModuleMap.zoneLabel._native
    if not nativeLabel or not nativeLabel.EvaluateLabels then return end
    _evalHooked = true
    hooksecurefunc(nativeLabel, "EvaluateLabels", function()
        if not _hoveredOverride then return end
        if nativeLabel.Name then
            nativeLabel.Name:SetText(_hoveredOverride)
        end
        nativeLabel:Show()
    end)
end

-- Enum.FlightPathState: 0=Current, 1=Reachable, 2=Unreachable.
local STATE_UNREACHABLE = 2

-- Eastern Plaguelands' four Argent Dawn / Scourge-invasion towers show
-- up in C_TaxiMap.GetTaxiNodesForMap as taxi nodes (Blizzard data legacy
-- — they're not real flight masters, no actual flight path connects them).
-- Filter them out by stable nodeID — locale-independent.
local TAXI_NODE_BLACKLIST = {
    [84] = true,   -- Crown Guard Tower
    [85] = true,   -- Eastwall Tower
    [86] = true,   -- Northpass Tower
    [87] = true,   -- Plaguewood Tower
}

local function _playerFaction()
    local g = UnitFactionGroup("player")
    if g == "Alliance" then return FACTION_ALLIANCE end
    if g == "Horde"    then return FACTION_HORDE end
    return FACTION_NEUTRAL
end

-- Difficulty palette (matches MUI_MapQuestLog._difficultyColor — same
-- thresholds and tints; duplicated locally instead of cross-importing
-- to keep the manager self-contained, in line with the existing
-- per-consumer convention in MUI_QuestTracker).
local _DIFF_RED    = { 1.00, 0.10, 0.10 }
local _DIFF_ORANGE = { 1.00, 0.50, 0.25 }
local _DIFF_YELLOW = { 1.00, 1.00, 0.00 }
local _DIFF_GREEN  = { 0.25, 0.75, 0.25 }
local _DIFF_GRAY   = { 0.62, 0.62, 0.62 }

local function _DifficultyColor(level)
    local diff = level - UnitLevel("player")
    if     diff >=  5                                   then return _DIFF_RED
    elseif diff >=  3                                   then return _DIFF_ORANGE
    elseif diff >= -2                                   then return _DIFF_YELLOW
    elseif -diff <= (GetQuestGreenRange("player") or 5) then return _DIFF_GREEN
    else                                                     return _DIFF_GRAY
    end
end

-- Format a quest title for tooltip display, applying the
-- showQuestLevel and showQuestDifficultyColor settings. Returns
-- (text, r, g, b); falls back to gold (1, 0.82, 0) when the difficulty
-- coloring setting is off.
local function _QuestLineFormat(questId)
    local q = MUI_QuestDB and MUI_QuestDB:Get(questId)
    local name  = (q and q.name) or "?"
    local level = q and q.questLevel

    local s = MUI_DB and MUI_DB.settings and MUI_DB.settings.questHelper
    local showLvl   = s and s.showQuestLevel
    local showColor = s and s.showQuestDifficultyColor

    local text = name
    if showLvl and level and level > 0 then
        text = "[" .. level .. "] " .. name
    end
    if showColor and level and level > 0 then
        local c = _DifficultyColor(level)
        return text, c[1], c[2], c[3]
    end
    return text, 1, 0.82, 0
end

-- Find the player's current continent uiMapID by walking up the map
-- hierarchy from the player's current zone. Cap the climb at 8 to
-- avoid pathological cycles.
local function _playerContinentMapId()
    local mapId = C_Map.GetBestMapForUnit("player")
    if not mapId then return nil end
    for _ = 1, 8 do
        local info = C_Map.GetMapInfo(mapId)
        if not info then return nil end
        if info.mapType == CONTINENT_MAP_TYPE then return mapId end
        if not info.parentMapID or info.parentMapID == 0 then return nil end
        mapId = info.parentMapID
    end
    return nil
end

class "MapStaticPinManager" : extends "Frame" {
    __init = function(self)
        Frame.__init(self, "Frame", nil, "MUI_MapStaticPinManagerDriver")
        self.flightMasterPins   = {}
        self.transportPins      = {}
        self.dungeonPins        = {}
        self.availableQuestPins = {}
        -- Per-kind world-coord caches keyed by stable identifier. Populated
        -- as we build pins for each zone the user navigates to. Persist
        -- across map switches so the focus arrow can keep pointing at a
        -- previously-clicked target after the user has moved on to another
        -- zone view. Lost on /reload (rebuilt lazily).
        self._taxiCoordCache      = {}   -- nodeID         -> {wx, wy, continent, name}
        self._transportCoordCache = {}   -- "<idx>_a/_b"   -> {wx, wy, continent, name}
        self._dungeonCoordCache   = {}   -- dungeonAreaId  -> {wx, wy, continent, name, isRaid}
        self._questGiverCache     = {}   -- "npc:N"/"object:N" -> {wx, wy, continent, name}
        self._questHubCache       = {}   -- hub.id -> {wx, wy, continent}

        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            self:Rebuild()
        end)
        -- Both events refresh discovery state. TAXIMAP_OPENED catches
        -- the bulk-capture window (player at a flight master); the
        -- status-changed event covers in-flight discoveries.
        self:RegisterEventHandler("TAXIMAP_OPENED", function()
            self:_ScanDiscovery()
            self:Rebuild()
        end)
        self:RegisterEventHandler("TAXI_NODE_STATUS_CHANGED", function()
            self:_ScanDiscovery()
            self:Rebuild()
        end)

        -- Register all three focus kinds owned by this manager. The
        -- closures below read the per-kind caches populated as we build
        -- pins, so the adapter can resolve a target's world coords
        -- regardless of whether a pin is currently rendered for it.
        MUI_FocusManager:RegisterKind("flightmaster", {
            GetTargetPoints = function(_, nodeID)
                local cached = self._taxiCoordCache[nodeID]
                if not cached then return nil end
                return {
                    {
                        points    = { { cached.wx, cached.wy } },
                        continent = cached.continent,
                    },
                }
            end,
            FillTooltip = function(_, nodeID, _mode)
                local cached = self._taxiCoordCache[nodeID]
                if cached and cached.name then
                    MUI_Tooltip:AddTitle(cached.name)
                end
            end,
        })
        MUI_FocusManager:RegisterKind("transport", {
            GetTargetPoints = function(_, key)
                local cached = self._transportCoordCache[key]
                if not cached then return nil end
                return {
                    {
                        points    = { { cached.wx, cached.wy } },
                        continent = cached.continent,
                        -- Transport endpoints are themselves the reroute
                        -- target — never reroute through a different one.
                        allowTransportReroute = false,
                    },
                }
            end,
            FillTooltip = function(_, key, _mode)
                local cached = self._transportCoordCache[key]
                if cached and cached.name then
                    MUI_Tooltip:AddTitle(cached.name)
                end
            end,
        })
        MUI_FocusManager:RegisterKind("dungeon", {
            GetTargetPoints = function(_, dungeonAreaId)
                local cached = self._dungeonCoordCache[dungeonAreaId]
                if not cached then return nil end
                return {
                    {
                        points    = { { cached.wx, cached.wy } },
                        continent = cached.continent,
                    },
                }
            end,
            FillTooltip = function(_, dungeonAreaId, _mode)
                local cached = self._dungeonCoordCache[dungeonAreaId]
                if cached and cached.name then
                    MUI_Tooltip:AddTitle(cached.name)
                end
            end,
        })
        MUI_FocusManager:RegisterKind("questgiver", {
            GetTargetPoints = function(_, key)
                local cached = self._questGiverCache[key]
                if not cached then return nil end
                return {
                    {
                        points    = { { cached.wx, cached.wy } },
                        continent = cached.continent,
                    },
                }
            end,
            FillTooltip = function(_, key, _mode)
                local cached = self._questGiverCache[key]
                if cached and cached.name then
                    MUI_Tooltip:AddTitle(cached.name)
                end
            end,
        })
        MUI_FocusManager:RegisterKind("questhub", {
            GetTargetPoints = function(_, hubId)
                local hub = MUI_QuestHubDB and MUI_QuestHubDB:GetHubById(hubId)
                if not hub then return nil end
                local cached = self._questHubCache[hubId]
                if not cached then
                    local wx, wy, cont = MUI_MapMath:MapToWorld(
                        hub.uiMapId, hub.nx, hub.ny)
                    if not wx then return nil end
                    cached = { wx = wx, wy = wy, continent = cont }
                    self._questHubCache[hubId] = cached
                end
                return {
                    {
                        points    = { { cached.wx, cached.wy } },
                        continent = cached.continent,
                    },
                }
            end,
            FillTooltip = function(_, hubId, _mode)
                local hub = MUI_QuestHubDB and MUI_QuestHubDB:GetHubById(hubId)
                if not hub then return end
                MUI_Tooltip:AddTitle(hub.name)
                if hub.flavor then
                    MUI_Tooltip:AddLine(hub.flavor, 0.7, 0.7, 0.7, true)
                end
            end,
        })

        -- Toggle the per-pin "focused" badge as focus changes. Cheap:
        -- walks at most a few dozen pins across all kinds per zone.
        MUI_FocusManager:RegisterChangeListener(function() self:_RefreshFocusStates() end)

        -- Available-quest pins: rebuild when the availability set
        -- shifts (level-up, accept, turn-in, trivial-toggle). After the
        -- rebuild, if the focused pin no longer exists on the current
        -- map, clear focus — the nav arrow shouldn't linger pointing at
        -- a now-empty target.
        if MUI_QuestHelper and MUI_QuestHelper.availability then
            MUI_QuestHelper.availability:RegisterChangeListener(function()
                self:Rebuild()
                self:_ClearFocusIfPinGone()
            end)
        end


        self:Rebuild()
    end;

    Rebuild = function(self)
        self:_DestroyAll()

        local uiMapId = WorldMapFrame:GetMapID()
        if not uiMapId then return end
        local info = C_Map.GetMapInfo(uiMapId)
        if not info or info.mapType ~= ZONE_MAP_TYPE then return end

        self:_BuildFlightMasterPins(uiMapId)
        self:_BuildTransportPins(uiMapId)
        self:_BuildDungeonPins(uiMapId)
        self:_BuildAvailableQuestPins(uiMapId)
    end;

    -- If the currently-focused pin isn't present in the rebuilt pin set,
    -- clear focus. Scoped to kinds OWNED by this manager — "quest"-kind
    -- (objective POIs, owned by MapQuestPoiManager) and "waypoint" are
    -- excluded so completing an objective doesn't wrongly nuke focus
    -- when the static availability listener fires as a side effect.
    _ClearFocusIfPinGone = function(self)
        local kind, key = MUI_FocusManager:GetFocus()
        if not kind or not key then return end
        if kind ~= "questgiver" and kind ~= "questhub" then return end

        for _, pin in ipairs(self.availableQuestPins) do
            if pin._focusKind == kind and pin._focusKey == key then
                return
            end
        end

        if kind == "questgiver" then
            self._questGiverCache[key] = nil
        end
        MUI_FocusManager:Clear()
    end;

    _IsDiscovered = function(self, nodeID)
        local set = MUI_DB and MUI_DB.data and MUI_DB.data.discoveredTaxiNodes
        return set and set[nodeID] == true
    end;

    _FlightMasterIcon = function(self, node)
        if not self:_IsDiscovered(node.nodeID) then
            return "FlightMasterUnknown"
        end
        return FACTION_ICON[node.faction] or "FlightMasterNeutral"
    end;

    -- Walk every zone child of the player's current continent and call
    -- GetAllTaxiNodes to read each node's state. Mark Reachable / Current
    -- nodes as discovered. Only meaningful while a flight master is open —
    -- outside that window state is all-Unreachable so the scan is a no-op.
    _ScanDiscovery = function(self)
        if not C_TaxiMap or not C_TaxiMap.GetAllTaxiNodes then return end
        local set = MUI_DB and MUI_DB.data and MUI_DB.data.discoveredTaxiNodes
        if not set then return end

        local continent = _playerContinentMapId()
        if not continent then return end
        local zones = C_Map.GetMapChildrenInfo(continent, ZONE_MAP_TYPE)
        if not zones then return end

        for _, z in ipairs(zones) do
            local nodes = C_TaxiMap.GetAllTaxiNodes(z.mapID)
            if nodes then
                for _, n in ipairs(nodes) do
                    if n.state ~= STATE_UNREACHABLE then
                        set[n.nodeID] = true
                    end
                end
            end
        end
    end;

    -- True when (nx, ny) on `uiMapId` falls within any curated hub's
    -- absorption radius. Used to suppress pins that would visually
    -- collide with the hub icon (flight master, …). Focus caches for
    -- the absorbed pin are still populated upstream so the focus arrow
    -- keeps working — only the on-canvas pin is skipped.
    _PointInsideAnyHub = function(self, uiMapId, nx, ny)
        local hubs = MUI_QuestHubDB and MUI_QuestHubDB:GetHubsForUiMap(uiMapId)
        if not hubs then return false end
        for _, hub in ipairs(hubs) do
            local dx = nx - hub.nx
            local dy = ny - hub.ny
            if dx * dx + dy * dy <= hub.radius * hub.radius then
                return true
            end
        end
        return false
    end;

    _BuildFlightMasterPins = function(self, uiMapId)
        if not C_TaxiMap or not C_TaxiMap.GetTaxiNodesForMap then return end
        local nodes = C_TaxiMap.GetTaxiNodesForMap(uiMapId)
        if not nodes then return end

        local playerFaction = _playerFaction()
        for _, node in ipairs(nodes) do
            -- Skip non-flight-master taxi entries (e.g. EPL towers).
            if not TAXI_NODE_BLACKLIST[node.nodeID] then

            -- Cache world coords for the focus adapter regardless of
            -- whether THIS character's faction renders a pin for this
            -- node — focusable identity is independent of pin display.
            if not self._taxiCoordCache[node.nodeID] then
                local wx, wy, cont = MUI_MapMath:MapToWorld(
                    uiMapId, node.position.x, node.position.y)
                if wx then
                    self._taxiCoordCache[node.nodeID] = {
                        wx = wx, wy = wy,
                        continent = cont,
                        name = node.name,
                    }
                end
            end

            -- Skip opposite-faction flight masters; neutral nodes always show.
            -- Also skip nodes that fall inside a curated hub's radius —
            -- the hub icon covers them visually (Booty Bay flight
            -- master, Gadgetzan, etc.). Cache populated above so focus
            -- arrow still resolves.
            if (node.faction == FACTION_NEUTRAL or node.faction == playerFaction)
                    and not self:_PointInsideAnyHub(uiMapId, node.position.x, node.position.y) then
                local nodeID = node.nodeID
                local pinName = "MUI_MapStaticPin_FlightMaster_" .. nodeID
                local pin = MapPin(pinName, 14)
                pin._focusKind = "flightmaster"
                pin._focusKey  = nodeID
                pin:SetIconType(self:_FlightMasterIcon(node))
                pin:SetMapPosition(uiMapId, node.position.x, node.position.y)
                pin:SetFocused(MUI_FocusManager:IsFocused("flightmaster", nodeID))
                pin:SetOnClick(
                    function()
                        if MUI_FocusManager:IsFocused("flightmaster", nodeID) then
                            MUI_FocusManager:SetFocus(nil)
                        else
                            MUI_FocusManager:SetFocus("flightmaster", nodeID)
                        end
                    end,
                    function() return MUI_FocusManager:IsFocused("flightmaster", nodeID) end
                )
                self.flightMasterPins[#self.flightMasterPins + 1] = pin
            end

            end -- TAXI_NODE_BLACKLIST
        end
    end;

    -- Walk every kind's pin list and re-sync the focused badge against
    -- the current focus state. Each pin records its (kind, key) at build
    -- time so we don't have to know the kind here.
    _RefreshFocusStates = function(self)
        local function refresh(list)
            for _, pin in ipairs(list) do
                if pin._focusKind and pin._focusKey ~= nil then
                    pin:SetFocused(MUI_FocusManager:IsFocused(pin._focusKind, pin._focusKey))
                end
            end
        end
        refresh(self.flightMasterPins)
        refresh(self.transportPins)
        refresh(self.dungeonPins)
        refresh(self.availableQuestPins)
    end;

    -- Place boat / zeppelin endpoint pins on the displayed zone, sourced
    -- from MUI_TransportDB. Faction-filtered the same way flight masters
    -- are: opposite-faction routes hide; neutral routes (Booty Bay /
    -- Ratchet ferry) show to everyone.
    _BuildTransportPins = function(self, uiMapId)
        if not MUI_TransportDB or not MUI_ZoneDB then return end
        local areaId = MUI_ZoneDB:GetAreaForUiMap(uiMapId)
        if not areaId then return end
        local endpoints = MUI_TransportDB:GetEndpointsAtArea(areaId)
        if not endpoints or #endpoints == 0 then return end

        local pf = UnitFactionGroup("player")
        local playerLetter = (pf == "Alliance" and "A")
                          or (pf == "Horde"    and "H")
                          or "N"
        -- DEBUG: show all factions while tweaking endpoint coords. Restore
        -- to `(ep.faction == "N" or ep.faction == playerLetter)` before
        -- shipping.
        local SHOW_ALL_FACTIONS = false

        for _, ep in ipairs(endpoints) do
            -- Cache world coords for the focus adapter regardless of
            -- whether THIS character's faction renders a pin for this
            -- endpoint — focusable identity is independent of pin display.
            if ep.key and ep.wx and not self._transportCoordCache[ep.key] then
                self._transportCoordCache[ep.key] = {
                    wx = ep.wx, wy = ep.wy,
                    continent = ep.continent,
                    name = ep.name,
                }
            end

            if SHOW_ALL_FACTIONS or ep.faction == "N" or ep.faction == playerLetter then
                local icon = TRANSPORT_FACTION_ICON[ep.faction]
                if icon then
                    local key = ep.key
                    local pinName = "MUI_MapStaticPin_Transport_"
                                    .. tostring(uiMapId) .. "_" .. tostring(key)
                    local pin = MapPin(pinName, 14)
                    pin._focusKind = "transport"
                    pin._focusKey  = key
                    pin:SetIconType(icon)
                    pin:SetMapPosition(uiMapId, ep.x / 100, ep.y / 100)
                    pin:SetFocused(MUI_FocusManager:IsFocused("transport", key))
                    pin:SetOnClick(
                        function()
                            if MUI_FocusManager:IsFocused("transport", key) then
                                MUI_FocusManager:SetFocus(nil)
                            else
                                MUI_FocusManager:SetFocus("transport", key)
                            end
                        end,
                        function() return MUI_FocusManager:IsFocused("transport", key) end
                    )
                    self:_WireTransportHover(pin, ep)
                    self.transportPins[#self.transportPins + 1] = pin
                end
            end
        end
    end;

    -- Hover override: while the cursor is over this pin, retitle the
    -- map's top-of-frame zone label with "<Boat|Zeppelin> to <other dock>
    -- (<other zone>)". The override is re-applied after Blizzard's
    -- per-frame EvaluateLabels via the hook in _EnsureLabelHook (which
    -- runs once on first hover). OnLeave clears the flag so the next
    -- evaluation falls back to whatever the cursor is over (subzone
    -- label or hidden).
    _WireTransportHover = function(self, pin, ep)
        local prefix = (ep.type == "zeppelin") and "Zeppelin to" or "Boat to"
        local otherZone = "?"
        local otherUi = MUI_ZoneDB:GetUiMapForArea(ep.otherAreaId)
        if otherUi then
            local info = C_Map.GetMapInfo(otherUi)
            if info and info.name then otherZone = info.name end
        end
        local overrideText = prefix .. " " .. (ep.otherName or "?")
                          .. " (" .. otherZone .. ")"

        pin:SetScript("OnEnter", function()
            _EnsureLabelHook()
            _hoveredOverride = overrideText
            MUI_ModuleMap.zoneLabelName:SetText(overrideText)
            MUI_ModuleMap.zoneLabel:Show()
        end)
        pin:SetScript("OnLeave", function()
            _hoveredOverride = nil
            MUI_ModuleMap.zoneLabelName:SetText("")
            --MUI_ModuleMap.zoneLabel:Hide()
        end)
    end;

    -- Place dungeon / raid entrance pins on the displayed zone, sourced
    -- from MUI_DungeonDB. No faction filter — both factions can enter
    -- every Classic Era instance. Hover label shows the
    -- "<Dungeon|Raid>: <Name>" via the same EvaluateLabels override
    -- mechanism transport pins use.
    --
    -- Visibility: a dungeon pin is shown on every zone-level map whose
    -- bounds contain the entrance's world position. That naturally
    -- yields Stockades on BOTH the Stormwind map and the Elwynn Forest
    -- map (Stormwind is visible inside Elwynn's bounds), without us
    -- having to enumerate parent areas.
    _BuildDungeonPins = function(self, uiMapId)
        if not MUI_DungeonDB or not MUI_MapMath then return end
        -- Filter button toggle. Coord cache is still populated below
        -- regardless so the focus arrow keeps resolving when the user
        -- has a dungeon focused.
        local s_qh = MUI_DB and MUI_DB.settings and MUI_DB.settings.questHelper
        local showPins = not (s_qh and s_qh.showDungeonsOnMap == false)
        local list = MUI_DungeonDB:GetAllDungeons()
        if not list or #list == 0 then return end

        for _, d in ipairs(list) do
            -- Cache every dungeon's world coords up front (independent of
            -- whether THIS map renders a pin for it) so the focus adapter
            -- can resolve a focused dungeon while the user is on any map.
            if not self._dungeonCoordCache[d.key] then
                self._dungeonCoordCache[d.key] = {
                    wx = d.wx, wy = d.wy,
                    continent = d.continent,
                    name = d.name,
                    isRaid = d.isRaid,
                }
            end

            if not showPins then
                -- skip pin emit; coord cache above keeps focus working
            else
            local nx, ny = MUI_MapMath:WorldToMap(uiMapId, d.wx, d.wy, d.continent)
            if nx and ny and nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1 then
                local key = d.key
                local icon = d.isRaid and "Raid" or "Dungeon"
                local pinName = "MUI_MapStaticPin_Dungeon_"
                                .. tostring(uiMapId) .. "_" .. tostring(key)
                local pin = MapPin(pinName, 16)
                pin._focusKind = "dungeon"
                pin._focusKey  = key
                pin:SetIconType(icon)
                pin:SetMapPosition(uiMapId, nx, ny)
                pin:SetFocused(MUI_FocusManager:IsFocused("dungeon", key))
                pin:SetOnClick(
                    function()
                        if MUI_FocusManager:IsFocused("dungeon", key) then
                            MUI_FocusManager:SetFocus(nil)
                        else
                            MUI_FocusManager:SetFocus("dungeon", key)
                        end
                    end,
                    function() return MUI_FocusManager:IsFocused("dungeon", key) end
                )
                self:_WireDungeonHover(pin, d)
                self.dungeonPins[#self.dungeonPins + 1] = pin
            end
            end -- showPins
        end
    end;

    -- Place available-quest pins on the displayed zone, sourced from
    -- MUI_QuestHelper.availability:GetStartersInArea. Two-pass build:
    --
    --   1) per-giver group  — multiple quests at the same NPC / object
    --      collapse into one giver-group (same heuristic as the
    --      minimap pin manager).
    --   2) hub absorption   — for each curated hub on this uiMap (from
    --      MUI_QuestHubDB), every giver-group whose normalized position
    --      lies within the hub's `radius` is absorbed into the hub's
    --      tooltip roster. Hub pins ALWAYS render (even when empty);
    --      unabsorbed giver-groups render as individual pins.
    --
    -- Single-giver icon priority:
    --   "Quest"                 — any non-trivial normal quest in the group
    --   "QuestRepeatableTurnIn" — only pure-delivery repeatables
    --   "QuestRepeatable"       — repeatables (with at least one non-turn-in)
    --   "Quest" + dim           — every quest in the group is trivial
    _BuildAvailableQuestPins = function(self, uiMapId)
        if not MUI_QuestHelper or not MUI_QuestHelper.availability
                or not MUI_QuestDB then
            return
        end

        -- Pass 1: per-giver grouping. Skipped entirely (empty groups
        -- table) when the area has no starters — but hub pins still
        -- need to render below, so we don't early-return on empty.
        local groups = {}
        local order  = {}
        local areaId = MUI_ZoneDB:GetAreaForUiMap(uiMapId)
        local starters
        if areaId then
            starters = MUI_QuestHelper.availability:GetStartersInArea(areaId)
        end
        -- Per-surface trivial filter. Availability always returns
        -- trivials; the world-map setting decides whether to keep them.
        local s_qh = MUI_DB and MUI_DB.settings and MUI_DB.settings.questHelper
        local includeTrivial = s_qh and s_qh.showLowLevelAvailableQuestsOnMap or false

        if starters then
            for _, s in ipairs(starters) do
                if not (s.isTrivial and not includeTrivial) then
                local key = s.kind .. ":" .. s.targetId
                            .. "@" .. math.floor(s.normX * 1000)
                            .. "_" .. math.floor(s.normY * 1000)
                local g = groups[key]
                if not g then
                    g = {
                        spec          = s,
                        questIds      = {},
                        quests        = {},
                        hasNormal     = false,
                        hasRepeatable = false,
                        hasTurnIn     = false,
                        allTurnIn     = true,
                        allTrivial    = true,
                    }
                    groups[key] = g
                    order[#order + 1] = key
                end
                g.questIds[#g.questIds + 1] = s.questId
                if not s.isTrivial then g.allTrivial = false end
                -- Repeatable turn-ins (e.g. "Additional Runecloth") get
                -- pre-tagged in the precomputed DB by the exporter.
                local q = MUI_QuestDB:Get(s.questId)
                local isTurnIn = q and q.isRepeatableTurnIn and true or false
                if isTurnIn then g.hasTurnIn = true else g.allTurnIn = false end
                if s.isRepeatable then
                    g.hasRepeatable = true
                elseif not s.isTrivial then
                    g.hasNormal = true
                end
                -- Per-quest detail used by the hub tooltip's section
                -- buckets + per-line icon classification.
                g.quests[#g.quests + 1] = {
                    questId      = s.questId,
                    isTrivial    = s.isTrivial    and true or false,
                    isRepeatable = s.isRepeatable and true or false,
                    isTurnIn     = isTurnIn,
                }
                end -- per-surface trivial filter
            end
        end

        -- Pass 2: hub absorption. For each curated hub on this uiMap,
        -- sweep every giver-group whose normalized position is within
        -- `radius` into that hub's roster. Hub renders ALWAYS, even
        -- when its roster is empty (low-level char visiting a high-
        -- level hub). First-match wins on overlapping radii (curator's
        -- list order is preference order).
        local absorbed = {}    -- [groupKey] = true
        local hubs = MUI_QuestHubDB and MUI_QuestHubDB:GetHubsForUiMap(uiMapId)
        if hubs then
            for _, hub in ipairs(hubs) do
                local r2 = hub.radius * hub.radius
                local hubMembers = {}
                for _, key in ipairs(order) do
                    if not absorbed[key] then
                        local g = groups[key]
                        local dx = g.spec.normX - hub.nx
                        local dy = g.spec.normY - hub.ny
                        if dx * dx + dy * dy <= r2 then
                            absorbed[key] = true
                            hubMembers[#hubMembers + 1] = g
                        end
                    end
                end
                self:_EmitHubPin(uiMapId, hub, hubMembers)
            end
        end

        -- Emit unabsorbed giver-groups as individual pins.
        for _, key in ipairs(order) do
            if not absorbed[key] then
                self:_EmitGiverPin(uiMapId, groups[key])
            end
        end
    end;

    -- Single-giver pin: NPC / object with one or more available quests.
    -- Icon priority documented on _BuildAvailableQuestPins.
    _EmitGiverPin = function(self, uiMapId, g)
        local s    = g.spec
        local icon
        local dim  = false
        if g.hasNormal then
            icon = "Quest"
        elseif g.hasRepeatable and g.allTurnIn then
            icon = "QuestRepeatableTurnIn"
        elseif g.hasRepeatable then
            icon = "QuestRepeatable"
        else
            icon = "Quest"
            dim  = true
        end

        local focusKey = s.kind .. ":" .. s.targetId
        if not self._questGiverCache[focusKey] then
            local wx, wy, cont = MUI_MapMath:MapToWorld(
                uiMapId, s.normX, s.normY)
            if wx then
                local giverName
                if s.kind == "npc" then
                    local npc = MUI_NpcDB:Get(s.targetId)
                    giverName = npc and npc.name
                elseif s.kind == "object" then
                    local obj = MUI_ObjectDB:Get(s.targetId)
                    giverName = obj and obj.name
                end
                self._questGiverCache[focusKey] = {
                    wx = wx, wy = wy,
                    continent = cont,
                    name = giverName,
                }
            end
        end

        local pinName = "MUI_MapStaticPin_AvailableQuest_"
                        .. tostring(uiMapId) .. "_"
                        .. focusKey:gsub("[^%w]", "_") .. "_"
                        .. math.floor(s.normX * 1000) .. "_"
                        .. math.floor(s.normY * 1000)
        local pin = MapPin(pinName, 14)
        pin._focusKind = "questgiver"
        pin._focusKey  = focusKey
        pin:SetIconType(icon)
        if dim then
            pin:SetIconTint(1.0, 1.0, 1.0, 0.5)
        end
        pin:SetMapPosition(uiMapId, s.normX, s.normY)
        pin:SetFocused(MUI_FocusManager:IsFocused("questgiver", focusKey))
        pin:SetOnClick(
            function()
                if MUI_FocusManager:IsFocused("questgiver", focusKey) then
                    MUI_FocusManager:SetFocus(nil)
                else
                    MUI_FocusManager:SetFocus("questgiver", focusKey)
                end
            end,
            function() return MUI_FocusManager:IsFocused("questgiver", focusKey) end
        )
        self:_WireAvailableQuestHover(pin, g.questIds)
        self.availableQuestPins[#self.availableQuestPins + 1] = pin
    end;

    -- Highest-priority quest icon across hubMembers, used for the hub
    -- pin's bottom-center indicator. Priority (matches tooltip order):
    --   1) standard non-trivial    -> "Quest"
    --   2) standard trivial        -> "Quest" dimmed
    --   3) repeatable (non-turnin) -> "QuestRepeatable"
    --   4) repeatable turn-in      -> "QuestRepeatableTurnIn"
    -- Returns (iconType, dimmed) or (nil, nil) when no quests absorbed.
    _DominantQuestIcon = function(self, hubMembers)
        if not hubMembers or #hubMembers == 0 then return nil, nil end
        local bestRank, bestIcon, bestDim = 5, nil, false
        for _, g in ipairs(hubMembers) do
            for _, q in ipairs(g.quests or {}) do
                local rank, icon, dim
                if not q.isRepeatable and not q.isTrivial then
                    rank, icon, dim = 1, "Quest", false
                elseif not q.isRepeatable then
                    rank, icon, dim = 2, "Quest", true
                elseif not q.isTurnIn then
                    rank, icon, dim = 3, "QuestRepeatable", false
                else
                    rank, icon, dim = 4, "QuestRepeatableTurnIn", false
                end
                if rank < bestRank then
                    bestRank, bestIcon, bestDim = rank, icon, dim
                end
            end
        end
        return bestIcon, bestDim
    end;

    -- Hub pin: fixed-position pin sourced from MUI_QuestHubDB. Renders
    -- whenever its uiMap is displayed regardless of whether any quests
    -- in the absorption radius are currently available — the hub is a
    -- universal map landmark, not a function of player state. Tooltip
    -- leads with hub name + flavor and lists any absorbed quests.
    _EmitHubPin = function(self, uiMapId, hub, hubMembers)
        -- Cache world coords for the focus adapter (used by the off-
        -- zone focus arrow when the player has navigated away).
        if not self._questHubCache[hub.id] then
            local wx, wy, cont = MUI_MapMath:MapToWorld(
                uiMapId, hub.nx, hub.ny)
            if wx then
                self._questHubCache[hub.id] = {
                    wx = wx, wy = wy, continent = cont,
                }
            end
        end

        local pinName = "MUI_MapStaticPin_QuestHub_" .. hub.id
        local pin = MapPin(pinName, 18)
        pin._focusKind = "questhub"
        pin._focusKey  = hub.id
        pin:SetIconType("Hub")
        pin:SetMapPosition(uiMapId, hub.nx, hub.ny)
        pin:SetFocused(MUI_FocusManager:IsFocused("questhub", hub.id))
        pin:SetOnClick(
            function()
                if MUI_FocusManager:IsFocused("questhub", hub.id) then
                    MUI_FocusManager:SetFocus(nil)
                else
                    MUI_FocusManager:SetFocus("questhub", hub.id)
                end
            end,
            function() return MUI_FocusManager:IsFocused("questhub", hub.id) end
        )
        -- Bottom-center indicator: surfaces the hub's "dominant" quest
        -- icon when the absorbed roster is non-empty. Empty hubs hide
        -- the indicator (SetIndicator(nil)).
        local indicatorIcon, indicatorDim = self:_DominantQuestIcon(hubMembers)
        pin:SetIndicator(indicatorIcon, indicatorDim)

        self:_WireHubHover(pin, hub, hubMembers)
        self.availableQuestPins[#self.availableQuestPins + 1] = pin
    end;

    -- Build a |T...|t inline tooltip-icon escape from a MUI_MapPinIcons
    -- spec. `dimmed=true` tints to mid-grey for trivial / low-level
    -- variants (the WoW tooltip texture escape only supports RGB tint,
    -- not real alpha — grey is the closest visual to the dim pin look).
    -- size is the on-screen pixel height/width of the inline icon.
    _IconEscape = function(self, iconType, size, dimmed)
        local spec = MUI_MapPinIcons and MUI_MapPinIcons[iconType]
        if not spec then return "" end
        local path, fileW, fileH = spec[1], spec[2], spec[3]
        local x, y, w, h = spec[4], spec[5], spec[6], spec[7]
        size = size or 14
        if dimmed then
            return string.format(
                "|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d:140:140:140|t",
                path, size, size, fileW, fileH,
                x, x + w, y, y + h)
        end
        return string.format(
            "|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t",
            path, size, size, fileW, fileH,
            x, x + w, y, y + h)
    end;

    -- Hub tooltip layout:
    --   * name (gold title, large)
    --   * flavor (grey, wrapped)
    --   * "Available quests" section — when absorbed roster has any
    --     non-repeatable quest: up to 4 lines, each "<icon> <title>",
    --     deduped by giver via round-robin (1 quest per giver per
    --     pass). If a section's total quests exceeds the visible 4,
    --     append "+N more" (N = total - shown).
    --   * "Available repeatable" section — same rules for repeatables.
    --
    -- Per-line icon:
    --   * standard non-trivial → "Quest"
    --   * standard trivial     → "Quest" tinted grey (low-level)
    --   * repeatable (turn-in) → "QuestRepeatableTurnIn"
    --   * repeatable           → "QuestRepeatable"
    --
    -- Empty-roster hubs (low-level char visiting a high-level hub)
    -- show only name + flavor.
    _WireHubHover = function(self, pin, hub, hubMembers)
        -- Collect every absorbed quest into per-giver lists, separately
        -- for standard and repeatable buckets. giverKey is "kind:targetId"
        -- (no coords) so two spawns of the same NPC dedupe.
        local stdByGiver, stdGiverOrder = {}, {}
        local repByGiver, repGiverOrder = {}, {}
        if hubMembers then
            for _, g in ipairs(hubMembers) do
                local giverKey = g.spec.kind .. ":" .. g.spec.targetId
                for _, q in ipairs(g.quests or {}) do
                    if q.isRepeatable then
                        local list = repByGiver[giverKey]
                        if not list then
                            list = {}
                            repByGiver[giverKey] = list
                            repGiverOrder[#repGiverOrder + 1] = giverKey
                        end
                        list[#list + 1] = q
                    else
                        local list = stdByGiver[giverKey]
                        if not list then
                            list = {}
                            stdByGiver[giverKey] = list
                            stdGiverOrder[#stdGiverOrder + 1] = giverKey
                        end
                        list[#list + 1] = q
                    end
                end
            end
        end

        -- Round-robin pick: round 1 takes first quest from each giver,
        -- round 2 takes second, ... Stops at maxLines or when no giver
        -- has more quests. If unique-giver count < maxLines, the
        -- remaining slots get filled by giving multi-quest givers
        -- additional lines.
        local function _Pick(byGiver, giverOrder, maxLines)
            local picked = {}
            local total  = 0
            for _, list in pairs(byGiver) do total = total + #list end
            local round = 1
            while #picked < maxLines do
                local addedThisRound = false
                for _, giverKey in ipairs(giverOrder) do
                    local list = byGiver[giverKey]
                    if list[round] then
                        picked[#picked + 1] = list[round]
                        addedThisRound = true
                        if #picked >= maxLines then break end
                    end
                end
                if not addedThisRound then break end
                round = round + 1
            end
            return picked, total
        end

        local stdPicked, stdTotal = _Pick(stdByGiver, stdGiverOrder, 4)
        local repPicked, repTotal = _Pick(repByGiver, repGiverOrder, 4)

        pin:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            tooltip:AddLine(hub.name, 1, 1, 1, true, 13)
            if hub.flavor then
                tooltip:AddLine(hub.flavor, 1, 0.82, 0, true)
            end

            if #stdPicked > 0 then
                tooltip:AddBlank()
                tooltip:AddLine("Available quests", 1, 1, 1)
                for _, q in ipairs(stdPicked) do
                    local icon = self:_IconEscape("Quest", 19, q.isTrivial)
                    local text, r, g, b = _QuestLineFormat(q.questId)
                    tooltip:AddLine(icon .. " " .. text, r, g, b)
                end
                if stdTotal > #stdPicked then
                    tooltip:AddLine("+" .. (stdTotal - #stdPicked) .. " more",
                                0.8, 0.8, 0.8)
                end
            end

            if #repPicked > 0 then
                tooltip:AddBlank()
                tooltip:AddLine("Available repeatable", 1, 1, 1)
                for _, q in ipairs(repPicked) do
                    local iconType = q.isTurnIn
                        and "QuestRepeatableTurnIn"
                        or  "QuestRepeatable"
                    local icon = self:_IconEscape(iconType, 19, false)
                    local text, r, g, b = _QuestLineFormat(q.questId)
                    tooltip:AddLine(icon .. " " .. text, r, g, b)
                end
                if repTotal > #repPicked then
                    tooltip:AddLine("+" .. (repTotal - #repPicked) .. " more",
                                0.8, 0.8, 0.8)
                end
            end
        end)
    end;

    -- Cursor-anchored tooltip top-right of the pin: each quest's title
    -- as a 13pt line (gold by default; respects showQuestLevel /
    -- showQuestDifficultyColor settings via _QuestLineFormat) followed
    -- by a white "Available quest(s)" subtitle.
    --
    -- Formatting runs INSIDE OnEnter so the tooltip reflects setting
    -- toggles (showQuestLevel, showQuestDifficultyColor) on the next
    -- hover — no /reload or zone change required.
    _WireAvailableQuestHover = function(self, pin, questIds)
        local count = questIds and #questIds or 0
        local subtitle = (count > 1) and "Available quests" or "Available quest"

        pin:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            if MUI_QuestDB and questIds then
                for _, qid in ipairs(questIds) do
                    local text, r, g, b = _QuestLineFormat(qid)
                    tooltip:AddLine(text, r, g, b, false, 13)
                end
            end
            tooltip:AddLine(subtitle, 1, 1, 1)
        end)
    end;

    _WireDungeonHover = function(self, pin, d)
        local label = d.name or "?"
        local sublabel = d.isRaid and "Raid" or "Dungeon"
        pin:SetScript("OnEnter", function()
            _EnsureLabelHook()
            _hoveredOverride = label
            MUI_ModuleMap.zoneLabelName:SetText(label)
            MUI_ModuleMap.zoneSubLabel:SetText(sublabel)
            MUI_ModuleMap.zoneLabel:Show()
        end)
        pin:SetScript("OnLeave", function()
            _hoveredOverride = nil
            MUI_ModuleMap.zoneLabelName:SetText("")
            MUI_ModuleMap.zoneSubLabel:SetText("")
            --MUI_ModuleMap.zoneLabel:Hide()
        end)
        pin:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            tooltip:AddLine(label, 1,1,1, false, 13)
            tooltip:AddLine(sublabel, 1, 0.82, 0, true)
        end)
    end;

    _DestroyAll = function(self)
        for _, pin in ipairs(self.flightMasterPins)   do pin:Destroy() end
        self.flightMasterPins = {}
        for _, pin in ipairs(self.transportPins)      do pin:Destroy() end
        self.transportPins = {}
        for _, pin in ipairs(self.availableQuestPins) do pin:Destroy() end
        self.availableQuestPins = {}
        for _, pin in ipairs(self.dungeonPins)        do pin:Destroy() end
        self.dungeonPins = {}
    end;
}
