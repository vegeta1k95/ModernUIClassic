-- MUI_CollectionsSetList: the sets down the left of the sets page — retail's
-- WardrobeSetsScrollFrameButtonTemplate rows in a scrolling column. A row
-- shows how far along its set is: grey with a grey icon while no piece is
-- held, green with a bar under it while some are, gold when all are.
--
--   CollectionsSetList(parent, page)
--     :SetSets(sets, selected)   the sets to list, top first
--     :Select(set)               mark its row
--     :Refresh()                 the rows' progress and stars, as the log has them
--     :ScrollTo(set)             bring its row into view

local Style = MUI_CollectionsStyle
local Log   = MUI_CollectionsLog

local VIEW_W, VIEW_H = 255, 499
local ROW_W, ROW_H   = 208, 46
local ROW_LEFT       = 44          -- room for a row's icon, left of its plate
local PROGRESS_W     = 204
local MENU_W         = 140

-- ---------------------------------------------------------------------
-- CollectionsSetRow
-- ---------------------------------------------------------------------
class "CollectionsSetRow" : extends "Button" {
    __init = function(self, parent, list)
        Button.__init(self, parent)
        self:SetSize(ROW_W, ROW_H)
        -- The icon stands left of the plate: a click on it is the row's too.
        self:SetHitRectInsets(2 - ROW_LEFT, 0, 0, 0)
        self:SetClickSound(nil)
        self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        self.set = nil
        self._list = list

        local plate = Texture(self, nil, "BACKGROUND")
        Style:SetPiece(plate, "Row", true)
        plate:FillParent()

        self._name = Style:Label(self, 12, 1, 0.82, 0, "ARTWORK")
        self._name:SetJustifyH("LEFT")
        self._name:SetWidth(190)
        self._name:SetMaxLines(2)
        self._name:AlignParentLeft(6, 6)

        self._source = Style:Label(self, 10, 0.329, 0.329, 0.329, "ARTWORK")
        self._source:SetJustifyH("LEFT")
        self._source:SetWidth(190)
        self._source:SetMaxLines(1)
        self._source:Below(self._name, 2)

        self._progress = Texture(self, nil, "ARTWORK")
        self._progress:SetColorTexture(0.0118, 0.247, 0.00392, 1)
        self._progress:SetSize(PROGRESS_W, 2)
        self._progress:AlignParentBottomLeft(2, 2)

        self._selected = Texture(self, nil, "OVERLAY")
        Style:SetPiece(self._selected, "RowSelected", true)
        self._selected:FillParent()
        self._selected:Hide()

        local glow = Texture(self, nil, "HIGHLIGHT")
        Style:SetPiece(glow, "RowHighlight", true)
        glow:FillParent()

        self:_BuildIcon()

        self.OnClick = function(_, button)
            if button == "RightButton" then
                list:ShowMenu(self)
            else
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                list:OnRowClicked(self.set)
            end
        end
    end;

    -- The set's first piece, dimmed until the set is whole, a star on its
    -- corner for a favourite.
    _BuildIcon = function(self)
        local holder = Frame("Frame", self)
        holder:SetSize(38, 38)
        holder:AlignParentLeft(-42)

        self._icon = Texture(holder, nil, "ARTWORK")
        self._icon:FillParent()

        self._cover = Texture(holder, nil, "OVERLAY")
        self._cover:SetDrawLayer("OVERLAY", -1)
        self._cover:SetColorTexture(0, 0, 0, 0.7)
        self._cover:FillParent()

        self._star = Style:Piece(holder, "OVERLAY", "Favorite", 1)
        self._star:SetSize(25, 27)
        self._star:AlignParentTopLeft(-8, -8)

        -- Hover only: a click here goes on to the row.
        holder:EnableMouseMotion(true)
        holder:SetScript("OnEnter", function() self._list:ShowTooltip(holder, self.set) end)
        holder:SetScript("OnLeave", function() MUI_Tooltip:Hide() end)
    end;

    Set = function(self, set, selected)
        self.set = set
        self._name:SetText(MUI_ItemSetDB:GetName(set))
        self._source:SetText(MUI_ItemSetDB:GetSource(set))
        self._icon:SetTexture(C_Item.GetItemIconByID(set.items[1]))
        if self._list:IsForPlayerClass(set) then
            self._icon:SetVertexColor(1, 1, 1)
        else
            self._icon:SetVertexColor(1, 0.125, 0.125)
        end
        self._selected:SetVisible(selected)
        self:Refresh()
    end;

    SetSelected = function(self, selected)
        self._selected:SetVisible(selected)
    end;

