-- MUI_DressingRoomModel: Era's dressing room model, handled as retail's is —
-- a left drag turns it, a right drag moves it, the wheel zooms, and retail's
-- control bar (the character window's) shows over its top while the cursor
-- is on it.
--
-- The model stays Era's own DressUpModelFrame: DressUpVisual tries items on
-- that frame by name. Zooming and moving are Era's model functions
-- (Blizzard_SharedXML ModelFrames.lua), which keep their state on the frame
-- and whose update still runs; the turn is kept here, in place of Era's
-- (its two rotate buttons are gone).
--
--   DressingRoomModel(over)
--     over       the frame the model shows over
--     :Reset()   the facing, zoom and place the room opens with

local S = 0.9

-- Retail stands the player at one angle on its character sheet and in its
-- dressing room: the character window's.
local FACING      = 0.35
local DRAG_TURN   = 0.010          -- radians a pixel of drag turns the model
local TURN_SPEED  = math.pi        -- radians a second under a rotate button
local ZOOM_REPEAT = 0.1            -- seconds between steps under a zoom button
-- Era zooms from 0 to MODELFRAME_MAX_PLAYER_ZOOM a MODELFRAME_ZOOM_STEP at a
-- time: this many steps out is all the way out from anywhere.
local ZOOM_OUT = -math.ceil(MODELFRAME_MAX_PLAYER_ZOOM / MODELFRAME_ZOOM_STEP)

class "DressingRoomModel" : extends "DressUpModel" {
    __init = function(self, over)
        DressUpModel.__init(self, DressUpModelFrame)
        self:PutInfront(over, 1)
        self._facing = FACING
        self._held   = nil         -- the control button action in progress
        self._since  = 0

        Frame(DressUpModelFrameRotateLeftButton):Hide()
        Frame(DressUpModelFrameRotateRightButton):Hide()

        self:EnableMouse(true)
        self:EnableMouseWheel(true)
        self:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" then
                self._dragFrom = GetCursorPosition()
            elseif button == "RightButton" then
                Model_StartPanning(DressUpModelFrame)
            end
        end)
        self:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then
                self._dragFrom = nil
            elseif button == "RightButton" then
                Model_StopPanning(DressUpModelFrame)
            end
        end)
        self:SetScript("OnMouseWheel", function(_, delta) self:Zoom(delta) end)
        self:HookScript("OnUpdate", function(_, elapsed) self:_OnUpdate(elapsed) end)
        self:HookScript("OnHide", function()
            self._dragFrom = nil
            self._held = nil
            Model_StopPanning(DressUpModelFrame)
        end)

        -- Half faded until the cursor is on the bar itself.
        self._bar = CharacterModelBar(self)
        self._bar:SetScale(S)
    end;

    Reset = function(self)
        self._facing = FACING
        self:SetRotation(self._facing, false)
        self:SetPosition(0, 0, 0)
        self:Zoom(ZOOM_OUT)
    end;

    Turn = function(self, radians)
        self._facing = (self._facing + radians) % (2 * math.pi)
        self:SetRotation(self._facing, false)
    end;

    Zoom = function(self, steps)
        Model_OnMouseWheel(DressUpModelFrame, steps)
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

        self._bar:SetVisible(self:IsMouseOver() or self._held ~= nil)
        self._bar:SetAlpha(self._bar:IsMouseOver() and 1 or 0.5)
    end;
}
