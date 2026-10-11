-- MUI_Loot: retail's loot window — a flat panel that fits what it holds and
-- scrolls past five items, a card to a loot slot, and retail's animations:
-- the window rises into place and sinks away, a card fades in, and under
-- auto loot each card slides off to the right as it is taken.
--
-- Era's LootFrame (four buttons to a page) is not shown any more: it no
-- longer hears the loot events, so nothing opens it. It still hears the
-- master loot events and still owns MasterLooterFrame, the list of raid
-- members an item is handed to. A click on a card leaves in LootFrame's
-- fields what that list reads: the slot, the item, and the frame to open
-- under.
--
-- The window is ours alone, not one of the panel manager's: Escape closes
-- it through UISpecialFrames, and it opens where Edit Mode has it. Left at
-- its default place it opens where a panel would, beside the ones that are
-- open; with "Open Loot Window at Mouse" it opens under the cursor.

-- Retail's Interface/LootFrame/LootFrame sheet (512x1024): x, y, w, h.
local SHEET = MUI.TEX_SKIN .. "loot\\loot-frame"
local ART = {
    card   = { 1, 457, 298, 76 },     -- looting_itemcard_bg
    stroke = { 1, 691, 298, 76 },     -- looting_itemcard_stroke_normal
    glow   = { 1, 613, 298, 76 },     -- looting_itemcard_stroke_clickstate
    tag    = { 301, 457, 208, 15 },   -- looting_raritytag_frame
    shade  = { 0, 1, 8, 150 },        -- _looting_itemcard_shadow-center
}

-- Retail's ScrollingFlatPanel / LootFrame metrics.
local PANEL_W     = 220
local PANEL_MAX_H = 290
local CHROME_H    = 46                -- the window's height over its cards'
local BAR_ROOM    = 16                -- it widens by this for the scroll bar
local LIST_X, LIST_TOP, LIST_BOTTOM = 4, 22, 4
local LIST_W      = PANEL_W - 6
local PAD         = 6                 -- around the cards
local CARD_W      = LIST_W - 2 * PAD
local CARD_H      = 46
local CARD_GAP    = 2
local ICON        = 37

local function Paint(texture, art, flipped)
    texture:SetTextureRegion(SHEET, 512, 1024, art[1], art[2], art[3], art[4], false, flipped)
end

-- ---------------------------------------------------------------------
-- LootCard: one loot slot — retail's LootFrameItemElement, or its money
-- element for coins.
-- ---------------------------------------------------------------------
class "LootCard" : extends "Button" {
    __init = function(self, parent, index)
        Button.__init(self, parent, "MUI_LootCard" .. index)
        self:SetSize(CARD_W, CARD_H)
        self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        self:SetClickSound(nil)
        self.slot    = nil            -- the loot slot shown
        self.quality = nil

        -- The card takes the quality's colour.
        self._card = Texture(self, nil, "BACKGROUND")
        Paint(self._card, ART.card)
        self._card:FillParent()

        self._tag = Texture(self, nil, "BACKGROUND")
        self._tag:SetDrawLayer("BACKGROUND", 1)
        Paint(self._tag, ART.tag)
        self._tag:SetSize(100, 13)
        self._tag:AlignParentTopRight(0, 0)

        local stroke = Texture(self, nil, "BORDER")
        Paint(stroke, ART.stroke)
        stroke:FillParent()

        self._icon = ItemIcon(self, nil, "ARTWORK")
        self._icon:SetSize(ICON, ICON)
        self._icon:AlignParentTopLeft(4, 5)

        self._slotArt = Texture(self, nil, "ARTWORK")
        self._slotArt:SetDrawLayer("ARTWORK", 1)
        self._slotArt:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        self._slotArt:SetSize(64, 64)
        self._slotArt:CenterAt(self._icon, 0, -1)

        self._quest = Texture(self, nil, "OVERLAY")
        self._quest:SetDrawLayer("OVERLAY", 1)
        self._quest:SetSize(37, 38)
        self._quest:AlignTop(self._icon, 0)

        self._count = FontString(self, nil, "OVERLAY", "NumberFontNormal")
        self._count:SetDrawLayer("OVERLAY", 2)
        self._count:SetJustifyH("RIGHT")
        self._count:AlignBottomRight(self._icon, 5, 2)

        self._name = FontString(self, nil, "ARTWORK")
        self._name:SetFontSize(12)
        self._name:SetShadowOffset(1, -1)
        self._name:SetJustifyH("LEFT")
        self._name:SetWordWrap(true)

