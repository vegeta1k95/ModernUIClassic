-- MUI_CalendarLists: the scrolling pieces of the calendar's panels.
--
--   CalendarScrollText(parent, font)     retail's ScrollingFontTemplate: text
--                                        that scrolls once it outgrows its box
--   CalendarList(parent, rowHeight, newRow)
--                                        rows on a scroll frame, made as needed
--   CalendarInviteList(parent, owner)    an event's invite list
--                                        (CalendarEventInviteListTemplate)
--   CalendarClassTotals(parent)          how many of each class have accepted
--                                        (CalendarClassButtonContainer)

local Style = MUI_CalendarStyle

local WHEEL_STEP = 20


-- ---------------------------------------------------------------------
-- CalendarScrollText
-- ---------------------------------------------------------------------
class "CalendarScrollText" : extends "Frame" {
    __init = function(self, parent, font)
        Frame.__init(self, "Frame", parent)

        self._scroll = ScrollFrame(self)
        self._scroll:FillParent()
        self._scroll:EnableMouseWheel(true)
        self._child = Frame("Frame", self._scroll)
        self._child:SetSize(1, 1)
        self._scroll:SetScrollChild(self._child)

        self._text = Style:Label(self._child, font)
        self._text:SetJustifyH("LEFT")
        self._text:SetJustifyV("TOP")
        self._text:AlignParentTopLeft()

        self._bar = MinimalScrollBar(self)
        self._bar:AlignParentTopRight(0, -14)
        self._bar:AlignParentBottomRight(0, -14)
        self._bar.OnScroll = function(_, value) self._scroll:SetVerticalScroll(value) end
        self._scroll:SetScript("OnMouseWheel", function(_, delta)
            self._bar:SetValue(self._bar:GetValue() - delta * WHEEL_STEP)
        end)
    end;

    SetText = function(self, text)
        local width, height = self:GetWidth(), self:GetHeight()
        self._text:SetWidth(width)
        self._text:SetText(text or "")
        local range = math.max(self._text:GetStringHeight() - height, 0)
        self._child:SetSize(width, self._text:GetStringHeight())
        self._bar:SetMinMax(0, range)
        self._bar:SetContentSize(height, height + range)
        self._bar:SetValue(0)
        self._bar:SetVisible(range > 0)
        self._scroll:SetVerticalScroll(0)
    end;

    SetTextColor = function(self, color)
        self._text:SetTextColor(color.r, color.g, color.b)
    end;
}


-- ---------------------------------------------------------------------
-- CalendarList: `newRow(content, list)` makes a row; SetCount shows as
-- many as there are entries and lets `fill(row, index)` set each up. The
-- scroll bar (.bar) is the caller's to place; it hides when nothing scrolls.
-- ---------------------------------------------------------------------
class "CalendarList" : extends "Frame" {
    __init = function(self, parent, rowHeight, newRow)
        Frame.__init(self, "Frame", parent)
        self._rowHeight = rowHeight
        self._newRow = newRow
        self.rows = {}

        self._scroll = ScrollFrame(self)
        self._scroll:FillParent()
        self._scroll:EnableMouseWheel(true)
        self.content = Frame("Frame", self._scroll)
        self.content:SetSize(1, 1)
        self._scroll:SetScrollChild(self.content)

        self.bar = MinimalScrollBar(self)
        self.bar:SetScrollSpeed(rowHeight)
        self.bar.OnScroll = function(_, value) self._scroll:SetVerticalScroll(value) end
        self._scroll:SetScript("OnMouseWheel", function(_, delta)
            self.bar:SetValue(self.bar:GetValue() - delta * rowHeight)
        end)
    end;

    SetCount = function(self, count, fill)
        self.content:SetWidth(self:GetWidth())
        for i = 1, count do
            local row = self.rows[i]
            if not row then
                row = self._newRow(self.content, self)
                row:AlignParentTopLeft((i - 1) * self._rowHeight, 0)
                self.rows[i] = row
            end
            fill(row, i)
            row:Show()
        end
        for i = count + 1, #self.rows do
            self.rows[i]:Hide()
        end
        local height = self:GetHeight()
        local range = math.max(count * self._rowHeight - height, 0)
        self.content:SetHeight(math.max(count * self._rowHeight, 1))
        self.bar:SetMinMax(0, range)
        self.bar:SetContentSize(height, height + range)
        self.bar:SetVisible(range > 0)
        self._scroll:SetVerticalScroll(self.bar:GetValue())
    end;

