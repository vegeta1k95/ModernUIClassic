-- MinimapBlipAtlasSwapper: swaps the minimap's blip texture between four
-- atlases (default / herbs / ores / treasure) so the yellow "tracked
-- resource" dots render as type-specific icons. Decision inputs:
--   1. Any quest turn-in pin currently visible on the minimap? → force
--      default (don't clobber a yellow ? marker with a herb/ore/treasure
--      sprite).
--   2. Active tracking spell — match its spell-icon against our three
--      atlas-mapped tracking spells (Find Herbs / Minerals / Treasure).
--
-- Debounced QUEST_LOG_UPDATE handling so the atlas doesn't thrash during
-- the burst of events around quest accept / turn-in. A low-frequency poll
-- (0.5s) covers "player walks into a quest pin's view" — quest visibility
-- depends on position, which no event reports.
--
-- Composed into ModuleMinimap as a sub-component, not a separate Module:
--   self.blipSwapper = MinimapBlipAtlasSwapper(self.minimap)

local ATLAS_DEFAULT  = "Interface\\AddOns\\ModernUI\\assets\\textures\\blips-default"
local ATLAS_HERBS    = "Interface\\AddOns\\ModernUI\\assets\\textures\\blips-herbs"
local ATLAS_ORES     = "Interface\\AddOns\\ModernUI\\assets\\textures\\blips-ores"
local ATLAS_TREASURE = "Interface\\AddOns\\ModernUI\\assets\\textures\\blips-treasure"

local SPELL_FIND_HERBS    = 2383
local SPELL_FIND_MINERALS = 2580
local SPELL_FIND_TREASURE = 2481

local DEBOUNCE_SEC = 0.25
local POLL_SEC     = 0.5

class "MinimapBlipAtlasSwapper" {
    __init = function(self, minimap)
        self.minimap          = minimap
        self._current         = nil
        self._debouncePending = false
        self._pollTime        = 0
        self._trackingIconMap = {
            --[133939] = ATLAS_HERBS,
            --[136025] = ATLAS_ORES,
            --[135725] = ATLAS_TREASURE
        }

        local function addIcon(spellID, atlas)
            local _, _, icon = GetSpellInfo(spellID)
            if icon then self._trackingIconMap[icon] = atlas end
            local override = MUI_IconOverrides and MUI_IconOverrides:GetOverride(spellID)
            if override then self._trackingIconMap[override] = atlas end
        end
        addIcon(SPELL_FIND_HERBS,    ATLAS_HERBS)
        addIcon(SPELL_FIND_MINERALS, ATLAS_ORES)
        addIcon(SPELL_FIND_TREASURE, ATLAS_TREASURE)

        self.driver = Frame("Frame", nil, "MUI_BlipAtlasSwapperDriver")
        self.driver:RegisterEventHandler("MINIMAP_UPDATE_TRACKING", function() self:_Recompute() end)
        self.driver:RegisterEventHandler("ZONE_CHANGED_NEW_AREA",   function() self:_Recompute() end)
        self.driver:RegisterEventHandler("PLAYER_ENTERING_WORLD",   function() self:_Recompute() end)
        self.driver:RegisterEventHandler("QUEST_LOG_UPDATE",        function() self:_ScheduleRecompute() end)

        -- Position-driven quest-pin visibility has no corresponding event,
        -- so poll twice a second. Recompute no-ops when the chosen atlas
        -- matches the current one.
        self.driver:SetScript("OnUpdate", function(_, elapsed)
            self._pollTime = self._pollTime + elapsed
            if self._pollTime < POLL_SEC then return end
            self._pollTime = 0
            self:_Recompute()
        end)

        self:_Recompute()
    end;

    _ScheduleRecompute = function(self)
        if self._debouncePending then return end
        self._debouncePending = true
        C_Timer.After(DEBOUNCE_SEC, function()
            self._debouncePending = false
            self:_Recompute()
        end)
    end;

    _Recompute = function(self)
        local target = self:_ChooseAtlas()
        if target ~= self._current then
            self.minimap:SetBlipTexture(target)
            self._current = target
        end
    end;

    _ChooseAtlas = function(self)
        -- Turn-in ? marker wins: fall back to the default atlas so a yellow
        -- ? never renders through the herb/ore/treasure atlas. Objective
        -- pins and grey ? in-progress reminders don't trigger the fallback.

        if MUI_QuestHelper:HasVisibleMinimapTurnInPinInRange() then
            return ATLAS_DEFAULT
        end
        local trackingIcon = GetTrackingTexture()
        --print(trackingIcon)
        if trackingIcon and self._trackingIconMap[trackingIcon] then
            --print("pidor")
            return self._trackingIconMap[trackingIcon]
        end
        return ATLAS_DEFAULT
    end;
}