        self._grade = FontString(self, nil, "ARTWORK")
        self._grade:SetFontSize(8)
        self._grade:SetTextColor(1, 1, 1, 1)
        self._grade:SetJustifyH("RIGHT")
        self._grade:AlignParentTopRight(2, 4)

        -- Under the cursor, and while a button is held on it.
        self._hover = Texture(self, nil, "OVERLAY")
        self._hover:SetDrawLayer("OVERLAY", 3)
        Paint(self._hover, ART.glow)
        self._hover:SetBlendMode("ADD")
        self._hover:SetAlpha(0.7)
        self._hover:FillParent()
        self._hover:Hide()

        self._press = Texture(self, nil, "OVERLAY")
        self._press:SetDrawLayer("OVERLAY", 3)
        Paint(self._press, ART.glow)
        self._press:SetBlendMode("ADD")
        self._press:FillParent()
        self._press:Hide()

        self:SetScript("OnMouseDown", function() self._press:Show() end)
        self:SetScript("OnMouseUp", function() self._press:Hide() end)
        self:SetScript("OnHide", function()
            self._hover:Hide()
            self._press:Hide()
        end)
        -- The tooltip asks its owner to fill it again several times a second:
        -- the comparison follows Shift, the cursor the dressing room key.
        self:SetNativeMethod("UpdateTooltip", function() self:_ShowTooltip() end)

        self:_BuildAnimations()
    end;

    -- Retail's ShowAnim and SlideOutRightAnim. The card's own alpha stays 1:
    -- a fade that is cut short falls back to it.
    _BuildAnimations = function(self)
        self._appear = AnimationGroup(self)
        local fadeIn = self._appear:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(1)
        fadeIn:SetDuration(0.1)
        fadeIn:SetSmoothing("IN")

        self._slide = AnimationGroup(self)
        self._slide:SetToFinalAlpha(true)
        local move = self._slide:CreateAnimation("Translation")
        move:SetOffset(100, 0)
        move:SetDuration(0.3)
        move:SetSmoothing("IN")
        local fadeOut = self._slide:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0)
        fadeOut:SetDuration(0.2)
        fadeOut:SetStartDelay(0.1)
        fadeOut:SetSmoothing("IN")
        self._slide:SetScript("OnFinished", function() self:Hide() end)
    end;

    -- Show loot slot `slot`, fading in.
    Set = function(self, slot)
        local texture, item, quantity, currencyID, quality, locked, isQuestItem, questID, isActive = GetLootSlotInfo(slot)
        if currencyID then
            item, texture, quantity, quality =
                CurrencyContainerUtil.GetCurrencyContainerInfo(currencyID, quantity, item, texture, quality)
        end
        quality = quality or 1
        self.slot    = slot
        self.quality = quality

        local color = ITEM_QUALITY_COLORS[quality]
        self._card:SetVertexColor(color.r, color.g, color.b)
        self._name:SetText(item or "")
        self._name:SetTextColor(color.r, color.g, color.b, 1)

        -- An item's name runs to two lines under its quality; coins have
        -- no quality and sit level with the icon.
        local money = GetLootSlotType(slot) == Enum.LootSlotType.Money
        self._name:ClearAllPoints()
        if money then
            self._name:SetSize(93, 38)
            self._name:SetJustifyV("MIDDLE")
            self._name:RightOf(self._icon, 8, 0)
        else
            self._name:SetSize(150, 30)
            self._name:SetJustifyV("TOP")
            self._name:RightOf(self._icon, 8, -4.5)
            self._grade:SetText(getglobal("ITEM_QUALITY" .. quality .. "_DESC"))
        end
        self._tag:SetVisible(not money)
        self._grade:SetVisible(not money)

        self._icon:SetTexture(texture)
        self._icon:SetQuality(quality)
        local shade = locked and 0 or 1
        self._icon:SetVertexColor(locked and 0.9 or 1, shade, shade)
        self._slotArt:SetVertexColor(locked and 0.9 or 1, shade, shade)

        if quantity and quantity > 1 then
            self._count:SetText(quantity)
            self._count:Show()
        else
            self._count:Hide()
        end

        if questID and not isActive then
            self._quest:SetTexture(TEXTURE_ITEM_QUEST_BANG)
            self._quest:Show()
        elseif questID or isQuestItem then
            self._quest:SetTexture(TEXTURE_ITEM_QUEST_BORDER)
            self._quest:Show()
        else
            self._quest:Hide()
        end

        -- An item the client has yet to hear of comes without a texture;
        -- Era's frame, too, looks again half a second later.
        self:SetEnabled(texture ~= nil)
        if not texture then
            C_Timer.After(0.5, function()
                if self.slot == slot and self:IsVisible() then self:Set(slot) end
            end)
        end

        self._slide:Stop()
        self:SetAlpha(1)
        self:Show()
        self._appear:Play()
    end;

    -- Taken by auto loot: off to the right, then gone.
    SlideOut = function(self)
        self._slide:Play()
    end;

    _ShowTooltip = function(self)
        local kind = GetLootSlotType(self.slot)
        if kind == Enum.LootSlotType.Item then
            MUI_Tooltip:SetOwner(self, "ANCHOR_RIGHT")
            MUI_Tooltip:SetLootItem(self.slot)
        elseif kind == Enum.LootSlotType.Currency then
            MUI_Tooltip:SetOwner(self, "ANCHOR_RIGHT")
            MUI_Tooltip:SetLootCurrency(self.slot)
        else
            return
        end
        if IsModifiedClick("DRESSUP") then ShowInspectCursor() else ResetCursor() end
    end;

    OnEnter = function(self)
        self._hover:Show()
        self:_ShowTooltip()
    end;

    OnLeave = function(self)
        self._hover:Hide()
        MUI_Tooltip:Hide()
        ResetCursor()
    end;

    OnClick = function(self)
        if IsModifiedClick() then
            HandleModifiedItemClick(GetLootSlotLink(self.slot))
            return
        end
        -- What Era's master loot list reads, should taking this item call
        -- for it (OPEN_MASTER_LOOT_LIST, still LootFrame's to hear).
        StaticPopup_Hide("CONFIRM_LOOT_DISTRIBUTION")
        Frame(MasterLooterFrame):Hide()
        LootFrame.selectedLootButton = self:GetName()
        LootFrame.selectedSlot       = self.slot
        LootFrame.selectedQuality    = self.quality
        LootFrame.selectedItemName   = self._name:GetText()
        LootFrame.selectedTexture    = self._icon:GetTexture()
        LootSlot(self.slot)
    end;
}

