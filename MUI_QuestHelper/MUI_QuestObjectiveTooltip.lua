-- MUI_QuestObjectiveTooltip: augment GameTooltip with active-quest info
-- when the cursor hovers an NPC, world object, or item that is a target
-- of any accepted quest's objective (or a finisher). Mirrors Questie's
-- tooltip behaviour.
--
-- Data model: reverse indices rebuilt reactively from MUI_QuestDB on
-- every OnQuestAdded and torn down on OnQuestRemoved.
--   _npcQuests    [npcId]  = { questId, ... }
--   _objNameQuests[name]   = { questId, ... }   (world objects: matched
--                                                 by tooltip line-1 text
--                                                 because GameObject IDs
--                                                 aren't exposed via any
--                                                 client API)
--   _itemQuests   [itemId] = { questId, ... }
--
-- Each list is small (a given target usually belongs to ≤ 2-3 active
-- quests), and lookups are O(1) hash + O(|list|) loop. No rebuild on
-- OnQuestChanged — the index tracks "is a target of this quest", which
-- is stable over the quest's life; objective progress lines come from
-- FillQuestTooltip which re-reads the live quest log on every emission.
--
-- Hover hooks on GameTooltip:
--   OnTooltipSetUnit — NPC path: parse npcId from UnitGUID.
--   OnTooltipSetItem — item path: parse itemId from link.
--   OnShow           — object fallback: match line-1 text against
--                      _objNameQuests when the tooltip has no unit /
--                      item association.

class "QuestObjectiveTooltip" {
    __init = function(self)
        self._npcQuests     = {}
        self._objNameQuests = {}
        self._itemQuests    = {}
        self:_HookGameTooltip()
    end;

    -- Wire up the watcher late so the MUI_QuestHelper module can control
    -- construction order. Also scans any quests already in the watcher
    -- (PLAYER_ENTERING_WORLD fires before our registration on /reload).
    SetWatcher = function(self, watcher)
        self.watcher = watcher
        watcher:RegisterCallback("OnQuestAdded", function(questId)
            self:_IndexQuest(questId)
        end)
        watcher:RegisterCallback("OnQuestRemoved", function(questId)
            self:_UnindexQuest(questId)
        end)
        for qid in pairs(watcher:GetWatched()) do
            self:_IndexQuest(qid)
        end
    end;

    -- ---- index maintenance ---------------------------------------------

    _IndexQuest = function(self, questId)
        local q = MUI_QuestDB:Get(questId)
        if not q then return end
        local objs = q.objectives
        if objs then
            -- [1] creature kills, [5] killCredit — both resolve to NPC ids.
            for _, cat in ipairs({ 1, 5 }) do
                local list = objs[cat]
                if list then
                    for _, e in ipairs(list) do
                        if e and e[1] then
                            self:_AddIdx(self._npcQuests, e[1], questId)
                        end
                    end
                end
            end
            -- [2] object interactions.
            if objs[2] then
                for _, e in ipairs(objs[2]) do
                    if e and e[1] then self:_IndexObject(e[1], questId) end
                end
            end
            -- [3] item collect: map the item itself, plus every drop source
            -- (NPC or world object) so hovering those surfaces the quest.
            if objs[3] then
                for _, e in ipairs(objs[3]) do
                    if e and e[1] then self:_IndexItem(e[1], questId) end
                end
            end
            -- [4] reputation, [6] spell: no hover target.
        end
        -- Turn-in NPCs / objects also get a hover annotation so the player
        -- can see "this is where quest X turns in" from the unit tooltip.
        if q.finishedBy then
            if q.finishedBy[1] then
                for _, npcId in ipairs(q.finishedBy[1]) do
                    self:_AddIdx(self._npcQuests, npcId, questId)
                end
            end
            if q.finishedBy[2] then
                for _, objId in ipairs(q.finishedBy[2]) do
                    self:_IndexObject(objId, questId)
                end
            end
        end
    end;

    _IndexObject = function(self, objectId, questId)
        local obj = MUI_ObjectDB:Get(objectId)
        if obj and obj.name and obj.name ~= "" then
            self:_AddIdx(self._objNameQuests, obj.name, questId)
        end
    end;

    _IndexItem = function(self, itemId, questId)
        self:_AddIdx(self._itemQuests, itemId, questId)
        local item = MUI_ItemDB:Get(itemId)
        if not item then return end
        if item.npcDrops then
            for _, npcId in ipairs(item.npcDrops) do
                self:_AddIdx(self._npcQuests, npcId, questId)
            end
        end
        if item.objectDrops then
            for _, objId in ipairs(item.objectDrops) do
                self:_IndexObject(objId, questId)
            end
        end
    end;

    _UnindexQuest = function(self, questId)
        self:_RemoveFromAll(self._npcQuests,     questId)
        self:_RemoveFromAll(self._objNameQuests, questId)
        self:_RemoveFromAll(self._itemQuests,    questId)
    end;