    ScrollToTop = function(self)
        self.bar:SetValue(0)
        self._scroll:SetVerticalScroll(0)
    end;
}


-- ---------------------------------------------------------------------
-- CalendarInviteRow: a name, class and status line of an invite list.
-- ---------------------------------------------------------------------
local ROW_W, ROW_H = 267, 14

class "CalendarInviteRow" : extends "Button" {
    __init = function(self, parent, list)
        Button.__init(self, parent)
        self.list = list
        self:SetSize(ROW_W, ROW_H)
        self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        self:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar"):SetBlendMode("ADD")

        self._mod = Texture(self, nil, "BORDER")
        self._mod:SetSize(14, 14)
        self._mod:AlignParentLeft()

        self._name = Style:Label(self, "GameFontNormalSmall", "BORDER")
        self._name:SetSize(110, 14)
        self._name:SetJustifyH("LEFT")

        self._class = Style:Label(self, "GameFontNormalSmall", "BORDER")
        self._class:SetSize(80, 14)
        self._class:SetJustifyH("LEFT")
        self._class:CenterInParent(20, 0)

        self._status = Style:Label(self, "GameFontNormalSmall", "BORDER")
        self._status:SetSize(77, 14)
        self._status:SetJustifyH("RIGHT")
        self._status:AlignParentRight()
    end;

    -- Retail's CalendarEventInviteList_InitButtonShared: the leader or
    -- assistant icon of the creator and moderators, the name and class in
    -- the class's colour, the status in its own.
    SetInvite = function(self, index, info)
        self.inviteIndex = index
        self.info = info

        if info.modStatus == "CREATOR" then
            self._mod:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
            self._mod:Show()
        elseif info.modStatus == "MODERATOR" then
            self._mod:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
            self._mod:Show()
        else
            self._mod:Hide()
        end
        self._name:ClearAllPoints()
        if self._mod:IsShown() then
            self._name:RightOf(self._mod)
        else
            self._name:AlignParentLeft()
        end

        local classColor = info.classFilename and MUI.ClassColor(info.classFilename) or NORMAL_FONT_COLOR
        self._name:SetText(info.name ~= "" and info.name or UNKNOWN)
        self._name:SetTextColor(classColor.r, classColor.g, classColor.b)
        self._class:SetText(info.className and info.className ~= "" and info.className or UNKNOWN)
        self._class:SetTextColor(classColor.r, classColor.g, classColor.b)

        local status = CalendarUtil.GetCalendarInviteStatusInfo(info.inviteStatus)
        self._status:SetText(status.name)
        self._status:SetTextColor(status.color.r, status.color.g, status.color.b)
    end;

    OnClick = function(self, mouseButton)
        self.list.owner:ClickInvite(self, mouseButton)
    end;

    -- When the invitee answered (retail shows it to an event's editors and
    -- to the view of an event).
    OnEnter = function(self)
        local responded = C_Calendar.EventGetInviteResponseTime(self.inviteIndex)
        if not responded or responded.weekday == 0 then return end
        MUI_Tooltip:ShowFor(self, "ANCHOR_TOPRIGHT", function(tooltip)
            tooltip:AddLine(CALENDAR_TOOLTIP_INVITE_RESPONDED, 1, 1, 1, false, 13)
            tooltip:AddLine(Style:FullDate(responded.weekday, responded.month, responded.monthDay, responded.year), 1, 1, 1)
            tooltip:AddLine(Style:FormatTime(responded.hour, responded.minute), 1, 1, 1)
        end)
    end;

    OnLeave = function(self)
        MUI_Tooltip:Hide()
    end;
}


