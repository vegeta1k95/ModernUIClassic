-- MUI_CollectionsSetDetails: the set on show, right of the list — the
-- character wearing it against retail's wardrobe wall, its name and where it
-- comes from over the model's head, its pieces in a row under them (retail's
-- WardrobeSetsCollectionFrame.Model and DetailsFrame).
--
-- Retail frames the character with a camera of its wardrobe's own, which Era
-- has no data for: the model keeps the camera the client gives a unit, which
-- fits the character to the model's frame. So the frame is the wall under the
-- row of pieces, not all of it as retail's. The left button turns the model,
-- the wheel moves in on it, the right button slides it about.
--
--   CollectionsSetDetails(parent)     fills an inset frame
--     :SetSet(set)                    nil: nothing to show
--     :Refresh()                      which pieces are held, as the log has it
--     :Reset()                        the model back as it first stood

local Style = MUI_CollectionsStyle
local Log   = MUI_CollectionsLog

local ITEM_SPACE = 37              -- an item's frame and the gap to the next
local MODEL_TOP  = 145             -- the row of pieces' lower edge, from the inset's top

local DRAG_TURN  = 0.010           -- radians a pixel of drag turns the model
local ZOOM_STEP  = 0.15
local ZOOM_MAX   = 0.8
local PAN_PIXELS = 100             -- pixels of drag that move the model one unit
local PAN_SIDE, PAN_HEIGHT = 1, 1.5

local BORDER_OF_QUALITY = { [2] = "Border2", [3] = "Border3", [4] = "Border4", [5] = "Border5" }

-- ---------------------------------------------------------------------
-- CollectionsSetItem: a piece of the set — its icon in its quality's border,
-- greyed out while the character has never held it.
-- ---------------------------------------------------------------------
class "CollectionsSetItem" : extends "Button" {
    __init = function(self, parent)
        Button.__init(self, parent)
        self:SetSize(32, 32)
        self:SetClickSound(nil)
        self.item = nil
        self._quality = nil

        self._icon = Texture(self, nil, "BORDER")
        self._icon:SetSize(28, 28)
        self._icon:CenterInParent()

        self._border = Texture(self, nil, "OVERLAY")
        self._border:CenterAt(self._icon, -0.5, 1)

        self.OnEnter = function()
            MUI_Tooltip:ShowFor(self, "ANCHOR_RIGHT", function(tip)
                tip:SetHyperlink("item:" .. self.item)
                if Log:Has(self.item) then
                    tip:AddLine(COLLECTED, 0.251, 0.753, 0.251)
                else
                    tip:AddLine(NOT_COLLECTED, 0.5, 0.5, 0.5)
                end
            end)
        end
        self.OnLeave = function() MUI_Tooltip:Hide() end
        -- Shift links the piece in chat, Control opens the dressing room.
        self.OnClick = function()
            local _, link = C_Item.GetItemInfo(self.item)
            if link then HandleModifiedItemClick(link) end
        end
    end;

    -- `quality`: the set's, until the client has the item's own.
    Set = function(self, item, quality)
        self.item = item
        self._quality = quality
        self._icon:SetTexture(C_Item.GetItemIconByID(item))
        self:Refresh()
    end;

    Refresh = function(self)
        local held = Log:Has(self.item)
        local quality = C_Item.GetItemQualityByID(self.item) or self._quality
        Style:SetPiece(self._border, held and BORDER_OF_QUALITY[quality] or "Border")
        self._icon:SetDesaturated(not held)
        self._icon:SetAlpha(held and 1 or 0.3)
        self._border:SetDesaturated(not held)
        self._border:SetAlpha(held and 1 or 0.3)
    end;
}

-- ---------------------------------------------------------------------
-- CollectionsSetModel: the player's character in nothing but the pieces
-- given.
-- ---------------------------------------------------------------------
class "CollectionsSetModel" : extends "DressUpModel" {
    __init = function(self, parent)
        DressUpModel.__init(self, parent)
        self._items  = {}
        self._loaded = false           -- the unit's model is in
        self:_Home()

