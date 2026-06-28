-- Modern bag button reskin

local TEX = MUI.TEX_SKIN .. "bags\\"
local ICON_SIZE = 25
local SLOT_SIZE = 30.5

-- Container windows (the bag frames) + their item slots.
local SLOT_ATLAS       = TEX .. "bagslots2x"  -- same atlas the bag-bar slots use
local BAG_SLOT         = 33                   -- native item button size
local CONTAINER_SPACING = 10
local ITEM_SPACING_X   = 5
local ITEM_SPACING_Y   = 4
-- Where the bag windows sit on screen (re-applied from UpdateContainerFrameAnchors).
local SCREEN_MARGIN_X  = 40                   -- gap from the right edge (clears the action bars)
local SCREEN_MARGIN_Y  = 70                   -- gap from the bottom edge
local BAG_STACK_GAP    = 8                    -- vertical gap between stacked bag windows

-- Combined ("join bags") mode: every bag's slots reflowed into one window.
local COMBINED_COLUMNS = 10                   -- grid width of the joined window
local COMBINED_TOP     = 52                   -- reserve for title + search box
local COMBINED_BOTTOM  = 28                   -- reserve for the money row

-- Editable container for the bottom bag bar. The bag buttons are parented to it
-- (so the whole bar drags + scales as one unit); it carries no visuals itself.
class "BagBar" : extends {"Frame", "Editable"} {
    __init = function(self)
        Frame.__init(self, "Frame", MUI_Root, "MUI_BagBar")
        Editable.__init(self)
        self:EditModeSetLabel("Bags Bar")
        self:EditModeSetupSettings(function(content) end)
    end;
}

