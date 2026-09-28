-- Reskin the Blizzard Settings panel + AddonList (both ButtonFrameTemplate) to
-- modern metal chrome via MUI_PanelChrome, and keep the Settings panel scaled +
-- centered. Both are no-portrait frames, so they use the plain metal corner.

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
        -- AddonList.CloseButton IS the top-right X, so the default close target works.
        local function apply()
            MUI_PanelChrome:Apply(AddonList, { noPortrait = true })
            MUI_PanelChrome:SetTitle(AddonList)  -- mirror Blizzard's "AddOns"
        end

        apply()
        panel:HookScript("OnShow", apply)
    end;

    AdjustSettingsPanel = function(self)
        if not SettingsPanel then return end

        local panel = Frame(SettingsPanel)

        -- SettingsPanel is protected: SetScale / SetPoint are blocked in combat,
        -- and the panel can open mid-combat (another addon triggers it). So only
        -- reposition out of combat; the chrome itself is non-protected and always
        -- applies. PLAYER_REGEN_ENABLED reapplies the position once combat ends.
        local function reposition()
            if InCombatLockdown() then return end
            panel:SetScale(0.9)
            panel:ClearAllPoints()
            panel:CenterInParent(0, 122)
        end

        local function apply()
            -- SettingsPanel's top-right X is .ClosePanelButton; its .CloseButton is
            -- the bottom "Close" action button — leave that alone, so skip the
            -- default close here and modernize ClosePanelButton explicitly.
            MUI_PanelChrome:Apply(SettingsPanel, { noPortrait = true, skipClose = true })
            if SettingsPanel.ClosePanelButton then
                MUI_PanelChrome:ModernizeCloseButton(SettingsPanel, SettingsPanel.ClosePanelButton)
            end
            MUI_PanelChrome:SetTitle(SettingsPanel)  -- mirror Blizzard's SETTINGS_TITLE
            reposition()
        end

        apply()
        panel:HookScript("OnShow", apply)
        panel:RegisterEventHandler("PLAYER_REGEN_ENABLED", function()
            if panel:IsShown() then apply() end
        end)
    end;
}
