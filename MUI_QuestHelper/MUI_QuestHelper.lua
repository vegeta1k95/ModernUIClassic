-- MUI_QuestHelper: live quest-log-driven helper coordinating every layer
-- that needs quest-state info — currently the minimap (pins, edge arrows,
-- area overlays); world-map pins / tracker panels plug in later and will
-- get their own sibling managers alongside .minimapPinManager.
--
-- Public API naming is qualified by the layer it affects (e.g.
-- HasVisibleMinimapTurnInPinInRange, SetMinimapObjectivePinsVisible) so
-- future world-map equivalents can coexist without ambiguity.

-- Resolver targetKind → quest-log leaderboard type. Used by IsSpecFinished
-- to restrict name matches to the correct leaderboard category (prevents an
-- NPC spec from matching an item leaderboard that happens to share its name).

-- Inline texture escapes for tooltip objective bullets.
--   _CHECK_ICON  — green TrackerCheck atlas (questtracker.tga, 1024×512),
--                  same region the quest tracker uses for completed lines.
--   _BULLET_ICON — Blizzard's Indicator-Yellow single-dot, dimmed to a
--                  dark/desaturated yellow via the inline-texture vertex
--                  color params (r:g:b are 0-255).
local _CHECK_ICON = ("|T%s:10:10:0:0:1024:512:871:909:59:97|t")
    :format(MUI.TEX_SKIN .. "questtracker\\questtracker")
local _BULLET_ICON = "|TInterface\\COMMON\\Indicator-Yellow:10:10:0:0:16:16:0:16:0:16:100:95:85|t"

local _LEADER_TYPE = {
    npc             = "monster",
    object          = "object",
    ["item-npc"]    = "item",
    ["item-object"] = "item",
    trigger         = "event",
}


object "QuestHelper" : extends "Module" {

    __init = function(self)
        Module.__init(self, "QuestHelper")
    end;

    OnEnable = function(self)
        self.watcher  = QuestLogWatcher()
        self.clusters = {}   -- [questId] = QuestObjectiveCluster

        -- Cluster registry is wired BEFORE the pin manager so its
        -- OnQuestAdded / OnQuestChanged callbacks run first; by the time
        -- the pin manager builds its area overlay the cluster data is
        -- already in GetQuestClusters().
        self:_WireClusterUpdates()
        self:_WireAutoFocus()
        self:_WireFocusTrackingSync()

        self.availability      = QuestAvailability()
        -- Trivial filtering moved to the consumers (minimap pin manager
        -- + world-map static pin manager). Availability always carries
        -- the full set with the per-quest isTrivial flag set.
        self.availability:SetWatcher(self.watcher)

        self.minimapPinManager = MinimapQuestPinManager(self.watcher)
        self.tracker           = QuestTracker(self.watcher)
        self.objectiveTooltip  = QuestObjectiveTooltip()
        self.objectiveTooltip:SetWatcher(self.watcher)
        self.mapQuestAreaMgr   = MapQuestAreaManager(self.watcher)

        -- Drop per-quest tracking state when the quest leaves the log, so
        -- a future accept of the same questId starts fresh.
        self.watcher:RegisterCallback("OnQuestRemoved", function(questId)
            self:_CleanupQuestState(questId)
        end)

    end;

    -- ---- cluster registry (shared geographic partitioning) -----------