object "ModuleBags" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Bags")
        self.bagsVisible = true
    end;

    OnEnable = function(self)

        self.backpack = Button(MainMenuBarBackpackButton)
        
        self._slots = {}

        for i = 0, 3 do
            self._slots[i] = {
                button  = Button(getglobal("CharacterBag" .. i .."Slot")),
                texture = Texture(getglobal("CharacterBag" .. i .. "SlotIconTexture")),
                count   = FontString(getglobal("CharacterBag" .. i .. "SlotCount"))
            }
        end


        self:SkinMainBag()
        self:SkinSmallBags()
        self:SkinKeyRing()
        self:CreateToggleButton()
        self:UpdateBagSlotIcons()
        self:CreateFreeSlotCounter()
        self:SkinContainerFrames()

    end;

    SkinMainBag = function(self)
        -- Container the bag bar hangs off. The backpack anchors to it (bags /
        -- keyring / toggle chain off the backpack) and every bar button is
        -- parented to it, so dragging it in edit mode moves the bar and scaling
        -- it scales every button by its own base × the slider factor.
        self.bagBar = BagBar()
        self.bagBar:SetSize(196, 46)
        self.bagBar:AlignParentBottomRight(43, 4)
        self.bagBar:EditModeSetDefaultPosition(function(b)
            b:ClearAllPoints()
            b:AlignParentBottomRight(36, 4)
        end)

        self.backpack:SetParent(self.bagBar)
        self.backpack:ClearAllPoints()
        self.backpack:AlignParentBottomRight(0, 0)
        self.backpack:SetClampedToScreen(true)
        self.backpack:SetScale(1.2)

        self.backpack:SetItemButtonTexture(TEX .. "bigbag")
        self.backpack:SetHighlightTexture(TEX .. "bigbagHighlight")
        self.backpack:SetPushedTexture(TEX .. "bigbagHighlight")
        self.backpack:SetCheckedTexture(TEX .. "bigbagHighlight")

        local normalTex = Texture(MainMenuBarBackpackButtonNormalTexture)
        if normalTex then
            normalTex:Hide()
            normalTex:SetTexture("")
        end

        local border = Texture(self.backpack, nil, "OVERLAY")
        border:SetTexture(TEX .. "bagslotCutout")
        border:FillParent()
    end;

    SkinSmallBags = function(self)
        local bagAtlas = TEX .. "bagslots2x"

        local bag0 = self._slots[0].button
        bag0:SetParent(self.bagBar)
        bag0:ClearAllPoints()
        bag0:LeftOf(self.backpack, 11)

        for i = 1, 3 do
            local bag = self._slots[i].button
            local prevBag = self._slots[i-1].button
            bag:SetParent(self.bagBar)
            bag:ClearAllPoints()
            bag:LeftOf(prevBag, 0)
        end

        for i = 0, 3 do
            local slot = self._slots[i].button
            slot:SetScale(0.9)
            slot:SetSize(30, 30)

            local normal = slot:GetNormalTexture()
            if normal then
                normal:SetTexture(bagAtlas)
                normal:SetTexCoord(0.576172, 0.695312, 0.5, 0.976562)
                normal:SetSize(SLOT_SIZE, SLOT_SIZE)
                normal:ClearAllPoints()
                normal:CenterInParent(2, -1)
                normal:SetDrawLayer("BACKGROUND")
            end

            local hl = slot:GetHighlightTexture()
            if hl then
                hl:SetTexture(bagAtlas)
                hl:SetTexCoord(0.699219, 0.818359, 0.0078125, 0.484375)
                hl:SetSize(SLOT_SIZE, SLOT_SIZE)
                hl:ClearAllPoints()
                hl:CenterInParent(2, -1)
            end

            local checked = slot:GetCheckedTexture()
            if checked then
                checked:SetTexture(bagAtlas)
                checked:SetTexCoord(0.699219, 0.818359, 0.0078125, 0.484375)
                checked:SetSize(SLOT_SIZE, SLOT_SIZE)
                checked:ClearAllPoints()
                checked:CenterInParent(2, -1)
            end

            local pushed = slot:GetPushedTexture()
            if pushed then
                pushed:SetTexture(bagAtlas)
                pushed:SetTexCoord(0.576172, 0.695312, 0.5, 0.976562)
                pushed:SetSize(SLOT_SIZE, SLOT_SIZE)
                pushed:ClearAllPoints()
                pushed:CenterInParent(2, -1)
                pushed:SetDrawLayer("BORDER")
            end

            local iconTex = self._slots[i].texture
            if iconTex then
                iconTex:ClearAllPoints()
                iconTex:CenterInParent()
                iconTex:SetSize(ICON_SIZE, ICON_SIZE + 1)
                iconTex:SetDrawLayer("BORDER")
            end

            local border = Texture(slot, nil, "ARTWORK")
            border:SetTexture(bagAtlas)
            border:SetTexCoord(0.576172, 0.695312, 0.0078125, 0.484375)
            border:SetSize(SLOT_SIZE, SLOT_SIZE)
            border:CenterInParent(2, -1)

            local countText = self._slots[i].count
            if countText then
                countText:SetFont(MUI.FONT, 8, "OUTLINE")
                countText:ClearAllPoints()
                countText:Below(iconTex, 1, 2)
                countText:SetJustifyH("CENTER")
            end
        end
    end;

    SkinKeyRing = function(self)
        if not KeyRingButton then return end
        local bagAtlas = TEX .. "bagslots2x"

        local keyRing = Button(KeyRingButton)
        keyRing:SetParent(self.bagBar)
        keyRing:SetSize(30, 30)
        keyRing:ClearAllPoints()
        keyRing:LeftOf(self._slots[3].button, 0)
        keyRing:SetScale(0.9)

        local normal = keyRing:GetNormalTexture()
        if normal then
            normal:SetTexture(bagAtlas)
            normal:SetTexCoord(0.822266, 0.941406, 0.0078125, 0.484375)
            normal:SetSize(SLOT_SIZE, SLOT_SIZE)
            normal:ClearAllPoints()
            normal:CenterInParent(2, -1)
            normal:SetDrawLayer("BORDER")
        end

        local hl = keyRing:GetHighlightTexture()
        if hl then
            hl:SetTexture(bagAtlas)
            hl:SetTexCoord(0.699219, 0.818359, 0.0078125, 0.484375)
            hl:SetSize(SLOT_SIZE, SLOT_SIZE)
            hl:ClearAllPoints()
            hl:CenterInParent(2, -1)
        end

        local pushed = keyRing:GetPushedTexture()
        if pushed then
            pushed:SetTexture(bagAtlas)
            pushed:SetTexCoord(0.699219, 0.818359, 0.0078125, 0.484375)
            pushed:SetSize(SLOT_SIZE, SLOT_SIZE)
            pushed:ClearAllPoints()
            pushed:CenterInParent(2, -1)
            pushed:SetDrawLayer("OVERLAY")
        end

        local border = Texture(keyRing, nil, "OVERLAY")
        border:SetTexture(bagAtlas)
        border:SetTexCoord(0.699219, 0.818359, 0.5, 0.976562)
        border:SetSize(SLOT_SIZE, SLOT_SIZE)
        border:CenterInParent(2, -1)
		
		local keyIcon = Texture(keyRing, nil, "ARTWORK")
        keyIcon:SetTexture("Interface\\Icons\\inv_misc_key_14")
		keyIcon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        keyIcon:SetSize(21, 21)
        keyIcon:CenterInParent()

        self.keyring = keyRing
    end;

    CreateToggleButton = function(self)
        self.toggleBtn = Button(self.bagBar, "MUI_BagToggleButton")
        self.toggleBtn:SetSize(20, 20)
        self.toggleBtn:SetScale(0.75)
        self.toggleBtn:ClearAllPoints()
        self.toggleBtn:LeftOf(self.backpack, -3)
        self.toggleBtn:SetNormalTexture(TEX .. "expand")
        self.toggleBtn:SetPushedTexture(TEX .. "expand")
        self.toggleBtn:SetHighlightTexture(TEX .. "expand")
        if self.toggleBtn.label then self.toggleBtn.label:Hide() end

        self.toggleBtn.OnClick = function()
            self.bagsVisible = not self.bagsVisible

            -- _slots is keyed 0..3 with entries {button, texture, count};
            -- iterate by index (ipairs would skip [0]) and toggle the
            -- button itself (the table wrapper has no Show/Hide).
            for i = 0, 3 do
                local btn = self._slots[i] and self._slots[i].button
                if btn then
                    if self.bagsVisible then btn:Show() else btn:Hide() end
                end
            end

            if KeyRingButton then
                local kr = Button(KeyRingButton)
                if self.bagsVisible then kr:Show() else kr:Hide() end
            end

            local normalT = self.toggleBtn:GetNormalTexture()
            local hlT = self.toggleBtn:GetHighlightTexture()
            local pushedT = self.toggleBtn:GetPushedTexture()
            if self.bagsVisible then
                if normalT then normalT:SetTexCoord(0, 1, 0, 1) end
                if hlT then hlT:SetTexCoord(0, 1, 0, 1) end
                if pushedT then pushedT:SetTexCoord(0, 1, 0, 1) end
            else
                if normalT then normalT:SetTexCoord(1, 0, 0, 1) end
                if hlT then hlT:SetTexCoord(1, 0, 0, 1) end
                if pushedT then pushedT:SetTexCoord(1, 0, 0, 1) end
            end
        end
    end;

    UpdateBagSlotIcons = function(self)
        -- Use secure hook so we don't clobber the original function
        if not self.bagUpdateHooked then
            self.bagUpdateHooked = true
            hooksecurefunc("PaperDollItemSlotButton_Update", function(btn)
                if btn and btn.isBag then
                    local b = Button(btn)
                    local iconTex = Texture(getglobal(b:GetName() .. "IconTexture"))
                    if iconTex then
                        local texture = GetInventoryItemTexture("player", b:GetID())
                        if texture then
                            iconTex:SetPortrait(texture)
                            iconTex:Show()
                        else
                            if btn.backgroundTextureName then
                                iconTex:SetPortrait(btn.backgroundTextureName)
                            end
                            iconTex:Hide()
                        end
                    end
                end
            end)
        end
        -- Seed the hook for every bag slot explicitly: /reload with all
        -- bags empty doesn't trigger PaperDollItemSlotButton_Update via
        -- Blizzard's usual inventory paths, so the iconTex would sit on
        -- the default rectangular UI-PaperDoll-Slot-Bag texture until
        -- the player equips a bag. Calling it here forces our hook to
        -- set the correct hidden state on init.
        if PaperDollItemSlotButton_Update then
            for i = 0, 3 do
                local slot = self._slots[i].button._native
                if slot then PaperDollItemSlotButton_Update(slot) end
            end
        end
    end;

    CreateFreeSlotCounter = function(self)
        self.freeSlotsText = FontString(self.backpack, nil, "OVERLAY")
        self.freeSlotsText:SetFont(MUI.FONT, 9, "OUTLINE")
        self.freeSlotsText:SetTextColor(1, 1, 1, 1)
        self.freeSlotsText:Below(self.backpack, -16)

        -- Mirror Blizzard's native free-slot count into our styled
        -- label: hide the native FontString (alpha 0) and hook its
        -- SetText / SetShown so our copy tracks both the formatted
        -- value AND the "Show Free Bag Space" setting. Blizzard's
        -- text is already pre-formatted with BACKPACK_FREESLOTS_FORMAT
        -- (`(%d)` in enUS) — we pass it through verbatim.
        local nativeCount = MainMenuBarBackpackButtonCount
        if nativeCount then
            local count = FontString(nativeCount)
            count:SetAlpha(0)

            local function sync()
                self.freeSlotsText:SetText(count:GetText() or "")
                if count:IsShown() then
                    self.freeSlotsText:Show()
                else
                    self.freeSlotsText:Hide()
                end
            end
            hooksecurefunc(nativeCount, "SetText",  sync)
            hooksecurefunc(nativeCount, "Show",     sync)
            hooksecurefunc(nativeCount, "Hide",     sync)
            hooksecurefunc(nativeCount, "SetShown", sync)
            sync()
        end

        -- Bag slot icons still need refreshing on bag updates.
        Frame():RegisterEventHandler("BAG_UPDATE", function()
            self:UpdateBagSlotIcons()
        end)
    end;

    -- ===================================================================
    -- Container windows (the bag frames) + item slots
    -- Reskin-in-place: hide the native bag art, overlay a metal border,
    -- reuse the bag-bar slot atlas for the item slots, and recompute the
    -- layout into a compact retail-style frame with money pinned to the
    -- bottom. ContainerFrames + their item buttons are non-secure in Era,
    -- but we still hook Blizzard's update path rather than replacing it.
    -- ===================================================================

    SkinContainerFrames = function(self)
        self._bags = {}
        self.tokenFrame = BackpackTokenFrame and Frame(BackpackTokenFrame)
        self._combined = MUI_DB.settings.bags.combined and true or false

        for i = 1, NUM_CONTAINER_FRAMES do
            local frame = Frame(getglobal("ContainerFrame" .. i))
            local entry = { index = i, frame = frame, name = frame:GetName(), slots = {} }
            self._bags[i] = entry

            self:SkinBagFrame(entry)

            for j = 1, MAX_CONTAINER_ITEMS do
                local btn = getglobal(entry.name .. "Item" .. j)
                if btn then
                    entry.slots[j] = self:SkinBagSlot(btn)
                end
            end
        end

        local backpack = self._bags[1] and self._bags[1].frame
        self._searchBox = Frame("EditBox", backpack, "MUI_BagSearchBox", "BagSearchBoxTemplate")
        self._searchBox:SetHeight(20)
        self._searchBox:FillWidth(45)
        self._searchBox:SetScale(0.9)
        self._searchBox:AlignParentTop(34)

        self._btnSort = ButtonSimple(self._searchBox)
        self._btnSort:SetTexture(MUI.TEX_SKIN .. "bags\\bags", 512, 256, 97, 50, 54, 54)
        self._btnSort:SetSize(23, 23)
        self._btnSort:AlignParentRight(-28, -1)
        self._btnSort:SetTooltip("ANCHOR_LEFT", function(tooltip)
            tooltip:AddLine("Sort items in bags", 1, 1, 1, true, 13)
            tooltip:AddLine("Automatic item sorting is a setting that automatically places items. You can choose a specific type of item for each bag by clicking the icon in the upper-left corner of the bag.", 1, 0.82, 0, true)
        end)
        self._btnSort.OnClick = function()
            MUI_BagSorter:SortBags()
        end

        -- Lay out + recolor whenever Blizzard refreshes a bag.
        hooksecurefunc("ContainerFrame_Update", function(native)
            self:OnContainerUpdate(native)
        end)

        -- Token (watched-currency) bar toggling re-flows the backpack. Must
        -- respect combined mode — ToggleBackpack calls this AFTER the frame is
        -- shown, so an unconditional LayoutBagFrame here would clobber the
        -- joined layout/size that LayoutCombined just applied.
        if ManageBackpackTokenFrame then
            hooksecurefunc("ManageBackpackTokenFrame", function()
                if self._combined then
                    self:LayoutCombined()
                else
                    local idx = IsBagOpen(0)
                    if idx and self._bags[idx] then
                        self:LayoutBagFrame(self._bags[idx], 0)
                    end
                end
            end)
        end

        -- Re-position the open bag windows after Blizzard lays them out, so we
        -- control the right/bottom screen margins and the gap between stacks.
        hooksecurefunc("UpdateContainerFrameAnchors", function()
            self:AnchorContainers()
        end)

        -- In combined mode, opening any bag opens them all (their item buttons
        -- live in the native frames, so every frame must be shown).
        hooksecurefunc("ToggleBackpack", function() self:NormalizeCombined() end)
        hooksecurefunc("ToggleBag",      function() self:NormalizeCombined() end)

        -- Joint mode: hovering a bottom-bar bag icon lights up that bag's slots
        -- in the joined window (focus texture).
        self.backpack:HookScript("OnEnter", function() self:HighlightBag(0, true) end)
        self.backpack:HookScript("OnLeave", function() self:HighlightBag(0, false) end)
        for i = 0, 3 do
            local id, btn = i + 1, self._slots[i].button
            btn:HookScript("OnEnter", function() self:HighlightBag(id, true) end)
            btn:HookScript("OnLeave", function() self:HighlightBag(id, false) end)
        end
        if self.keyring then
            self.keyring:HookScript("OnEnter", function() self:HighlightBag(KEYRING_CONTAINER, true) end)
            self.keyring:HookScript("OnLeave", function() self:HighlightBag(KEYRING_CONTAINER, false) end)
        end
    end;

    -- Show/hide the focus texture on every slot of bag `id`. Joint mode only —
    -- in per-bag mode each bag is already its own window, nothing to
    -- disambiguate.
    HighlightBag = function(self, id, on)
        if not self._combined then return end
        local idx = IsBagOpen(id)
        if not idx then return end
        local entry = self._bags[idx]
        local size = (id == KEYRING_CONTAINER) and GetKeyRingSize() or C_Container.GetContainerNumSlots(id)
        for s = 1, (size or 0) do
            local slot = entry.slots[s]
            if slot then slot.focus:SetVisible(on) end
        end
    end;

    SkinBagFrame = function(self, entry)
        local frame, name = entry.frame, entry.name
        -- Hide native bag art. Alpha 0 (not Hide) survives the :Show() that
        -- ContainerFrame_GenerateFrame calls on these every time a bag opens.
        local artSuffixes = { "BackgroundTop", "BackgroundMiddle1", "BackgroundMiddle2", "BackgroundBottom", "Background1Slot" }
        for _, suffix in ipairs(artSuffixes) do
            local tex = getglobal(name .. suffix)
            if tex then Texture(tex):SetAlpha(0) end
        end

        -- The panel supplies the title + portrait, so hide the native ones.
        entry.nativeName = FontString(getglobal(name .. "Name"))
        entry.nativeName:SetAlpha(0)
        Texture(getglobal(name .. "Portrait")):SetAlpha(0)

        -- Left-clicking the portrait opens the join/separate menu (retail-style).
        entry.portraitBtn = Button(getglobal(name .. "PortraitButton"))
        entry.portraitBtn:RegisterForClicks("LeftButtonUp")
        entry.portraitBtn:SetScript("OnClick", function()
            self:ShowPortraitMenu(entry.portraitBtn)
        end)

        entry.panel = PanelPortrait(frame, nil, "", 0.9, true)
        entry.panel:FillParentPadding(0, 0, 4, 0)
        entry.panel:SetFrameLevel(0)
        entry.panel:GetBackgroundTexture():SetColorTexture(0.1, 0.1, 0.1, 0.75)

        -- Close button into the top-right corner, reskinned like Options' X.
        entry.close = Button(getglobal(name .. "CloseButton"))
        local redAtlas = MUI_AtlasRegistry.ButtonRedControl
        entry.close:SetStateAtlas(redAtlas, "ExitNormal", "ExitPressed", "ExitDisabled")
        entry.close:SetHighlightAtlas(redAtlas, "Highlight", true)
        entry.close:SetSize(21.5, 21.5)
        entry.close:ClearAllPoints()
        entry.close:AlignParentTopRight(-1, 3)
        entry.close:PutInfront(entry.panel, 1000)

        -- Cached money frame for re-layout.
        entry.money = Frame(getglobal(name .. "MoneyFrame"))

        -- Resize the gold/silver/copper amount text (keep the native number
        -- font face; MoneyFrame_Update only SetTexts, so this sticks).
        local moneyName = entry.money:GetName()
        for _, denom in ipairs({ "Gold", "Silver", "Copper" }) do
            local amount = FontString(getglobal(moneyName .. denom .. "ButtonText"))
            amount:SetFontSize(13)
        end
    end;

    SkinBagSlot = function(self, native)
        local btn = Button(native)
        btn:SetSize(BAG_SLOT, BAG_SLOT + 1)
        btn:GetNormalTexture():SetTexture(nil)

        local bg = Texture(btn, nil, "BACKGROUND")
        bg:SetTexture(MUI.TEX_SKIN .. "bags\\bagsitemslot2x")
        bg:FillParentPadding(0, 0, 0, 0)

        local border = Texture(btn, nil, "ARTWORK")
        border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        border:FillParentPadding(-11, -11, -12, -12)

        local hl = btn:GetHighlightTexture()
        hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        hl:ClearAllPoints()
        hl:FillParent()

        local focus = Texture(btn, nil, "OVERLAY")
        focus:SetTextureRegion(MUI.TEX_SKIN .. "bags\\bags", 512, 256, 440, 1, 39, 39)
        focus:FillParentPadding()
        focus:Hide()

        local nativeIcon = Texture(native.icon)
        nativeIcon:Hide()

        local icon = ItemIcon(btn, nil, "BORDER")
        icon:FillParent()

        return { 
            button = btn,
            border = border,
            icon = icon,
            nativeIcon = nativeIcon,
            focus = focus
        }
    end;

    OnContainerUpdate = function(self, native)
        -- The hook hands us the raw frame; match it to our cached wrapper by
        -- native identity (the _native base field) rather than a raw method.
        local entry
        for i = 1, NUM_CONTAINER_FRAMES do
            if self._bags[i].frame._native == native then entry = self._bags[i]; break end
        end
        if not entry then return end

        local id = entry.frame:GetID()

        -- Drive each slot's ItemIcon from the container data. Blizzard re-shows
        -- its own icon every update, so hide it again before showing ours.
        local size = native.size or 0
        for i = 1, size do
            local slot = entry.slots[i]
            if slot then
                slot.nativeIcon:Hide()
                local info = C_Container.GetContainerItemInfo(id, slot.button:GetID())
                if info then
                    slot.icon:SetTexture(info.iconFileID)
                    slot.icon:SetDesaturated(info.isLocked)
                    slot.icon:Show()
                    slot.icon:SetQuality(info.quality)
                else
                    slot.icon:Hide()
                    slot.icon:SetQuality(nil)
                end
            end
        end

        -- In combined mode the joined grid covers the backpack + bags; the
        -- keyring isn't part of it, so it keeps its own standalone window
        -- (parked on top of the joined frame by AnchorCombined).
        if self._combined and id ~= KEYRING_CONTAINER then
            self:LayoutCombined()
        else
            self:LayoutBagFrame(entry, id)
        end
    end;

    LayoutBagFrame = function(self, entry, id)
        local frame = entry.frame

        -- Restore the per-bag decoration (combined mode hides non-host panels).
        entry.panel:Show()
        entry.close:Show()

        local size
        if id == KEYRING_CONTAINER then
            size = GetKeyRingSize()
        else
            size = C_Container.GetContainerNumSlots(id)
        end
        if not size or size == 0 then return end

        local item1 = entry.slots[1] and entry.slots[1].button
        if not item1 then return end

        local slotW, slotH = item1:GetWidth(), item1:GetHeight()
        local rows = math.ceil(size / NUM_CONTAINER_COLUMNS)
        local itemsHeight = rows * slotH + (rows - 1) * ITEM_SPACING_Y
        -- Padding accounts for the title bar + bottom border (backpack also
        -- reserves a row for the money frame).
        local padding = (id == 0) and (9 + 48 + 18) or (9 + 48 - 7)

        local tokenShown = id == 0 and self.tokenFrame and self.tokenFrame:IsShown()
        local extra = 0
        if id == 0 then
            extra = 12
            if tokenShown then extra = extra + 17 end
        end

        frame:SetWidth(NUM_CONTAINER_COLUMNS * slotW + (NUM_CONTAINER_COLUMNS - 1) * ITEM_SPACING_X + 2 * CONTAINER_SPACING)
        frame:SetHeight(itemsHeight + padding + extra)

        -- Title + portrait from the bag itself (the backpack has no bag item,
        -- so it falls back to the backpack icon).
        entry.panel:SetTitle(entry.nativeName:GetText() or "")
        local icon
        if id == KEYRING_CONTAINER then
            icon = "Interface\\Icons\\inv_misc_key_14"
        elseif id ~= 0 then
            icon = GetInventoryItemTexture("player", C_Container.ContainerIDToInventoryID(id))
        else
            icon = 133633
        end
        entry.panel:SetPortrait(icon)

        item1:ClearAllPoints()
        if id == 0 then
            entry.money:ClearAllPoints()
            if tokenShown then
                self.tokenFrame:ClearAllPoints()
                self.tokenFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", CONTAINER_SPACING, 5)
                self.tokenFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CONTAINER_SPACING, 5)
                entry.money:SetPoint("BOTTOMLEFT", self.tokenFrame, "TOPLEFT", 0, 3)
                entry.money:SetPoint("BOTTOMRIGHT", self.tokenFrame, "TOPRIGHT", 0, 3)
            else
                entry.money:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", CONTAINER_SPACING, 5)
                entry.money:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CONTAINER_SPACING, 5)
            end
            item1:SetPoint("BOTTOMRIGHT", entry.money, "TOPRIGHT", 0, 4)

            self._searchOwner = entry.index
            self._searchBox:Show()
        else
            item1:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CONTAINER_SPACING, 9)
            if self._searchOwner == entry.index then
                self._searchOwner = nil
                self._searchBox:Hide()
            end
        end

        for i = 2, size do
            local btn = entry.slots[i].button
            btn:ClearAllPoints()
            if (i - 1) % NUM_CONTAINER_COLUMNS == 0 then
                btn:SetPoint("BOTTOMRIGHT", entry.slots[i - NUM_CONTAINER_COLUMNS].button, "TOPRIGHT", 0, ITEM_SPACING_Y)
            else
                btn:SetPoint("BOTTOMRIGHT", entry.slots[i - 1].button, "BOTTOMLEFT", -ITEM_SPACING_X, 0)
            end
        end
    end;

    -- Re-position the open bag windows (keeping the scale Blizzard computed).
    -- The first bag anchors to the bag bar / right action bars; the rest stack
    -- upward with BAG_STACK_GAP, and once a column fills past SCREEN_MARGIN_Y
    -- the next column sits to its left. Defers to Blizzard while the bank is
    -- open (bank bags anchor next to the bank frame).
    AnchorContainers = function(self)
        local bags = ContainerFrame1 and ContainerFrame1.bags
        if not bags or not bags[1] then return end
        local bank = _G.BankFrame
        if bank and Frame(bank):IsShown() then return end
        if self._combined then self:AnchorCombined(); return end

        local scale = Frame(getglobal(bags[1])):GetScale()
        local screenH = GetScreenHeight() / scale
        local yOffset = SCREEN_MARGIN_Y / scale
        local freeH = screenH - yOffset
        local columnAnchor   -- the bottom (first) bag of the current column

        for index, frameName in ipairs(bags) do
            local frame = Frame(getglobal(frameName))
            frame:ClearAllPoints()
            frame:SetToplevel(true)   -- restore (combined mode disables it)
            if index == 1 then
                self:_AnchorToBar(frame)
                columnAnchor = getglobal(frameName)

            elseif freeH < frame:GetHeight() then
                -- New column: sit to the left of the previous column's bottom
                -- bag, bottom-aligned. Keeps columns relative to wherever the
                -- first one is anchored, instead of the screen edge.
                freeH = screenH - yOffset
                frame:SetPoint("BOTTOMRIGHT", columnAnchor, "BOTTOMLEFT", -4, 0)
                columnAnchor = getglobal(frameName)
            else
                frame:SetPoint("BOTTOMRIGHT", getglobal(bags[index - 1]), "TOPRIGHT", 0, BAG_STACK_GAP)
            end
            freeH = freeH - frame:GetHeight() - BAG_STACK_GAP
        end
    end;

    -- Anchor a bag window to the bag bar / right action bars (shared by the
    -- per-bag first window and the combined window).
    _AnchorToBar = function(self, frame)
        frame:ClearAllPoints()
        frame:Above(self.backpack, -11)
        if MUI_ModuleActionBars.bars.MULTIBAR4:IsShown() then
            frame:LeftOf(MUI_ModuleActionBars.bars.MULTIBAR4, 8, 0)
        elseif MUI_ModuleActionBars.bars.MULTIBAR3:IsShown() then
            frame:LeftOf(MUI_ModuleActionBars.bars.MULTIBAR3, 8, 0)
        else
            frame:AlignParentRight(8, 0)
        end
    end;

    -- ===================================================================
    -- Combined ("join bags") mode
    -- All bags' native item buttons reflowed into one window. The native
    -- ContainerFrames stay shown (so GetParent():GetID() and every native
    -- click/use keep working); we only hide their decoration and re-anchor
    -- every button into one grid hosted by the backpack's frame.
    -- ===================================================================

    -- Opening any bag opens the whole set (every frame must be shown for its
    -- buttons to render); closing the backpack closes the set.
    NormalizeCombined = function(self)
        if not self._combined then return end
        if IsBagOpen(0) then
            for id = 1, NUM_BAG_SLOTS do
                if not IsBagOpen(id) then OpenBag(id) end
            end
        else
            CloseAllBags()
        end
    end;

    SetCombined = function(self, on)
        on = on and true or false
        if self._combined == on then return end
        self._combined = on
        MUI_DB.settings.bags.combined = on
        -- OpenAllBags() no-ops unless everything is closed first, so reset the
        -- whole set and reopen it under the new mode.
        CloseAllBags()
        OpenAllBags()
    end;

    ShowPortraitMenu = function(self, anchorBtn)
        if not self._portraitMenu then
            self._portraitMenu = DropdownMenu(Frame(UIParent), "MUI_BagPortraitMenu")
            self._portraitMenu:SetMenuWidth(150)
            self._portraitMenu:SetAnchor(function(popup, a) if a then 
                popup:Below(a, -14)
                popup:AlignLeft(a, -14)
            end end)
        end
        local menu = self._portraitMenu
        menu:SetItems({
            {
                type    = "text",
                label   = self._combined and "Separate Bags" or "Combine Bags",
                OnClick = function() self:SetCombined(not self._combined) end,
            },
        })
        menu:SetToggleAnchor(anchorBtn)
        menu:Toggle()
    end;

    -- Reflow every open bag's item buttons into one grid in the backpack's
    -- frame; hide the other frames' decoration.
    LayoutCombined = function(self)
        local hostIdx = IsBagOpen(0)
        if not hostIdx then return end
        local host  = self._bags[hostIdx]
        local frame = host.frame

        -- Build the joined order: left-most small bag first (it fills the
        -- bottom rows), each bag rightward, backpack last (the top rows). Bag
        -- containers are 1..N with the highest = left-most on the bar, so walk
        -- N..1 then 0.
        local buttons = {}
        for id = NUM_BAG_SLOTS, 0, -1 do
            local idx = IsBagOpen(id)
            if idx then
                local e = self._bags[idx]
                local size = C_Container.GetContainerNumSlots(id) or 0
                for s = 1, size do
                    if e.slots[s] then buttons[#buttons + 1] = e.slots[s].button end
                end
                if idx ~= hostIdx then
                    e.panel:Hide()
                    e.close:Hide()
                end
            end
        end
        host.panel:Show()
        host.close:Show()

        local total = #buttons
        if total == 0 then return end

        local cols = COMBINED_COLUMNS
        local rows = math.ceil(total / cols)
        local slotW, slotH = buttons[1]:GetWidth(), buttons[1]:GetHeight()

        frame:SetWidth(cols * slotW + (cols - 1) * ITEM_SPACING_X + 2 * CONTAINER_SPACING)
        frame:SetHeight(COMBINED_TOP + rows * slotH + (rows - 1) * ITEM_SPACING_Y + COMBINED_BOTTOM + 12)

        host.panel:SetTitle(BACKPACK_TOOLTIP or "Bags")
        host.panel:SetPortrait(133633)

        -- Fill from the bottom-right: item 1 (left-most bag's first slot) sits
        -- bottom-right; fill leftward across the row, then upward.
        for i = 1, total do
            local k   = i - 1
            local col = k % cols              -- 0 = right-most column
            local row = math.floor(k / cols)  -- 0 = bottom row
            local btn = buttons[i]
            btn:ClearAllPoints()
            btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
                -(CONTAINER_SPACING + col * (slotW + ITEM_SPACING_X)),
                COMBINED_BOTTOM + row * (slotH + ITEM_SPACING_Y))
        end

        host.money:ClearAllPoints()
        host.money:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  CONTAINER_SPACING, 8)
        host.money:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CONTAINER_SPACING, 8)

        --self._searchBox:ClearAllPoints()
        --self._searchBox:AlignTop(frame, 34)
        self._searchBox:Show()
        self._searchOwner = hostIdx
    end;

    -- Position the joined window (the backpack frame); park the other frames
    -- off-screen. Their item buttons are anchored to the host grid
    -- (cross-parent) so they still render there — but their mouse-enabled,
    -- Raise()'d frame bodies must NOT sit over the grid, or they swallow every
    -- click/hover and cover the search box.
    AnchorCombined = function(self)
        local hostIdx = IsBagOpen(0)
        if not hostIdx then return end
        local host = self._bags[hostIdx].frame
        self:_AnchorToBar(host)
        -- ContainerFrames are toplevel, so clicking a backpack slot would raise
        -- the host to the top of its strata — above the (off-screen) bag frames
        -- whose buttons live in the host grid, burying those slots behind the
        -- panel. Disable toplevel on the whole set so the open-time stacking
        -- (host lowest, bags above) holds. Keeps them all in MEDIUM, so the
        -- joined window still layers correctly under spellbook etc.
        host:SetToplevel(false)
        for id = 1, NUM_BAG_SLOTS do
            local idx = IsBagOpen(id)
            if idx then
                local f = self._bags[idx].frame
                f:ClearAllPoints()
                f:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", -500, -500)
                f:SetToplevel(false)
            end
        end

        -- Keyring stays its own window, sat on top of the joined frame.
        local kidx = IsBagOpen(KEYRING_CONTAINER)
        if kidx then
            local kf = self._bags[kidx].frame
            kf:ClearAllPoints()
            kf:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", 0, BAG_STACK_GAP)
        end
    end;
}