        self:SetAutoDress(false)
        self:EnableMouse(true)
        self:EnableMouseWheel(true)
        self:SetScript("OnMouseDown", function(_, button)
            local x, y = GetCursorPosition()
            if button == "LeftButton" then
                self._turnFrom = x
            elseif button == "RightButton" then
                self._slideFrom = { x, y, self._side, self._height }
            end
        end)
        self:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then
                self._turnFrom = nil
            elseif button == "RightButton" then
                self._slideFrom = nil
            end
        end)
        self:SetScript("OnMouseWheel", function(_, delta)
            self._zoom = math.min(ZOOM_MAX, math.max(0, self._zoom + delta * ZOOM_STEP))
            self:SetPortraitZoom(self._zoom)
        end)
        self:SetScript("OnUpdate", function() self:_OnUpdate() end)
        -- A hidden model comes back empty: it is set up again each time it shows.
        self:SetScript("OnShow", function() self:_Load() end)
        self:SetScript("OnHide", function()
            self._loaded = false
            self._turnFrom, self._slideFrom = nil, nil
        end)
        self:RegisterUnitEventHandler("UNIT_MODEL_CHANGED", "player", function()
            if self:IsVisible() then self:_Load() end
        end)
    end;

    SetItems = function(self, items)
        self._items = items
        if self._loaded then self:_Dress() end
    end;

    -- Facing the viewer, whole and centred.
    Reset = function(self)
        self:_Home()
        if self._loaded then self:_Place() end
    end;

    _Home = function(self)
        self._facing = 0
        self._zoom   = 0
        self._side, self._height = 0, 0
    end;

    _Load = function(self)
        self:SetUnit("player")
        self._loaded = true
        self:_Dress()
        self:_Place()
    end;

    _Dress = function(self)
        self:Undress()
        for _, item in ipairs(self._items) do
            self:TryOn("item:" .. item)
        end
    end;

    _Place = function(self)
        self:SetFacing(self._facing)
        self:SetPortraitZoom(self._zoom)
        self:SetPosition(0, self._side, self._height)
    end;

    _OnUpdate = function(self)
        if self._turnFrom then
            local x = GetCursorPosition()
            self._facing = (self._facing + (x - self._turnFrom) * DRAG_TURN) % (2 * math.pi)
            self._turnFrom = x
            self:SetFacing(self._facing)
        elseif self._slideFrom then
            local x, y = GetCursorPosition()
            local from = self._slideFrom
            self._side   = math.max(-PAN_SIDE, math.min(PAN_SIDE, from[3] + (x - from[1]) / PAN_PIXELS))
            self._height = math.max(-PAN_HEIGHT, math.min(PAN_HEIGHT, from[4] + (y - from[2]) / PAN_PIXELS))
            self:SetPosition(0, self._side, self._height)
        end
    end;
}

-- ---------------------------------------------------------------------
-- CollectionsSetDetails
-- ---------------------------------------------------------------------
class "CollectionsSetDetails" : extends "Frame" {
    __init = function(self, parent)
        Frame.__init(self, "Frame", parent)
        self:FillParent()
        self._set = nil
        self._items = {}
        self._stale = false

        self._model = CollectionsSetModel(self)
        self._model:FillParentPadding(3, MODEL_TOP, 4, 3)

        -- Over the model: what the set is.
        local over = Frame("Frame", self)
        over:FillParentPadding(0, 3, 3, 2)
        over:PutInfront(self._model, 5)
        self._over = over

        local fade = Texture(over, nil, "BACKGROUND")
        Style:SetPiece(fade, "ModelFade", true)
        fade:SetHeight(178)
        fade:AlignParentTopLeft(0, 2)
        fade:AlignParentTopRight(0, 0)

        local band = Style:Piece(over, "BORDER", "IconRow")
        band:AlignParentTop(78)

        self._name = Style:Title(over, 24, "ARTWORK")
        self._name:SetWidth(380)
        self._name:SetMaxLines(1)
        self._name:AlignParentTop(37)

        -- A name too long for one line, smaller on two.
        self._longName = Style:Title(over, 16, "ARTWORK")
        self._longName:SetWidth(380)
        self._longName:SetMaxLines(2)
        self._longName:AlignParentTop(30)
        self._longName:Hide()

        self._source = Style:Label(over, 12, 1, 1, 1, "ARTWORK")
        self._source:SetWidth(380)
        self._source:SetMaxLines(1)
        self._source:AlignParentTop(63)

        -- A piece's quality and link come with its item data; the model may
        -- not show a piece the client has not loaded yet.
        self:RegisterEventHandler("GET_ITEM_INFO_RECEIVED", function(_, _, item)
            if not self._set or not self:IsVisible() then return end
            for _, piece in ipairs(self._set.items) do
                if piece == item then
                    self._stale = true
                    return
                end
            end
        end)
        self:SetScript("OnUpdate", function()
            if not self._stale then return end
            self._stale = false
            self:Refresh()
            self._model:SetItems(self._set.items)
        end)
    end;

    SetSet = function(self, set)
        self._set = set
        self._stale = false
        self:SetVisible(set ~= nil)
        if not set then return end

        local name = MUI_ItemSetDB:GetName(set)
        self._name:SetText(name)
        self._name:Show()
        local long = self._name:IsTruncated()
        self._name:SetVisible(not long)
        self._longName:SetVisible(long)
        self._longName:SetText(name)
        self._source:SetText(MUI_ItemSetDB:GetSource(set))

        local count = #set.items
        local first = -math.floor((count - 1) * ITEM_SPACE / 2)
        for i, item in ipairs(set.items) do
            local frame = self._items[i]
            if not frame then
                frame = CollectionsSetItem(self._over)
                self._items[i] = frame
            end
            frame:ClearAllPoints()
            frame:AlignParentTop(94, first + (i - 1) * ITEM_SPACE)
            frame:Set(item, set.quality)
            frame:Show()
            if not C_Item.IsItemDataCachedByID(item) then
                C_Item.RequestLoadItemDataByID(item)
            end
        end
        for i = count + 1, #self._items do
            self._items[i]:Hide()
        end

        self._model:SetItems(set.items)
    end;

    Refresh = function(self)
        if not self._set then return end
        for i = 1, #self._set.items do
            self._items[i]:Refresh()
        end
    end;

    Reset = function(self)
        self._model:Reset()
    end;
}
