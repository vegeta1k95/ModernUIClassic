-- MUI_CalendarDay: a day of the month grid — retail's CalendarDayButtonTemplate
-- (91x91) with its four event lines (CalendarDayEventButtonTemplate).
--
--   CalendarDayButton(window, index)
--     :SetDate(day, monthOffset, darkTop, darkBottom)   the date; the dark
--         flags shade a day of the month before or after (nil: in the month)
--     :SetEvents(events, hasPendingInvite)   the day's events, in the order
--         to show them; the envelope over a day with an unanswered invite

local Style = MUI_CalendarStyle

local CELL               = 90 / 256 - 0.001   -- a quarter of the parchment sheet
local MAX_EVENTS         = 4
local MAX_BIG_EVENTS     = 2
local HIGHLIGHT_ALPHA    = 0.5
local SELECTED_ALPHA     = 1.0
local EVENT_HEIGHT       = 12
local EVENT_BIG_HEIGHT   = 24
local EVENT_X, EVENT_GAP = 4, 3
local HOLIDAY_COORDS     = { 0, 0.7109375, 0, 0.7109375 }
local FULL_COORDS        = { 0, 1, 0, 1 }

-- Retail's dark-day flags and the cuts of CalendarShadows each combination
-- takes, so the shading of the days around the month joins up.
local PREV, NEXT, CORNER = 0x01, 0x02, 0x04
local LEFT, RIGHT, TOP, BOTTOM = 0x08, 0x10, 0x20, 0x40
local W, H = 512, 256
local DARK_TOP = {
    [PREV + TOP]                       = { 90 / W, 180 / W, 0, 45 / H },
    [PREV + TOP + LEFT]                = { 0, 90 / W, 0, 45 / H - 0.001 },
    [PREV + TOP + RIGHT]               = { 90 / W, 0, 0, 45 / H - 0.001 },
    [PREV + TOP + LEFT + RIGHT]        = { 0, 90 / W, 180 / H, 225 / H - 0.001 },
    [NEXT]                             = { 90 / W, 180 / W, 45 / H, 90 / H },
    [NEXT + LEFT]                      = { 90 / W, 0, 90 / H, 135 / H },
    [NEXT + RIGHT]                     = { 0, 90 / W, 90 / H, 135 / H - 0.001 },
    [NEXT + TOP]                       = { 90 / W, 180 / W, 0, 45 / H },
    [NEXT + TOP + LEFT]                = { 0, 90 / W, 0, 45 / H - 0.001 },
    [NEXT + TOP + RIGHT]               = { 90 / W, 0, 0, 45 / H - 0.001 },
    [NEXT + CORNER]                    = { 90 / W, 180 / W - 0.001, 135 / H, 180 / H },
    [NEXT + CORNER + TOP]              = { 0, 90 / W, 135 / H, 180 / H - 0.001 },
    [NEXT + CORNER + RIGHT]            = { 180 / W, 270 / W - 0.001, 45 / H, 90 / H - 0.001 },
    [NEXT + CORNER + TOP + LEFT]       = { 0, 90 / W, 45 / H, 90 / H },
    [NEXT + CORNER + TOP + LEFT + RIGHT] = { 180 / W, 90 / W, 225 / H, 180 / H },
}
local DARK_BOTTOM = {
    [PREV + BOTTOM]                    = { 90 / W, 180 / W, 45 / H, 0 },
    [PREV + BOTTOM + LEFT]             = { 0, 90 / W, 45 / H - 0.001, 0 },
    [PREV + BOTTOM + RIGHT]            = { 90 / W, 0, 90 / H, 45 / H },
    [PREV + BOTTOM + LEFT + RIGHT]     = { 90 / W, 180 / W, 180 / H, 225 / H },
    [NEXT]                             = { 90 / W, 180 / W, 45 / H, 90 / H },
    [NEXT + LEFT]                      = { 90 / W, 0, 90 / H, 135 / H },
    [NEXT + RIGHT]                     = { 0, 90 / W, 90 / H, 135 / H },
    [NEXT + BOTTOM]                    = { 90 / W, 180 / W, 45 / H, 0 },
    [NEXT + BOTTOM + LEFT]             = { 0, 90 / W, 45 / H - 0.001, 0 },
    [NEXT + BOTTOM + RIGHT]            = { 90 / W, 0, 45 / H - 0.001, 0 },
    [NEXT + BOTTOM + LEFT + RIGHT]     = { 0, 90 / W, 225 / H, 180 / H },
    [NEXT + LEFT + RIGHT]              = { 180 / W, 270 / W - 0.001, 0, 45 / H },
}