-- ---------------------------------------------------------------------
-- LootWindow
-- ---------------------------------------------------------------------
class "LootWindow" : extends {"Panel", "Editable"} {
    __init = function(self)
        Panel.__init(self, nil, "MUI_LootFrame", ITEMS)
        self:SetFrameStrata("HIGH")
        self:SetToplevel(true)
        self:SetClampedToScreen(true)
        self:SetSize(PANEL_W, PANEL_MAX_H)
        self:Hide()

        self._cards      = {}
        self._used       = 0          -- cards showing this loot's slots
        self._looting    = false      -- from LOOT_OPENED until the window hides
        self._auto       = false      -- this loot is being taken by auto loot
        self._previewing = false      -- shown empty, for Edit Mode

        self:_BuildList()
        self:_BuildAnimations()
        self._closeButton.OnClick = function() self:Close() end
        self:SetScript("OnHide", function() self:_OnHide() end)
        tinsert(UISpecialFrames, "MUI_LootFrame")

        self:RegisterEventHandler("LOOT_OPENED", function(_, _, autoLoot) self:_OnLootOpened(autoLoot) end)
        self:RegisterEventHandler("LOOT_SLOT_CLEARED", function(_, _, slot) self:_OnSlotCleared(slot) end)
        self:RegisterEventHandler("LOOT_SLOT_CHANGED", function(_, _, slot) self:_OnSlotChanged(slot) end)
        self:RegisterEventHandler("LOOT_CLOSED", function() self:Close() end)

        self:SeatDefault()
        Editable.__init(self)
        self:EditModeSetLabel("Loot Window")
        self:EditModeSetOption("loot")
        self:EditModeSetDragAnchor("TOPLEFT")
        self:EditModeSetDefaultPosition(function() self:SeatDefault() end)
        self:EditModeSetupSettings(function(content) end)
    end;

    -- The cards' scrolling list, its bar, and the shadows that close the
    -- list off where it runs on past an edge. The list is retail's scroll
    -- box in small: a frame that clips, and the cards' frame moved up
    -- inside it by the scroll offset.
    _BuildList = function(self)
        self._list = Frame("Frame", self)
        self._list:SetClipsChildren(true)
        self._list:AlignParentTopLeft(LIST_TOP, LIST_X)
        self._list:AlignParentBottomLeft(LIST_BOTTOM, LIST_X)
        self._list:SetWidth(LIST_W)
        self._content = Frame("Frame", self._list)
        self._content:SetSize(LIST_W, 1)
        self._content:AlignParentTopLeft(0, 0)

