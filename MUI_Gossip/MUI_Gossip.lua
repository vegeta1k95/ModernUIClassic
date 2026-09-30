-- MUI_Gossip: NPC dialog tweaks — the gossip window (GossipFrame) and the
-- quest greeting panel (QuestFrameGreetingPanel, used when an NPC offers
-- several quests without gossip text).
--
-- Quest rows: Era's row templates ship vanilla's bullet dot. The gossip code
-- swaps in the classic Interface\GossipFrame\*QuestIcon files, which don't
-- show on 1.15.9, and the greeting panel doesn't even try before TBC. Rows get
-- ModernUI's own "!" / "?" art instead (the map / minimap pin icons).

object "ModuleGossip" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Gossip")
    end;

    OnEnable = function(self)
        self._icons = {
            available        = MUI_MapPinIcons["Quest"],
            availableRepeat  = MUI_MapPinIcons["QuestRepeatable"],
            turnIn           = MUI_MinimapPinIcons["QuestTurnIn"],
            turnInRepeat     = MUI_MapPinIcons["QuestRepeatableTurnIn"],
            inProgress       = MUI_MinimapPinIcons["QuestCompletable"],
        }
        self:_HookGossipRows()
        self:_HookGreetingRows()
    end;

    -- ---- quest row icons ------------------------------------------------

    _ApplyIcon = function(self, native, kind, trivial)
        local spec = self._icons[kind]
        local icon = Texture(native)
        icon:SetTextureRegion(spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], spec[7])
        local c = trivial and 0.5 or 1
        icon:SetVertexColor(c, c, c)
    end;

    -- Ready to hand in: complete per the game, or a quest with no objectives
    -- at all (deliveries like "Elmore's Task": "Speak with Grimand Elmore."),
    -- which Era never flags complete though the NPC takes it. Same rule as the
    -- minimap turn-in pins.
    _IsReady = function(self, entry, isComplete)
        if isComplete then return true end
        return entry ~= nil and (entry.isComplete or #entry.objectives == 0)
    end;

    -- Quest-log entry for a greeting-panel row: Era has no GetActiveQuestID,
    -- so match the row's title.
    _EntryByTitle = function(self, title)
        for _, entry in pairs(MUI_QuestHelper.watcher:GetWatched()) do
            if entry.title == title then return entry end
        end
    end;

    -- Gossip rows are pooled ScrollBox buttons whose mixin is copied onto each
    -- button when it is created, on the first gossip open — after this runs,
    -- so hooking the mixin tables reaches every row.
    _HookGossipRows = function(self)
        hooksecurefunc(GossipAvailableQuestButtonMixin, "Setup", function(button, info)
            -- Only the repeatable flag: `frequency` reports ordinary quests as
            -- non-default here, so every row came out blue (Era has no dailies).
            local kind = info.repeatable and "availableRepeat" or "available"
            self:_ApplyIcon(button.Icon, kind, info.isTrivial or info.isIgnored)
        end)
        hooksecurefunc(GossipActiveQuestButtonMixin, "Setup", function(button, info)
            local kind = "inProgress"
            if self:_IsReady(MUI_QuestHelper.watcher:GetEntry(info.questID), info.isComplete) then
                kind = info.repeatable and "turnInRepeat" or "turnIn"
            end
            self:_ApplyIcon(button.Icon, kind, info.isTrivial or info.isIgnored)
        end)
    end;

    -- The greeting panel's OnShow script can be bound to the function itself,
    -- which a hook on the global wouldn't reach, and QuestFrame's event
    -- handler calls the global to refresh a panel that's already shown — so
    -- hook both.
    _HookGreetingRows = function(self)
        local refresh = function() self:_UpdateGreetingIcons() end
        Frame(QuestFrameGreetingPanel):HookScript("OnShow", refresh)
        hooksecurefunc("QuestFrameGreetingPanel_OnShow", refresh)
    end;

    _UpdateGreetingIcons = function(self)
        local numActive = GetNumActiveQuests()
        for i = 1, numActive do
            local title, isComplete = GetActiveTitle(i)
            local ready = self:_IsReady(self:_EntryByTitle(title), isComplete)
            self:_ApplyIcon(_G["QuestTitleButton" .. i .. "QuestIcon"],
                            ready and "turnIn" or "inProgress",
                            IsActiveQuestTrivial(i))
        end
        for i = 1, GetNumAvailableQuests() do
            -- The second return (daily flag / frequency) is skipped for the
            -- same reason as on gossip rows.
            local isTrivial, _, isRepeatable = GetAvailableQuestInfo(i)
            self:_ApplyIcon(_G["QuestTitleButton" .. (numActive + i) .. "QuestIcon"],
                            isRepeatable and "availableRepeat" or "available", isTrivial)
        end
    end;
}
