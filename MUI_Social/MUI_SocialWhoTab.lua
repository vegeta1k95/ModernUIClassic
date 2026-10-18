-- SocialWhoTab: the Who tab at retail's width — retail's column proportions,
-- rows as wide as the list, the sort dropdown filling its column header.

-- Retail's WhoFrameColumnHeader1..4, the first one on the inset's left edge.
local COLUMNS = { 116, 105, 54, 86 }
local HEADER_X, HEADER_Y = 4, 57
-- The rows: Era's 17, as wide as retail's ScrollBox.
local LIST_X, LIST_Y, LIST_W = 8, 82, 349
-- Retail's WhoListButtonTemplate: name, the zone / guild / race column,
-- level, and class out to the row's right edge.
local NAME_X, NAME_W = 6, 106
local VARIABLE_GAP, VARIABLE_W = 5, 98
local LEVEL_GAP, LEVEL_W = 4, 34
local CLASS_GAP = 15

class "SocialWhoTab" {

    __init = function(self)
        self._variables = {}
        self:_LayoutHeaders()
        self:_LayoutRows()
        self:_BuildScrollBar()

        -- Blizzard sizes the middle column, in the header and on every row,
        -- for its own scroll bar on each update.
        hooksecurefunc("WhoList_Update", function() self:_Reassert() end)
    end;

    _LayoutHeaders = function(self)
        for i, width in ipairs(COLUMNS) do
            WhoFrameColumn_SetWidth(_G["WhoFrameColumnHeader" .. i], width)
        end
        local first = Frame(WhoFrameColumnHeader1)
        first:ClearAllPoints()
        first:AlignParentTopLeft(HEADER_Y, HEADER_X)

        -- Anchored by both corners, so the width Blizzard gives it is moot.
        local dropdown = Frame(WhoFrameDropdown)
        dropdown:ClearAllPoints()
        dropdown:FillParentPadding(0, -1, 0, -1)
        self._dropdown = DropdownSkin(WhoFrameDropdown)
    end;

    _LayoutRows = function(self)
        for i = 1, WHOS_TO_DISPLAY do
            local name = "WhoFrameButton" .. i
            local row = Button(_G[name])
            row:SetWidth(LIST_W)
            local highlight = row:GetHighlightTexture()
            highlight:ClearAllPoints()
            highlight:FillParent()

            local who = FontString(_G[name .. "Name"])
            who:ClearAllPoints()
            who:SetWidth(NAME_W)
            who:AlignParentLeft(NAME_X)

            local variable = FontString(_G[name .. "Variable"])
            variable:ClearAllPoints()
            variable:SetWidth(VARIABLE_W)
            variable:RightOf(who, VARIABLE_GAP)
            self._variables[i] = variable

            local level = FontString(_G[name .. "Level"])
            level:ClearAllPoints()
            level:SetWidth(LEVEL_W)
            level:RightOf(variable, LEVEL_GAP)

            local class = FontString(_G[name .. "Class"])
            class:ClearAllPoints()
            class:RightOf(level, CLASS_GAP)
            class:AlignParentRight(0)
        end

        -- The others hang under the first.
        local first = Frame(WhoFrameButton1)
        first:ClearAllPoints()
        first:AlignParentTopLeft(LIST_Y, LIST_X)
    end;

    -- Blizzard's scroll frame over the rows, so the wheel scrolls anywhere
    -- on the list, and our bar beside it.
    _BuildScrollBar = function(self)
        local height = WHOS_TO_DISPLAY * FRIENDS_FRAME_WHO_HEIGHT
        local scroll = Frame(WhoListScrollFrame)
        scroll:ClearAllPoints()
        scroll:AlignParentTopLeft(LIST_Y, LIST_X)
        scroll:SetSize(LIST_W, height)

        local bar = NativeScrollBar(Frame(WhoFrame), WhoListScrollFrame,
                                    WhoListScrollFrameScrollBar, height - 6)
        bar:RightOf(scroll, 5, -1)
    end;

    _Reassert = function(self)
        for _, variable in ipairs(self._variables) do
            variable:SetWidth(VARIABLE_W)
        end
        WhoFrameColumn_SetWidth(WhoFrameColumnHeader2, COLUMNS[2])
    end;
}