    _AddIdx = function(self, tbl, key, questId)
        local list = tbl[key]
        if not list then
            list = {}
            tbl[key] = list
        end
        for _, q in ipairs(list) do
            if q == questId then return end
        end
        list[#list + 1] = questId
    end;

    _RemoveFromAll = function(self, tbl, questId)
        for key, list in pairs(tbl) do
            for i = #list, 1, -1 do
                if list[i] == questId then table.remove(list, i) end
            end
            if #list == 0 then tbl[key] = nil end
        end
    end;

    -- ---- tooltip hooks -------------------------------------------------

    _HookGameTooltip = function(self)
        MUI_Tooltip:HookScript("OnTooltipSetUnit", function(tt)
            self:_AugmentUnit(tt)
        end)
        MUI_Tooltip:HookScript("OnTooltipSetItem", function(tt)
            self:_AugmentItem(tt)
        end)
        -- Fallback for world objects: no dedicated OnTooltipSetObject
        -- exists, so use OnShow + match line 1 text against the object
        -- name index. Unit / item tooltips are filtered out inside the
        -- handler so we don't double-process.
        MUI_Tooltip:HookScript("OnShow", function(tt)
            self:_AugmentObject(tt)
        end)
    end;

    _AugmentUnit = function(self, tt)
        if tt ~= GameTooltip then return end
        local _, unit = tt:GetUnit()
        if not unit or UnitIsPlayer(unit) then return end
        local guid = UnitGUID(unit)
        if not guid then return end
        -- Classic Era GUID: Creature-0-<svr>-<inst>-<zone>-<npcId>-<uid>.
        -- Pet / Vehicle share the same position. Players use "Player-"
        -- which we've already filtered via UnitIsPlayer above.
        local kind, _, _, _, _, idStr = strsplit("-", guid)
        if kind ~= "Creature" and kind ~= "Vehicle" and kind ~= "Pet" then
            return
        end
        local npcId = tonumber(idStr)
        if npcId then
            self:_AppendQuestsFor(tt, self._npcQuests[npcId], "npc", npcId, true)
        end
    end;

    _AugmentItem = function(self, tt)
        if tt ~= GameTooltip then return end
        local _, link = tt:GetItem()
        if not link then return end
        local idStr = link:match("item:(%d+)")
        local itemId = idStr and tonumber(idStr) or nil
        if itemId then
            self:_AppendQuestsFor(tt, self._itemQuests[itemId], "item", itemId, true)
        end
    end;

    _AugmentObject = function(self, tt)
        if tt ~= GameTooltip then return end
        -- Unit / item / spell tooltips flow through their own hooks or
        -- aren't interesting for quest-target matching. Bail if any of
        -- those fire so the name-based match only runs on actual world-
        -- object tooltips (chests, herb nodes, quest objects, etc).
        if tt:GetUnit() then return end
        local _, itemLink = tt:GetItem()
        if itemLink then return end
        if tt.GetSpell then
            local _, spellId = tt:GetSpell()
            if spellId then return end
        end
        local name = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
        if not name or name == "" then return end
        self:_AppendQuestsFor(tt, self._objNameQuests[name], "object-name", name)
    end;

    _AppendQuestsFor = function(self, tt, questIds, targetKind, targetId, monoSize)
        if not questIds or #questIds == 0 then return end
        local watcher = self.watcher
        local appended = false
        for _, questId in ipairs(questIds) do
            local entry = watcher and watcher:GetEntry(questId)
            if entry then
                local filter = self:_FilterFor(questId, entry, targetKind, targetId)
                MUI_QuestHelper:FillQuestTooltip(questId, "full", filter, monoSize)
                appended = true
            end
        end
        if appended then tt:Show() end  -- recalc tooltip size after additions
    end;

    -- Build a {idx → true} set of objective indices in `entry.objectives`
    -- whose text refers to the hovered target. Match is by substring of
    -- the target's display name(s); for an NPC/object that drops a quest
    -- item, the item's name is included so the loot objective ("Wolf
    -- Pelt: 5/10") still matches when hovering the wolf or chest.
    --
    -- Returns nil (= "no filter, show all") when no objective matches —
    -- e.g. the hovered NPC is only the quest's turn-in giver. Showing all
    -- objectives is more useful there than emitting just a bare title.
    _FilterFor = function(self, questId, entry, targetKind, targetId)
        if not entry.objectives then return nil end
        local names = self:_TargetNames(questId, targetKind, targetId)
        if not names or #names == 0 then return nil end
        local matched, any = {}, false
        for idx, o in ipairs(entry.objectives) do
            local txt = o.text
            if txt and txt ~= "" then
                for _, n in ipairs(names) do
                    if n and n ~= "" and txt:find(n, 1, true) then
                        matched[idx] = true
                        any = true
                        break
                    end
                end
            end
        end
        return any and matched or nil
    end;

    _TargetNames = function(self, questId, kind, id)
        local q = MUI_QuestDB:Get(questId)
        if not q then return {} end
        local names = {}

        if kind == "npc" then
            local npc = MUI_NpcDB:Get(id)
            if npc and npc.name then names[#names + 1] = npc.name end
            -- Items this NPC drops as part of this quest's [3] objectives.
            if q.objectives and q.objectives[3] then
                for _, e in ipairs(q.objectives[3]) do
                    local item = e[1] and MUI_ItemDB:Get(e[1])
                    if item and item.npcDrops then
                        for _, nid in ipairs(item.npcDrops) do
                            if nid == id and item.name then
                                names[#names + 1] = item.name
                                break
                            end
                        end
                    end
                end
            end

        elseif kind == "object-name" then
            -- World-object IDs aren't exposed; we already matched by name.
            names[#names + 1] = id
            -- Items this object drops/contains for this quest's [3].
            if q.objectives and q.objectives[3] then
                for _, e in ipairs(q.objectives[3]) do
                    local item = e[1] and MUI_ItemDB:Get(e[1])
                    if item and item.objectDrops then
                        for _, oid in ipairs(item.objectDrops) do
                            local obj = MUI_ObjectDB:Get(oid)
                            if obj and obj.name == id and item.name then
                                names[#names + 1] = item.name
                                break
                            end
                        end
                    end
                end
            end

        elseif kind == "item" then
            local item = MUI_ItemDB:Get(id)
            if item and item.name then names[#names + 1] = item.name end
        end

        return names
    end;
}