-- ---------------------------------------------------------------------
-- CalendarSortButton: a column header of the invite list; the arrow points
-- the way the column is sorted.
-- ---------------------------------------------------------------------
class "CalendarSortButton" : extends "Button" {
    __init = function(self, parent, criterion, text)
        Button.__init(self, parent)
        self.criterion = criterion
        self:SetHeight(14)
        self:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)

        self._label = Style:Label(self, "GameFontHighlightSmall")
        self._label:SetText(text)
        self._label:AlignParentLeft()

        self._arrow = Style:Art(self, "BACKGROUND", "MoreArrow", 15, 11)
        self._arrow:AlignParentRight()
        self._arrow:Hide()
    end;

    OnClick = function(self)
        local criterion = C_Calendar.EventGetInviteSortCriterion()
        C_Calendar.EventSortInvites(self.criterion, self.criterion == criterion)
    end;

    OnEnter = function(self)
        self._label:SetFontObject("GameFontNormalSmall")
    end;

    OnLeave = function(self)
        self._label:SetFontObject("GameFontHighlightSmall")
    end;

    Update = function(self, criterion, reverse)
        if self.criterion == criterion then
            if reverse then
                self._arrow:SetTexCoord(0, 0.9375, 0, 0.6875)
            else
                self._arrow:SetTexCoord(0, 0.9375, 0.6875, 0)
            end
            self._arrow:Show()
            self:SetWidth(self._label:GetStringWidth() + 15)
        else
            self._arrow:Hide()
            self:SetWidth(self._label:GetStringWidth())
        end
    end;
}


-- ---------------------------------------------------------------------
-- CalendarInviteList: `owner` (the panel) answers ClickInvite(row, button).
-- ---------------------------------------------------------------------
class "CalendarInviteList" : extends "Frame" {
    __init = function(self, parent, owner)
        Frame.__init(self, "Frame", parent, nil, "TooltipBackdropTemplate")
        self.owner = owner
        self:SetSize(294, 250)
        self:SetBackdropColor(0, 0, 0, 0.9)

        self._list = CalendarList(self, ROW_H, function(content, list)
            return CalendarInviteRow(content, self)
        end)
        self._list:Fill(self, 4, 4, 23, 3)
        self._list.bar:AlignParentTopRight(4, -15)
        self._list.bar:AlignParentBottomRight(5, -15)

        -- The column headers over the box, lined up with the rows' columns.
        self._sort = {
            CalendarSortButton(self, "name", NAME),
            CalendarSortButton(self, "class", CLASS),
            CalendarSortButton(self, "status", STATUS),
        }
        self._sort[1]:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 4, 0)
        self._sort[2]:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 4 + ROW_W / 2 - 20, 0)
        self._sort[3]:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", 4 + ROW_W, 0)

        -- While the server is still sending the invitees' names.
        self._retrieving = Frame("Frame", self)
        self._retrieving:FillParent()
        self._retrieving:EnableMouse(true)
        self._retrieving:SetFrameLevel(self:GetFrameLevel() + 10)
        local shade = Texture(self._retrieving, nil, "BACKGROUND")
        shade:FillParent()
        shade:SetColorTexture(0, 0, 0, 0.75)
        local text = Style:Label(self._retrieving, "GameFontNormal", "ARTWORK")
        text:SetText(RETRIEVING_INVITE_LIST)
        text:CenterInParent()
        local dots = Style:Label(self._retrieving, "GameFontNormal", "ARTWORK")
        dots:RightOf(text)
        local timer, count = 0, 0
        self._retrieving:SetScript("OnUpdate", function(_, elapsed)
            timer = timer + elapsed
            if timer >= 0.3 then
                timer, count = 0, (count + 1) % 4
                dots:SetText(string.rep(".", count))
            end
        end)
        self._retrieving:Hide()
    end;

    -- The invitees, as the server sorted them; the totals per class to
    -- `totals` when given.
    Update = function(self, totals)
        if not C_Calendar.AreNamesReady() then
            self._retrieving:Show()
            return
        end
        self._retrieving:Hide()

        local invites = {}
        for index = 1, C_Calendar.GetNumInvites() do
            local info = C_Calendar.EventGetInvite(index)
            if info and info.name then
                invites[#invites + 1] = { index = index, info = info }
            end
        end
        self._list:SetCount(#invites, function(row, i)
            row:SetInvite(invites[i].index, invites[i].info)
        end)

        local criterion, reverse = C_Calendar.EventGetInviteSortCriterion()
        for _, button in ipairs(self._sort) do
            button:Update(criterion, reverse)
        end

        if totals then totals:Update(invites) end
    end;
}


