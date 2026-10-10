-- MUI_CollectionsMountList: the mounts down the left of the mounts page —
-- retail's MountListButtonTemplate rows in a scrolling column. A row shows how
-- the character stands to its mount: plain when it can ride it, on a red plate
-- when it has it and cannot (it lies in the bank, or the level or the riding
-- skill is short), grey with a faded icon while it has not got it. A side's
-- crest marks a mount only that side rides, a glow round the icon the one
-- being ridden.
--
--   CollectionsMountList(parent, page)
--     :SetMounts(mounts, selected)   the mounts to list, top first, as the
--                                    character stands to each now
--     :Select(mount)                 mark its row
--     :ScrollTo(mount)               bring its row into view

local Style = MUI_CollectionsStyle
local Log   = MUI_CollectionsLog

local VIEW_W, VIEW_H = 255, 481
local ROW_W, ROW_H   = 208, 46
local ROW_LEFT       = 44          -- room for a row's icon, left of its plate
local MENU_W         = 140

-- ---------------------------------------------------------------------
-- CollectionsMountRow
-- ---------------------------------------------------------------------
class "CollectionsMountRow" : extends "Button" {
    __init = function(self, parent, list, page)
        Button.__init(self, parent)
        self:SetSize(ROW_W, ROW_H)
        self:SetClickSound(nil)
        self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        self.mount = nil
        self._list = list
        self._page = page

        self._plate = Texture(self, nil, "BACKGROUND")
        Style:SetPiece(self._plate, "Row", true)
        self._plate:FillParent()

        self._crest = Texture(self, nil, "BORDER")
        self._crest:AlignParentBottomRight(1, 1)

        self._name = Style:Label(self, 12, 1, 0.82, 0, "ARTWORK")
        self._name:SetJustifyH("LEFT")
        self._name:SetWidth(147)
        self._name:SetMaxLines(2)
        self._name:AlignParentLeft(6, 1)

        self._selected = Texture(self, nil, "OVERLAY")
        Style:SetPiece(self._selected, "RowSelected", true)
        self._selected:FillParent()
        self._selected:Hide()

        local glow = Texture(self, nil, "HIGHLIGHT")
        Style:SetPiece(glow, "RowHighlight", true)
        glow:FillParent()

        self:_BuildIcon()

        self.OnClick = function(_, button) self:_Click(button) end
    end;

    -- The mount's icon left of the plate, a button of its own: it tells what
    -- the mount is, and a drag off it takes the mount to an action bar.
    _BuildIcon = function(self)
        local button = Button(self)
        button:SetSize(40, 40)
        button:AlignParentLeft(-43)
        button:SetClickSound(nil)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:RegisterForDrag("LeftButton")

        self._icon = Texture(button, nil, "ARTWORK")
        self._icon:SetSize(38, 38)
        self._icon:CenterInParent()

        self._riding = Texture(button, nil, "OVERLAY")
        self._riding:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        self._riding:SetBlendMode("ADD")
        self._riding:FillParent()

        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square"):SetBlendMode("ADD")

        self._star = Style:Piece(button, "OVERLAY", "Favorite", 1)
        self._star:SetSize(25, 27)
        self._star:AlignParentTopLeft(-7, -7)

        button.OnClick = function(_, mouseButton) self:_Click(mouseButton) end
        button.OnEnter = function() self._list:ShowTooltip(button, self.mount) end
        button.OnLeave = function() MUI_Tooltip:Hide() end
        button:SetScript("OnDragStart", function() self._page:PickUp(self.mount) end)
    end;

    _Click = function(self, button)
        if button == "RightButton" then
            self._list:ShowMenu(self)
        elseif IsModifiedClick("CHATLINK") then
            self._page:Link(self.mount)
        else
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            self._list:OnRowClicked(self.mount)
        end
    end;

    Set = function(self, mount, selected)
        self.mount = mount
        self._name:SetText(mount.name)
        self._icon:SetTexture(MUI_MountDB:GetIcon(mount))
        if mount.faction then Style:SetPiece(self._crest, mount.faction) end
        self._crest:SetVisible(mount.faction ~= nil)
        self._selected:SetVisible(selected)
        self:Refresh()
    end;

