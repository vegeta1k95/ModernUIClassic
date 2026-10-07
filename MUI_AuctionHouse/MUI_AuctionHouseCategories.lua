-- MUI_AuctionHouseCategories: the category tree down the left of the Buy
-- tab (retail's AuctionHouseCategoriesList).
--
-- The tree is the client's own AuctionCategories, which Era's auction addon
-- builds from the item class tables: categories, their sub-categories and,
-- under armour, the slots. Only the selected branch is open. Clicking a row
-- selects it (clicking the selection again clears it) and searches with
-- that node's filters.

local Style = MUI_AuctionHouseStyle
local S     = Style.S

local ROW_H = 21
local ROW_W = 136

-- ---------------------------------------------------------------------
-- AuctionHouseCategoryRow: one row, dressed for its depth
-- (AuctionHouseFilterButton_SetUp): a plate for a category, a narrower one
-- for a sub-category, bare text on the tree line for a slot.
-- ---------------------------------------------------------------------
class "AuctionHouseCategoryRow" : extends "Button" {
    __init = function(self, parent, owner)
        Button.__init(self, parent)
        self:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self:SetSize(ROW_W * S, ROW_H * S)
        self.entry = nil

        self._plate     = Texture(self, nil, "BACKGROUND")
        self._highlight = Texture(self, nil, "BORDER")
        self._highlight:Hide()
        self._selected  = Texture(self, nil, "ARTWORK")
        self._line      = Style:Piece(self, "BACKGROUND", "FilterLine", 5, 11)
        self._line:AlignParentLeft(18 * S, 3 * S)
        self._label     = Style:Label(self, 9.5, 1, 1, 1)
        self._label:SetJustifyH("LEFT")
        self._label:SetWordWrap(false)
        self._label:SetWidth(100 * S)

        self.OnClick = function() owner:Select(self.entry) end
        self.OnEnter = function() self._highlight:Show() end
        self.OnLeave = function() self._highlight:Hide() end
    end;

    -- One of the three state textures: its art, size and place in the row.
    _Dress = function(self, texture, region, w, h, anchor, a, b)
        Style:SetPiece(texture, region)
        texture:SetSize(w * S, h * S)
        texture:ClearAllPoints()
        texture[anchor](texture, a, b)
    end;

    SetEntry = function(self, entry)
        self.entry = entry
        local indent
        if entry.depth == 1 then
            self._plate:Show()
            self:_Dress(self._plate,     "NavButton",          136, 32, "AlignParentTopLeft", 0, -2 * S)
            self:_Dress(self._selected,  "NavButtonSelect",    132, 21, "AlignParentLeft")
            self:_Dress(self._highlight, "NavButtonHighlight", 132, 21, "AlignParentLeft")
            self._highlight:SetBlendMode("BLEND")
            self._label:SetTextColor(1, 0.82, 0, 1)
            indent = 8
        elseif entry.depth == 2 then
            self._plate:Show()
            self:_Dress(self._plate,     "NavButtonSecondary",          133, 32, "AlignParentTopLeft", 0, 1 * S)
            self:_Dress(self._selected,  "NavButtonSecondarySelect",    122, 21, "AlignParentTopLeft", 0, 10 * S)
            self:_Dress(self._highlight, "NavButtonSecondaryHighlight", 122, 21, "AlignParentTopLeft", 0, 10 * S)
            self._highlight:SetBlendMode("BLEND")
            self._label:SetTextColor(1, 1, 1, 1)
            indent = 18
        else
            self._plate:Hide()
            self:_Dress(self._selected,  "RowSelect",    116, 18, "AlignParentTopRight", 2 * S, 2 * S)
            self:_Dress(self._highlight, "RowHighlight", 116, 18, "AlignParentTopRight", 2 * S, 2 * S)
            self._highlight:SetBlendMode("ADD")
            self._label:SetTextColor(1, 1, 1, 1)
            indent = 26
        end
        self._line:SetVisible(entry.depth == 3)
        self._selected:SetVisible(entry.selected)
        self._label:ClearAllPoints()
        self._label:AlignParentLeft(indent * S)
        self._label:SetText(entry.name)
    end;
}


class "AuctionHouseCategories" : extends "Frame" {
    __init = function(self, parent, owner)
        Frame.__init(self, "Frame", parent)
        self:SetSize(168 * S, 438 * S)
        self._owner = owner
        self._rows  = {}
        -- the open path: category, sub-category, slot (indices into the tree)
        self._category, self._subCategory, self._slot = nil, nil, nil

        local bg = Style:Background(self, "Categories")
        bg:SetSize(138 * S, 433 * S)
        bg:AlignParentTopLeft(3 * S, 3 * S)
        Style:Inset(self)

        self._area = AuctionHouseScrollArea(self, 140 * S, 430 * S, 6 * S, 2 * ROW_H * S)
        self._area:AlignParentTopLeft(6 * S, 3 * S)

        self:Refresh()
    end;

    -- The tree flattened to what is open: every category, the selected
    -- one's sub-categories under it, the selected sub-category's slots
    -- under that. The WoW Token category has nothing behind it on Era.
    _Entries = function(self)
        local entries = {}
        for ci, category in ipairs(AuctionCategories) do
            if not category:HasFlag("WOW_TOKEN_FLAG") then
                local open = self._category == ci
                entries[#entries + 1] = { depth = 1, name = category.name, category = ci, selected = open }
                if open and category.subCategories then
                    for si, sub in ipairs(category.subCategories) do
                        local subOpen = self._subCategory == si
                        entries[#entries + 1] = { depth = 2, name = sub.name, subCategory = si, selected = subOpen }
                        if subOpen and sub.subCategories then
                            for ssi, slot in ipairs(sub.subCategories) do
                                entries[#entries + 1] = { depth = 3, name = slot.name, slot = ssi, selected = self._slot == ssi }
                            end
                        end
                    end
                end
            end
        end
        return entries
    end;

    Refresh = function(self)
        local entries = self:_Entries()
        for i, entry in ipairs(entries) do
            local row = self._rows[i]
            if not row then
                row = AuctionHouseCategoryRow(self._area.content, self)
                row:AlignParentTopLeft((i - 1) * ROW_H * S, 3 * S)
                self._rows[i] = row
            end
            row:SetEntry(entry)
            row:Show()
        end
        for i = #entries + 1, #self._rows do self._rows[i]:Hide() end
        self._area:SetContentHeight(#entries * ROW_H * S)
    end;

    -- A click on a row: select it, or clear it when it is the selection
    -- (retail's OnFilterClicked), then search.
    Select = function(self, entry)
        if entry.depth == 1 then
            if self._category == entry.category then self._category = nil else self._category = entry.category end
            self._subCategory, self._slot = nil, nil
        elseif entry.depth == 2 then
            if self._subCategory == entry.subCategory then self._subCategory = nil else self._subCategory = entry.subCategory end
            self._slot = nil
        else
            if self._slot == entry.slot then self._slot = nil else self._slot = entry.slot end
        end
        self:Refresh()
        self._owner:StartSearch()
    end;

    -- The deepest selected node's filter list, as QueryAuctionItems takes
    -- it; nil with nothing selected.
    GetFilters = function(self)
        local node = self._category and AuctionCategories[self._category]
        if not node then return nil end
        local sub = self._subCategory and node.subCategories and node.subCategories[self._subCategory]
        if sub then
            node = sub
            local slot = self._slot and sub.subCategories and sub.subCategories[self._slot]
            if slot then node = slot end
        end
        return node.filters
    end;
}
