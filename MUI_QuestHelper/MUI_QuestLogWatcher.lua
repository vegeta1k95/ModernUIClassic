-- QuestLogWatcher: reads the player's quest log and emits state-change
-- callbacks for consumers (MinimapQuestPinManager, world-map helpers, future
-- tracker-panel UIs). Owns the authoritative in-memory view of what the
-- player currently has accepted; callbacks describe diffs, not full state.
--
-- Callbacks (register via :RegisterCallback("Name", fn)):
--   OnQuestAdded(questId, entry, isNew)
--                                   — quest newly present in watched[]. isNew
--                                     is true only when the quest arrived via
--                                     a live QUEST_ACCEPTED event (real player
--                                     action). On /reload the first
--                                     _FullRefresh rehydrates every existing
--                                     quest via this callback too — those fire
--                                     with isNew=false so listeners can avoid
--                                     treating them as fresh accepts.
--   OnQuestRemoved(questId, reason) — "abandoned" when the player drops
--                                     the quest, "turned_in" when they
--                                     complete it at a quest-giver. Lets
--                                     UI consumers play a farewell
--                                     animation on turn-in but skip it
--                                     for abandons.
--   OnQuestChanged(questId, entry, diff)
--                                   — objective progress / completion state changed
--                                   — diff = { completedObjectives = {idx, ...},
--                                              becameComplete = bool,
--                                              titleChanged = bool, ... }
--
-- The engine fires bursts of QUEST_LOG_UPDATE events around every action
-- (quest-accept, level-up, zone change, tooltip hover on a quest NPC...).
-- We debounce full-log refreshes to avoid spamming consumers. Debounce
-- window mirrors Questie's `MARKER_EVENT_TIMEFRAME` (~150 ms).

local DEBOUNCE_SEC = 0.15

local function _readQuestEntry(logIndex, questId)
    -- Classic Era quest-log API. Args: title, level, suggGroup, isHeader,
    -- isCollapsed, isComplete (int: 1=complete, -1=failed), frequency,
    -- questID (may be nil; use passed-in questId if so).
    local title, level, _, isHeader, _, isComplete, _, qid = GetQuestLogTitle(logIndex)
    if isHeader then return nil end
    questId = questId or qid
    if not questId or questId == 0 then return nil end

    local objectives = {}
    local numObj = GetNumQuestLeaderBoards(logIndex) or 0
    for i = 1, numObj do
        local text, objType, finished = GetQuestLogLeaderBoard(i, logIndex)
        objectives[i] = {
            type = objType,       -- "monster" | "object" | "item" | "event" | "reputation"
            finished = finished and true or false,
            text = text or "",
        }
    end

    return {
        questId     = questId,
        logIndex    = logIndex,
        title       = title or "",
        level       = level or 0,
        -- isComplete can be 1 (all objectives done) or nil (in progress).
        -- Normalise to boolean.
        isComplete  = isComplete == 1,
        objectives  = objectives,
    }
end


class "QuestLogWatcher" : extends "Frame" {
    __init = function(self)
        Frame.__init(self, "Frame", nil, "MUI_QuestLogWatcher")

        self.watched  = {}   -- [questId] = entry
        self.callbacks = { OnQuestAdded = {}, OnQuestRemoved = {}, OnQuestChanged = {} }

        self._debouncePending = false
        -- QuestIds captured from the live QUEST_ACCEPTED event, flagged
        -- as genuine accepts so the next _FullRefresh can pass `isNew=true`
        -- to OnQuestAdded subscribers. /reload populates `watched` from
        -- empty but never fires QUEST_ACCEPTED, so those quests emit with
        -- isNew=false and auto-focus listeners can skip them.
        self._justAccepted = {}

        -- Events. Engine callback signature: (cframe, event, ...). We just
        -- route into methods on self; `self` is captured by the closure.
        self:RegisterEventHandler("QUEST_ACCEPTED", function(_, _, logIndex, questId)
            self:_OnQuestAccepted(logIndex, questId)
        end)
        self:RegisterEventHandler("QUEST_REMOVED", function(_, _, questId)
            self:_OnQuestRemoved(questId, "abandoned")
        end)
        self:RegisterEventHandler("QUEST_TURNED_IN", function(_, _, questId)
            self:_OnQuestRemoved(questId, "turned_in")
        end)
        self:RegisterEventHandler("QUEST_LOG_UPDATE", function()
            self:_ScheduleRefresh()
        end)
        self:RegisterEventHandler("QUEST_WATCH_UPDATE", function(_, _, questId)
            self:_ScheduleRefresh()
        end)
        self:RegisterEventHandler("PLAYER_ENTERING_WORLD", function()
            self:_FullRefresh()
        end)
    end;

