-- Customize the default Blizzard Settings panel (scale, position).

object "ModuleOptions" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Options")
    end;

    OnEnable = function(self)
        self:AdjustSettingsPanel()
        self:ReskinAddonList()
    end;

    ReskinAddonList = function(self)
        if not AddonList then return end

        local panel = Frame(AddonList)

        -- Hide everything ButtonFrameTemplate provides (portrait, title bar, nineslice, inset, etc.)
        local function hideNative()
            for _, key in ipairs({
                "NineSlice", "Bg", "Inset",
                "PortraitContainer", "TitleContainer",
                "TopTileStreaks", "LeftBorder", "RightBorder",
                "TopBorder", "BottomBorder",
                "TopLeftCorner", "TopRightCorner",
                "BotLeftCorner", "BotRightCorner",
                "BtnCornerLeft", "BtnCornerRight",
                "ButtonBottomBorder",
                "PortraitFrame",
            }) do
                local r = AddonList[key]
                if r and r.Hide then Frame(r):Hide() end
            end
            if AddonList.Inset then
                local insetBg = AddonList.Inset.Bg or AddonList.Inset.NineSlice
                if insetBg and insetBg.Hide then Frame(insetBg):Hide() end
                for _, r in ipairs(Frame(AddonList.Inset):GetRegions()) do
                    if r:GetObjectType() == "Texture" then
                        r:Hide()
                    end
                end
            end
            for _, g in ipairs({
                "AddonListTitleBg", "AddonListTitleText", "AddonListPortrait", "AddonListBg",
                "AddonListPortraitFrame",
                "AddonListTopBorder", "AddonListBottomBorder",
                "AddonListLeftBorder", "AddonListRightBorder",
                "AddonListTopLeftCorner", "AddonListTopRightCorner",
                "AddonListBotLeftCorner", "AddonListBotRightCorner",
                "AddonListBtnCornerLeft", "AddonListBtnCornerRight",
                "AddonListButtonBottomBorder",
            }) do
                local o = getglobal(g)
                if o and o.Hide then Frame(o):Hide() end
            end
        end

        local function apply()
            hideNative()
            if not self.addonBorder then
                self.addonBorder = Panel(panel, "MUI_AddonListBorder", "")
                self.addonBorder:FillParent(-1)
                self.addonBorder:SetFrameLevel(0)
                self.addonBorder:SetCloseVisible(false)

                -- Reskin native AddonList.CloseButton in place (keeps its secure OnClick,
                -- works in combat). Hide our custom close.
                if self.addonBorder.closeButton then
                    self.addonBorder.closeButton:Hide()
                end

                if AddonList.CloseButton then
                    local closeBtn = Button(AddonList.CloseButton)
                    local atlas = MUI_AtlasRegistry.ButtonRedControl
                    closeBtn:SetStateAtlas(atlas, "ExitNormal", "ExitPressed", "ExitDisabled")
                    closeBtn:SetHighlightAtlas(atlas, "Highlight", true)
                    closeBtn:SetSize(24, 24)
                    closeBtn:ClearAllPoints()
                    closeBtn:SetPoint("TOPRIGHT", self.addonBorder, "TOPRIGHT", 1, 0)
                    closeBtn:SetFrameLevel(panel:GetFrameLevel() + 20)
                end

            end
        end

        apply()
        panel:HookScript("OnShow", apply)
    end;

    AdjustSettingsPanel = function(self)
        if not SettingsPanel then return end

        local panel = Frame(SettingsPanel)

        local function hideNative()
            -- NOTE: SettingsPanel.CloseButton is the BOTTOM "Close" action button
            -- (UIPanelButtonTemplate), not a top-right X — keep it visible.
            for _, key in ipairs({
                "NineSlice", "Bg", "Inset",
                "PortraitContainer", "TitleContainer",
                "TopTileStreaks", "LeftBorder", "RightBorder",
                "TopBorder", "BottomBorder",
                "TopLeftCorner", "TopRightCorner",
                "BotLeftCorner", "BotRightCorner",
                "BtnCornerLeft", "BtnCornerRight",
                "ButtonBottomBorder",
            }) do
                local r = SettingsPanel[key]
                if r and r.Hide then Frame(r):Hide() end
            end
            for _, g in ipairs({
                "SettingsPanelTitleBg",
                "SettingsPanelTitleText",
                "SettingsPanelBg",
                "SettingsPanelTopBorder", "SettingsPanelBottomBorder",
                "SettingsPanelLeftBorder", "SettingsPanelRightBorder",
                "SettingsPanelTopLeftCorner", "SettingsPanelTopRightCorner",
                "SettingsPanelBotLeftCorner", "SettingsPanelBotRightCorner",
                "SettingsPanel.ClosePanelButton"
            }) do
                local o = getglobal(g)
                if o and o.Hide then Frame(o):Hide() end
            end
        end

        local function apply()
            -- SettingsPanel is protected. SetScale/ClearAllPoints/SetPoint on
            -- it from tainted code is blocked in combat. SettingsPanel can
            -- open mid-combat (e.g., another addon triggers it), so skip the
            -- repositioning then; the panel stays at whatever position it
            -- last had. PLAYER_REGEN_ENABLED reapplies once combat ends.
            if InCombatLockdown() then return end
            panel:SetScale(0.9)
            panel:ClearAllPoints()
            panel:CenterInParent(0, 122)
            hideNative()
        end

        apply()
        panel:HookScript("OnShow", apply)
        panel:RegisterEventHandler("PLAYER_REGEN_ENABLED", function()
            if panel:IsShown() then apply() end
        end)

        hideNative()

        if not self.border then
            self.border = Panel(panel, "MUI_SettingsPanelBorder", "Options")
            self.border:FillParent()
            self.border:SetFrameLevel(0)
            self.border:SetCloseVisible(false)

            -- SettingsPanel: reskin the top-right X (ClosePanelButton, from SettingsFrameTemplate
            -- via UIPanelCloseButtonDefaultAnchors). The bottom "Close" is SettingsPanel.CloseButton
            -- — leave it alone. Hide our custom X.
            if self.border.closeButton then
                self.border.closeButton:Hide()
            end
            if SettingsPanel.ClosePanelButton then
                local closeBtn = Button(SettingsPanel.ClosePanelButton)
                local atlas = MUI_AtlasRegistry.ButtonRedControl
                closeBtn:SetStateAtlas(atlas, "ExitNormal", "ExitPressed", "ExitDisabled")
                closeBtn:SetHighlightAtlas(atlas, "Highlight", true)
                closeBtn:SetSize(24, 24)
                closeBtn:ClearAllPoints()
                closeBtn:SetPoint("TOPRIGHT", self.border, "TOPRIGHT", 1, 0)
                closeBtn:SetFrameLevel(panel:GetFrameLevel() + 20)
            end
        end
    end;
}
