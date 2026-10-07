-- MUI_AuctionHouseList: the results table every auction house view shares
-- (retail's AuctionHouseItemListTemplate) — sortable column headers over a
-- column of rows, a scroll bar, the "no results" line, the searching spinner
-- and, where the view wants one, a refresh button with a count beside it.
--
-- Rows are a fixed pool re-bound as the list scrolls, so a browse of a
-- thousand items costs what one of ten does.
--
--   AuctionHouseList(parent, columns, opts)
--     columns   { { key, title, width | fill, justify, icon, favorite,
--                   sortable, text = function(data) } }
--               `width` in retail's units; one column may `fill`. An `icon`
--               column leads with data.icon; a `favorite` column is the
--               star toggle (IsFavorite / OnFavorite).
--     opts      width, height   the table's size, retail's units
--               background      region of the backgrounds sheet
--               tooltips        rows show their item's tooltip (data.link)
--               refresh         { x, y }: show the refresh corner, offset
--                               from the table's top right as retail does
--
--   list:SetData(rows, keepScroll)   list:SetSelected(data)
--   list:SetSort(key, descending)    list:SetEmptyText(text)
--   list:SetLoading(on, text)        list:SetTotalText(text)
--
-- The owner assigns the callbacks it wants:
--   OnSort(key)   OnRowClick(data)   OnRefresh()
--   IsFavorite(data)   OnFavorite(data)

local Style = MUI_AuctionHouseStyle
local S     = Style.S

local HEADER_H      = 19
local ROW_H         = 20
local COLUMN_TABS   = "Interface\\FriendsFrame\\WhoFrame-ColumnTabs"
local TAB_HIGHLIGHT = "Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight"
local REFRESH_ICON  = "Interface\\Buttons\\UI-RefreshButton"
local CLICK         = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON

-- ---------------------------------------------------------------------
-- AuctionHouseListRow: one pooled row. `data` is whatever the owner put in
-- the list; the columns' text functions read it.
-- ---------------------------------------------------------------------
class "AuctionHouseListRow" : extends "Button" {
    __init = function(self, list)
        Button.__init(self, list.view)
        self:SetClickSound(CLICK)
        self:SetSize(list.innerWidth, ROW_H * S)
        self._list  = list
        self._hover = false
        self.data   = nil

        self._selected = Style:Piece(self, "BACKGROUND", "RowSelect", 1, 1)
        self._selected:FillParent()
        self._selected:Hide()
        self:SetHighlightAtlas(MUI_AtlasRegistry.AuctionHouse, "RowHighlight", true)

        self._cells = {}
        for i, col in ipairs(list.columns) do
            self._cells[i] = self:_Cell(col, list.rects[i])
        end

        self.OnClick = function()
            local data = self.data
            if not data then return end
            if data.link and IsModifiedClick() and HandleModifiedItemClick(data.link) then return end
            if list.OnRowClick then list:OnRowClick(data) end
        end
        self.OnEnter = function()
            self:_SetHover(true)
            self:ShowTooltip()
        end
        self.OnLeave = function()
            self:_SetHover(false)
            MUI_Tooltip:Hide()
        end
    end;

    _Cell = function(self, col, rect)
        local cell = {}
        local x = rect.x
        if col.icon then
            cell.icon = Texture(self, nil, "ARTWORK")
            cell.icon:SetSize((ROW_H - 4) * S, (ROW_H - 4) * S)
            cell.icon:AlignParentLeft(x + 2 * S)
            x = x + ROW_H * S
        end
        if col.favorite then
            -- The button stays shown and only its star comes and goes: a
            -- button hiding under the cursor would bounce the hover between
            -- it and the row.
            cell.star = Button(self)
            cell.star:SetClickSound(CLICK)
            cell.star:SetSize(18 * S, 18 * S)
            cell.star:AlignParentLeft(rect.x + (rect.w - 18 * S) / 2)
            cell.starArt = Style:Piece(cell.star, "ARTWORK", "IconFavorite", 16, 14.4)
            cell.starArt:CenterInParent()
            cell.star.OnClick = function()
                if self.data and self._list.OnFavorite then self._list:OnFavorite(self.data) end
                self:_UpdateStars()
            end
            cell.star.OnEnter = function() self:_SetHover(true) end
            cell.star.OnLeave = function() self:_SetHover(false) end
        else
            cell.text = Style:Label(self, 10.5, 1, 1, 1, "ARTWORK")
            cell.text:SetJustifyH(col.justify or "LEFT")
            cell.text:SetWordWrap(false)
            cell.text:SetWidth(math.max(rect.x + rect.w - x - 10 * S, 1))
            cell.text:AlignParentLeft(x + 4 * S)
        end
        return cell
    end;

    _SetHover = function(self, hover)
        self._hover = hover
        self:_UpdateStars()
    end;

    -- A favourite shows the gold star; anything else shows the outline
    -- while the row is hovered.
    _UpdateStars = function(self)
        for _, cell in ipairs(self._cells) do
            if cell.starArt then
                local list = self._list
                local on = self.data ~= nil and list.IsFavorite ~= nil and list:IsFavorite(self.data)
                if on then
                    Style:SetPiece(cell.starArt, "IconFavorite")
                    cell.starArt:Show()
                elseif self._hover and self.data then
                    Style:SetPiece(cell.starArt, "IconFavoriteOff")
                    cell.starArt:Show()
                else
                    cell.starArt:Hide()
                end
            end
        end
    end;

    ShowTooltip = function(self)
        local data = self.data
        if not (self._list.tooltips and data and data.link) then return end
        MUI_Tooltip:ShowFor(self, "ANCHOR_RIGHT", function(tip)
            tip:SetHyperlink(data.link)
        end)
        MUI_Tooltip:ShowCompareItem()
    end;

    SetData = function(self, data, selected)
        self.data = data
        for i, col in ipairs(self._list.columns) do
            local cell = self._cells[i]
            if cell.icon then
                cell.icon:SetTexture(data.icon)
                cell.icon:SetVisible(data.icon ~= nil)
            end
            if cell.text then
                cell.text:SetText(col.text(data) or "")
            end
        end
        self._selected:SetVisible(selected)
        self:_UpdateStars()
    end;
}


class "AuctionHouseList" : extends "Frame" {
    __init = function(self, parent, columns, opts)
        Frame.__init(self, "Frame", parent)
        self:SetSize(opts.width * S, opts.height * S)

        self.columns    = columns
        self.tooltips   = opts.tooltips and true or false
        -- headers and rows run from 4 in at the left to 26 short of the
        -- right, where the scroll bar stands
        self.innerWidth = (opts.width - 30) * S
        self.rects      = self:_Layout()

        self._data     = {}
        self._selected = nil
        self._scroll   = 0
        self._rowH     = ROW_H * S
        self._viewH    = (opts.height - HEADER_H - 10) * S
        self._rows     = {}

        if opts.background then
            local bg = Style:Background(self, opts.background, "ARTWORK")
            bg:FillParentPadding(3 * S, 22 * S, 25 * S, 3 * S)
        end
        Style:Inset(self, 0, 19, 22, 0)

        self:_BuildHeaders()
        self:_BuildBody()
        self:_BuildStatus()
        if opts.refresh then self:_BuildRefresh(opts.refresh) end

        self:SetData({})
    end;

    -- Column rects across the inner width: fixed columns before the fill
    -- column run from the left, those after it from the right, and the
    -- fill column takes what is between.
    _Layout = function(self)
        local columns, rects = self.columns, {}
        local fill
        for i, col in ipairs(columns) do
            if col.fill then fill = i break end
        end
        local x = 0
        for i = 1, (fill or #columns + 1) - 1 do
            local w = columns[i].width * S
            rects[i] = { x = x, w = w }
            x = x + w
        end
        if fill then
            local right = self.innerWidth
            for i = #columns, fill + 1, -1 do
                local w = columns[i].width * S
                right = right - w
                rects[i] = { x = right, w = w }
            end
            rects[fill] = { x = x, w = math.max(right - x, 1) }
        end
        return rects
    end;

    -- Retail's ColumnDisplayButtonShortTemplate: the three-piece column tab,
    -- its title at the left, the sort arrow right after the title.
    _BuildHeaders = function(self)
        self._headers = {}
        for i, col in ipairs(self.columns) do
            local rect = self.rects[i]
            local header = Button(self)
            header:SetClickSound(CLICK)
            header:SetSize(rect.w, HEADER_H * S)
            header:AlignParentTopLeft(1 * S, 4 * S + rect.x)

            local left = Texture(header, nil, "BACKGROUND")
            left:SetTexture(COLUMN_TABS)
            left:SetTexCoord(0, 0.078125, 0, 0.59375)
            left:SetWidth(5 * S)
            left:AlignParentTopLeft()
            left:AlignParentBottomLeft()
            local right = Texture(header, nil, "BACKGROUND")
            right:SetTexture(COLUMN_TABS)
            right:SetTexCoord(0.90625, 0.96875, 0, 0.59375)
            right:SetWidth(4 * S)
            right:AlignParentTopRight()
            right:AlignParentBottomRight()
            local middle = Texture(header, nil, "BACKGROUND")
            middle:SetTexture(COLUMN_TABS)
            middle:SetTexCoord(0.078125, 0.90625, 0, 0.59375)
            middle:FillBetweenH(left, right)

            local title = Style:Label(header, 9.5, 1, 1, 1)
            title:SetText(col.title or "")
            title:AlignParentLeft(8 * S)

            header.arrow = Style:Piece(header, "OVERLAY", "SortArrow", 9, 9)
            header.arrow:RightOf(title, 3 * S)
            header.arrow:Hide()

            if col.sortable ~= false and not col.favorite then
                header:SetHighlightTexture(TAB_HIGHLIGHT, "ADD")
                header.OnClick = function()
                    if self.OnSort then self:OnSort(col.key) end
                end
            end
            self._headers[i] = header
        end
    end;

    -- The clipped view the rows slide in, the scroll bar to its right.
    _BuildBody = function(self)
        self.view = Frame("Frame", self)
        self.view:SetClipsChildren(true)
        self.view:SetSize(self.innerWidth, self._viewH)
        self.view:AlignParentTopLeft((HEADER_H + 7) * S, 4 * S)

        for i = 1, math.ceil(self._viewH / self._rowH) + 1 do
            self._rows[i] = AuctionHouseListRow(self)
        end

        self.bar = MinimalScrollBar(self, nil, 8 * S, 8 * S)
        self.bar:AlignParentTopRight((HEADER_H + 7) * S, 9 * S)
        self.bar:AlignParentBottomRight(7 * S, 9 * S)
        self.bar:SetScrollSpeed(3 * self._rowH)
        self.bar.OnScroll = function(_, value)
            self._scroll = value
            self:_Refresh()
        end

        self.view:EnableMouseWheel(true)
        self.view:SetScript("OnMouseWheel", function(_, delta)
            self.bar:SetValue(self.bar:GetValue() - delta * 3 * self._rowH)
        end)
    end;

    -- The line shown over an empty table, and the spinner with its own line
    -- while a search runs (retail's LoadingSpinner / SearchingText).
    _BuildStatus = function(self)
        self._empty = Style:Label(self, 11, 1, 0.82, 0)
        self._empty:SetJustifyH("CENTER")
        self._empty:SetWidth(self.innerWidth - 80 * S)
        self._empty:AlignTop(self.view, 45 * S)

        self._spinner = Frame("Frame", self)
        self._spinner:SetSize(90 * S, 90 * S)
        self._spinner:CenterAt(self.view, 0, -15 * S)
        self._spinner:Hide()
        local ring = Style:Piece(self._spinner, "ARTWORK", "LoadingSpinner", 90, 90)
        ring:CenterInParent()
        local angle = 0
        self._spinner:SetScript("OnUpdate", function(_, elapsed)
            angle = (angle - elapsed * 2 * math.pi / 1.2) % (2 * math.pi)
            ring:SetRotation(angle)
        end)

        self._searching = Style:Label(self._spinner, 11, 1, 0.82, 0)
        self._searching:SetJustifyH("CENTER")
        self._searching:Above(self._spinner, 10 * S)
    end;

    -- Retail's RefreshFrame: the refresh button at the corner, the count to
    -- its left.
    _BuildRefresh = function(self, offset)
        local button = ButtonSimple(self)
        button:SetSize(18 * S, 18 * S)
        button:SetTexture(REFRESH_ICON, 1, 1, 0, 0, 1, 1)
        button:AlignParentTopRight(-(offset.y or 0) * S, -(offset.x or 0) * S)
        button.OnClick = function()
            if self.OnRefresh then self:OnRefresh() end
        end
        self._total = Style:Label(self, 9.5, 1, 0.82, 0)
        self._total:SetJustifyH("RIGHT")
        self._total:LeftOf(button, 4 * S)
    end;

    -- ---- data ----------------------------------------------------------

    -- Show `rows`; `keepScroll` holds the scroll position (a list that grows
    -- while it is being read) instead of returning to the top.
    SetData = function(self, rows, keepScroll)
        self._data = rows or {}
        local contentH = #self._data * self._rowH
        local maxScroll = math.max(0, contentH - self._viewH)
        self.bar:SetMinMax(0, maxScroll)
        self.bar:SetContentSize(self._viewH, math.max(contentH, 1))
        if not keepScroll then self.bar:SetValue(0) end
        self._scroll = self.bar:GetValue()
        self._empty:SetVisible(#self._data == 0 and not self._spinner:IsShown())
        self:_Refresh()
    end;

    GetData = function(self)
        return self._data
    end;

    SetSelected = function(self, data)
        self._selected = data
        self:_Refresh()
    end;

    GetSelected = function(self)
        return self._selected
    end;

    -- Bind the pool to the rows in view.
    _Refresh = function(self)
        local first = math.floor(self._scroll / self._rowH)
        local shift = self._scroll - first * self._rowH
        for i, row in ipairs(self._rows) do
            local data = self._data[first + i]
            if data then
                row:ClearAllPoints()
                row:AlignParentTopLeft((i - 1) * self._rowH - shift, 0)
                row:SetData(data, data == self._selected)
                row:Show()
                if MUI_Tooltip:IsOwnedBy(row) then row:ShowTooltip() end
            else
                row:Hide()
            end
        end
    end;

    -- ---- presentation --------------------------------------------------

    -- The arrow on the sorted column: as drawn for ascending, turned over
    -- for descending.
    SetSort = function(self, key, descending)
        for i, col in ipairs(self.columns) do
            local arrow = self._headers[i].arrow
            arrow:SetVisible(col.key == key)
            arrow:SetRotation(descending and math.pi or 0)
        end
    end;

    SetEmptyText = function(self, text)
        self._empty:SetText(text or "")
    end;

    SetLoading = function(self, loading, text)
        self._spinner:SetVisible(loading)
        self._searching:SetText(text or "")
        self._empty:SetVisible(#self._data == 0 and not loading)
    end;

    SetTotalText = function(self, text)
        if self._total then self._total:SetText(text or "") end
    end;
}
