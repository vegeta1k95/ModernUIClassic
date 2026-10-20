-- MUI_Inspect: retail's inspect window on Classic Era.
--
--   MUI_InspectFrame       the window, on Era's own InspectFrame: the
--                          chrome, the tabs, the pane each tab shows
--   MUI_InspectPaperDoll   the Character tab
--   MUI_InspectHonor       the Honor tab, in place of retail's PvP tab
--   MUI_InspectGuild       the Guild tab
--
-- Made of the character window's pieces (MUI_Character): its tabs, its
-- model, the paper doll's stage and border, the honor sheet.
--
-- Not carried over from retail, which Era has nothing for: the Talents
-- button (vanilla servers don't send an inspected player's talents), the
-- PvP tab's ratings and PvP talents, the guild's achievement points.

object "ModuleInspect" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Inspect")
    end;

    -- Era's inspect UI loads the first time a player is inspected.
    OnEnable = function(self)
        if C_AddOns.IsAddOnLoaded("Blizzard_InspectUI") then
            self.window = InspectWindow()
            return
        end
        self._loader = Frame()
        self._loader:RegisterEventHandler("ADDON_LOADED", function(_, _, addon)
            if addon == "Blizzard_InspectUI" then
                self._loader:UnregisterEventHandler("ADDON_LOADED")
                self.window = InspectWindow()
            end
        end)
    end;
}
