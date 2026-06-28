-- MapQuestPoiManager: places a QuestPoiButton on the WorldMap canvas for
-- every TRACKED quest at its "next step" location. Position matches the
-- exact spot MUI_FocusedTargetArrow / MUI_FocusNavigation would aim at if
-- the quest were focused — i.e. the nearest cluster centroid (or stray /
-- finisher under the same fallback rules), with cross-continent reroute
-- to the nearest transport dock when the quest is on a different
-- continent than the player. PickTarget handles all of that.
--
-- The button instance is the SAME QuestPoiButton class used in the quest
-- tracker and quest-log rows (MUI_QuestHelper/MUI_QuestTracker.lua), so
-- visual states (focused glow, complete checkmark, recurring atlas, hover
-- innerGlow, pressed state) are consistent across all three surfaces.
-- OnClick toggles MUI_FocusManager focus, identical to those rows.
--
-- Lifecycle:
--   * Driven by WorldMapFrame.OnMapChanged (reproject onto new map),
--     MUI_QuestHelper tracking listener (track on/off ⇒ show/hide), and
--     MUI_QuestHelper clusters-changed listener (objective progress
--     can shift the centroid). Watcher OnQuestRemoved destroys.
--   * MUI_FocusManager change listener rebuilds — needed on continent
--     view where focus determines visibility (only the focused quest's
--     POI is shown).
--   * Buttons are pooled per questId; on rebuild, off-map quests are
--     hidden, on-map quests reuse / repositioned.

-- Enum.UIMapType: Continent == 2, Zone == 3.
-- Visibility rules (see Rebuild):
--   Zone:      every tracked quest's POI (subject to solo filter).
--   Continent: ONLY the currently-focused quest's POI. Lets the player
--              see where their focus target is at continent scale
--              without crowding the view with every tracked quest.
--   World/cosmic: nothing.
local ZONE_MAP_TYPE      = 3
local CONTINENT_MAP_TYPE = 2

-- specialFlags bit 0 = repeatable (matches Questie's QuestieDB.IsRepeatable
-- and QuestTracker._isRepeatable). Tiny duplicate; exposing it from
-- QuestHelper would be busywork for one bitcheck.
local function _isRepeatable(questId)
    if not MUI_QuestDB then return false end
    local q = MUI_QuestDB:Get(questId)
    if not q then return false end
    local f = q.specialFlags
    return f and (f % 2) >= 1 or false
end

-- Same canvas-wrapper cache pattern MapPin uses. World-map canvas is
-- created once at WorldMapFrame load; we wrap it lazily.
local _canvasWrapper
local function _Canvas()
    if _canvasWrapper then return _canvasWrapper end
    if not WorldMapFrame or not WorldMapFrame.GetCanvas then return nil end
    local native = WorldMapFrame:GetCanvas()
    if not native then return nil end
    _canvasWrapper = Frame(native)
    return _canvasWrapper
end

-- Each POI gets its own frame level, incremented per creation. Without
-- this, two overlapping POIs at the same frame level would interleave
-- their textures by draw layer — the back POI's OVERLAY (dots / innerGlow)
-- would render ABOVE the front POI's ARTWORK (ring), since draw layer
-- ordering wins inside a frame-level tie. Staggering ensures each POI
-- renders as one self-contained stack. Pooled buttons keep their level
-- across rebuilds; only new creations advance the counter.
local _nextPoiFrameLevel = MUI_MAP_PIN_FRAME_LEVEL + 10

class "MapQuestPoiManager" : extends "Frame" {
    __init = function(self)
        Frame.__init(self, "Frame", nil, "MUI_MapQuestPoiManagerDriver")
        self._buttons     = {}   -- questId -> QuestPoiButton
        -- When non-nil, Rebuild only shows the POI for this single
        -- quest (others hidden). Set by the map module when the quest
        -- description tab opens; cleared when the quest log tab is
        -- shown again. Tracking listeners + cluster updates still drive
        -- rebuilds normally, just filtered to this one quest.
        self._soloQuestId = nil

        hooksecurefunc(WorldMapFrame, "OnMapChanged", function() self:Rebuild() end)

        -- MUI_QuestHelper.OnEnable runs at PEW BEFORE ModuleMap.OnEnable
        -- (toc order), so by the time this manager is constructed,
        -- MUI_QuestHelper exists and its watcher is wired up.
        if MUI_QuestHelper then
            MUI_QuestHelper:RegisterTrackingListener(function() self:Rebuild() end)
            MUI_QuestHelper:RegisterClustersChangedListener(function() self:Rebuild() end)