        self._bar = MinimalScrollBar(self)
        self._bar:AlignParentTopRight(28, 8)
        self._bar:AlignParentBottomRight(6, 8)
        self._bar:SetScrollSpeed(CARD_H + CARD_GAP)
        self._bar.OnScroll = function(_, value) self:_ScrollTo(value) end
        self._bar:Hide()

        self._list:EnableMouseWheel(true)
        self._list:SetScript("OnMouseWheel", function(_, delta)
            self._bar:SetValue(self._bar:GetValue() - delta * (CARD_H + CARD_GAP))
        end)

        local shades = Frame("Frame", self)
        shades:Fill(self._list)
        shades:PutInfront(self._list, 15)
        self._shadeTop = Texture(shades, nil, "ARTWORK")
        Paint(self._shadeTop, ART.shade, true)
        self._shadeTop:SetHeight(30)
        self._shadeTop:AlignParentTopLeft(0, 6)
        self._shadeTop:AlignParentTopRight(0, 6)
        self._shadeBottom = Texture(shades, nil, "ARTWORK")
        Paint(self._shadeBottom, ART.shade)
        self._shadeBottom:SetHeight(30)
        self._shadeBottom:AlignParentBottomLeft(0, 6)
        self._shadeBottom:AlignParentBottomRight(0, 6)
    end;

    -- Retail's ScrollingFlatPanel animations: 10 px of travel and a fade in
    -- a tenth of a second. It plays its ShowAnim backwards, so the window
    -- rises into place as it appears, and sinks as it goes. The window's own
    -- alpha stays 1 while it is up; only the way out is left at its end, so
    -- the window does not show once more before it hides.
    _BuildAnimations = function(self)
        local function sink(group)
            local move = group:CreateAnimation("Translation")
            move:SetOffset(0, -10)
            move:SetDuration(0.1)
            move:SetSmoothing("IN")
            local fade = group:CreateAnimation("Alpha")
            fade:SetFromAlpha(1)
            fade:SetToAlpha(0)
            fade:SetDuration(0.1)
            fade:SetSmoothing("IN")
        end
        self._showAnim = AnimationGroup(self)
        sink(self._showAnim)
        self._hideAnim = AnimationGroup(self)
        self._hideAnim:SetToFinalAlpha(true)
        sink(self._hideAnim)
        self._hideAnim:SetScript("OnFinished", function() self:Hide() end)
    end;

    -- ---- placing ---------------------------------------------------------

    -- Retail's default anchor, where a panel opens; with panels open, beside
    -- the last of them, as Era's own loot frame was pushed along.
    SeatDefault = function(self)
        self:ClearAllPoints()
        local panel = GetUIPanel("right") or GetUIPanel("center") or GetUIPanel("doublewide") or GetUIPanel("left")
        if panel then
            local last, scale = Frame(panel), self:GetScale()
            local edge = last:GetLeft() * last:GetScale() + GetUIPanelWidth(panel)
            self:AlignParentTopLeft(116 / scale, (edge + 10) / scale)
        else
            self:AlignParentTopLeft(116, 16)
        end
    end;

    _Seat = function(self)
        if GetCVarBool("lootUnderMouse") then
            -- The first card's icon under the cursor, as retail places it.
            local scale = self:GetEffectiveScale()
            local x, y = GetCursorPosition()
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", MUI_Root, "BOTTOMLEFT", x / scale - 30, math.max(y / scale + 50, 350))
        else
            MUI_EditMode:ReassertLayout(self)
        end
    end;

    -- ---- contents --------------------------------------------------------

    -- A card for every slot that holds something. Returns how many.
    _Fill = function(self)
        local used = 0
        for slot = 1, GetNumLootItems() do
            if LootSlotHasItem(slot) then
                used = used + 1
                local card = self._cards[used]
                if not card then
                    card = LootCard(self._content, used)
                    card:AlignParentTopLeft(PAD + (used - 1) * (CARD_H + CARD_GAP), PAD)
                    self._cards[used] = card
                end
                card:Set(slot)
            end
        end
        for i = used + 1, #self._cards do
            self._cards[i]:Hide()
        end
        self._used = used
        return used
    end;

