-- MUI_CharacterModel: a unit's model that turns under the mouse and zooms on
-- the wheel, with retail's control bar (ModelSceneControlFrame) over its top
-- while the cursor is on it.
--
--   CharacterModel(stage, name, unit, facing)
--     stage      the frame the model fills: its rect is what the cursor is
--                tested against
--     :Refresh() take the unit's model again (it changed, or the frame showed)
--     :Reset()   back to the starting facing and zoom

local BUTTONS = "Interface\\Common\\CommonButtons"
local ICONS   = "Interface\\Common\\CommonIcons"

local DRAG_TURN   = 0.010          -- radians a pixel of drag turns the model
local TURN_SPEED  = math.pi        -- radians a second under a rotate button
local ZOOM_STEP   = 0.15
local ZOOM_MAX    = 0.8
local ZOOM_REPEAT = 0.1            -- seconds between steps under a zoom button

local BUTTON_SIZE, BUTTON_OVERLAP = 32, 6

-- ---------------------------------------------------------------------
-- CharacterModelButton: one square of the control bar. `action` is what the
-- model does while it is held.
-- ---------------------------------------------------------------------
class "CharacterModelButton" : extends "Button" {
    __init = function(self, parent, model, action, l, r, t, b)
        Button.__init(self, parent)
        self:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        self:SetHitRectInsets(4, 4, 4, 4)
        self:SetClickSound(nil)

        self:SetNormalTexture(BUTTONS):SetTexCoord(0.000977, 0.250977, 0.536133, 0.786133)
        local pushed = self:SetPushedTexture(BUTTONS)
        pushed:SetTexCoord(0.000977, 0.250977, 0.284180, 0.534180)
        pushed:ClearAllPoints()
        pushed:FillParentPadding(1, 1, -1, -1)

        self._icon = Texture(self, nil, "OVERLAY")
        self._icon:SetTexture(ICONS)
        self._icon:SetTexCoord(l, r, t, b)
        self._icon:SetSize(16, 16)
        self._icon:CenterInParent()

        local glow = Texture(self, nil, "HIGHLIGHT")
        glow:SetTexture(ICONS)
        glow:SetTexCoord(l, r, t, b)
        glow:SetBlendMode("ADD")
        glow:SetAlpha(0.4)
        glow:Fill(self._icon)

        self:SetScript("OnMouseDown", function()
            self:_Press(1, -1)
            model:Hold(action)
        end)
        self:SetScript("OnMouseUp", function()
            self:_Press(0, 0)
            model:Hold(nil)
        end)
    end;

    _Press = function(self, x, y)
        self._icon:ClearAllPoints()
        self._icon:CenterInParent(x, y)
    end;
}

-- ---------------------------------------------------------------------
-- CharacterModelBar: the control bar over a model's top — zoom in, zoom
-- out, turn left, turn right, reset. The model is told what is held:
-- model:Hold(action), and model:Hold(nil) when it is let go.
-- ---------------------------------------------------------------------
class "CharacterModelBar" : extends "Frame" {
    __init = function(self, model)
        Frame.__init(self, "Frame", model)
        self:SetSize(5 * BUTTON_SIZE - 4 * BUTTON_OVERLAP, BUTTON_SIZE)
        self:AlignParentTop(10)
        self:Hide()

        local specs = {
            { "in",    0.504395, 0.629395, 0.000977, 0.250977 },
            { "out",   0.756348, 0.881348, 0.000977, 0.250977 },
            { "left",  0.126465, 0.175293, 0.756836, 0.854492 },
            { "right", 0.126465, 0.175293, 0.856445, 0.954102 },
            { "reset", 0.378418, 0.503418, 0.252930, 0.502930 },
        }
        for i, spec in ipairs(specs) do
            local button = CharacterModelButton(self, model, spec[1], spec[2], spec[3], spec[4], spec[5])
            button:AlignParentLeft((i - 1) * (BUTTON_SIZE - BUTTON_OVERLAP))
        end
    end;
}

-- ---------------------------------------------------------------------
-- CharacterModel
-- ---------------------------------------------------------------------
class "CharacterModel" : extends "PlayerModel" {
    __init = function(self, stage, name, unit, facing)
        PlayerModel.__init(self, stage, name)
        self:FillParent()
        self.unit = unit
        self._stage  = stage
        self._home   = facing or 0
        self._facing = self._home
        self._zoom   = 0
        self._held   = nil         -- the control button action in progress
        self._since  = 0

        self:EnableMouse(true)
        self:EnableMouseWheel(true)
        self:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" then self._dragFrom = GetCursorPosition() end
        end)
        self:SetScript("OnMouseUp", function() self._dragFrom = nil end)
        self:SetScript("OnMouseWheel", function(_, delta) self:Zoom(delta) end)
        self:SetScript("OnShow", function() self:Refresh() end)
        self:SetScript("OnHide", function()
            self._dragFrom = nil
            self._held = nil
        end)
        self:SetScript("OnUpdate", function(_, elapsed) self:_OnUpdate(elapsed) end)
        self:RegisterUnitEventHandler("UNIT_MODEL_CHANGED", unit, function(_, _, changed)
            if changed == unit and self:IsVisible() then self:Refresh() end
        end)

        -- Half faded until the cursor is on the bar itself.
        self._bar = CharacterModelBar(self)
    end;

    Refresh = function(self)
        self:SetUnit(self.unit)
        self:SetFacing(self._facing)
        self:SetPortraitZoom(self._zoom)
    end;

    Reset = function(self)
        self._facing = self._home
        self._zoom   = 0
        self:SetFacing(self._facing)
        self:SetPortraitZoom(self._zoom)
    end;

    Turn = function(self, radians)
        self._facing = (self._facing + radians) % (2 * math.pi)
        self:SetFacing(self._facing)
    end;

    Zoom = function(self, steps)
        self._zoom = math.min(ZOOM_MAX, math.max(0, self._zoom + steps * ZOOM_STEP))
        self:SetPortraitZoom(self._zoom)
    end;

    -- A control button went down (`action`) or came back up (nil). A zoom
    -- takes its first step at once and repeats while held.
    Hold = function(self, action)
        self._held  = action
        self._since = 0
        if action == "in" then
            self:Zoom(1)
        elseif action == "out" then
            self:Zoom(-1)
        elseif action == "reset" then
            self:Reset()
        end
    end;

    _OnUpdate = function(self, elapsed)
        if self._dragFrom then
            local x = GetCursorPosition()
            self:Turn((x - self._dragFrom) * DRAG_TURN)
            self._dragFrom = x
        elseif self._held == "left" then
            self:Turn(TURN_SPEED * elapsed)
        elseif self._held == "right" then
            self:Turn(-TURN_SPEED * elapsed)
        elseif self._held == "in" or self._held == "out" then
            self._since = self._since + elapsed
            if self._since >= ZOOM_REPEAT then
                self._since = 0
                self:Zoom(self._held == "in" and 1 or -1)
            end
        end

        local over = self._stage:IsMouseOver()
        self._bar:SetVisible(over or self._held ~= nil)
        self._bar:SetAlpha(self._bar:IsMouseOver() and 1 or 0.5)
    end;
}
