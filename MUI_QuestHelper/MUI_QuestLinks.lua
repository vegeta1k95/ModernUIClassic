-- MUI_QuestLinks: quest links in chat, compatible with Questie.
--
-- Questie sends quest links as plain text, "[[<level>] <name> (<questId>)]",
-- and each Questie client turns that text into a clickable link locally. So:
--   * Shift-click on a quest (map quest log, tracker) with a chat box open
--     inserts that text: Questie users get their usual link.
--   * Incoming chat text in that format becomes a link here too. Clicking it
--     opens a Questie-style quest tooltip in the sticky ItemRef tooltip (click
--     again to close); shift-click relinks. ModernUI otherwise keeps the
--     ItemRef tooltip hidden (MUI_TooltipHooks asks IsItemRefQuest).
-- The link type is our own, handled through LinkUtil, so nothing of
-- Blizzard's is overridden. With Questie loaded, its own filter does the
-- converting and ours stays off.

local LINK_TYPE = "muiquest"

-- "[[<level>] <name> (<questId>)]" and the level-less "[<name> (<questId>)]".
local LEVELED_LINK = "%[%[%-?%d+[^%]]*%] ([^%[%]]-) %((%d+)%)%]"
local PLAIN_LINK   = "%[([^%[%]]-) %((%d+)%)%]"

-- Chat events Questie converts links in.
local CHAT_EVENTS = {
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
}

local GREEN  = { 0.10, 1.00, 0.10 }
local YELLOW = { 1.00, 1.00, 0.00 }
local RED    = { 1.00, 0.10, 0.10 }
local GREY   = { 0.60, 0.60, 0.60 }
local GOLD   = { 1.00, 0.82, 0.00 }

-- Zone (or dungeon) name for a Questie area id.
local function _ZoneName(areaId)
    if not areaId or areaId <= 0 then return nil end
    local dungeon = MUI_DungeonDB:GetDungeonEntrance(areaId)
    if dungeon then return dungeon.name end
    local uiMap = MUI_ZoneDB:GetUiMapForArea(areaId)
    local info = uiMap and C_Map.GetMapInfo(uiMap)
    return info and info.name
end

object "ModuleQuestLinks" : extends "Module" {
    __init = function(self)
        Module.__init(self, "QuestLinks")
    end;

    OnEnable = function(self)
        -- Claiming the type also keeps SetItemRef from handing our links to
        -- the ItemRef tooltip, which doesn't know them.
        LinkUtil.RegisterLinkHandler(LINK_TYPE, function(_, _, linkData)
            local questId = tonumber(linkData.options)
            if not questId then return end
            if IsModifiedClick("CHATLINK") then
                self:InsertLink(questId)
            else
                self:_ToggleItemRef(questId)
            end
        end)
        -- Anything else put into the ItemRef tooltip (it clears first) or
        -- closing it ends our claim on it.
        local release = function() self._itemRefQuest = nil end
        MUI_TooltipItemRef:HookScript("OnTooltipCleared", release)
        MUI_TooltipItemRef:HookScript("OnHide", release)

        if C_AddOns.IsAddOnLoaded("Questie") then return end
        local filter = function(_, _, msg, ...)
            local linked = self:_LinkQuests(msg)
            if linked then return false, linked, ... end
            return false
        end
        for _, event in ipairs(CHAT_EVENTS) do
            ChatFrameUtil.AddMessageEventFilter(event, filter)
        end
    end;

    -- ---- sending ----------------------------------------------------------

    -- Put Questie's link text for a quest into the open chat box. Returns
    -- false when no chat box is open, so the click can do its usual thing.
    InsertLink = function(self, questId)
        if not ChatFrameUtil.GetActiveWindow() then return false end
        local q = MUI_QuestDB:Get(questId)
        local entry = MUI_QuestHelper.watcher:GetEntry(questId)
        local name = (q and q.name) or (entry and entry.title)
        if not name then return false end
        local level = (entry and entry.level) or (q and q.questLevel) or 0
        ChatFrameUtil.InsertLink(string.format("[[%d] %s (%d)]", level, name, questId))
        return true
    end;

    -- ---- receiving --------------------------------------------------------

    -- The message with every known quest's link text made clickable, or nil
    -- when there was nothing to convert.
    _LinkQuests = function(self, msg)
        if not msg:find(" %(%d+%)%]") then return nil end
        local changed = false
        local function link(id)
            local questId = tonumber(id)
            if not MUI_QuestDB:Get(questId) then return nil end
            changed = true
            return self:_Hyperlink(questId)
        end
        msg = msg:gsub(LEVELED_LINK, function(_, id) return link(id) end)
        msg = msg:gsub(PLAIN_LINK, function(_, id) return link(id) end)
        return changed and msg or nil
    end;