    -- Size the window for `count` cards, as retail's Resize does: as tall as
    -- they need up to the panel's most, wider by the scroll bar past that.
    _Fit = function(self, count)
        local rows    = math.max(count, 1)
        local cards   = rows * CARD_H + (rows - 1) * CARD_GAP
        local height  = math.min(cards + CHROME_H, PANEL_MAX_H)
        local view    = height - LIST_TOP - LIST_BOTTOM
        local content = cards + 2 * PAD
        local range   = math.max(content - view, 0)

        self:SetSize(PANEL_W + (range > 0 and BAR_ROOM or 0), height)
        self._content:SetHeight(content)
        self._bar:SetMinMax(0, range)
        self._bar:SetContentSize(view, content)
        self._bar:SetValue(0)
        self._bar:SetVisible(range > 0)
        self:_ScrollTo(0)
    end;

    -- Move the cards up by `offset`; a shadow lies over each edge of the
    -- list that has cards beyond it.
    _ScrollTo = function(self, offset)
        self._content:ClearAllPoints()
        self._content:AlignParentTopLeft(-offset, 0)
        self._shadeTop:SetVisible(offset > 0)
        self._shadeBottom:SetVisible(offset < self._bar:GetMax())
    end;

    _CardOf = function(self, slot)
        for i = 1, self._used do
            if self._cards[i].slot == slot then return self._cards[i] end
        end
    end;

    -- ---- loot ------------------------------------------------------------

    _OnLootOpened = function(self, autoLoot)
        self._auto       = autoLoot and true or false
        self._looting    = true
        self._previewing = false

        -- Shown before it is filled, so the cards' fades start on a window
        -- that is up.
        self._hideAnim:Stop()
        self:SetAlpha(1)
        self:Show()
        self:Raise()

        local count = self:_Fill()
        self:_Fit(count)
        self:_Seat()
        self._showAnim:Play(true)

        if IsFishingLoot() then
            PlaySound(SOUNDKIT.FISHING_REEL_IN)
        elseif count == 0 then
            PlaySound(SOUNDKIT.LOOT_WINDOW_OPEN_EMPTY)
        end
    end;

    -- The other cards keep their places, as in retail.
    _OnSlotCleared = function(self, slot)
        local card = self._looting and self:_CardOf(slot)
        if not card then return end
        if self._auto then
            card:SlideOut()
        else
            card:Hide()
        end
    end;

    _OnSlotChanged = function(self, slot)
        if not self._looting then return end
        local card = self:_CardOf(slot)
        if card then
            card:Set(slot)
        else
            self:_Fit(self:_Fill())
        end
    end;

    -- The loot is over, or the close button was pressed: sink away, then
    -- hide. Hiding is what tells the game the loot is closed.
    Close = function(self)
        if not self:IsShown() or self._hideAnim:IsPlaying() then return end
        self._showAnim:Stop()
        self._hideAnim:Play()
    end;

    _OnHide = function(self)
        self._looting    = false
        self._previewing = false
        self._showAnim:Stop()
        self._hideAnim:Stop()
        CloseLoot()
        StaticPopup_Hide("LOOT_BIND")
        StaticPopup_Hide("CONFIRM_LOOT_DISTRIBUTION")
        Frame(MasterLooterFrame):Hide()
    end;

    -- ---- Edit Mode -------------------------------------------------------

    -- Shown empty and at its full height while Edit Mode is up, as retail
    -- shows it, and from where it opens when it is not opened at the cursor
    -- (unless it was moved since Edit Mode came up: its checkbox there can
    -- put it away and up again, and it then comes back where it was left).
    EditModeShow = function(self)
        if not self._editEnabled then return end
        if not self._looting then
            if not self:EditModeIsDirty() then MUI_EditMode:ReassertLayout(self) end
            self._showAnim:Stop()
            self._hideAnim:Stop()
            self:_Fit(self:_Fill())
            self:SetHeight(PANEL_MAX_H)
            self:SetAlpha(1)
            self:Show()
            self._previewing = true
        end
        Editable.EditModeShow(self)
    end;

    EditModeHide = function(self)
        Editable.EditModeHide(self)
        if self._previewing then self:Hide() end
    end;
}

object "ModuleLoot" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Loot")
    end;

    OnEnable = function(self)
        -- Era's loot frame no longer hears of loot; the master loot events
        -- stay with it.
        local era = Frame(LootFrame)
        for _, event in ipairs({ "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_SLOT_CHANGED", "LOOT_CLOSED", "LOOT_READY" }) do
            era:UnregisterEvent(event)
        end

        self.window = LootWindow()
    end;
}
