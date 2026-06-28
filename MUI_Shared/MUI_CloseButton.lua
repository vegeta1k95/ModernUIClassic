-- CloseButton: Retail-style red X close button
-- Plain Button (NOT SecureButton). Putting a SecureButton inside a frame
-- implicitly protects the parent — every Show/Hide/SetPoint on that parent
-- then needs secure context. For panels that need combat-safe close, the
-- close action goes through Blizzard's secure path anyway (CloseTradeSkill,
-- HideUIPanel, CloseAllWindows via ESC/UISpecialFrames). When that's not
-- available (e.g. fully addon-owned frames like ProfessionsOverview),
-- combat-X simply does nothing; ESC + keybinding cover the combat case.

class "CloseButton" : extends "Button" {
    __init = function(self, parent, name)
        Button.__init(self, parent, name)

        local atlas = MUI_AtlasRegistry.ButtonRedControl
        self:SetStateAtlas(atlas, "ExitNormal", "ExitPressed", "ExitDisabled")
        self:SetHighlightAtlas(atlas, "Highlight", true)

        self:SetSize(23, 24.5)
        self:AlignParentTopRight(0, -1)
        self:SetFrameLevel(parent:GetFrameLevel() + 20)
        self:AlignParentTopRight(-2, -0.5)

        -- Default OnClick: hide parent. Override by setting self.OnClick on
        -- the instance after construction (e.g., TradeSkill overlay calls
        -- CloseTradeSkill() so Blizzard's UIPanel system cleans up).
        self.OnClick = function()
            if parent then
                parent:Hide()
            end
        end
    end;
}

class "SecureCloseButton" : extends "SecureButton" {
    __init = function(self, parent, name, target)
        SecureButton.__init(self, parent, name, "SecureHandlerShowHideTemplate")

        local atlas = MUI_AtlasRegistry.ButtonRedControl
        self:SetStateAtlas(atlas, "ExitNormal", "ExitPressed", "ExitDisabled")
        self:SetHighlightAtlas(atlas, "Highlight", true)

        self:SetSize(23, 24.5)
        self:AlignParentTopRight(0, -1)
        self:SetFrameLevel(parent:GetFrameLevel() + 20)
        self:AlignParentTopRight(-2, -0.5)

        -- Default OnClick: hide parent. Override by setting self.OnClick on
        -- the instance after construction (e.g., TradeSkill overlay calls
        -- CloseTradeSkill() so Blizzard's UIPanel system cleans up).

        self:SetFrameRef("target", target or parent)
        self:SetOnClick([[
            self:GetFrameRef("target"):Hide()
        ]])

        -- Close on ESC in combat too. UISpecialFrames hides via the insecure
        -- CloseSpecialWindows, blocked on this protected frame. Bind ESCAPE to
        -- a secure close-button click while shown and clear it when hidden,
        -- driven by the frame's own secure OnShow/OnHide (works in combat).
        self:SetAttribute("_onshow", string.format([[ self:SetBindingClick(true, "ESCAPE", "%s") ]], name))
        self:SetAttribute("_onhide", [[ self:ClearBinding("ESCAPE") ]])

    end;
}