    -- ---- public API ----------------------------------------------------

    RegisterCallback = function(self, name, fn)
        local bucket = self.callbacks[name]
        if not bucket then
            error("QuestLogWatcher: unknown callback " .. tostring(name))
        end
        bucket[#bucket + 1] = fn
    end;

    GetWatched = function(self)
        return self.watched
    end;

    GetEntry = function(self, questId)
        return self.watched[questId]
    end;

    Count = function(self)
        local n = 0
        for _ in pairs(self.watched) do n = n + 1 end
        return n
    end;

    -- ---- internals -----------------------------------------------------

    _Emit = function(self, name, ...)
        local bucket = self.callbacks[name]
        if not bucket then return end
        for _, fn in ipairs(bucket) do
            local ok, err = pcall(fn, ...)
            if not ok then
                MUI.Print(
                    "|cffff4040MUI_QuestHelper|r callback " .. name .. " error: " .. tostring(err))
            end
        end
    end;

    _OnQuestAccepted = function(self, logIndex, questId)
        -- QUEST_ACCEPTED fires before QUEST_LOG_UPDATE settles; the log
        -- index may be stale. Let _FullRefresh catch it shortly. Stash
        -- the questId so the resulting OnQuestAdded fire can be marked
        -- as a real accept (vs /reload re-hydration).
        if questId then self._justAccepted[questId] = true end
        self:_ScheduleRefresh()
    end;

    _OnQuestRemoved = function(self, questId, reason)
        if not self.watched[questId] then return end
        self.watched[questId] = nil
        self:_Emit("OnQuestRemoved", questId, reason)
    end;

    _ScheduleRefresh = function(self)
        if self._debouncePending then return end
        self._debouncePending = true
        C_Timer.After(DEBOUNCE_SEC, function()
            self._debouncePending = false
            self:_FullRefresh()
        end)
    end;

    _FullRefresh = function(self)
        -- Read the entire quest log, diff against `watched`, emit callbacks.
        -- Headers are skipped inside _readQuestEntry.
        local seen = {}
        local numEntries = GetNumQuestLogEntries()
        for i = 1, numEntries do
            local entry = _readQuestEntry(i)
            if entry then
                seen[entry.questId] = true
                local prev = self.watched[entry.questId]
                self.watched[entry.questId] = entry
                if not prev then
                    local isNew = self._justAccepted[entry.questId] and true or false
                    self._justAccepted[entry.questId] = nil
                    self:_Emit("OnQuestAdded", entry.questId, entry, isNew)
                else
                    local diff = self:_Diff(prev, entry)
                    if diff then
                        self:_Emit("OnQuestChanged", entry.questId, entry, diff)
                    end
                end
            end
        end
        -- Remove quests no longer in the log that QUEST_REMOVED didn't
        -- already catch (e.g. silent turn-in edge cases).
        for questId in pairs(self.watched) do
            if not seen[questId] then
                self.watched[questId] = nil
                self:_Emit("OnQuestRemoved", questId)
            end
        end
    end;

    _Diff = function(self, prev, cur)
        local diff
        if prev.isComplete ~= cur.isComplete then
            diff = diff or {}
            diff.becameComplete = cur.isComplete
        end
        if prev.title ~= cur.title then
            diff = diff or {}
            diff.titleChanged = true
        end
        -- Objective-level diff: collect indices whose finished flag flipped.
        local completed = {}
        local progressed = {}
        local changed = false
        for i, obj in ipairs(cur.objectives) do
            local p = prev.objectives[i]
            if p then
                if not p.finished and obj.finished then
                    completed[#completed + 1] = i
                    changed = true
                elseif p.text ~= obj.text then
                    progressed[#progressed + 1] = i
                    changed = true
                end
            else
                changed = true    -- new objective (rare, usually impossible)
            end
        end
        if #prev.objectives ~= #cur.objectives then changed = true end
        if changed then
            diff = diff or {}
            diff.completedObjectives = completed
            diff.progressedObjectives = progressed
        end
        return diff
    end;
}
