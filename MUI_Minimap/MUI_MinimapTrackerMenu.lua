-- MinimapTrackerMenu: Era's minimap-tracking-style popup. Internally just
-- a DropdownMenu instance with: a "Clear All" text row, a fixed list of
-- objective-pin filter checkboxes, the quest-helper toggles, and the
-- player's learned tracking spells (Track Humanoids / Find Herbs / etc.)
-- as a one-of radio group. Toggled externally via Show / Hide / Toggle.

local OBJECTS_ATLAS = "Interface\\AddOns\\ModernUI\\assets\\textures\\objecticonsatlas"

-- Classic Era has no GetNumTrackingTypes — enumerate by IsSpellKnown on the
-- known set of tracking/sense spells across all classes + gathering professions.
local TRACKING_SPELL_IDS = {
    1494,  -- Track Beasts (Hunter)
    19878, -- Track Demons
    19879, -- Track Dragonkin
    19880, -- Track Elementals
    19882, -- Track Giants
    19883, -- Track Humanoids (Hunter)
    19884, -- Track Undead
    19885, -- Track Hidden
    5225,  -- Track Humanoids (Druid cat form)
    5500,  -- Sense Demons (Warlock)
    5502,  -- Sense Undead (Paladin)
    2383,  -- Find Herbs (Herbalism)
    2580,  -- Find Minerals (Mining)
    2481,  -- Find Treasure (Dwarf racial)
}

-- Override the default spell icon with an OBJECTS_ATLAS region for specific
-- tracking spells whose native icons look out of place next to the hardcoded
-- filter icons (Auctioneer, Banker, …). Fill in x/y/w/h once you know them.
local SPELL_ICON_OVERRIDES = {
    [2383] = { x = 963, y = 520, w = 32, h = 32 }, -- Find Herbs    — TODO: real atlas coords
    [2580] = { x = 520, y = 552, w = 32, h = 32 }, -- Find Minerals — TODO: real atlas coords
    [2481] = { x = 656, y = 756, w = 32, h = 32 }, -- Find Treasure — TODO: real atlas coords
}

class "MinimapTrackerMenu" {
    __init = function(self, parent, name, toggleAnchor)
        self.toggleAnchor = toggleAnchor

        self.menu = DropdownMenu(parent, name, toggleAnchor)
        self.menu:SetMenuWidth(267.3)
        self.menu:SetAnchor(function(popup, anchor)
            popup:Below(anchor, -4.5)
            popup:LeftOf(anchor, -10)
        end)

        self:_WireEvents()
        self:_SchedulePopulate()
    end;

    Toggle  = function(self) self.menu:Toggle()  end;
    IsShown = function(self) return self.menu:IsShown() end;

    _WireEvents = function(self)
        -- Rebuild when the player learns a new spell or gains/loses a
        -- profession skill, so Find Herbs / Track Humanoids / etc. appear
        -- without /reload.
        self.menu.popup:RegisterEventHandler("LEARNED_SPELL_IN_TAB", function() self:_SchedulePopulate() end)
        self.menu.popup:RegisterEventHandler("SKILL_LINES_CHANGED",  function() self:_SchedulePopulate() end)
        self.menu.popup:RegisterEventHandler("SPELLS_CHANGED",       function() self:_SchedulePopulate() end)
        -- Refresh radio-state when tracking spell toggles (including from
        -- external macros).
        self.menu.popup:RegisterEventHandler("MINIMAP_UPDATE_TRACKING", function() self:UpdateStates() end)
        -- SetItems builds CheckBox rows internally and CheckBox calls
        -- SetPropagateMouseClicks (a protected API blocked in combat),
        -- so defer rebuilds until combat ends if an event fires mid-fight.
        self.menu.popup:RegisterEventHandler("PLAYER_REGEN_ENABLED", function()
            if self._pendingRepopulate then
                self._pendingRepopulate = false
                self:Populate()
            end
        end)
    end;

    _SchedulePopulate = function(self)
        if InCombatLockdown() then
            self._pendingRepopulate = true
        else
            self:Populate()
        end
    end;

    Populate = function(self)
        self._items = self:_BuildItems()
        self.menu:SetItems(self._items)
        self:UpdateStates()
    end;

    -- Build the item list in DropdownMenu schema. Each item carries its
    -- own filter/spell/quest key so ClearAll / UpdateStates can find it
    -- without per-row scripting.
    _BuildItems = function(self)
        local items = {
            { type = "text", label = "Clear All",
              closeOnClick = false,
              OnClick = function() self:ClearAll() end },
            self:_FilterItem("Auctioneer",         "Auctioneer",            385, 757, 32, 32),
            self:_FilterItem("Banker",             "Banker",                385, 859, 32, 32),
            self:_FilterItem("Innkeeper",          "Innkeeper",             521, 451, 32, 32),
            -- Flight Master intentionally omitted: always shown regardless
            -- of this menu (see MinimapTracker:Rebuild — builds the
            -- FlightMaster filter unconditionally).
            self:_FilterItem("Repair",             "Repair",                555, 927, 32, 32),
            self:_FilterItem("Mailbox",            "Mailbox",               453, 519, 32, 32),
            self:_FilterItem("Profession Trainer", "ProfessionTrainer",     864, 521, 29, 29),
            self:_FilterItem("Class Trainer",      "ClassTrainer",          487, 416, 32, 32),
            self:_QuestItem("Quest Objectives",    "showMinimapObjectivePins",     759, 757, 32, 32),
            self:_QuestItem("Quest Area",          "showMinimapObjectiveAreas",    895, 553, 32, 32),
            self:_QuestItem("Low-Level Quests",    "showLowLevelAvailableQuests",  828, 621, 32, 32),
        }