-- ---------------------------------------------------------------------
-- CalendarClassTotals: a button per class with how many of it have
-- accepted, been confirmed or signed up, and the sum under them.
-- ---------------------------------------------------------------------
class "CalendarClassTotals" : extends "Frame" {
    __init = function(self, parent)
        Frame.__init(self, "Frame", parent)
        self:SetSize(24, 535)

        self._buttons = {}
        local previous
        for _, class in ipairs(CLASS_SORT_ORDER) do
            local button = Button(self)
            button:SetSize(20, 20)
            local tab = Style:Art(button, "BACKGROUND", "Interface\\SpellBook\\SpellBook-SkillLineTab", 36, 36, 0, 0.875, 0, 0.875)
            tab:AlignParentLeft(-2)
            local icon = button:SetNormalTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
            icon:SetDrawLayer("BORDER")
            local coords = CLASS_ICON_TCOORDS[class]
            icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            button.icon = icon
            button.count = Style:Label(button, "NumberFontNormalSmall")
            button.count:AlignParentBottomRight(0, -2)
            button.class = class
            button.OnEnter = function()
                MUI_Tooltip:ShowFor(button, "ANCHOR_LEFT", function(tooltip)
                    tooltip:AddLine(LOCALIZED_CLASS_NAMES_MALE[class], 1, 1, 1, true, 13)
                end)
            end
            button.OnLeave = function() MUI_Tooltip:Hide() end
            if previous then
                button:Below(previous, 12)
            else
                button:AlignParentTopLeft()
            end
            previous = button
            self._buttons[#self._buttons + 1] = button
        end

        local totals = Button(self)
        totals:SetSize(20, 10)
        totals:Below(previous, 12)
        local middle = Style:Art(totals, "BACKGROUND", "Interface\\SpellBook\\SpellBook-SkillLineTab", 26, 8, 0, 0.625, 0.21875, 0.640625)
        middle:AlignParentLeft(-2)
        local top = Style:Art(totals, "BACKGROUND", "Interface\\SpellBook\\SpellBook-SkillLineTab", 26, 11, 0, 0.625, 0, 0.21875)
        top:Above(middle)
        local bottom = Style:Art(totals, "BACKGROUND", "Interface\\SpellBook\\SpellBook-SkillLineTab", 26, 15, 0, 0.625, 0.640625, 0.875)
        bottom:Below(middle)
        self._total = Style:Label(totals, "GameFontGreenSmall", "BORDER")
        self._total:CenterInParent()
        totals.OnEnter = function()
            MUI_Tooltip:ShowFor(totals, "ANCHOR_LEFT", function(tooltip)
                tooltip:AddLine(CALENDAR_TOOLTIP_INVITE_TOTALS, 1, 1, 1, true)
            end)
        end
        totals.OnLeave = function() MUI_Tooltip:Hide() end
    end;

    Update = function(self, invites)
        local counts = {}
        for _, invite in ipairs(invites) do
            local info = invite.info
            local status = info.inviteStatus
            if info.classFilename and (status == Enum.CalendarStatus.Confirmed
                or status == Enum.CalendarStatus.Available or status == Enum.CalendarStatus.Signedup) then
                counts[info.classFilename] = (counts[info.classFilename] or 0) + 1
            end
        end
        local total = 0
        for _, button in ipairs(self._buttons) do
            local count = counts[button.class] or 0
            button.count:SetText(count)
            button.count:SetVisible(count > 0)
            button.icon:SetDesaturated(count == 0)
            total = total + count
        end
        self._total:SetText(total)
    end;
}
