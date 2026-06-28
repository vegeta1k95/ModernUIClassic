-- Both yellow `?` (ready to turn in) and grey `?` (in-progress quest-giver
-- reminder) are finisher pins — destroy/restore logic keys off the kind,
-- not the exact icon.

local function _isFinisherIcon(iconType)
    return iconType == "QuestTurnIn" or iconType == "QuestCompletable"
end

-- Quests whose surviving objective points number fewer than QuestObjective-
-- Cluster's MIN_CLUSTER_SIZE don't form a cluster hull. Render a small
-- CCW-polygon circle around each stray point so single-target quests still
-- get a visible area overlay (with hover tooltip). Radius / vertex count
-- are picked for "clearly localised marker" rather than geographic accuracy.
local STRAY_CIRCLE_YARDS    = 26
local STRAY_CIRCLE_VERTICES = 12
local function _strayCircleHull(cx, cy)
    local hull = {}
    local step = 2 * math.pi / STRAY_CIRCLE_VERTICES
    for i = 1, STRAY_CIRCLE_VERTICES do
        local a = (i - 1) * step
        hull[i] = {
            cx + STRAY_CIRCLE_YARDS * math.cos(a),
            cy + STRAY_CIRCLE_YARDS * math.sin(a),
        }
    end
    return hull
end

-- Hotzone cluster radius for objective pins (world yards). Matches Questie's
-- `clusterLevelHotzone` default — merges nearby spawns of the same target
-- (e.g. 31 kobolds in a camp) into a single centered pin instead of pinning
-- every spawn individually.
local CLUSTER_YARDS = 50