local function SetCoords(texture, coords)
    texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
end


-- ---------------------------------------------------------------------
-- CalendarDayEventButton: one event on the day — its title, its time
-- beside or under it, a dark band while it is the event selected.
-- ---------------------------------------------------------------------
class "CalendarDayEventButton" : extends "Button" {
    __init = function(self, dayButton)
        Button.__init(self, dayButton)
        self.dayButton = dayButton
        self:SetSize(83, EVENT_BIG_HEIGHT)
        self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        self:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self:Hide()

        self._black = Style:Art(self, "ARTWORK", "EventHighlight", nil, nil, 0, 1, 0.5, 1)
        self._black:Fill(self, 0, -1, 0, -2)
        self._black:SetAlpha(0.7)
        self._black:Hide()

        local highlight = self:SetHighlightTexture(Style.ART .. "EventHighlight")
        highlight:SetTexCoord(0, 1, 0, 0.5)
        highlight:SetBlendMode("ADD")
        highlight:ClearAllPoints()
        highlight:Fill(self, -2, -1, -2, -2)

        self._text2 = Style:Label(self, "GameFontHighlightSmall")
        self._text2:SetHeight(12)
        self._text1 = Style:Label(self, "GameFontNormalSmall")
        self._text1:SetJustifyH("LEFT")
    end;

    OnEnter = function(self)
        self.dayButton:OnEnter()
    end;

    OnLeave = function(self)
        self.dayButton:OnLeave()
    end;

    OnClick = function(self, mouseButton)
        self.dayButton.window:ClickEvent(self, mouseButton)
    end;

    -- `event` as a line of a day showing `big` (one or two) events or small
    -- ones. A holiday or a lockout takes the whole line for its name; a
    -- player event shows its time too.
    SetEvent = function(self, event, big)
        self.event = event
        self:SetHeight(big and EVENT_BIG_HEIGHT or EVENT_HEIGHT)

        local text1, text2 = self._text1, self._text2
        text1:SetText(Style:EventTitle(event))
        text1:ClearAllPoints()
        if event.calendarType == "HOLIDAY" or event.calendarType == "RAID_LOCKOUT" then
            text2:Hide()
            text1:FillParent()
        else
            local date = event.sequenceType == "END" and event.endTime or event.startTime
            text2:SetText(GameTime_GetFormattedTime(date.hour, date.minute, big))
            text2:ClearAllPoints()
            if big then
                text2:AlignParentBottomLeft()
                text2:SetJustifyH("LEFT")
                text1:SetSize(83, 12)
                text1:AlignParentTopLeft()
            else
                text2:AlignParentRight()
                text2:SetJustifyH("RIGHT")
                text1:AlignParentTopLeft()
                text1:SetPoint("BOTTOMRIGHT", text2, "BOTTOMLEFT")
            end
            text2:Show()
        end
        local color = Style:EventColor(event)
        text1:SetTextColor(color.r, color.g, color.b)
        self:Show()
    end;

    SetSelected = function(self, selected)
        if selected then
            self:LockHighlight()
            self._black:Show()
        else
            self:UnlockHighlight()
            self._black:Hide()
        end
    end;
}