            local watcher = MUI_QuestHelper.watcher
            if watcher then
                watcher:RegisterCallback("OnQuestRemoved", function(questId)
                    self:_DestroyButton(questId)
                end)
                watcher:RegisterCallback("OnQuestChanged", function(questId)
                    -- Cluster-changed already covers position shifts. This
                    -- catches isComplete / leaderboard-finished flips that
                    -- only affect the POI's visual state.
                    self:_SyncQuestState(questId)
                end)
            end
        end

        -- Focus change rebuilds: on continent view the visibility set
        -- depends on the focused quest (only it shows), so a new focus
        -- means the old POI hides and the new one shows. Rebuild also
        -- updates SetFocused on every button via SyncStateInline.
        -- BringFocusedToTop ensures the focused POI is the top of the
        -- staggered frame-level stack regardless of whether Rebuild
        -- created any new buttons this round.
        MUI_FocusManager:RegisterChangeListener(function()
            self:Rebuild()
            self:_BringFocusedToTop()
        end)

        self:Rebuild()
    end;

    Rebuild = function(self)
        local displayedMapId = WorldMapFrame and WorldMapFrame:GetMapID()
        if not displayedMapId then
            for _, poi in pairs(self._buttons) do poi:Hide() end
            return
        end

        -- Master toggle from the world-map filter button. When off,
        -- every POI hides and we skip the per-quest projection pass.
        local s_qh = MUI_DB and MUI_DB.settings and MUI_DB.settings.questHelper
        if s_qh and s_qh.showObjectivesOnMap == false then
            for _, poi in pairs(self._buttons) do poi:Hide() end
            return
        end

        local info = C_Map.GetMapInfo(displayedMapId)
        if not info then
            for _, poi in pairs(self._buttons) do poi:Hide() end
            return
        end

        -- Eligibility filter per the file-header rules. `restrictTo` is
        -- nil on zone maps (every tracked quest may show), or the
        -- focused questId on continent maps (only it may show), or false
        -- on world/cosmic maps (nothing shows — early return).
        local restrictTo
        if info.mapType == ZONE_MAP_TYPE then
            restrictTo = nil
        elseif info.mapType == CONTINENT_MAP_TYPE then
            local kind, key = MUI_FocusManager:GetFocus()
            if kind == "quest" and key then
                restrictTo = key
            else
                for _, poi in pairs(self._buttons) do poi:Hide() end
                return
            end
        else
            for _, poi in pairs(self._buttons) do poi:Hide() end
            return
        end

        local canvas = _Canvas()
        if not canvas then return end

        local watcher = MUI_QuestHelper and MUI_QuestHelper.watcher
        if not watcher then return end

        -- Compute desired set: for each eligible quest, project its target
        -- onto the displayed map. Off-map quests are absent from `needed`
        -- and their pooled buttons hide below.
        local needed = {}
        for questId, entry in pairs(watcher:GetWatched() or {}) do
            -- Solo filter (description tab open) only applies on zone
            -- maps. On continent maps the focus filter above is the
            -- only gate.
            local soloOk = (not self._soloQuestId) or (self._soloQuestId == questId)
            local mapOk  = (restrictTo == nil) or (restrictTo == questId)
            if mapOk and soloOk and MUI_QuestHelper:IsTracked(questId) then
                -- Stationary placement: skip transport reroute so the POI
                -- sits at the actual quest location even when it's on a
                -- different continent than the player. The minimap edge
                -- arrow + on-screen compass still reroute (they guide
                -- the player to the boat dock).
                local target = MUI_FocusManager:PickTarget("quest", questId, true)
                if target and target.continent then
                    local nx, ny = MUI_MapMath:WorldToMap(
                        displayedMapId, target.wx, target.wy, target.continent)
                    if nx and ny and nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1 then
                        needed[questId] = { normX = nx, normY = ny, entry = entry }
                    end
                end
            end
        end

        local createdAny = false
        for questId, info in pairs(needed) do
            local poi = self._buttons[questId]
            if not poi then
                poi = self:_CreateButton(questId)
                self._buttons[questId] = poi
                createdAny = true
            end
            poi:ClearAllPoints()
            poi:SetPoint("CENTER", canvas, "TOPLEFT",
                           info.normX * canvas:GetWidth(),
                          -info.normY * canvas:GetHeight())
            self:_SyncStateInline(poi, questId, info.entry)
            poi:Show()
        end

        for questId, poi in pairs(self._buttons) do
            if not needed[questId] then poi:Hide() end
        end

        -- New POIs were just created at the top of the stack; bump the
        -- focused one back up so it stays the most prominent. Skipped
        -- when no creations happened — saves needless counter inflation.
        if createdAny then self:_BringFocusedToTop() end
    end;