    SetSelected = function(self, selected)
        self._selected:SetVisible(selected)
    end;

    Refresh = function(self)
        local collected, usable, riding = self._page:StateOf(self.mount)
        -- Retail's red: the plate tinted, the icon greyed and tinted after it.
        local red = collected and not usable
        if red then
            self._plate:SetVertexColor(1, 0, 0)
            self._icon:SetVertexColor(150 / 255, 50 / 255, 50 / 255)
        else
            self._plate:SetVertexColor(1, 1, 1)
            self._icon:SetVertexColor(1, 1, 1)
        end
        self._icon:SetDesaturated(not usable)
        self._icon:SetAlpha(usable and 1 or collected and 0.75 or 0.25)
        if collected then
            self._name:SetTextColor(1, 0.82, 0, 1)
        else
            self._name:SetTextColor(0.5, 0.5, 0.5, 1)
        end
        self._riding:SetVisible(riding)
        self._star:SetVisible(Log:IsFavoriteMount(self.mount.spell))
    end;
}

-- ---------------------------------------------------------------------
-- CollectionsMountList
-- ---------------------------------------------------------------------
class "CollectionsMountList" : extends "Frame" {
    __init = function(self, parent, page)
        Frame.__init(self, "Frame", parent)
        self:SetSize(VIEW_W, VIEW_H)
        self._page = page
        self._mounts = {}
        self._rows = {}

        self._scroll = AdventureGuideScroll(self, VIEW_W, VIEW_H, ROW_H)
        self._scroll:AlignParentTopLeft()
        -- Retail's bar starts beside the search box, above the rows.
        self._scroll:PlaceBar(8, -31, -1)

        -- A row's right-click menu. It is not on the canvas, so its size is
        -- its own.
        self._menu = DropdownMenu(self, "MUI_CollectionsMountMenu")
        self._menu:SetMenuWidth(MENU_W)
        self._menu:SetItems({
            { label = BATTLE_PET_FAVORITE, OnClick = function()
                local spell = self._menuMount.spell
                Log:SetFavoriteMount(spell, not Log:IsFavoriteMount(spell))
            end },
        })
    end;

    SetMounts = function(self, mounts, selected)
        self._mounts = mounts
        local content = self._scroll.content
        for i, mount in ipairs(mounts) do
            local row = self._rows[i]
            if not row then
                row = CollectionsMountRow(content, self, self._page)
                row:AlignParentTopLeft((i - 1) * ROW_H, ROW_LEFT)
                self._rows[i] = row
            end
            row:Set(mount, mount == selected)
            row:Show()
        end
        for i = #mounts + 1, #self._rows do
            self._rows[i]:Hide()
        end
        self._scroll:SetContentHeight(#mounts * ROW_H)
    end;

    Select = function(self, mount)
        for i = 1, #self._mounts do
            self._rows[i]:SetSelected(self._mounts[i] == mount)
        end
    end;

    ScrollTo = function(self, mount)
        for i, other in ipairs(self._mounts) do
            if other == mount then
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

    OnRowClicked = function(self, mount)
        self._menu:Close()
        self._page:SelectMount(mount)
    end;

    ShowMenu = function(self, row)
        self._menuMount = row.mount
        self._menu:SetItemLabel(1, Log:IsFavoriteMount(row.mount.spell) and BATTLE_PET_UNFAVORITE or BATTLE_PET_FAVORITE)
        self._menu:SetToggleAnchor(row)
        self._menu:Open()
    end;

    -- The mount's item, or the spell of a class's own, and whether the
    -- character has it.
    ShowTooltip = function(self, owner, mount)
        local collected = self._page:StateOf(mount)
        MUI_Tooltip:ShowFor(owner, "ANCHOR_LEFT", function(tip)
            if mount.item then
                tip:SetHyperlink("item:" .. mount.item)
            else
                tip:SetSpellByID(mount.spell)
            end
            if collected then
                tip:AddLine(COLLECTED, 0.251, 0.753, 0.251)
            else
                tip:AddLine(NOT_COLLECTED, 0.5, 0.5, 0.5)
            end
        end)
    end;
}
