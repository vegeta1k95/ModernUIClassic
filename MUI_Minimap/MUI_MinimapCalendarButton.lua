-- MinimapCalendarButton: retail's GameTimeFrame — today's date on a calendar
-- leaf beside the minimap's top bar. A click opens the calendar
-- (MUI_ModuleCalendar); invitations waiting for an answer make it flash.
-- Era's own GameTimeFrame (a day / night dial with no calendar) stays hidden.

local SHEET = MUI.TEX_SKIN .. "minimap\\calendar"   -- retail's interface/hud/uicalendar
local CELL_W, CELL_H = 21, 19
local PULSE = 0.5   -- flashes a second (retail's INVITE_PULSE_SEC)

-- Each day's leaf on the sheet: its up, pressed and hovered cells' left, top.
local CELLS = {
    [1] = { up = { 47, 1 }, down = { 1, 1 }, over = { 24, 1 } },
    [2] = { up = { 93, 43 }, down = { 47, 43 }, over = { 70, 43 } },
    [3] = { up = { 70, 85 }, down = { 47, 211 }, over = { 47, 232 } },
    [4] = { up = { 70, 127 }, down = { 231, 85 }, over = { 70, 106 } },
    [5] = { up = { 70, 190 }, down = { 70, 148 }, over = { 70, 169 } },
    [6] = { up = { 93, 106 }, down = { 70, 211 }, over = { 70, 232 } },
    [7] = { up = { 162, 106 }, down = { 116, 106 }, over = { 139, 106 } },
    [8] = { up = { 231, 106 }, down = { 185, 106 }, over = { 208, 106 } },
    [9] = { up = { 93, 169 }, down = { 93, 127 }, over = { 93, 148 } },
    [10] = { up = { 116, 1 }, down = { 70, 1 }, over = { 93, 1 } },
    [11] = { up = { 185, 1 }, down = { 139, 1 }, over = { 162, 1 } },
    [12] = { up = { 1, 22 }, down = { 208, 1 }, over = { 231, 1 } },
    [13] = { up = { 70, 22 }, down = { 24, 22 }, over = { 47, 22 } },
    [14] = { up = { 139, 22 }, down = { 93, 22 }, over = { 116, 22 } },
    [15] = { up = { 208, 22 }, down = { 162, 22 }, over = { 185, 22 } },
    [16] = { up = { 1, 64 }, down = { 231, 22 }, over = { 1, 43 } },
    [17] = { up = { 1, 127 }, down = { 1, 85 }, over = { 1, 106 } },
    [18] = { up = { 1, 190 }, down = { 1, 148 }, over = { 1, 169 } },
    [19] = { up = { 24, 43 }, down = { 1, 211 }, over = { 1, 232 } },
    [20] = { up = { 162, 43 }, down = { 116, 43 }, over = { 139, 43 } },
    [21] = { up = { 231, 43 }, down = { 185, 43 }, over = { 208, 43 } },
    [22] = { up = { 24, 106 }, down = { 24, 64 }, over = { 24, 85 } },
    [23] = { up = { 24, 169 }, down = { 24, 127 }, over = { 24, 148 } },
    [24] = { up = { 24, 232 }, down = { 24, 190 }, over = { 24, 211 } },
    [25] = { up = { 93, 64 }, down = { 47, 64 }, over = { 70, 64 } },
    [26] = { up = { 162, 64 }, down = { 116, 64 }, over = { 139, 64 } },
    [27] = { up = { 231, 64 }, down = { 185, 64 }, over = { 208, 64 } },
    [28] = { up = { 47, 127 }, down = { 47, 85 }, over = { 47, 106 } },
    [29] = { up = { 47, 190 }, down = { 47, 148 }, over = { 47, 169 } },
    [30] = { up = { 139, 85 }, down = { 93, 85 }, over = { 116, 85 } },
    [31] = { up = { 208, 85 }, down = { 162, 85 }, over = { 185, 85 } },
}

class "MinimapCalendarButton" : extends "Button" {
    __init = function(self, parent)
        Button.__init(self, parent, "MUI_MinimapCalendarButton")
        self:SetSize(19, 18)
        self:SetFrameLevel(self:GetFrameLevel() + 2)   -- as retail: over the bar and its clock
        self:RegisterForClicks("AnyUp")
        self:SetClickSound(nil)

        self._invites = Texture(self, nil, "ARTWORK")
        self._invites:SetTexture("Interface\\Calendar\\EventNotification")
        self._invites:SetTexCoord(0.03125, 0.6484375, 0.03125, 0.8671875)
        self._invites:SetSize(28, 32)
        self._invites:CenterInParent(0, 1)
        self._invites:Hide()
        self._glow = Texture(self, nil, "ARTWORK")
        self._glow:SetTexture("Interface\\Calendar\\EventNotificationGlow")
        self._glow:SetBlendMode("ADD")
        self._glow:SetSize(48, 48)
        self._glow:CenterInParent(0, 2)
        self._glow:Hide()

        self._pending = 0
        self._flash = 0
        self._check = 0
        self:SetScript("OnUpdate", function(_, elapsed) self:_OnUpdate(elapsed) end)
        self:RegisterEventHandler("CALENDAR_UPDATE_PENDING_INVITES", function() self:_Refresh() end)
        self:RegisterEventHandler("PLAYER_ENTERING_WORLD", function() self:_Refresh() end)
        self:_Refresh()

        self:SetTooltip("ANCHOR_BOTTOMLEFT", function(tooltip)
            if self._invites:IsShown() then
                tooltip:AddLine(GAMETIME_TOOLTIP_CALENDAR_INVITES, 1, 1, 1, true, 13)
                tooltip:AddBlank()
            end
            tooltip:AddLine(GAMETIME_TOOLTIP_TOGGLE_CALENDAR, 1, 0.82, 0, true)
        end)
    end;

    -- Retail's GameTimeFrame_OnClick: with invitations waiting, the calendar
    -- opens and the flashing stops.
    OnClick = function(self)
        if self._invites:IsShown() then
            MUI_ModuleCalendar.window:Show()
            self:_SetFlashing(false)
            self._pending = 0
        else
            MUI_ModuleCalendar:Toggle()
        end
    end;

    -- New invitations flash it while the calendar is closed.
    _Refresh = function(self)
        local pending = C_Calendar.GetNumPendingInvites()
        if pending > self._pending then
            if not MUI_ModuleCalendar.window or not MUI_ModuleCalendar.window:IsShown() then
                self:_SetFlashing(true)
                self._pending = pending
            end
        elseif pending == 0 then
            self:_SetFlashing(false)
            self._pending = 0
        end
        self:_SetDate()
    end;

    _SetFlashing = function(self, flashing)
        self._invites:SetVisible(flashing)
        self._glow:SetVisible(flashing)
        self._flash = 0
    end;

    -- Today's leaf, up, pressed and hovered.
    _SetDate = function(self)
        local day = C_DateAndTime.GetCurrentCalendarTime().monthDay
        if day == self._day then return end
        self._day = day
        local cell = CELLS[day]
        self:SetNormalTexture(SHEET):SetTextureRegion(SHEET, 256, 256, cell.up[1], cell.up[2], CELL_W, CELL_H)
        self:SetPushedTexture(SHEET):SetTextureRegion(SHEET, 256, 256, cell.down[1], cell.down[2], CELL_W, CELL_H)
        self:SetHighlightTexture(SHEET):SetTextureRegion(SHEET, 256, 256, cell.over[1], cell.over[2], CELL_W, CELL_H)
    end;

    _OnUpdate = function(self, elapsed)
        -- The date turns over at midnight; a look every few seconds will do.
        self._check = self._check - elapsed
        if self._check <= 0 then
            self._check = 5
            self:_SetDate()
        end
        if self._invites:IsShown() then
            self._flash = (self._flash + elapsed * PULSE) % 1
            local alpha = math.max(0, 0.5 + 0.5 * math.cos(2 * math.pi * self._flash))
            self._invites:SetAlpha(alpha)
            self._glow:SetAlpha(alpha)
        end
    end;
}