    _CreateButton = function(self, questId)
        local poi = QuestPoiButton(_Canvas(), "MUI_MapQuestPoi_" .. questId, 21)
        poi:SetFrameStrata("MEDIUM")
        -- Sit above flight master pins (MUI_MAP_PIN_FRAME_LEVEL = 3000)
        -- with a unique per-POI level so overlapping POIs don't suffer
        -- the cross-frame draw-layer interleave (see _nextPoiFrameLevel).
        poi:SetFrameLevel(_nextPoiFrameLevel)
        _nextPoiFrameLevel = _nextPoiFrameLevel + 1
        -- Constant on-screen size as the user zooms the canvas; the
        -- scale tracker counter-scales the pin to (1/canvasScale).
        MUI_MapPinScaleTracker:Register(poi)
        poi.OnClick = function()
            if MUI_FocusManager:IsFocused("quest", questId) then
                MUI_FocusManager:SetFocus(nil)
            else
                MUI_FocusManager:SetFocus("quest", questId)
            end
        end
        -- Cursor-sticky tooltip with the quest's title + DB description +
        -- live per-objective progress (same content as the quest-log
        -- row's hover tooltip). HookScript so the QuestPoiButton's own
        -- OnEnter/OnLeave (innerGlow) keeps running.
        poi:HookScript("OnEnter", function()
            --self:_ShowPoiTooltip(poi, questId)
            MUI_QuestHelper:PushQuestHover(questId)
        end)
        poi:HookScript("OnLeave", function()
            --MUI_Tooltip:Hide()
            MUI_QuestHelper:PopQuestHover(questId)
        end)

        poi:SetTooltip("ANCHOR_CURSOR", function(tooltip)

            local entry = MUI_QuestHelper.watcher and MUI_QuestHelper.watcher:GetEntry(questId)
            if not entry then return end
            local title = entry.title or ("quest " .. questId)

            tooltip:SetMinimumWidth(100)
            tooltip:AddTitle(title, true)

            -- Live leaderboard objectives. Finished lines go green, in-
            -- progress white, both bullet-prefixed for easy scanning.
            local emittedAny = false
            if entry.objectives then
                for _, o in ipairs(entry.objectives) do
                    if o.text and o.text ~= "" then
                        emittedAny = true
                        if o.finished then
                            tooltip:AddLine("-" .. o.text, 0.4, 0.85, 0.4, true)
                        else
                            tooltip:AddLine("-" .. o.text, 1, 1, 1, true)
                        end
                    end
                end
            end

            -- Fallback for quests with NO leaderboard objectives at all
            -- (e.g. "Speak with Marshal McBride." quests). Show the DB
            -- objectivesText so the tooltip isn't just a bare title.
            if not emittedAny then
                local q = MUI_QuestDB and MUI_QuestDB:Get(questId)
                local lines = q and q.objectivesText
                if lines and #lines > 0 then
                    local text = type(lines) == "table"
                            and table.concat(lines, "\n")
                            or tostring(lines)
                    if text ~= "" then
                        tooltip:AddLine(text, 1, 1, 1, true)
                    end
                end
            end

        end)

        return poi
    end;

    _SyncStateInline = function(self, poi, questId, entry)
        poi:SetRecurring(_isRepeatable(questId))
        poi:SetComplete(entry and entry.isComplete and true or false)
        poi:SetFocused(MUI_FocusManager:IsFocused("quest", questId))
    end;

    _SyncQuestState = function(self, questId)
        local poi = self._buttons[questId]
        if not poi or not poi:IsShown() then return end
        local entry = MUI_QuestHelper.watcher and MUI_QuestHelper.watcher:GetEntry(questId)
        self:_SyncStateInline(poi, questId, entry)
    end;

    -- Restrict the manager to a single quest's POI (others hidden), or
    -- pass nil to clear and show every tracked quest. Used by ModuleMap's
    -- ShowQuestDescription / ShowQuestLog tab switches.
    SetSoloQuestFilter = function(self, questId)
        if self._soloQuestId == questId then return end
        self._soloQuestId = questId
        self:Rebuild()
    end;

    -- Push the currently-focused quest's POI to the top of the staggered
    -- frame-level stack. No-op when nothing is focused, focus is a non-
    -- quest kind, or the focused quest's POI doesn't (yet) exist on the
    -- displayed map.
    _BringFocusedToTop = function(self)
        local focusKind, focusKey = MUI_FocusManager:GetFocus()
        if focusKind ~= "quest" then return end
        local poi = self._buttons[focusKey]
        if not poi then return end
        poi:SetFrameLevel(_nextPoiFrameLevel)
        _nextPoiFrameLevel = _nextPoiFrameLevel + 1
    end;

    _DestroyButton = function(self, questId)
        local poi = self._buttons[questId]
        if not poi then return end
        MUI_MapPinScaleTracker:Unregister(poi)
        poi:Hide()
        poi:ClearAllPoints()
        self._buttons[questId] = nil
    end;
}