    _WireClusterUpdates = function(self)
        self.watcher:RegisterCallback("OnQuestAdded", function(questId, entry)
            self:_UpdateQuestClusters(questId, entry)
        end)
        self.watcher:RegisterCallback("OnQuestChanged", function(questId, entry, diff)
            -- Cluster membership only shifts when the set of non-finished
            -- specs changes. Mere objective progress (counter updates) doesn't
            -- warrant a recluster; completions and full-quest completion do.
            -- `becameComplete` is its own trigger because Classic's "event"
            -- leaderboard type (heal-on-unit etc.) never sets finished=true
            -- even when the whole quest is isComplete — so completedObjectives
            -- can be empty while the quest is done.
            if diff and ((diff.completedObjectives
                    and #diff.completedObjectives > 0)
                    or diff.becameComplete) then
                self:_UpdateQuestClusters(questId, entry)
            end
        end)
        self.watcher:RegisterCallback("OnQuestRemoved", function(questId)
            if self.clusters[questId] then
                self.clusters[questId] = nil
                self:_FireClustersChanged(questId)
            end
        end)
    end;

    -- Build the QuestObjectiveCluster instance for a quest, using the
    -- precomputed cluster data shipped in MUI_QuestClustersDB.
    -- Filtering by completed targets happens inside SetData via
    -- locale-safe position-within-type matching against entry.objectives.
    --
    -- Dungeon-entrance rewrites that used to live in a runtime _specCoord
    -- helper are now applied in the offline exporter
    -- (tools/questdb_export/clusters.py:DUNGEON_ENTRANCES), so the
    -- precomputed coords already point at outer-world entrances.
    _UpdateQuestClusters = function(self, questId, entry)
        local data = MUI_QuestClustersDB:Get(questId)
        local cluster = QuestObjectiveCluster()
        cluster:SetData(data, entry)
        if cluster:IsEmpty() then
            self.clusters[questId] = nil
        else
            self.clusters[questId] = cluster
        end
        self:_FireClustersChanged(questId)
    end;

    -- Returns true when the given objective spec corresponds to a quest-log
    -- leaderboard whose `finished` flag is set. Matching is by leaderboard
    -- TYPE + TARGET NAME rather than by index, because the resolver tags
    -- specs with their DB category (1=creature, 2=object, 3=item, 5=killCredit)
    -- while the quest log numbers leaderboards 1..N sequentially — the two
    -- numberings diverge for any multi-objective quest (e.g. "slay 15 X and
    -- 15 Y" stores both as category 1 but surfaces them as leaderboards 1 & 2).
    -- Name-based matching also sidesteps reputation / spell objectives (which
    -- have no geographic spec but still occupy a leaderboard slot and would
    -- shift the index mapping).
    IsSpecFinished = function(self, spec, entry)
        if not entry then return false end
        -- isComplete short-circuit: when the quest itself is flagged complete
        -- every objective is trivially done — including Classic's "event"
        -- leaderboards whose per-line `finished` flag stays false due to a
        -- game-API bug. Without this, heal-on-unit / scout-location quests
        -- keep their specs in the cluster forever and the nav arrow never
        -- swaps to the turn-in.
        if entry.isComplete then return true end
        if not entry.objectives then return false end
        local name = spec.targetName or ""
        -- Item specs carry "ItemName <SourceName>"; the quest log shows only
        -- "ItemName: X/Y", so strip the source suffix before prefix-matching.
        local anglePos = name:find(" <", 1, true)
        if anglePos then name = name:sub(1, anglePos - 1) end
        if name == "" then return false end
        local wantType = _LEADER_TYPE[spec.targetKind]
        local nameLen  = #name
        for _, o in ipairs(entry.objectives) do
            if o and o.finished
               and (not wantType or o.type == wantType)
               and o.text and o.text:sub(1, nameLen) == name then
                return true
            end
        end
        return false
    end;

    -- ---- auto-focus --------------------------------------------------
    -- Wired BEFORE the pin manager is constructed so the focus change
    -- propagates before _SpawnPinsForQuest runs — pins are then born
    -- with the correct dim factor in one pass. Quests accepted while
    -- something is already focused leave that focus alone.

    _WireAutoFocus = function(self)
        self.watcher:RegisterCallback("OnQuestAdded", function(questId, _, isNew)
            -- Only auto-focus on a real QUEST_ACCEPTED (isNew=true). A
            -- /reload re-emits OnQuestAdded for every quest in the log
            -- with isNew=false — picking the first one up there would
            -- stomp a deliberate "no focus" state the player set before
            -- reloading.
            if not isNew then return end

            local curKind, curKey = MUI_FocusManager:GetFocus()

            -- Nothing focused: auto-focus the new quest. "First-accepted
            -- wins" inside quest space falls out of the same nil check.
            if not curKind then
                self:SetFocusedQuest(questId)
                return
            end

            -- Focused on the giver this quest just came from: transition
            -- the focus to the accepted quest. Without this the giver
            -- pin's disappearance (it has no more available quests)
            -- would clear focus via the static manager's pin-presence
            -- check, leaving the player with no focus at all.
            if curKind == "questgiver" and curKey then
                local giverKind, idStr = curKey:match("^(%a+):(%d+)$")
                local giverId = tonumber(idStr)
                local q = MUI_QuestDB and MUI_QuestDB:Get(questId)
                if giverId and q and q.startedBy then
                    local idx = (giverKind == "npc") and 1 or 2
                    local starters = q.startedBy[idx]
                    if starters then
                        for _, id in ipairs(starters) do
                            if id == giverId then
                                self:SetFocusedQuest(questId)
                                return
                            end
                        end
                    end
                end
            end

            -- Other focus kinds (flight master, etc.) the player set
            -- deliberately — accepting a quest doesn't stomp those.
        end)
    end;

    -- Listen for focus changes coming from MUI_FocusManager and apply the
    -- "focusing implies tracked" side effect for quest-kind focus. Lives
    -- here (not in MUI_FocusManager) because tracking is quest-specific
    -- — non-quest kinds don't have a tracked/untracked distinction.
    _WireFocusTrackingSync = function(self)
        MUI_FocusManager:RegisterChangeListener(function(prevKind, prevKey, newKind, newKey)
            if newKind ~= "quest" then return end
            local qh = MUI_DB.settings.questHelper
            if qh.untrackedQuests and qh.untrackedQuests[newKey] then
                qh.untrackedQuests[newKey] = nil
                self:_FireTrackingChanged(newKey, true)
            end
        end)
    end;

    -- Public: returns the QuestObjectiveCluster for a quest, or nil if
    -- the quest has no clusterable objectives (complete, all finished,
    -- below minimum, no uiMapId resolution, cross-continent-only, etc.).
    GetQuestClusters = function(self, questId)
        return self.clusters[questId]
    end;

    RegisterClustersChangedListener = function(self, fn)
        self._clusterListeners = self._clusterListeners or {}
        table.insert(self._clusterListeners, fn)
    end;

    _FireClustersChanged = function(self, questId)
        local lst = self._clusterListeners
        if not lst then return end
        for _, fn in ipairs(lst) do
            local ok, err = pcall(fn, questId)
            if not ok then
                MUI.Print(
                    "|cffff4040MUI_QuestHelper|r cluster listener error: "
                    .. tostring(err))
            end
        end
    end;

    -- ---- custom tracking state (3 states: tracked / not tracked / focused)
    --
    -- Default is tracked; untrackedQuests[questId] = true marks opt-out.
    -- Focus is delegated to MUI_FocusManager (kind="quest"), which holds
    -- focus for every kind — quest, flight master, future. Focusing a
    -- quest implies tracked (untrack flag cleared); un-tracking the
    -- focused quest clears focus.

    IsTracked = function(self, questId)
        local qh = MUI_DB.settings.questHelper
        return not (qh.untrackedQuests and qh.untrackedQuests[questId])
    end;

    SetTracked = function(self, questId, tracked)
        local qh = MUI_DB.settings.questHelper
        qh.untrackedQuests = qh.untrackedQuests or {}
        local wasTracked = not qh.untrackedQuests[questId]
        if tracked then
            qh.untrackedQuests[questId] = nil
        else
            qh.untrackedQuests[questId] = true
            -- Untracking the focused quest clears focus. Other kinds
            -- aren't touched.
            if MUI_FocusManager:IsFocused("quest", questId) then
                MUI_FocusManager:SetFocus(nil)
            end
        end
        if wasTracked ~= (tracked and true or false) then
            self:_FireTrackingChanged(questId, tracked and true or false)
        end
    end;

    -- Quest-side conveniences over MUI_FocusManager. IsFocused / GetFocusedQuest
    -- return nil/false when a non-quest is focused — that's the right semantic
    -- for quest-only consumers (e.g. _ApplyFocusDimming dims everything when
    -- no quest is focused).

    IsFocused = function(self, questId)
        return MUI_FocusManager:IsFocused("quest", questId)
    end;

    GetFocusedQuest = function(self)
        local kind, key = MUI_FocusManager:GetFocus()
        return (kind == "quest") and key or nil
    end;

    SetFocusedQuest = function(self, questId)
        MUI_FocusManager:SetFocus(questId and "quest" or nil, questId)
    end;

    -- Shared tooltip-content helper. Used by every minimap-layer widget
    -- that wants to contribute quest info to MUI_MinimapTooltip. `mode`
    -- = "title" emits only the quest title (focused-quest arrow hover);
    -- any other value (or nil) renders title + objective lines.
    --
    -- Dedup every emitted line against the tooltip's existing contents so
    -- cursor-jitter re-augmentation (over stacked pins, or over a pin
    -- while WoW's native blip tooltip is open) doesn't stack duplicates
    -- of the title or of any individual objective. Scoped to this helper
    -- — global AddTitle/AddLine stay dumb so callers can still add blank
    -- separators or intentional repeated lines.
    -- objectiveFilter (optional): { [idx] = true, ... } — when present,
    -- only entry.objectives at those indices are emitted. nil = emit all.
    FillQuestTooltip = function(self, questId, mode, objectiveFilter, monoSize)
        local entry = self.watcher and self.watcher:GetEntry(questId)
        if not entry then return end
        local title = entry.title or ("quest " .. questId)
        if not MUI_Tooltip:HasLine(title) then
            if monoSize then
                MUI_Tooltip:AddLine(title, 1, 0.82, 0)
            else
                MUI_Tooltip:AddTitle(title)
            end
        end
        if mode == "title" then return end
        if not entry.objectives then return end
        for idx, o in ipairs(entry.objectives) do
            if (not objectiveFilter or objectiveFilter[idx])
                and o.text and o.text ~= "" then
                local line = (o.finished and _CHECK_ICON or _BULLET_ICON) .. " " .. o.text
                if not MUI_Tooltip:HasLine(line) then
                    local c = o.finished and 0.5 or 1
                    MUI_Tooltip:AddLine(line, c, c, c)
                end
            end
        end
    end;

    RegisterTrackingListener = function(self, fn)
        self._trackingListeners = self._trackingListeners or {}
        table.insert(self._trackingListeners, fn)
    end;

    -- Cursor-anchored quest tooltip used by both the world-map POI button
    -- and the world-map objective hull on hover. Title + leaderboard
    -- objective bullets (green when finished, white when in-progress);
    -- falls back to the DB objectivesText for quests with no leaderboard
    -- (e.g. talk-to-NPC quests). Anchor frame is whatever owns the hover
    -- — passed through so MUI_Tooltip can dismiss correctly when the
    -- frame hides mid-hover.
    ShowMapQuestTooltip = function(self, anchorFrame, questId)
        local entry = self.watcher:GetEntry(questId)
        if not entry then return end
        local title = entry.title or ("quest " .. questId)
        MUI_Tooltip:ShowFor(anchorFrame, "ANCHOR_CURSOR", function(tip)
            tip:SetMinimumWidth(100)
            tip:AddTitle(title, true)
            local emittedAny = false
            if entry.objectives then
                for _, o in ipairs(entry.objectives) do
                    if o.text and o.text ~= "" then
                        emittedAny = true
                        if o.finished then
                            tip:AddLine("-" .. o.text, 0.4, 0.85, 0.4, true)
                        else
                            tip:AddLine("-" .. o.text, 1, 1, 1, true)
                        end
                    end
                end
            end
            if not emittedAny then
                local q = MUI_QuestDB and MUI_QuestDB:Get(questId)
                local lines = q and q.objectivesText
                if lines and #lines > 0 then
                    local text = type(lines) == "table"
                            and table.concat(lines, "\n")
                            or tostring(lines)
                    if text ~= "" then
                        tip:AddLine(text, 1, 1, 1, true)
                    end
                end
            end
        end)
    end;

    -- ---- hover signal -----------------------------------------------------
    --
    -- Any widget that displays a quest (tracker entry, world-map quest log
    -- row, world-map POI button, …) can mark its quest as "hovered" by
    -- calling PushQuestHover on enter and PopQuestHover on leave. The
    -- minimap area overlay listens to the change events and shows the
    -- objective hull when its quest is focused OR hovered, hiding it
    -- otherwise. Reference-counted so multiple overlapping hover sources
    -- (e.g. POI button inside a tracker block) compose correctly: the
    -- listener fires only on transitions across the 0/1 boundary.

    PushQuestHover = function(self, questId)
        if not questId then return end
        self._hoverCounts = self._hoverCounts or {}
        local prev = self._hoverCounts[questId] or 0
        self._hoverCounts[questId] = prev + 1
        if prev == 0 then self:_FireHoverChanged(questId, true) end
    end;

    PopQuestHover = function(self, questId)
        if not questId then return end
        local counts = self._hoverCounts
        if not counts then return end
        local prev = counts[questId] or 0
        if prev <= 0 then return end
        if prev == 1 then
            counts[questId] = nil
            self:_FireHoverChanged(questId, false)
        else
            counts[questId] = prev - 1
        end
    end;

    IsQuestHovered = function(self, questId)
        return (self._hoverCounts and self._hoverCounts[questId] or 0) > 0
    end;

    RegisterQuestHoverListener = function(self, fn)
        self._hoverListeners = self._hoverListeners or {}
        table.insert(self._hoverListeners, fn)
    end;

    _FireHoverChanged = function(self, questId, isHovered)
        local lst = self._hoverListeners
        if not lst then return end
        for _, fn in ipairs(lst) do
            local ok, err = pcall(fn, questId, isHovered)
            if not ok then
                MUI.Print(
                    "|cffff4040MUI_QuestHelper|r hover listener error: "
                    .. tostring(err))
            end
        end
    end;

    _CleanupQuestState = function(self, questId)
        local qh = MUI_DB.settings.questHelper
        if qh.untrackedQuests then qh.untrackedQuests[questId] = nil end
        if MUI_FocusManager:IsFocused("quest", questId) then
            MUI_FocusManager:SetFocus(nil)
        end
    end;

    _FireTrackingChanged = function(self, questId, tracked)
        local lst = self._trackingListeners
        if not lst then return end
        for _, fn in ipairs(lst) do
            local ok, err = pcall(fn, questId, tracked)
            if not ok then
                MUI.Print(
                    "|cffff4040MUI_QuestHelper|r tracking listener error: "
                    .. tostring(err))
            end
        end
    end;

    -- ---- public API ----------------------------------------------------

    HasVisibleMinimapTurnInPinInRange = function(self)
        return self.minimapPinManager and self.minimapPinManager:HasVisibleTurnInPinInRange() or false
    end;

    GetActiveMinimapPinCount = function(self)
        return self.minimapPinManager and self.minimapPinManager:GetActivePinCount() or 0
    end;

    -- Minimap tracker menu toggles. Persist the flag into MUI_DB then ask
    -- the minimap pin manager to tear down / rebuild the affected layer.
    SetMinimapObjectivePinsVisible = function(self, visible)
        MUI_DB.settings.questHelper.showMinimapObjectivePins = visible and true or false
        self.minimapPinManager:SetPinsVisible(visible)
    end;

    SetMinimapObjectiveAreasVisible = function(self, visible)
        MUI_DB.settings.questHelper.showMinimapObjectiveAreas = visible and true or false
        self.minimapPinManager:SetAreasVisible(visible)
    end;

    -- Toggle whether trivial ("grey") available quests are shown on the
    -- minimap. Availability data layer is untouched (it always returns
    -- trivials); we just notify listeners so the minimap pin manager
    -- rebuilds and applies the new filter at its layer.
    SetShowLowLevelAvailableQuests = function(self, visible)
        MUI_DB.settings.questHelper.showLowLevelAvailableQuests = visible and true or false
        if self.availability then
            self.availability:NotifyListeners()
        end
    end;

    -- Same toggle, world map only. Independent persistent setting so the
    -- player can keep low-level quests off the minimap but visible on
    -- the map (or vice versa).
    SetShowLowLevelAvailableQuestsOnMap = function(self, visible)
        MUI_DB.settings.questHelper.showLowLevelAvailableQuestsOnMap =
            visible and true or false
        if self.availability then
            self.availability:NotifyListeners()
        end
    end;
}