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
--   _FAIL_ICON   — red ObjectiveFail "x" from the same atlas, drawn a bit
--                  smaller than the check as the tracker does.
local _FAIL_ICON = ("|T%s:8:8:1:0:1024:512:937:975:1:39|t")
    :format(MUI.TEX_SKIN .. "questtracker\\questtracker")

local _LEADER_TYPE = {
    npc             = "monster",
    object          = "object",
    ["item-npc"]    = "item",
    ["item-object"] = "item",
    trigger         = "event",
}

-- Quest-level difficulty colours for tooltip titles (same thresholds as
-- the quest tracker and the map quest log).
local _DIFF_RED    = { 1.00, 0.10, 0.10 }
local _DIFF_ORANGE = { 1.00, 0.50, 0.25 }
local _DIFF_YELLOW = { 1.00, 1.00, 0.00 }
local _DIFF_GREEN  = { 0.25, 0.75, 0.25 }
local _DIFF_GRAY   = { 0.62, 0.62, 0.62 }

local function _difficultyColor(level)
    local diff = level - UnitLevel("player")
    if     diff >=  5                                   then return _DIFF_RED
    elseif diff >=  3                                   then return _DIFF_ORANGE
    elseif diff >= -2                                   then return _DIFF_YELLOW
    elseif -diff <= (GetQuestGreenRange("player") or 5) then return _DIFF_GREEN
    else                                                     return _DIFF_GRAY
    end
end


object "QuestHelper" : extends "Module" {