-- Greedy Questie-style clustering: group specs by objectiveIdx ONLY, so all
-- drop sources of the same item (or all kill targets of the same objective)
-- collapse into a shared point cloud. Within each group, merge points whose
-- world-yard distance < range. Mirrors Questie's `_DrawObjectiveIcons` which
-- feeds every `objective.spawnList` entry into one hotzone pass and picks
-- `hotzone[1]` as the representative. Spawn positions from different sources
-- at the same location thus merge into a single pin instead of visually
-- duplicating.
local function _clusterSpecs(specs, rangeYards)
    local groups = {}
    for _, spec in ipairs(specs) do
        local key = tostring(spec.objectiveIdx)
        groups[key] = groups[key] or {}
        groups[key][#groups[key] + 1] = spec
    end

    local out = {}
    for _, group in pairs(groups) do
        local pts = {}
        for _, spec in ipairs(group) do
            local wx, wy = MUI_MapMath:MapToWorld(spec.uiMapId, spec.normX, spec.normY)
            if wx then
                pts[#pts + 1] = { spec = spec, wx = wx, wy = wy }
            end
        end

        local clusterIdx = 0
        for i = 1, #pts do
            local p = pts[i]
            if not p.touched then
                p.touched = true
                clusterIdx = clusterIdx + 1
                local sumNX, sumNY, n = p.spec.normX, p.spec.normY, 1
                for j = i + 1, #pts do
                    local q = pts[j]
                    if not q.touched then
                        local dx, dy = p.wx - q.wx, p.wy - q.wy
                        if (dx * dx + dy * dy) < (rangeYards * rangeYards) then
                            q.touched = true
                            sumNX, sumNY, n = sumNX + q.spec.normX, sumNY + q.spec.normY, n + 1
                        end
                    end
                end
                -- Representative spec carries the cluster's first source's
                -- targetId / targetName. Pin-name uniqueness is maintained by
                -- spawnIdx, which is the per-objective cluster index.
                local rep = {}
                for k, v in pairs(p.spec) do rep[k] = v end
                rep.normX       = sumNX / n
                rep.normY       = sumNY / n
                rep.spawnIdx    = clusterIdx
                rep.clusterSize = n
                out[#out + 1] = rep
            end
        end
    end
    return out
end

-- MinimapQuestPinManager: owns every MinimapPin /
-- MinimapQuestObjectiveArea created for active quests on the minimap.
-- The focused-target chevron is no longer owned here — it's a generic
-- MUI_FocusedTargetArrow constructed by MUI_FocusManager and tracks
-- whatever's focused (quest, flightmaster, future). A future
-- WorldmapQuestPinManager will be a separate class with its own logic
-- — we namespace this one to the minimap layer explicitly.
--
-- Driven by QuestLogWatcher callbacks:
--   * OnQuestAdded   — resolve specs, cache them, spawn current-zone pins
--   * OnQuestRemoved — destroy pins for that quest and drop the spec cache
--   * OnQuestChanged — swap objective pins → turn-in on completion; destroy
--                      pins for individually-finished objectives
-- Plus ZONE_CHANGED_* events for full zone-rebuild, and
-- PLAYER_ENTERING_WORLD to cover reload / login.
--
-- Specs are cached per quest for every zone the target is known in; pins
-- are only materialised for the player's current top-level area. Out-of-
-- zone targets are NOT pinned — the single focused-quest edge arrow is
-- the only off-minimap hint.

class "MinimapQuestPinManager" : extends "Frame" {
    __init = function(self, watcher)
        Frame.__init(self, "Frame", nil, "MUI_MinimapQuestPinManagerDriver")

        self.watcher       = watcher
        -- specs[questId] = { objective = { spec, ... }, finisher = { spec, ... } }
        self.specs         = {}
        -- pins[questId]  = { { pin=..., objectiveIdx=..., kind=..., spec=... }, ... }
        self.pins          = {}
        -- areas[questId] = MinimapQuestObjectiveArea — only populated
        -- when MUI_QuestHelper has a non-empty cluster set for the quest.
        self.areas         = {}
        -- Available-quest (`!`) pins. Keyed by starter NPC/object spawn so
        -- multiple quests at the same giver collapse into one pin whose
        -- tooltip lists every available quest from that giver.
        -- availablePins[key] = { pin, tooltipId, questIds = {qid, ...} }
        self.availablePins = {}
        self.currentAreaId = nil

        -- Visibility gates persisted via MUI_DB.settings.questHelper. When
        -- false, creation methods short-circuit; lifecycle events still fire
        -- but produce nothing on the minimap.
        local qh = (MUI_DB.settings and MUI_DB.settings.questHelper) or {}
        self._pinsVisible  = qh.showMinimapObjectivePins  ~= false
        self._areasVisible = qh.showMinimapObjectiveAreas ~= false

        watcher:RegisterCallback("OnQuestAdded", function(questId, entry)
            self:_OnQuestAdded(questId, entry)
        end)
        watcher:RegisterCallback("OnQuestRemoved", function(questId)
            self:_OnQuestRemoved(questId)
        end)
        watcher:RegisterCallback("OnQuestChanged", function(questId, entry, diff)
            self:_OnQuestChanged(questId, entry, diff)
        end)

        self:RegisterEventHandler("ZONE_CHANGED_NEW_AREA", function()
            self:_MaybeRebuildForZone()
        end)
        self:RegisterEventHandler("ZONE_CHANGED", function()
            self:_MaybeRebuildForZone()
        end)
        self:RegisterEventHandler("PLAYER_ENTERING_WORLD", function()
            self:_MaybeRebuildForZone()
        end)

        -- Tracking / focus state: objective pins + area depend on the
        -- quest being tracked, and every pin/area's alpha depends on which
        -- quest (if any) is focused. Focus listener fires for ALL kinds
        -- (quest, flightmaster, etc.) — _OnFocusChanged just re-runs
        -- _ApplyFocusDimming, which uses MUI_QuestHelper:GetFocusedQuest
        -- (shim returns nil for non-quest focus), so non-quest focus
        -- correctly dims every quest pin uniformly.
        MUI_QuestHelper:RegisterTrackingListener(function(questId, tracked)
            self:_OnTrackingChanged(questId, tracked)
        end)
        MUI_FocusManager:RegisterChangeListener(function() self:_OnFocusChanged() end)

        -- Available-quest pin lifecycle: rebuild whenever the availability
        -- set changes (level-up, quest-accept, quest-turn-in). Zone change
        -- also rebuilds (through _MaybeRebuildForZone → _RebuildAll) so
        -- pins always reflect the current zone's starters. If the first
        -- recompute fires before our PLAYER_ENTERING_WORLD handler had a
        -- chance to run (OnEnable runs ON that event, so its handler
        -- registers AFTER the initial firing), lazily compute the zone
        -- here — _MaybeRebuildForZone is the same path the regular event
        -- handler uses and it will call _RebuildAvailablePins via
        -- _RebuildAll on success, so we skip the direct call in that case.
        MUI_QuestHelper.availability:RegisterChangeListener(function()
            if not self.currentAreaId then
                if self:_MaybeRebuildForZone() then return end
            end
            self:_RebuildAvailablePins()
        end)

        -- The minimap focused-target edge arrow is owned by MUI_FocusManager
        -- (it tracks whatever's focused, not just quests). Construction
        -- happens in MUI_FocusManager:OnEnable.
    end;

    -- ---- public API ------------------------------------------------------

    -- True if any ready-to-turn-in (yellow ?) pin is currently visible on
    -- the minimap. Used by MinimapBlipAtlasSwapper to fall back to blip-default
    -- when a turn-in marker is in range, so a QuestTurnIn icon never gets
    -- re-rendered through the herb/ore/treasure atlas. Objective pins
    -- (kill / loot / interact), grey ? in-progress reminders, and edge
    -- arrows don't trigger the fallback — they're common enough that
    -- gating the atlas on them would defeat the swap.
    HasVisibleTurnInPinInRange = function(self)
        for _, bucket in pairs(self.pins) do
            for _, entry in ipairs(bucket) do
                if entry.spec and entry.spec.iconType == "QuestTurnIn"
                        and not entry.isArrow
                        and entry.pin:IsShown()
                        and entry.pin:GetAlpha() > 0 then
                    return true
                end
            end
        end
        return false
    end;

    GetActivePinCount = function(self)
        local n = 0
        for _, bucket in pairs(self.pins) do n = n + #bucket end
        return n
    end;

    -- ---- watcher callbacks ----------------------------------------------

    _OnQuestAdded = function(self, questId, entry)
        self.specs[questId] = {
            objective = MUI_QuestObjectiveResolver:ResolveObjectives(questId),
            finisher  = MUI_QuestObjectiveResolver:ResolveFinishers(questId),
        }
        -- On login the watcher may emit OnQuestAdded before our own zone
        -- handler has initialised currentAreaId. Sync now; if the sync ran a
        -- full rebuild it already spawned pins for this quest, so don't
        -- double-spawn.
        if self:_MaybeRebuildForZone() then return end
        self:_SpawnPinsForQuest(questId, entry)
    end;

    _OnQuestRemoved = function(self, questId)
        self:_DestroyPinsForQuest(questId)
        self:_DestroyAreaForQuest(questId)
        self.specs[questId] = nil
    end;

    _OnQuestChanged = function(self, questId, entry, diff)
        if diff.becameComplete then
            -- Transition: destroy objective pins AND grey `?` finishers,
            -- then spawn yellow `?` finishers. Area overlay is no longer
            -- meaningful once the quest is ready to turn in.
            self:_DestroyPinsForQuest(questId)
            self:_DestroyAreaForQuest(questId)
            self:_SpawnFinisherPins(questId, "QuestTurnIn")
            return
        end
        if diff.completedObjectives and #diff.completedObjectives > 0 then
            -- Match pins against the CURRENT leaderboard (entry.objectives
            -- already reflects the just-flipped finished flags); destroy
            -- every objective pin whose target is now a finished leaderboard
            -- entry. Can't just key on diff.completedObjectives indices
            -- because resolver specs carry DB-category indices, not log-
            -- order indices — see MUI_QuestHelper.IsSpecFinished.
            self:_DestroyPinsForQuest(questId, function(e)
                return e.kind == "objective"
                   and MUI_QuestHelper:IsSpecFinished(e.spec, entry)
            end)
            -- Rebuild area without the finished objective's spawn specs;
            -- drops the overlay if the survivors fall below the threshold.
            self:_UpdateAreaForQuest(questId, entry)
        end
    end;

    -- ---- pin lifecycle ---------------------------------------------------

    _SpawnPinsForQuest = function(self, questId, entry)
        -- Clean slate for the area overlay; only the objective branch below
        -- recreates it. Finisher-only branches leave it destroyed.
        self:_DestroyAreaForQuest(questId)

        if entry and entry.isComplete then
            self:_SpawnFinisherPins(questId, "QuestTurnIn")
            return
        end
        -- Questie PopulateQuestLogInfo fallback: some "speak with X" /
        -- "deliver item" quests have no leaderboard objectives but do have a
        -- finisher, and the game doesn't flag them isComplete=1 on accept.
        -- Treat them as ready-to-turn-in so the pin shows immediately.
        local leaderboardEmpty = not entry or not entry.objectives or #entry.objectives == 0
        local specs = self.specs[questId]
        local resolvedObjectivesEmpty = not specs or not specs.objective or #specs.objective == 0
        if leaderboardEmpty and resolvedObjectivesEmpty and specs and specs.finisher and #specs.finisher > 0 then
            self:_SpawnFinisherPins(questId, "QuestTurnIn")
            return
        end
        self:_SpawnObjectivePins(questId, entry)
        -- Retail-style grey `?` at the finisher while the quest is in progress.
        self:_SpawnFinisherPins(questId, "QuestCompletable")
        self:_UpdateAreaForQuest(questId, entry)
    end;

    _SpawnObjectivePins = function(self, questId, entry)
        if not self._pinsVisible then return end
        -- Untracked quests: no objective pins on the minimap. Finisher
        -- pins (? turn-in / grey ?) still render so the player can find
        -- the quest giver.
        if not MUI_QuestHelper:IsTracked(questId) then return end
        local specList = self.specs[questId] and self.specs[questId].objective
        if specList then
            self:_SpawnFromSpecList(questId, entry, specList, false)
        end
    end;

    -- iconType is "QuestTurnIn" (yellow `?`, ready to turn in) or
    -- "QuestCompletable" (grey `?`, quest-giver reminder while in progress).
    -- Finisher pins are NOT gated by self._pinsVisible — that toggle only
    -- controls objective pins. The player always needs to be able to find
    -- the quest-giver regardless of whether tracking clutter is hidden.
    _SpawnFinisherPins = function(self, questId, iconType)
        local specList = self.specs[questId] and self.specs[questId].finisher
        if not specList or #specList == 0 then return end
        -- Resolver always emits QuestTurnIn; override per-call so the same
        -- spec list can produce grey or yellow `?` pins without re-resolving.
        local overridden = {}
        for _, s in ipairs(specList) do
            local c = {}
            for k, v in pairs(s) do c[k] = v end
            c.iconType = iconType
            overridden[#overridden + 1] = c
        end
        local entry = self.watcher:GetEntry(questId)
        self:_SpawnFromSpecList(questId, entry, overridden, true)
    end;

    -- Place in-zone specs onto the minimap as MinimapPins (one per cluster
    -- for objectives, one per spawn for finishers). Off-zone specs are
    -- ignored here — the generic MUI_FocusedTargetArrow (owned by
    -- MUI_FocusManager) handles "point toward whatever's focused" using
    -- the quest adapter's tier walk on its own. isFinisher disables the
    -- "skip finished objectives" filter
    -- for turn-in pins (finishers always render while the quest sits in the
    -- log complete).
    _SpawnFromSpecList = function(self, questId, entry, specList, isFinisher)
        local areaId = self.currentAreaId
        if not areaId then return end

        local bucket = self.pins[questId] or {}
        self.pins[questId] = bucket

        local function isFinished(spec)
            if isFinisher then return false end
            return MUI_QuestHelper:IsSpecFinished(spec, entry)
        end

        local inZoneSpecs = {}
        for _, spec in ipairs(specList) do
            if spec.uiMapId and not isFinished(spec) and spec.areaId == areaId then
                inZoneSpecs[#inZoneSpecs + 1] = spec
            end
        end

        -- Finishers are pinned one per spawn without clustering (typically
        -- <5 per quest, and the player wants every candidate turn-in spot
        -- visible). Objective pins cluster so 31 kobolds become 1 camp mark.
        local renderSpecs = isFinisher and inZoneSpecs or _clusterSpecs(inZoneSpecs, CLUSTER_YARDS)
        for _, spec in ipairs(renderSpecs) do
            bucket[#bucket + 1] = self:_CreatePinEntry(spec)
        end

        if #bucket == 0 then
            self.pins[questId] = nil
        else
            -- Apply current focus dimming to the pins we just added, so new
            -- pins respect the focus state on creation (not just on toggle).
            self:_ApplyFocusDimming(questId)
        end
    end;

    _CreatePinEntry = function(self, spec)
        local pinName = string.format("MUI_QuestPin_%d_%d_%d_%d",
                spec.questId, spec.objectiveIdx, spec.targetId, spec.spawnIdx)
        local pin = MinimapPin(pinName, 12)
        pin:SetIconType(spec.iconType)
        pin:SetWorldPosition(spec.uiMapId, spec.normX, spec.normY)
        -- EnableMouse(false) keeps the pin from capturing mouse focus —
        -- WoW auto-hides GameTooltip when the cursor enters a mouse-enabled
        -- frame without an OnEnter handler. Hover detection is purely
        -- geometric via MouseIsOver inside the tooltip coordinator.
        pin:EnableMouse(false)

        -- Register with the shared minimap tooltip coordinator. All pins
        -- for the same quest share a dedupKey so they collapse to one
        -- block; the focused-quest arrow registers the same key with a
        -- lower priority, so a pin hover wins over an arrow hover for
        -- the same quest.
        local tooltipId = "questpin:" .. pinName
        local questId   = spec.questId
        -- Turn-in pin (yellow `?`) shows only the quest title: by the time
        -- this pin is visible every objective is finished, and rendering
        -- the completed objective list ("Red Burlap Bandana 12/12") is
        -- just clutter. In-progress pins (objective & grey `?`) still show
        -- the full block so the player can read remaining progress.
        local tooltipMode = (spec.iconType == "QuestTurnIn") and "title" or "full"
        MUI_MinimapTooltip:Register(tooltipId, {
            isHovered = function()
                return MouseIsOver(Minimap)
                   and pin:IsShown()
                   and pin:GetAlpha() > 0.05
                   and pin:IsMouseOver()
            end,
            dedupKey = "quest:" .. questId,
            priority = 10,   -- above arrow (1); see MUI_FocusedTargetArrow
            build    = function()
                MUI_QuestHelper:FillQuestTooltip(questId, tooltipMode)
            end,
        })

        return {
            pin          = pin,
            objectiveIdx = spec.objectiveIdx,
            kind         = _isFinisherIcon(spec.iconType) and "finisher" or "objective",
            spec         = spec,
            tooltipId    = tooltipId,
        }
    end;

    -- Destroy pins for a quest. Without predicate: everything. With predicate:
    -- only entries where predicate(entry) is truthy; the rest stay.
    _DestroyPinsForQuest = function(self, questId, predicate)
        local bucket = self.pins[questId]
        if not bucket then return end
        local function _killEntry(e)
            if e.tooltipId then MUI_MinimapTooltip:Unregister(e.tooltipId) end
            e.pin:Destroy()
        end
        if not predicate then
            for _, e in ipairs(bucket) do _killEntry(e) end
            self.pins[questId] = nil
            return
        end
        local keep = {}
        for _, e in ipairs(bucket) do
            if predicate(e) then
                _killEntry(e)
            else
                keep[#keep + 1] = e
            end
        end
        self.pins[questId] = (#keep > 0) and keep or nil
    end;

    -- ---- area overlay ----------------------------------------------------

    _DestroyAreaForQuest = function(self, questId)
        local area = self.areas[questId]
        if area then
            MUI_MinimapTooltip:Unregister("questarea:" .. questId)
            area:Destroy()
            self.areas[questId] = nil
        end
    end;

    -- Build/rebuild the minimap area overlay for a quest from clusters
    -- already cached in MUI_QuestHelper. This is a pure consumer — every
    -- non-finished point, clustering, hull, and centroid is decided in
    -- QuestObjectiveCluster; the pin manager just takes the CCW hulls
    -- and hands them to the renderer. The quest clusters registry fires
    -- its own updates from OnQuestAdded / OnQuestChanged before the pin
    -- manager's same-event callbacks run, so by the time we query here
    -- the data is already current.
    _UpdateAreaForQuest = function(self, questId, entry)
        self:_DestroyAreaForQuest(questId)
        if not self._areasVisible then return end
        -- Untracked quests don't get an area overlay.
        if not MUI_QuestHelper:IsTracked(questId) then return end

        local cluster = MUI_QuestHelper:GetQuestClusters(questId)
        if not cluster then return end

        -- Prefer real cluster hulls when the quest has enough points to
        -- form one; otherwise fall back to per-point stray circles so
        -- low-count quests (1-2 objectives) still get an area outline.
        local hulls, strayCenters = {}, nil
        if cluster:HasClusters() then
            for _, c in ipairs(cluster:GetClusters()) do
                hulls[#hulls + 1] = c.hull
            end
        else
            strayCenters = {}
            for _, p in ipairs(cluster:GetPoints()) do
                hulls[#hulls + 1] = _strayCircleHull(p[1], p[2])
                strayCenters[#strayCenters + 1] = { p[1], p[2] }
            end
        end
        if #hulls == 0 then return end

        local area = MinimapQuestObjectiveArea()
        area:SetHulls(hulls, cluster:GetContinent())
        if strayCenters then
            -- Centre icons render only for the focused quest; visibility
            -- is toggled from _ApplyFocusDimming. The icon stays in sync
            -- with the circle because they share projection in Refresh.
            area:SetCenterIcons("ObjectiveGeneric", strayCenters)
        end
        self.areas[questId] = area

        -- Share the quest's dedup slot with its pins (and arrow) so
        -- hovering pin + area of the same quest shows one block.
        MUI_MinimapTooltip:Register("questarea:" .. questId, {
            isHovered = function() return area:IsMouseOver() end,
            dedupKey  = "quest:" .. questId,
            priority  = 10,   -- same as pins; either's full block works
            build     = function()
                MUI_QuestHelper:FillQuestTooltip(questId, "full")
            end,
        })

        -- Inherit the current focus state.
        self:_ApplyFocusDimming(questId)
    end;

    -- ---- visibility toggles ---------------------------------------------

    -- Only the objective layer is affected by this toggle. Finisher pins
    -- (? turn-in, grey ? in-progress) stay untouched so the player can
    -- always see where to pick up / turn in quests.
    SetPinsVisible = function(self, visible)
        if self._pinsVisible == visible then return end
        self._pinsVisible = visible and true or false
        if self._pinsVisible then
            -- Re-spawn objective pins for every in-progress quest; finishers
            -- were never destroyed when the toggle went off.
            for questId, entry in pairs(self.watcher:GetWatched()) do
                if entry and not entry.isComplete then
                    self:_SpawnObjectivePins(questId, entry)
                end
            end
        else
            -- Destroy only objective-kind entries (pins + arrows); keep
            -- finisher entries intact.
            for questId in pairs(self.pins) do
                self:_DestroyPinsForQuest(questId, function(e)
                    return e.kind == "objective"
                end)
            end
        end
    end;

    SetAreasVisible = function(self, visible)
        if self._areasVisible == visible then return end
        self._areasVisible = visible and true or false
        if self._areasVisible then
            for questId, entry in pairs(self.watcher:GetWatched()) do
                self:_UpdateAreaForQuest(questId, entry)
            end
        else
            for questId in pairs(self.areas) do
                self:_DestroyAreaForQuest(questId)
            end
        end
    end;

    -- ---- tracking / focus ----------------------------------------------

    -- Tracking toggled for a quest. Full destroy + respawn via
    -- _SpawnPinsForQuest — the IsTracked gate inside _SpawnObjectivePins /
    -- _UpdateAreaForQuest filters correctly for both directions:
    -- * tracked → untracked: re-spawn creates only finisher pins (objective
    --   pins and area skipped by the gate).
    -- * untracked → tracked: re-spawn creates everything fresh.
    _OnTrackingChanged = function(self, questId, tracked)
        self:_DestroyPinsForQuest(questId)
        self:_DestroyAreaForQuest(questId)
        local entry = self.watcher:GetEntry(questId)
        if entry then self:_SpawnPinsForQuest(questId, entry) end
    end;

    -- Focus changed (any kind). Every tracked quest's pins + area re-read
    -- their dim factor — _ApplyFocusDimming reads the focused quest via
    -- MUI_QuestHelper:GetFocusedQuest (returns nil if a non-quest is
    -- focused), so all quests dim uniformly on non-quest focus.
    -- Cheap: O(#quests-with-pins) per focus change.
    _OnFocusChanged = function(self)
        for questId in pairs(self.pins) do
            self:_ApplyFocusDimming(questId)
        end
        for questId in pairs(self.areas) do
            self:_ApplyFocusDimming(questId)
        end
    end;

    -- Compute the alpha multiplier for this quest based on the currently
    -- focused quest, then push it into every pin + the area. Rule:
    --   focused == questId    → this quest full (1.0).
    --   otherwise             → dimmed, including when nothing is focused
    --                           at all — focus is the only brightening
    --                           signal.
    -- Finisher pins (? turn-in, grey ? in-progress) stay at full brightness
    -- regardless of focus: they're navigational markers the player always
    -- needs to be able to spot. Only objective pins / arrows and the area
    -- overlay follow focus.
    _ApplyFocusDimming = function(self, questId)
        local focusedId = MUI_QuestHelper:GetFocusedQuest()
        local isFocused = (focusedId == questId)
        local factorPins = isFocused and 1 or 0.5
        local factorArea = isFocused and 1 or 0.4
        local bucket = self.pins[questId]
        if bucket then
            for _, e in ipairs(bucket) do
                if e.pin.SetDimFactor then
                    local f = (e.kind == "finisher") and 1 or factorPins
                    e.pin:SetDimFactor(f)
                end
            end
        end
        local area = self.areas[questId]
        if area then
            if area.SetDimFactor then area:SetDimFactor(factorArea) end
            -- Centre icons on stray-mode areas render only for the focused
            -- quest (no-op on cluster-mode areas — _centers is nil there).
            if area.SetCentersVisible then area:SetCentersVisible(isFocused) end
        end
    end;

    -- ---- zone handling ---------------------------------------------------

    -- Returns true if a rebuild actually ran (area changed).
    _MaybeRebuildForZone = function(self)
        local areaId = self:_CurrentAreaId()
        if areaId == self.currentAreaId then return false end
        self.currentAreaId = areaId
        self:_RebuildAll()
        return true
    end;

    _CurrentAreaId = function(self)
        local uiMapId = C_Map.GetBestMapForUnit("player")
        if not uiMapId then return nil end
        -- Walk up the map hierarchy: subzone maps (e.g. Lion's Pride Inn)
        -- aren't in Questie's area mapping, but their parent zone (Elwynn)
        -- is. Cap the climb at 8 to avoid any pathological cycles.
        for _ = 1, 8 do
            local areaId = MUI_ZoneDB:GetAreaForUiMap(uiMapId)
            if areaId then return areaId end
            local info = C_Map.GetMapInfo(uiMapId)
            if not info or not info.parentMapID or info.parentMapID == 0 then
                return nil
            end
            uiMapId = info.parentMapID
        end
        return nil
    end;

    _RebuildAll = function(self)
        for questId in pairs(self.pins) do
            self:_DestroyPinsForQuest(questId)
        end
        for questId, entry in pairs(self.watcher:GetWatched()) do
            -- Spec cache may be empty if the quest predates the manager
            -- (e.g. /reload while quests are active). Re-resolve.
            if not self.specs[questId] then
                self.specs[questId] = {
                    objective = MUI_QuestObjectiveResolver:ResolveObjectives(questId),
                    finisher  = MUI_QuestObjectiveResolver:ResolveFinishers(questId),
                }
            end
            self:_SpawnPinsForQuest(questId, entry)
        end
        self:_RebuildAvailablePins()
    end;

    -- ---- available-quest (`!`) pin lifecycle ----------------------------

    -- Full rebuild from scratch. Cheap enough: Classic zones hold at most
    -- ~100 starter spawns and availability changes are infrequent (level-
    -- up, accept, turn-in). Collapses spawns at identical coords into a
    -- single pin whose tooltip lists every quest available at that giver.
    _RebuildAvailablePins = function(self)
        self:_DestroyAllAvailablePins()
        local areaId = self.currentAreaId
        if not areaId then return end
        if not MUI_QuestHelper.availability then return end
        local starters = MUI_QuestHelper.availability:GetStartersInArea(areaId)
        if not starters or #starters == 0 then return end

        -- Group by (kind, targetId, roughly-rounded coord) so multiple
        -- quests from the same NPC/object spawn produce one pin.
        --
        -- Icon priority (matches Questie's QuestieLib.GetQuestIcon for
        -- the aggregated case):
        --   yellow `QuestAvailable`  — any normal quest in the group
        --   blue  `QuestRepeatable`  — all non-trivial quests are repeatable
        --                              (or mix of repeatable + trivial;
        --                              repeatable dominates trivial)
        --   grey  `QuestLowLevel`    — every quest in the group is trivial
        -- Per-surface trivial filter. Availability always returns
        -- trivials; the minimap's own "Low-Level Quests" toggle (under
        -- the tracker menu) decides whether to keep them.
        local s_qh = MUI_DB and MUI_DB.settings and MUI_DB.settings.questHelper
        local includeTrivial = s_qh and s_qh.showLowLevelAvailableQuests or false

        local groups = {}
        for _, s in ipairs(starters) do
            if not (s.isTrivial and not includeTrivial) then
            local key = s.kind .. ":" .. s.targetId
                        .. "@" .. math.floor(s.normX * 1000)
                        .. "_" .. math.floor(s.normY * 1000)
            local g = groups[key]
            if not g then
                g = { spec = s, questIds = {},
                      hasNormal = false, hasRepeatable = false,
                      allTrivial = true }
                groups[key] = g
            end
            g.questIds[#g.questIds + 1] = s.questId
            if not s.isTrivial then g.allTrivial = false end
            if s.isRepeatable then
                g.hasRepeatable = true
            elseif not s.isTrivial then
                g.hasNormal = true
            end
            end -- per-surface trivial filter
        end
        for key, g in pairs(groups) do
            local icon
            if g.hasNormal then
                icon = "QuestAvailable"
            elseif g.hasRepeatable then
                icon = "QuestRepeatable"
            else
                icon = "QuestLowLevel"
            end
            self:_SpawnAvailablePin(key, g.spec, g.questIds, icon)
        end
    end;

    _SpawnAvailablePin = function(self, key, spec, questIds, iconType)
        local sanitized = key:gsub("[^%w]", "_")
        local pinName = "MUI_QuestAvailablePin_" .. sanitized
        local pin = MinimapPin(pinName, 12)
        pin:SetIconType(iconType or "QuestAvailable")
        pin:SetWorldPosition(spec.uiMapId, spec.normX, spec.normY)
        pin:EnableMouse(false)

        -- Resolve the questgiver's own name once; the tooltip shows just
        -- this. Quest names / descriptions come from the giver's in-game
        -- gossip when the player actually interacts.
        local giverName
        if spec.kind == "npc" then
            local npc = MUI_NpcDB:Get(spec.targetId)
            giverName = npc and npc.name
        elseif spec.kind == "object" then
            local obj = MUI_ObjectDB:Get(spec.targetId)
            giverName = obj and obj.name
        end

        local tooltipId = "questavail:" .. key
        MUI_MinimapTooltip:Register(tooltipId, {
            isHovered = function()
                return MouseIsOver(Minimap)
                   and pin:IsShown()
                   and pin:GetAlpha() > 0.05
                   and pin:IsMouseOver()
            end,
            dedupKey = tooltipId,
            priority = 10,
            build = function()
                if giverName and not MUI_Tooltip:HasLine(giverName) then
                    MUI_Tooltip:AddTitle(giverName)
                end
            end,
        })

        self.availablePins[key] = {
            pin       = pin,
            tooltipId = tooltipId,
            questIds  = questIds,
        }
    end;

    _DestroyAllAvailablePins = function(self)
        for _, entry in pairs(self.availablePins) do
            if entry.tooltipId then
                MUI_MinimapTooltip:Unregister(entry.tooltipId)
            end
            entry.pin:Destroy()
        end
        self.availablePins = {}
    end;
}