        for _, spellID in ipairs(TRACKING_SPELL_IDS) do
            if IsSpellKnown(spellID, false) then
                local name, _, icon = GetSpellInfo(spellID)
                local override = MUI_IconOverrides and MUI_IconOverrides:GetOverride(spellID)
                if override then icon = override end
                if name then
                    table.insert(items, self:_SpellItem(spellID, name, icon))
                end
            end
        end

        return items
    end;

    _FilterItem = function(self, label, filterKey, x, y, w, h)
        local filters = MUI_DB.settings.minimapTracker.filters
        return {
            type      = "checkbox",
            label     = label,
            filterKey = filterKey,
            checked   = filters[filterKey] and true or false,
            icon      = { file = OBJECTS_ATLAS, fileW = 1024, fileH = 1024,
                          x = x, y = y, w = w, h = h, size = 18 },
            OnChanged = function(item, checked)
                filters[filterKey] = checked
                if MUI_MinimapTracker then
                    MUI_MinimapTracker:OnFilterChanged(filterKey, checked)
                end
            end,
        }
    end;

    _QuestItem = function(self, label, questKey, x, y, w, h)
        local qh = MUI_DB.settings.questHelper
        -- "show low-level quests" defaults OFF; every other quest toggle
        -- defaults ON. Handle both in one expression.
        local defaultOn = questKey ~= "showLowLevelAvailableQuests"
        local stored    = qh[questKey]
        local checked   = (stored == nil) and defaultOn or (stored and true or false)
        return {
            type     = "checkbox",
            label    = label,
            questKey = questKey,
            checked  = checked,
            icon     = { file = OBJECTS_ATLAS, fileW = 1024, fileH = 1024,
                         x = x, y = y, w = w, h = h, size = 18 },
            OnChanged = function(item, c)
                if not MUI_QuestHelper then return end
                if questKey == "showMinimapObjectivePins" then
                    MUI_QuestHelper:SetMinimapObjectivePinsVisible(c)
                elseif questKey == "showMinimapObjectiveAreas" then
                    MUI_QuestHelper:SetMinimapObjectiveAreasVisible(c)
                elseif questKey == "showLowLevelAvailableQuests" then
                    MUI_QuestHelper:SetShowLowLevelAvailableQuests(c)
                end
            end,
        }
    end;

    _SpellItem = function(self, spellID, name, icon)
        local override = SPELL_ICON_OVERRIDES[spellID]
        local iconSpec
        if override then
            iconSpec = { file = OBJECTS_ATLAS, fileW = 1024, fileH = 1024,
                         x = override.x, y = override.y, w = override.w, h = override.h, size = 18 }
        else
            iconSpec = { texture = icon, size = 17, portrait = true }
        end
        return {
            type    = "checkbox",
            label   = name,
            spellID = spellID,
            icon    = iconSpec,
            -- Classic Era only allows one active tracking spell, and casting an already-active
            -- tracking spell re-casts it instead of toggling off (vanilla mechanic). So:
            -- activate via CastSpellByID (auto-swaps from any prior); deactivate via
            -- CancelTrackingBuff (matches the default tracking button's right-click).
            -- MINIMAP_UPDATE_TRACKING then fires and UpdateStates re-syncs the radio group.
            OnChanged = function(item, checked)
                if checked then
                    CastSpellByID(spellID)
                else
                    CancelTrackingBuff()
                end
            end,
        }
    end;

    ClearAll = function(self)
        local filters = MUI_DB.settings.minimapTracker.filters
        for _, item in ipairs(self._items or {}) do
            if item.filterKey and item._checkbox then
                item._checkbox:SetChecked(false)
                filters[item.filterKey] = false
                if MUI_MinimapTracker then
                    MUI_MinimapTracker:OnFilterChanged(item.filterKey, false)
                end
            end
        end
        if GetTrackingTexture() then CancelTrackingBuff() end
    end;

    UpdateStates = function(self)
        local activeTex = GetTrackingTexture()
        for _, item in ipairs(self._items or {}) do
            if item.spellID and item._checkbox then
                local _, _, icon = GetSpellInfo(item.spellID)
                local override = MUI_IconOverrides and MUI_IconOverrides:GetOverride(item.spellID)
                item._checkbox:SetChecked(icon == activeTex or override == activeTex)
            end
        end
    end;
}