    -- Clickable link showing the quest's title as our tooltips format it.
    _Hyperlink = function(self, questId)
        local q = MUI_QuestDB:Get(questId)
        local title, r, g, b = MUI_QuestHelper:FormatQuestTitle({ title = q.name, level = q.questLevel }, questId)
        return string.format("|cff%02x%02x%02x|H%s:%d|h[%s]|h|r",
            math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), LINK_TYPE, questId, title)
    end;

    -- Click: the quest in the sticky ItemRef tooltip, as Questie does; a
    -- second click on the same quest closes it. The claim is set after
    -- SetOwner (which clears the tooltip) and before it shows, so the ItemRef
    -- hide rule in MUI_TooltipHooks lets it through. A plain Show: the tooltip
    -- has no panel area, and ShowUIPanel from addon code is blocked in combat.
    _ToggleItemRef = function(self, questId)
        local tip = MUI_TooltipItemRef
        if tip:IsShown() and self._itemRefQuest == questId then
            tip:Hide()
            return
        end
        tip:SetOwner(UIParent, "ANCHOR_PRESERVE")
        self._itemRefQuest = questId
        self:FillTooltip(tip, questId)
        tip:Show()
    end;

    -- Whether the ItemRef tooltip currently shows one of our quests.
    IsItemRefQuest = function(self)
        return self._itemRefQuest ~= nil
    end;

    -- ---- tooltip ----------------------------------------------------------

    -- Questie's quest link tooltip: title, your status, description,
    -- instance, objectives (when not on it), then progress / where it ends
    -- or starts.
    FillTooltip = function(self, tip, questId)
        local q = MUI_QuestDB:Get(questId)
        if not q then return end
        local entry = MUI_QuestHelper.watcher:GetEntry(questId)
        local ready = entry and (entry.isComplete or #entry.objectives == 0)
        local completed = C_QuestLog.IsQuestFlaggedCompleted(questId)

        local title, r, g, b = MUI_QuestHelper:FormatQuestTitle({ title = q.name, level = q.questLevel }, questId)
        tip:AddLine(title, r, g, b, true, 13)

        local avail = MUI_QuestHelper.availability
        if entry then
            if ready then
                tip:AddLine("You are on this quest (|cff19ff19Complete|r)", 1, 1, 1)
            else
                tip:AddLine("You are on this quest", GREEN[1], GREEN[2], GREEN[3])
            end
        elseif completed then
            tip:AddLine("You have completed this quest", GREEN[1], GREEN[2], GREEN[3])
        elseif avail and avail:IsAvailable(questId) then
            local text = avail:IsRepeatable(questId) and "This quest is repeatable" or "You have not done this quest"
            tip:AddLine(text, YELLOW[1], YELLOW[2], YELLOW[3])
        else
            tip:AddLine("You are ineligible for this quest", RED[1], RED[2], RED[3])
        end

        tip:AddBlank()
        local described = false
        for _, line in ipairs(q.objectivesText or {}) do
            if line ~= "" then
                tip:AddLine(line, 1, 1, 1, true)
                described = true
            end
        end
        if not described then
            tip:AddLine("This quest is an automatic completion quest and does not contain an objective.", 1, 1, 1, true)
        end

        local dungeon = q.zoneOrSort and q.zoneOrSort > 0 and MUI_DungeonDB:GetDungeonEntrance(q.zoneOrSort)
        if dungeon then
            tip:AddBlank()
            tip:AddLine("Instance: " .. dungeon.name, GREY[1], GREY[2], GREY[3])
        end

        if not entry and not completed then
            local names = self:_ObjectiveNames(q)
            if #names > 0 then
                tip:AddBlank()
                tip:AddLine("Objectives", GOLD[1], GOLD[2], GOLD[3])
                for _, name in ipairs(names) do tip:AddLine(name, 1, 1, 1) end
            end
        end

        if entry and not ready then
            tip:AddBlank()
            tip:AddLine("Your progress:", 1, 1, 1)
            for _, o in ipairs(entry.objectives) do
                if o.text and o.text ~= "" then
                    if o.failed then
                        tip:AddLine(" " .. MUI_QuestHelper:GetFailIconEscape() .. " " .. o.text, RED[1], RED[2], RED[3])
                    else
                        local c = o.finished and GREEN or { 1, 1, 1 }
                        tip:AddLine(" - " .. o.text, c[1], c[2], c[3])
                    end
                end
            end
        elseif entry then
            self:_AddGiver(tip, "Ended by: ", q.finishedBy, q)
        elseif not completed then
            self:_AddGiver(tip, "Started by: ", q.startedBy, q)
        end
    end;

    -- "Started by / Ended by: <name>" and "Found in: <zone>" for the first NPC,
    -- object or item of a startedBy / finishedBy list.
    _AddGiver = function(self, tip, label, list, q)
        local name, zone
        local npcId = list and list[1] and list[1][1]
        local objId = list and list[2] and list[2][1]
        local itemId = list and list[3] and list[3][1]
        if npcId and MUI_NpcDB:Get(npcId) then
            local npc = MUI_NpcDB:Get(npcId)
            name, zone = npc.name, _ZoneName(npc.zoneID)
        elseif objId and MUI_ObjectDB:Get(objId) then
            local obj = MUI_ObjectDB:Get(objId)
            name, zone = obj.name, _ZoneName(obj.zoneID)
        elseif itemId and MUI_ItemDB:Get(itemId) then
            name = MUI_ItemDB:Get(itemId).name
        end
        zone = zone or _ZoneName(q.zoneOrSort)
        if name then
            tip:AddBlank()
            tip:AddLine(label .. "|cff999999" .. name .. "|r", 1, 1, 1)
        end
        if zone then
            if not name then tip:AddBlank() end
            tip:AddLine("Found in: |cff999999" .. zone .. "|r", 1, 1, 1)
        end
    end;

    -- Names of what the quest asks for: creatures, objects, items (Questie's
    -- objectives table; a custom objective text wins over the DB name).
    _ObjectiveNames = function(self, q)
        local names, objs = {}, q.objectives
        if not objs then return names end
        local function add(list, db)
            for _, e in ipairs(list or {}) do
                local id, text
                if type(e[1]) == "table" then id, text = e[2], e[3] else id, text = e[1], e[2] end
                local row = id and db:Get(id)
                local name = type(text) == "string" and text or (row and row.name)
                if name then names[#names + 1] = name end
            end
        end
        add(objs[1], MUI_NpcDB)
        add(objs[2], MUI_ObjectDB)
        add(objs[3], MUI_ItemDB)
        add(objs[5], MUI_NpcDB)
        return names
    end;
}