    __init = function(self)
        Module.__init(self, "QuestHelper")
        self._questTags  = {}   -- [questId] = tag id | false, see GetQuestTag
        self._tagAsked   = {}
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
            self._sourceItemState[questId] = nil
            if self.clusters[questId] then
                self.clusters[questId] = nil
                self:_FireClustersChanged(questId)
            end
        end)

        -- Required source items (pendant halves, keys, …) have no
        -- leaderboard line, so the quest log never signals when one is
        -- looted or destroyed: watch the bags and recluster / re-pin the
        -- quests whose source-item state changed.
        self._sourceItemState = {}
        self._bagDriver = Frame("Frame", nil, "MUI_QuestHelperBagDriver")
        self._bagDriver:RegisterEventHandler("BAG_UPDATE_DELAYED", function()
            for questId, entry in pairs(self.watcher:GetWatched()) do
                if self:_SourceItemStateKey(questId) ~= self._sourceItemState[questId] then
                    self:_UpdateQuestClusters(questId, entry)
                    self.minimapPinManager:RefreshQuest(questId)
                end
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
        self._sourceItemState[questId] = self:_SourceItemStateKey(questId)
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
        -- Required source item pins: done once the item is in the bags.
        if spec.sourceItemId then
            return C_Item.GetItemCount(spec.sourceItemId) > 0
        end
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
    -- titleIcon (optional): inline texture put before the title (see
    -- GetQuestIconEscape), e.g. the "?" on the quest's turn-in NPC.
    FillQuestTooltip = function(self, questId, mode, objectiveFilter, titleIcon)
        local entry = self.watcher and self.watcher:GetEntry(questId)
        if not entry then return end
        local title, r, g, b = self:FormatQuestTitle(entry, questId)
        if titleIcon then title = titleIcon .. " " .. title end
        if not MUI_Tooltip:HasLine(title) then
            MUI_Tooltip:AddLine(title, r, g, b, nil, 13)
        end
        if mode == "title" then return end
        for idx, o in ipairs(entry.objectives or {}) do
            if (not objectiveFilter or objectiveFilter[idx])
                and o.text and o.text ~= "" then
                local icon = (o.finished and _CHECK_ICON) or (o.failed and _FAIL_ICON) or _BULLET_ICON
                local line = icon .. " " .. o.text
                if not MUI_Tooltip:HasLine(line) then
                    if o.failed then
                        MUI_Tooltip:AddLine(line, 0.85, 0.3, 0.3)
                    else
                        local c = o.finished and 0.5 or 1
                        MUI_Tooltip:AddLine(line, c, c, c)
                    end
                end
            end
        end
        -- Required source items have no leaderboard line, so a target
        -- filter can never name them: only the unfiltered block lists them.
        if objectiveFilter then return end
        for _, s in ipairs(self:GetSourceItemObjectives(questId)) do
            local line = (s.finished and _CHECK_ICON or _BULLET_ICON) .. " "
                      .. s.name .. ": " .. (s.finished and "1/1" or "0/1")
            if not MUI_Tooltip:HasLine(line) then
                local c = s.finished and 0.5 or 1
                MUI_Tooltip:AddLine(line, c, c, c)
            end
        end
    end;

    -- Inline texture of a quest pin icon for tooltip lines, from the pin
    -- registries (so it matches the map / minimap). kind: "available" (the
    -- "!"), "turnIn" (yellow "?"), "inProgress" (grey "?"); repeatable and
    -- PvP quests get their variants.
    -- Inline "x" for a failed objective line in a tooltip.
    GetFailIconEscape = function(self)
        return _FAIL_ICON
    end;

    GetQuestIconEscape = function(self, kind, questId, size)
        local spec
        if kind == "available" then
            -- Same precedence as the pins: repeatable, then low-level (grey), then PvP.
            local avail = self.availability
            spec = (avail and avail:IsRepeatable(questId)) and MUI_MapPinIcons["QuestRepeatable"]
                or (avail and avail:IsTrivial(questId)) and MUI_MinimapPinIcons["QuestLowLevel"]
                or self:IsPvPQuest(questId) and MUI_MapPinIcons["QuestPvP"]
                or MUI_MapPinIcons["Quest"]
        elseif kind == "turnIn" then
            spec = self:IsPvPQuest(questId) and MUI_MinimapPinIcons["QuestTurnInPvP"]
                or MUI_MinimapPinIcons["QuestTurnIn"]
        else
            spec = MUI_MinimapPinIcons["QuestCompletable"]
        end
        size = size or 14
        local x, y, w, h = spec[4], spec[5], spec[6], spec[7]
        local escape = string.format("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d",
            spec[1], size, size, spec[2], spec[3], x, x + w, y, y + h)
        local tint = spec.tint
        if tint then
            escape = escape .. string.format(":%d:%d:%d",
                math.floor(tint[1] * 255), math.floor(tint[2] * 255), math.floor(tint[3] * 255))
        end
        return escape .. "|t"
    end;

    -- One "!" line for a quest available from a hovered NPC / object, in the
    -- same title format as the quest-log quests above it.
    AddAvailableQuestLine = function(self, questId)
        local q = MUI_QuestDB:Get(questId)
        if not q then return end
        local title, r, g, b = self:FormatQuestTitle({ title = q.name, level = q.questLevel }, questId)
        local line = self:GetQuestIconEscape("available", questId) .. " " .. title
        if not MUI_Tooltip:HasLine(line) then
            MUI_Tooltip:AddLine(line, r, g, b, nil, 13)
        end
    end;

    -- Drop sources of an item for the player's faction. The exporter bakes
    -- Alliance sources into npcDrops / objectDrops and adds npcDropsHorde /
    -- objectDropsHorde only where the Horde sources differ.
    GetItemDrops = function(self, item)
        if UnitFactionGroup("player") == "Horde" then
            return item.npcDropsHorde or item.npcDrops,
                   item.objectDropsHorde or item.objectDrops
        end
        return item.npcDrops, item.objectDrops
    end;

    -- Questie's NPC faction rule: nil / "AH" friendly to both factions,
    -- "A" / "H" to one (vendors of the other faction don't sell to you).
    IsFriendlyToPlayer = function(self, friendlyToFaction)
        if not friendlyToFaction or friendlyToFaction == "AH" then return true end
        local faction = UnitFactionGroup("player")
        return (friendlyToFaction == "A" and faction == "Alliance")
            or (friendlyToFaction == "H" and faction == "Horde")
    end;

    -- Vendors selling an item that the player can buy from.
    GetItemVendors = function(self, item)
        local out = {}
        for _, npcId in ipairs(item.vendors or {}) do
            local npc = MUI_NpcDB:Get(npcId)
            if npc and self:IsFriendlyToPlayer(npc.friendlyToFaction) then
                out[#out + 1] = npcId
            end
        end
        return out
    end;

    -- Items the quest requires but never lists as a leaderboard objective
    -- (requiredSourceItems minus the item objectives and the item handed
    -- out on accept) — Questie's "special objectives".
    GetRequiredSourceItems = function(self, questId)
        local q = MUI_QuestDB:Get(questId)
        local req = q and q.requiredSourceItems
        if not req then return {} end
        local listed = {}
        if q.objectives and q.objectives[3] then
            for _, e in ipairs(q.objectives[3]) do
                if e and e[1] then listed[e[1]] = true end
            end
        end
        local out = {}
        for _, itemId in ipairs(req) do
            if not listed[itemId] and itemId ~= q.sourceItemId then
                out[#out + 1] = itemId
            end
        end
        return out
    end;

    -- Tooltip view of the required source items: name + whether the item
    -- is already in the bags.
    GetSourceItemObjectives = function(self, questId)
        local out = {}
        for _, itemId in ipairs(self:GetRequiredSourceItems(questId)) do
            local item = MUI_ItemDB:Get(itemId)
            out[#out + 1] = {
                itemId   = itemId,
                name     = item and item.name or ("item " .. itemId),
                finished = C_Item.GetItemCount(itemId) > 0,
            }
        end
        return out
    end;

    -- "itemId=0|1" per required source item, nil for quests without any;
    -- a change between two bag updates means recluster + re-pin.
    _SourceItemStateKey = function(self, questId)
        local items = self:GetRequiredSourceItems(questId)
        if #items == 0 then return nil end
        local parts = {}
        for i, itemId in ipairs(items) do
            parts[i] = itemId .. "=" .. (C_Item.GetItemCount(itemId) > 0 and 1 or 0)
        end
        return table.concat(parts, ",")
    end;

    RegisterTrackingListener = function(self, fn)
        self._trackingListeners = self._trackingListeners or {}
        table.insert(self._trackingListeners, fn)
    end;

    -- Quest tag id (Enum.QuestTag: Group = elite, Dungeon, Raid, PvP …) or
    -- nil. Questie's per-quest tag corrections are baked into the DB as
    -- `questTag`; otherwise GetQuestTagInfo answers. It can return nothing
    -- until the client has the quest cached, so a first empty answer isn't
    -- cached, and meanwhile a quest filed under a dungeon zone counts as a
    -- dungeon (raid) quest.
    GetQuestTag = function(self, questId)
        local cached = self._questTags[questId]
        if cached ~= nil then return cached or nil end
        local q = MUI_QuestDB:Get(questId)
        local tag = q and q.questTag or GetQuestTagInfo(questId)
        if not tag then
            local dungeon = q and q.zoneOrSort and MUI_DungeonDB:GetDungeonEntrance(q.zoneOrSort)
            local fallback = dungeon and (dungeon.isRaid and Enum.QuestTag.Raid or Enum.QuestTag.Dungeon)
            if not self._tagAsked[questId] then
                self._tagAsked[questId] = true
                return fallback
            end
            tag = fallback
        end
        self._questTags[questId] = tag or false
        return tag
    end;

    IsPvPQuest = function(self, questId)
        return self:GetQuestTag(questId) == Enum.QuestTag.PvP
    end;

    -- A quest name as every ModernUI surface shows it: "(Elite)" or
    -- "(Dungeon)" appended, like Era's quest log tags them.
    GetQuestDisplayName = function(self, questId, name)
        local tag = self:GetQuestTag(questId)
        if tag == Enum.QuestTag.Group then return name .. " (Elite)" end
        if tag == Enum.QuestTag.Dungeon then return name .. " (Dungeon)" end
        return name
    end;

    -- Quest title as the objective tooltips (minimap pin / area / arrow,
    -- world-map POI / hull) show it: "[level] " prefix when showQuestLevel
    -- is on, difficulty colour when showQuestDifficultyColor is on, gold
    -- otherwise. Returns text, r, g, b.
    FormatQuestTitle = function(self, entry, questId)
        local title = self:GetQuestDisplayName(questId, entry.title or ("quest " .. questId))
        local level = entry.level
        local s = MUI_DB and MUI_DB.settings and MUI_DB.settings.questHelper
        if s and s.showQuestLevel and level and level > 0 then
            title = "[" .. level .. "] " .. title
        end
        if s and s.showQuestDifficultyColor and level and level > 0 then
            local c = _difficultyColor(level)
            return title, c[1], c[2], c[3]
        end
        return title, 1, 0.82, 0
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
        MUI_Tooltip:ShowFor(anchorFrame, "ANCHOR_CURSOR", function(tip)
            local title, r, g, b = self:FormatQuestTitle(entry, questId)
            tip:SetMinimumWidth(100)
            tip:AddLine(title, r, g, b, true, 13)
            local emittedAny = false
            if entry.objectives then
                for _, o in ipairs(entry.objectives) do
                    if o.text and o.text ~= "" then
                        emittedAny = true
                        if o.finished then
                            tip:AddLine("-" .. o.text, 0.4, 0.85, 0.4, true)
                        elseif o.failed then
                            tip:AddLine(_FAIL_ICON .. " " .. o.text, 0.85, 0.3, 0.3, true)
                        else
                            tip:AddLine("-" .. o.text, 1, 1, 1, true)
                        end
                    end
                end
            end
            for _, s in ipairs(self:GetSourceItemObjectives(questId)) do
                emittedAny = true
                local line = "-" .. s.name .. ": " .. (s.finished and "1/1" or "0/1")
                if s.finished then
                    tip:AddLine(line, 0.4, 0.85, 0.4, true)
                else
                    tip:AddLine(line, 1, 1, 1, true)
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