-- ---------------------------------------------------------------------
-- CalendarDayButton
-- ---------------------------------------------------------------------
class "CalendarDayButton" : extends "Button" {
    __init = function(self, window, index)
        Button.__init(self, window)
        self.window = window
        self.index = index
        self:SetSize(91, 91)
        self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        self:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)

        -- A quarter of the parchment, at random as in retail.
        local background = self:SetNormalTexture(Style.ART .. "CalendarBackground")
        background:SetDrawLayer("BACKGROUND")
        local left, top = math.random(0, 1) * CELL, math.random(0, 1) * CELL
        background:SetTexCoord(left, left + CELL, top, top + CELL)

        self._highlight = self:SetHighlightTexture(Style.ART .. "Highlights")
        self._highlight:SetTexCoord(0, 0.34375, 0, 0.6875)
        self._highlight:SetBlendMode("ADD")
        self._highlight:ClearAllPoints()
        self._highlight:SetSize(88, 88)
        self._highlight:CenterInParent()
        self._highlight:SetAlpha(HIGHLIGHT_ALPHA)

        self._eventTexture = Style:Art(self, "BORDER", "CalendarBackground", 91, 91)
        self._eventTexture:CenterInParent()
        self._eventTexture:Hide()

        self._eventBackground = Style:Art(self, "ARTWORK", "CalendarEventBackground", 91, 86, 0, 0.671875, 0, 0.671875)
        self._eventBackground:AlignParentBottom()
        self._eventBackground:Hide()

        self._pendingInvite = Style:Art(self, "OVERLAY", "EventNotification", 71, 91, 0.03125, 0.6484375, 0.03125, 0.8671875)
        self._pendingInvite:CenterInParent()
        self._pendingInvite:Hide()

        local base = self:GetFrameLevel()

        -- A holiday running through several days lays its art over them.
        self._overlay = Frame("Frame", self)
        self._overlay:FillParent()
        self._overlay:SetFrameLevel(base + 1)
        self._overlay:Hide()
        self._overlayTexture = Texture(self._overlay, nil, "BACKGROUND")
        self._overlayTexture:FillParent()

        local dateFrame = Frame("Frame", self)
        dateFrame:SetSize(23, 18)
        dateFrame:AlignParentTopLeft(5, 5)
        dateFrame:SetFrameLevel(base + 2)
        self._date = Style:Label(dateFrame, "GameFontHighlight", "ARTWORK")
        self._date:CenterInParent()

        self.moreButton = Button(self)
        self.moreButton:SetSize(15, 11)
        self.moreButton:AlignParentTopRight(7, 5)
        self.moreButton:SetFrameLevel(base + 2)
        self.moreButton:SetNormalTexture(Style.ART .. "MoreArrow"):SetTexCoord(0, 0.9375, 0, 0.6875)
        self.moreButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        self.moreButton:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self.moreButton.OnEnter = function() self:OnEnter() end
        self.moreButton.OnLeave = function() self:OnLeave() end
        self.moreButton.OnClick = function(_, mouseButton) self.window:ClickMoreEvents(self, mouseButton) end
        self.moreButton:Hide()

        self.eventButtons = {}
        for i = 1, MAX_EVENTS do
            local button = CalendarDayEventButton(self)
            button:SetFrameLevel(base + 2)
            self.eventButtons[i] = button
        end

        -- Shading for a day of the month before or after.
        self._dark = Frame("Frame", self)
        self._dark:SetSize(91, 91)
        self._dark:CenterInParent()
        self._dark:SetFrameLevel(base + 3)
        self._dark:Hide()
        self._darkTop = Style:Art(self._dark, "OVERLAY", "CalendarShadows", 91, 45)
        self._darkTop:AlignParentTop()
        self._darkTop:SetVertexColor(1, 1, 1, 0.9)
        self._darkBottom = Style:Art(self._dark, "OVERLAY", "CalendarShadows", 91, 46)
        self._darkBottom:AlignParentBottom()
        self._darkBottom:SetVertexColor(1, 1, 1, 0.9)
    end;

    -- Retail's dark-day flags, which the window composes for SetDate.
    DARK = { PREV = PREV, NEXT = NEXT, CORNER = CORNER, LEFT = LEFT, RIGHT = RIGHT, TOP = TOP, BOTTOM = BOTTOM };

    -- The frame level today's glow goes over: above the shading.
    GetTopLevel = function(self)
        return self._dark:GetFrameLevel() + 1
    end;

    SetDate = function(self, day, monthOffset, darkTop, darkBottom)
        self.day = day
        self.monthOffset = monthOffset
        self._date:SetText(day)
        self.dark = darkTop ~= nil
        if self.dark then
            SetCoords(self._darkTop, DARK_TOP[darkTop])
            SetCoords(self._darkBottom, DARK_BOTTOM[darkBottom])
            self._dark:Show()
        else
            self._dark:Hide()
        end
    end;

    -- The selected day keeps its highlight, at full strength.
    SetSelected = function(self, selected)
        if selected then
            self:LockHighlight()
            self._highlight:SetAlpha(SELECTED_ALPHA)
        else
            self:UnlockHighlight()
            self._highlight:SetAlpha(HIGHLIGHT_ALPHA)
        end
    end;

    -- Retail's CalendarFrame_UpdateDayEvents and _UpdateDayTextures: up to
    -- four lines, the latest at the bottom; an ongoing holiday has none.
    -- The first line's event lends the day its art.
    SetEvents = function(self, events, hasPendingInvite)
        self.events = events
        self._pendingInvite:SetVisible(hasPendingInvite)

        local viewable, firstHoliday = {}, nil
        for _, event in ipairs(events) do
            if event.calendarType == "HOLIDAY" and not firstHoliday then
                firstHoliday = event
            end
            if event.sequenceType ~= "ONGOING" and not (event.sequenceType == "END" and event.dontDisplayEnd) then
                viewable[#viewable + 1] = event
            end
        end
        self.numViewableEvents = #viewable

        local big = #viewable <= MAX_BIG_EVENTS
        self.moreButton:SetVisible(#viewable > MAX_EVENTS)

        local previous
        for i, button in ipairs(self.eventButtons) do
            local event = viewable[i]
            if event then
                button:SetEvent(event, big)
                button:ClearAllPoints()
                button:AlignParentBottomLeft(EVENT_GAP, EVENT_X)
                if previous then
                    previous:ClearAllPoints()
                    previous:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, EVENT_GAP)
                end
                previous = button
            else
                button.event = nil
                button:Hide()
            end
        end

        local first = viewable[1] and self.eventButtons[1]
        self.firstEventButton = first
        if first then
            self._eventBackground:ClearAllPoints()
            self._eventBackground:AlignTop(first, -40)
            self._eventBackground:AlignParentBottom()
            self._eventBackground:Show()
            self:_SetArt(self._eventTexture, first.event)
        else
            self._eventBackground:Hide()
            self._eventTexture:Hide()
        end

        -- By art request, no banner for a holiday of two days or fewer.
        if firstHoliday and firstHoliday.numSequenceDays > 2 and not firstHoliday.dontDisplayBanner
           and self:_SetArt(self._overlayTexture, firstHoliday) then
            self._overlay:Show()
        else
            self._overlay:Hide()
        end
    end;

    -- An event's icon on `texture`; false when it has none.
    _SetArt = function(self, texture, event)
        if not event.iconTexture then
            texture:Hide()
            return false
        end
        texture:SetTexture(event.iconTexture)
        SetCoords(texture, event.calendarType == "HOLIDAY" and HOLIDAY_COORDS or FULL_COORDS)
        texture:Show()
        return true
    end;

    OnEnter = function(self)
        self:LockHighlight()
        self.window:ShowDayTooltip(self)
    end;

    OnLeave = function(self)
        if self.window.selectedDayButton ~= self then
            self:UnlockHighlight()
        end
        MUI_Tooltip:Hide()
    end;

    OnClick = function(self, mouseButton)
        self.window:ClickDay(self, mouseButton)
    end;
}