    Refresh = function(self)
        local held, total = Log:Count(self.set)
        local whole = held == total
        if whole then
            self._name:SetTextColor(1, 0.82, 0, 1)
        elseif held == 0 then
            self._name:SetTextColor(0.5, 0.5, 0.5, 1)
        else
            self._name:SetTextColor(0.251, 0.753, 0.251, 1)
        end
        self._icon:SetDesaturated(held == 0)
        self._cover:SetVisible(not whole)
        self._star:SetVisible(Log:IsFavorite(self.set.id))
        self._progress:SetVisible(held > 0 and not whole)
        self._progress:SetWidth(math.max(PROGRESS_W * held / total, 0.1))
    end;
}

-- ---------------------------------------------------------------------
-- CollectionsSetList
-- ---------------------------------------------------------------------
class "CollectionsSetList" : extends "Frame" {
    __init = function(self, parent, page)
        Frame.__init(self, "Frame", parent)
        self:SetSize(VIEW_W, VIEW_H)
        self._page = page
        self._sets = {}
        self._rows = {}
        self._selected = nil

        self._scroll = AdventureGuideScroll(self, VIEW_W, VIEW_H, ROW_H)
        self._scroll:AlignParentTopLeft()
        -- Retail's bar starts beside the search box, above the rows.
        self._scroll:PlaceBar(8, -31, -1)

        -- A row's right-click menu. It is not on the canvas, so its size is
        -- its own.
        self._menu = DropdownMenu(self, "MUI_CollectionsSetMenu")
        self._menu:SetMenuWidth(MENU_W)
        self._menu:SetItems({
            { label = BATTLE_PET_FAVORITE, OnClick = function()
                local id = self._menuSet.id
                Log:SetFavorite(id, not Log:IsFavorite(id))
            end },
        })
    end;

    SetSets = function(self, sets, selected)
        self._sets, self._selected = sets, selected
        local content = self._scroll.content
        for i, set in ipairs(sets) do
            local row = self._rows[i]
            if not row then
                row = CollectionsSetRow(content, self)
                row:AlignParentTopLeft((i - 1) * ROW_H, ROW_LEFT)
                self._rows[i] = row
            end
            row:Set(set, set == selected)
            row:Show()
        end
        for i = #sets + 1, #self._rows do
            self._rows[i]:Hide()
        end
        self._scroll:SetContentHeight(#sets * ROW_H)
    end;

    Select = function(self, set)
        self._selected = set
        for i = 1, #self._sets do
            self._rows[i]:SetSelected(self._sets[i] == set)
        end
    end;

    Refresh = function(self)
        for i = 1, #self._sets do
            self._rows[i]:Refresh()
        end
    end;

    ScrollTo = function(self, set)
        for i, other in ipairs(self._sets) do
            if other == set then
                local top = (i - 1) * ROW_H
                local scrolled = self._scroll:GetScroll()
                if top < scrolled then
                    self._scroll:ScrollTo(top)
                elseif top + ROW_H > scrolled + VIEW_H then
                    self._scroll:ScrollTo(top + ROW_H - VIEW_H)
                end
                return
            end
        end
    end;

    IsForPlayerClass = function(self, set)
        return self._page:IsForPlayerClass(set)
    end;

    OnRowClicked = function(self, set)
        self._menu:Close()
        self._page:SelectSet(set)
    end;

    ShowMenu = function(self, row)
        self._menuSet = row.set
        self._menu:SetItemLabel(1, Log:IsFavorite(row.set.id) and BATTLE_PET_UNFAVORITE or BATTLE_PET_FAVORITE)
        self._menu:SetToggleAnchor(row)
        self._menu:Open()
    end;

    -- A set's name, and whose it is: its classes in red when the player's is
    -- not one of them.
    ShowTooltip = function(self, owner, set)
        local page = self._page
        MUI_Tooltip:ShowFor(owner, "ANCHOR_RIGHT", function(tip)
            tip:AddLine(MUI_ItemSetDB:GetName(set), 1, 1, 1, false, 13)
            local classes = page:ClassNames(set)
            if classes then
                if page:IsForPlayerClass(set) then
                    tip:AddLine(ITEM_CLASSES_ALLOWED:format(classes), 1, 1, 1, true)
                else
                    tip:AddLine(ITEM_CLASSES_ALLOWED:format(classes), 1, 0.125, 0.125, true)
                end
            end
            if set.faction then
                tip:AddLine(set.faction == "Alliance" and FACTION_ALLIANCE or FACTION_HORDE, 1, 1, 1, true)
            end
        end)
    end;
}
