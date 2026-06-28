
local FRAME_WIDTH = 1459
local FRAME_HEIGHT = 792.5

object "ClassBookFrame" : extends {"PanelPortrait", "SecureFrame"} {

    __init = function(self)
        SecureFrame.__init(self, nil, "MUI_ClassBookFrame", "Frame")
        PanelPortrait.__init(self, nil, nil, "Specializations")

        self:Hide()
        self:SetFrameStrata("DIALOG")

        self._bg:SetTextureRegion(MUI.TEX_SKIN .. "talents\\spec", 2048, 2048, 0, 0, 1614, 858)

        self:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
        self:AlignParentTop(38.5, -2.5)

        self._closeButton = SecureCloseButton(self, "MUI_ClassBookCloseButton")
        self._closeButton:SetScale(scale or 0.9)
        self._closeButton:PutInfront(self._border, 1)

        self:_HookBindings()
        self:_HookPortraitUpdate()
        self:_HookPanels()

        self:HookScript("OnShow", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN) end)
        self:HookScript("OnHide", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end)

    end;

    ---@override
    PopulateContent = function(self, content)
        self._tabSpecs = TabSpecializations(content)
        self._tabTalents = TabTalents(content)
        self._tabSpellbook = TabSpellbook(content)

        self._tabTalents:Hide()
        self._tabSpellbook:Hide()

        self._tabs = TabGroup(self, "MUI_ClassBookTabs", TabFrame, "bottom", -7)
        self._tabs:SetSilent(true)
        self._tabs:SetSize(1, 1)
        self._tabs:Below(self, -1)
        self._tabs:AlignLeft(self, 23)
        self._tabs.OnTabSelected = function(_, tab)
            if tab == 1 then
                self:SetTitle("Specializations")
            elseif tab == 2 then
                self:SetTitle("Talents")
            else
                self:SetTitle("Spellbook")
            end
        end

        local t1 = self._tabs:AddTab("MUI_ClassbookTabBtnSpecs", "Specializations", self._tabSpecs, 98, 200, 4)
        local t2 = self._tabs:AddTab("MUI_ClassbookTabBtnTalents", "Talents", self._tabTalents, 98, 200, 4)
        local t3 = self._tabs:AddTab("MUI_ClassbookTabBtnSpellbook", "Spellbook", self._tabSpellbook, 98, 200, 4)

        local script = [[ -- (self, button, down)
            local oldIndex = group:GetAttribute("index")
            local newIndex = %d
            if oldIndex == newIndex and classbook:IsShown() and (button == "Keybind" or button == "Macro") then
                classbook:Hide()
            else
                classbook:Show()
            end
        ]]

        local postSound = function(_, button, _)
            if button ~= "Macro" and button ~= "Keybind" then
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            end
        end

        t1:HookScript("OnClick", postSound)

        t2:SetFrameRef("classbook", self)
        t2:SecureWrapScript(t2, "OnClick", string.format(script, 2), "")
        t2:HookScript("OnClick", postSound)

        t3:SetFrameRef("classbook", self)
        t3:SecureWrapScript(t3, "OnClick", string.format(script, 3), "")
        t3:HookScript("OnClick", postSound)

    end;

    GoToTalents = function(self, spec)
        self._tabTalents:SetSpec(spec or 1)
    end;

    _HookPortraitUpdate = function(self)
        local function PortraitUpdate()
            local spec = MUI_Talents:GetPrimarySpec()
            if spec then
                self:SetPortrait(MUI_SPEC_ICONS[MUI.GetClassID()][spec.index], 50)
            else
                self:SetPortrait(MUI.TEX_SKIN .. "professions\\professions-book-icon")
            end
        end
        -- Hook character portrait on talents changes / dual spec change
        self:RegisterEventHandler("PLAYER_ENTERING_WORLD", PortraitUpdate)
        self:RegisterEventHandler("CHARACTER_POINTS_CHANGED", PortraitUpdate)
        self:RegisterEventHandler("ACTIVE_TALENT_GROUP_CHANGED", PortraitUpdate)

    end;

    _HookBindings = function(self)

        self:RegisterEventHandler("UPDATE_BINDINGS", function()

            local s1, s2 = GetBindingKey("TOGGLESPELLBOOK")
            local n1, n2 = GetBindingKey("TOGGLETALENTS")

            if s1 then self:SetOverrideBindingClick(false, s1, "MUI_ClassbookTabBtnSpellbook", "Keybind") end
            if s2 then self:SetOverrideBindingClick(false, s2, "MUI_ClassbookTabBtnSpellbook", "Keybind") end

            if n1 then self:SetOverrideBindingClick(false, n1, "MUI_ClassbookTabBtnTalents", "Keybind") end
            if n2 then self:SetOverrideBindingClick(false, n2, "MUI_ClassbookTabBtnTalents", "Keybind") end

        end)

    end;

    -- QoL: ClassBook and Blizzard UIPanels are mutually exclusive out of
    -- combat. Opening a UIPanel closes the book; opening the book closes the
    -- panels. Combat-guarded — neither auto-closes in combat, where hiding a
    -- protected frame / HideUIPanel would be blocked.
    _HookPanels = function(self)
        hooksecurefunc("ShowUIPanel", function()
            if not InCombatLockdown() and self:IsShown() then
                self:Hide()
            end
        end)
        self:HookScript("OnShow", function()
            if not InCombatLockdown() then
                CloseWindows()
            end
        end)
    end;

}