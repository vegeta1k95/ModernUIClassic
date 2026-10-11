-- Retail-style action bar reskin

local BUTTON_TYPES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "BonusActionButton",
    "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
    "StanceButton", "PetActionButton"
}

object "ModuleActionBars" : extends "Module" {
    __init = function(self)
        Module.__init(self, "ActionBars")
        self._watcher = Frame("Frame", nil, "MUI_ActionBarWatcher")
    end;

    OnEnable = function(self)
        self.bars = {
            MAIN1     = ActionBarEditable("horizontal", "IconFrameSlot", nil, "MUI_MainBar1"),
            MAIN2     =         ActionBar("horizontal", "IconFrameSlot", nil, "MUI_MainBar2"),
            MULTIBAR1 = ActionBarEditable("horizontal", "IconFrameBG", 	 nil, "MUI_MultiBar1"),
            MULTIBAR2 = ActionBarEditable("horizontal", "IconFrameBG",   nil, "MUI_MultiBar2"),
            MULTIBAR3 = ActionBarEditable("vertical",	"IconFrameBG",   nil, "MUI_MultiBar3"),
            MULTIBAR4 = ActionBarEditable("vertical", 	"IconFrameBG",   nil, "MUI_MultiBar4"),
            MULTIBAR5 = ActionBarEditable("horizontal", "IconFrameBG",   nil, "MUI_MultiBar5"),
            MULTIBAR6 = ActionBarEditable("horizontal", "IconFrameBG",   nil, "MUI_MultiBar6"),
            MULTIBAR7 = ActionBarEditable("horizontal", "IconFrameBG",   nil, "MUI_MultiBar7"),
            PET       = ActionBarEditable("horizontal", "IconFrameBG",   nil, "MUI_PetBar"),
            STANCE    = ActionBarEditable("horizontal", "IconFrameBG",   nil, "MUI_StanceBar")
        }

        self:_SetupMainBar()
        self:_SetupMultiBars()
        self:_SetupPetBar()
        self:_SetupStanceBar()
        self:_SkinAllButtons()
        self:_HideBlizzardArt()

        self:_UpdateBarsVisibility()
		self:_UpdateSlotsVisibility()

        self:_SetupRangeIndicator()
        self:_SetupEditMode()

        local function relayoutAll()
            for _, bar in pairs(self.bars) do bar:Relayout() end
        end

        local function updateHotkeys()
            for _, bar in pairs(self.bars) do
                bar:UpdateHotkeys()
            end
        end

        updateHotkeys()

        self._watcher:RegisterEventHandler("UI_SCALE_CHANGED",     relayoutAll)
        self._watcher:RegisterEventHandler("DISPLAY_SIZE_CHANGED", relayoutAll)
        self._watcher:RegisterEventHandler("UPDATE_BINDINGS", updateHotkeys)

    end;

    _SetupEditMode = function(self)

        local main = self.bars.MAIN1
        local pet = self.bars.PET
        local stance = self.bars.STANCE
        -- Action Bars 2-8, in Blizzard's order.
        local multi = {}
        for i = 1, 7 do multi[i] = self.bars["MULTIBAR" .. i] end

        main:EditModeSetLabel("Action Bar 1")
        for i, bar in ipairs(multi) do
            bar:EditModeSetLabel("Action Bar " .. (i + 1), bar.orientation == "vertical" and math.pi / 2 or 0)
        end
        pet:EditModeSetLabel("Pet Bar")
        stance:EditModeSetLabel("Stance Bar")

        -- Only the bar relevant to the player's class is editable: the stance
        -- (shapeshift) bar for warrior/paladin/druid/rogue, the pet bar for
        -- warlock/hunter. The other stays out of edit mode entirely.
        local _, class = UnitClass("player")
        local STANCE_CLASSES = { WARRIOR = true, PALADIN = true, DRUID = true, ROGUE = true }
        local PET_CLASSES    = { WARLOCK = true, HUNTER = true }
        stance:EditModeEnabled(STANCE_CLASSES[class] and true or false)
        pet:EditModeEnabled(PET_CLASSES[class] and true or false)
        stance:EditModeSetOption("stanceBar")
        pet:EditModeSetOption("petBar")

        -- Retail's settings: the layout for every bar, the number of icons
        -- for bars 1-8, "Always Show Buttons" for 2-8 and, for bar 1, hiding
        -- its art and its page arrows.
        main:EditModeSetupSettings(function(content)
            main:EditModeAddLayoutSettings(content, true)
            main:EditModeAddToggle(content, "hideBarArt", HUD_EDIT_MODE_SETTING_ACTION_BAR_HIDE_BAR_ART,
                function() return self._hideBarArt end,
                function(hide) self:_SetBarArtHidden(hide) end)
            main:EditModeAddToggle(content, "hideBarScrolling", HUD_EDIT_MODE_SETTING_ACTION_BAR_HIDE_BAR_SCROLLING,
                function() return self._hideBarScrolling end,
                function(hide) self:_SetBarScrollingHidden(hide) end)
        end)

        for _, bar in ipairs(multi) do
            bar:EditModeSetupSettings(function(content)
                bar:EditModeAddLayoutSettings(content, true)
                bar:EditModeAddAlwaysShowButtons(content)
            end)
        end

        pet:EditModeSetupSettings(function(content)
            pet:EditModeAddLayoutSettings(content)
        end)

        stance:EditModeSetupSettings(function(content)
            stance:EditModeAddLayoutSettings(content)
        end)

        -- "Restore default position" must re-run the real, state-dependent layout
        -- (mb3 → right edge, mb4 → left of mb3, stance/pet → above whichever
        -- bottom bar is shown), not replay a captured snapshot.
        for _, bar in ipairs({ main, pet, stance, unpack(multi) }) do
            bar:EditModeSetDefaultPosition(function(b) self:_ApplyBarDefault(b) end)
        end

    end;

    -- Default anchor for a single bar, mirroring _SetupMultiBars + the
    -- _UpdateBarsVisibility re-anchoring. Reads current bar visibility so the
    -- result tracks which bars are enabled right now.
    _ApplyBarDefault = function(self, bar)
        local main, mb1, mb2 = self.bars.MAIN1, self.bars.MULTIBAR1, self.bars.MULTIBAR2
        local mb3, mb4 = self.bars.MULTIBAR3, self.bars.MULTIBAR4
        local mb5, mb6, mb7 = self.bars.MULTIBAR5, self.bars.MULTIBAR6, self.bars.MULTIBAR7
        local stance, pet = self.bars.STANCE, self.bars.PET

        local show2 = MultiBar1_IsVisible and MultiBar1_IsVisible() and true or false
        local show3 = MultiBar2_IsVisible and MultiBar2_IsVisible() and true or false

        bar:ClearAllPoints()

        if bar == main then
            bar:AlignParentBottom(43)
        elseif bar == mb1 then
            bar:Above(main, 8.5)
        elseif bar == mb2 then
            if show3 and not show2 then bar:Above(main, 8.5) else bar:Above(mb1, 9) end
        elseif bar == mb3 then
            bar:AlignParentRight(6.5, -70)
        elseif bar == mb4 then
            bar:LeftOf(mb3, 9)
        -- Bars 6-8 start where Blizzard's presets put them: mid-screen, the
        -- first with its top edge on the centre, the others 50 px apart below.
        elseif bar == mb5 then
            bar:CenterInParent(0, -18)
        elseif bar == mb6 then
            bar:CenterInParent(0, -68)
        elseif bar == mb7 then
            bar:CenterInParent(0, -118)
        elseif bar == stance or bar == pet then
            local ref = show3 and mb2 or (show2 and mb1 or main)
            local gap = (show2 or show3) and 2.5 or 4
            bar:Above(ref, gap)
            bar:AlignLeft(ref)
        end
    end;

    _SetupRangeIndicator = function(self)
        local updateTimer = 0
        local rangeFrame = Frame("Frame", nil, "MUI_RangeCheck")
        local function refresh() self:_UpdateRangeIndicators() end
        rangeFrame:RegisterEventHandler("PLAYER_TARGET_CHANGED", refresh)
        rangeFrame:RegisterEventHandler("ACTIONBAR_SLOT_CHANGED", refresh)
        rangeFrame:RegisterEventHandler("SPELLS_CHANGED",        refresh)
        rangeFrame:SetScript("OnUpdate", function(_, elapsed)
            updateTimer = updateTimer + elapsed
            if updateTimer >= 0.1 then
                self:_UpdateRangeIndicators()
                updateTimer = 0
            end
        end)
    end;

    _UpdateRangeIndicators = function(self)
        local canAttack = UnitExists("target") and UnitCanAttack("player", "target")

        for key, bar in pairs(self.bars) do
            if key ~= "PET" and key ~= "STANCE" and bar:IsShown() then
                for _, slot in ipairs(bar.slots) do
                    if slot.button:IsShown() then
                        local actionSlot = slot.button:GetActionID()
                        local outOfRange = false

                        local inRange = C_ActionBar.IsActionInRange(actionSlot)
                        if canAttack and C_ActionBar.HasAction(actionSlot) and inRange == false then
                            outOfRange = true
                        end

                        local keybindFS = slot.hotkey
                        local hasKeybind = keybindFS and keybindFS:GetText() and keybindFS:GetText() ~= ""

                        if outOfRange then
                            if hasKeybind then
                                keybindFS:SetTextColor(1, 0.2, 0.2)
                                keybindFS:SetAlpha(1)
                                slot.range:Hide()
                            else
                                keybindFS:SetAlpha(0)
                                slot.range:Show()
                            end
                        else
                            if hasKeybind then
                                keybindFS:SetTextColor(1, 1, 1)
                                keybindFS:SetAlpha(1)
                            end
                            slot.range:Hide()
                        end
                    end
                end
            end
        end
    end;

    _HideBlizzardArt = function(self)
        -- Blizzard re-shows bar art via SetShown (UpdateEndCaps / SetBackgroundArtShown),
        -- so blank the textures instead of relying on Hide.
        local textures = {
            MainMenuBarTexture0, MainMenuBarTexture1,
            MainMenuBarTexture2, MainMenuBarTexture3,
            MainMenuBarLeftEndCap, MainMenuBarRightEndCap,
            MainActionBar.EndCaps.LeftEndCap, MainActionBar.EndCaps.RightEndCap,
            PetActionBar.BackgroundArt1, PetActionBar.BackgroundArt2,
            StanceBar.BackgroundArtLeft, StanceBar.BackgroundArtMiddle, StanceBar.BackgroundArtRight,
        }
        for _, tex in ipairs(textures) do
            local t = Texture(tex)
            t:SetTexture(nil)
            t:Hide()
        end

        Frame(MainMenuBar):EnableMouse(false)
        Frame(MainMenuBarArtFrame):EnableMouse(false)
        Frame(MainActionBar):EnableMouse(false)
        Frame(StanceBar):EnableMouse(false)
        Frame(PetActionBar):EnableMouse(false)

        Frame(MainMenuBarPerformanceBarFrame):Kill()

        local pageNumber = MainActionBar.ActionBarPageNumber
        Frame(pageNumber):Kill()
        Frame(pageNumber.UpButton):Kill()
        Frame(pageNumber.DownButton):Kill()
    end;

    _SetupMainBar = function(self)
	
        local mainBar1 = self.bars.MAIN1
		local mainBar2 = self.bars.MAIN2
		
        mainBar1:AlignParentBottom(43)
        mainBar2:Fill(mainBar1)
		
		mainBar1:SetShowEmptySlots(true)
		mainBar2:SetShowEmptySlots(true)

        for i = 1, 12 do
            mainBar1:AddButton(getglobal("ActionButton" .. i))
			local btn = getglobal("BonusActionButton" .. i)
			if btn then mainBar2:AddButton(btn) end
        end

        local atlas = MUI_AtlasRegistry.ActionBar
        local atlasFrame = MUI_AtlasRegistry.ActionBarMainBg

        self.bg = Frame("Frame", mainBar1, "MUI_ActionBarBG")
        self.bg:SetSize(514, 48)
        self.bg:CenterInParent(0, 100)
        self.bg:SetFrameStrata("BACKGROUND")

        self.bgLeft = Texture(mainBar1, nil, "BACKGROUND")
        self.bgLeft:SetAtlas(atlasFrame, "Left", true)
        self.bgLeft:SetWidth(9)
        self.bgLeft:SetHeight(48)
        self.bgLeft:AlignParentLeft(-6)

        self.bgRight = Texture(mainBar1, nil, "BACKGROUND")
        self.bgRight:SetAtlas(atlasFrame, "Right", true)
        self.bgRight:SetWidth(9)
        self.bgRight:SetHeight(48)
        self.bgRight:AlignParentRight(-6)

        self.bgMiddle = Texture(mainBar1, nil, "BACKGROUND")
        self.bgMiddle:SetAtlas(atlasFrame, "Middle", true)
        self.bgMiddle:FillBetweenH(self.bgLeft, self.bgRight, 0)
        self.bgMiddle:SetHeight(48)

        -- The same plate as a nine-slice, for a bar set to more than one row
        -- or made vertical: the strip above is one row high.
        self.bgGrid = NineSlice(mainBar1.bgFrame)
        self.bgGrid:SetFromTextureRegion("skin\\actionbars\\actionbar-main-bg", 128, 128, 2, 2, 102, 104, 18, 18, 18, 18, 0.5)
        self.bgGrid:Fill(mainBar1, -6, -6, -6, -6)
        self.bgGrid:Hide()

        -- Gryphons/Wyverns
        local faction = UnitFactionGroup("player")
        local dir = MUI.TEX_SKIN .. "actionbars\\"
        local texPath = (faction == "Alliance") and (dir .. "art-gryphon.tga") or (dir .. "art-wyvern.tga")

        self.gryphonFrame = Frame("Frame", mainBar1, "MUI_GryphonFrame")
        self.gryphonFrame:FillParent()
        self.gryphonFrame:SetFrameLevel(100)

        self.leftGryphon = Texture(self.gryphonFrame, "MUI_LeftGryphon", "OVERLAY")
        self.leftGryphon:SetTexture(texPath)
        self.leftGryphon:SetSize(105*1.29, 98*1.38)
        self.leftGryphon:AlignParentBottomLeft(-46, -98)

        self.rightGryphon = Texture(self.gryphonFrame, "MUI_RightGryphon", "OVERLAY")
        self.rightGryphon:SetTexture(texPath)
        self.rightGryphon:SetSize(105*1.29, 98*1.38)
        self.rightGryphon:AlignParentBottomRight(-46, -96)
        self.rightGryphon:SetTexCoord(1, 0, 0, 1)

        -- Dividers between buttons
        self._dividers = {}
        for i = 1, 11 do
            local ab = getglobal("ActionButton" .. i)

            local div = Frame("Frame", mainBar1, "MUI_Divider" .. i)
            self._dividers[i] = div
            div:SetSize(6, 0)
            div:RightOf(Frame(ab), 0.5)
            div:AlignTop(mainBar1, -0.5)
            div:AlignBottom(mainBar1, -1)
            div:SetFrameLevel(50)

            local top = Texture(div, nil, "OVERLAY")
            top:SetAtlas(atlas, "DividerEdgeTop", true)
            top:SetSize(6*1.6, 7*1.6)
            top:AlignParentTop(-1.8)

            local bot = Texture(div, nil, "OVERLAY")
            bot:SetAtlas(atlas, "DividerEdgeBottom", true)
            bot:SetSize(6*1.6, 7*1.6)
            bot:AlignParentBottom(-1)

            local mid = Texture(div, nil, "OVERLAY")
            mid:SetAtlas(atlas, "DividerCenter", true)
            mid:FillBetweenV(top, bot, 0.5)
            mid:SetWidth(0)
        end

        -- Page up button
        self.pageUp = Button(mainBar1, "MUI_PageUp")
        self.pageUp:SetSize(14.5, 12.5)
        local upR = atlas:GetRegion("PageUpNormal")
        if upR then
            self.pageUp:SetNormalTexture(upR.file)
            self.pageUp:GetNormalTexture():SetTexCoord(upR.left, upR.right, upR.top, upR.bottom)
        end
        local upD = atlas:GetRegion("PageUpDown")
        if upD then
            self.pageUp:SetPushedTexture(upD.file)
            self.pageUp:GetPushedTexture():SetTexCoord(upD.left, upD.right, upD.top, upD.bottom)
        end
        local upH = atlas:GetRegion("PageUpMouseover")
        if upH then
            self.pageUp:SetHighlightTexture(upH.file)
            self.pageUp:GetHighlightTexture():SetTexCoord(upH.left, upH.right, upH.top, upH.bottom)
        end
        self.pageUp:LeftOf(mainBar1, 7)
        self.pageUp:AlignTop(mainBar1, -0.5)
        self.pageUp:SetFrameLevel(101)
        self.pageUp:SetScript("OnClick", function()
            ActionBar_PageUp()
            self:_UpdatePageNum()
        end)

        self.pageNumFrame = Frame("Frame", mainBar1, "MUI_PageNumFrame")
        self.pageNumFrame:SetSize(17, 12)
        self.pageNumFrame:SetFrameLevel(101)
        self.pageNumFrame:Below(self.pageUp, -3.5)
        self.pageNumFrame:AlignLeft(self.pageUp, -3)

        self.pageNumText = FontString(self.pageNumFrame, nil, "OVERLAY")
        self.pageNumText:SetFont(MUI.FONT, 10, "")
        self.pageNumText:SetTextColor(1, 0.82, 0)
        self.pageNumText:SetShadowOffset(1, -1)
        self.pageNumText:CenterInParent()

        self.pageDown = Button(mainBar1, "MUI_PageDown")
        self.pageDown:SetSize(15, 13)
        local dnR = atlas:GetRegion("PageDownNormal")
        if dnR then
            self.pageDown:SetNormalTexture(dnR.file)
            self.pageDown:GetNormalTexture():SetTexCoord(dnR.left, dnR.right, dnR.top, dnR.bottom)
        end
        local dnD = atlas:GetRegion("PageDownDown")
        if dnD then
            self.pageDown:SetPushedTexture(dnD.file)
            self.pageDown:GetPushedTexture():SetTexCoord(dnD.left, dnD.right, dnD.top, dnD.bottom)
        end
        local dnH = atlas:GetRegion("PageDownMouseover")
        if dnH then
            self.pageDown:SetHighlightTexture(dnH.file)
            self.pageDown:GetHighlightTexture():SetTexCoord(dnH.left, dnH.right, dnH.top, dnH.bottom)
        end
        self.pageDown:Below(self.pageNumFrame, -3)
        self.pageDown:AlignRight(self.pageNumFrame, -1)
		self.pageDown:SetFrameLevel(101)
        self.pageDown:SetScript("OnClick", function()
            ActionBar_PageDown()
            self:_UpdatePageNum()
        end)

        self:_UpdatePageNum()

        self.pageWatcher = Frame("Frame", nil, "MUI_PageWatcher")
        local function refresh() self:_UpdatePageNum() end
        self.pageWatcher:RegisterEventHandler("ACTIONBAR_PAGE_CHANGED",  refresh)
        self.pageWatcher:RegisterEventHandler("UPDATE_SHAPESHIFT_FORM",  refresh)
        self.pageWatcher:RegisterEventHandler("UPDATE_BONUS_ACTIONBAR",  refresh)

        mainBar1.OnLayoutChanged = function() self:_UpdateMainBarArt() end
    end;

    -- Bar 1's art was drawn for one row; it follows another layout by
    -- Blizzard's rules for its own main bar (MainActionBarMixin): dividers
    -- only along a single row at the default padding and between the buttons
    -- in use, the gryphons moved out past the ends of a taller grid.
    _UpdateMainBarArt = function(self)
        local bar = self.bars.MAIN1
        local row = bar.orientation == "horizontal" and bar.numRows == 1
        local count = bar:GetLaidOutCount()
        local art = not self._hideBarArt

        self.bgLeft:SetVisible(art and row)
        self.bgMiddle:SetVisible(art and row)
        self.bgRight:SetVisible(art and row)
        self.bgGrid:SetVisible(art and not row)

        local divided = art and row and bar.iconPadding == bar.MIN_ICON_PADDING
        for i, div in ipairs(self._dividers) do
            div:SetVisible(divided and i < count)
        end

        self.leftGryphon:ClearAllPoints()
        self.rightGryphon:ClearAllPoints()
        if row then
            self.leftGryphon:AlignParentBottomLeft(-46, -98)
            self.rightGryphon:AlignParentBottomRight(-46, -96)
        else
            self.leftGryphon:AlignParentBottomLeft(-46, -134)
            self.rightGryphon:AlignParentBottomRight(-46, -132)
        end
    end;

    -- Retail's "Hide Bar Art" for bar 1: the gryphons, the plate and the
    -- dividers go, and its slots take the background the other bars have.
    _SetBarArtHidden = function(self, hide)
        self._hideBarArt = hide
        self.gryphonFrame:SetVisible(not hide)
        self.bars.MAIN1:SetSlotBackground(hide and "IconFrameBG" or "IconFrameSlot")
        self:_UpdateMainBarArt()
    end;

    -- Retail's "Hide Bar Scrolling": the page arrows and the page number.
    _SetBarScrollingHidden = function(self, hide)
        self._hideBarScrolling = hide
        self.pageUp:SetVisible(not hide)
        self.pageNumFrame:SetVisible(not hide)
        self.pageDown:SetVisible(not hide)
    end;

    _UpdatePageNum = function(self)
        self.pageNumText:SetText(tostring(C_ActionBar.GetActionBarPage()))
    end;

    _SetupMultiBars = function(self)

        local main = self.bars.MAIN1
        local mb1 = self.bars.MULTIBAR1
        local mb2 = self.bars.MULTIBAR2
        local mb3 = self.bars.MULTIBAR3
        local mb4 = self.bars.MULTIBAR4

        for i = 1, 12 do
            mb1:AddButton(getglobal("MultiBarBottomLeftButton" .. i))
            mb2:AddButton(getglobal("MultiBarBottomRightButton" .. i))
            mb3:AddButton(getglobal("MultiBarRightButton" .. i))
            mb4:AddButton(getglobal("MultiBarLeftButton" .. i))
            for n = 5, 7 do
                self.bars["MULTIBAR" .. n]:AddButton(getglobal("MultiBar" .. n .. "Button" .. i))
            end
        end

        mb1:Above(main, 8.5)
        mb2:Above(mb1, 9)
        mb3:AlignParentRight(6.5, -70)
        mb4:LeftOf(mb3, 9)
        for n = 5, 7 do
            self:_ApplyBarDefault(self.bars["MULTIBAR" .. n])
        end

		hooksecurefunc("MultiActionBar_Update", function()
			self:_UpdateBarsVisibility()
        end)

        self.slotChangeWatcher = Frame("Frame", nil, "MUI_SlotChangeWatcher")
        self.slotChangeWatcher:RegisterEventHandler("ACTIONBAR_SHOWGRID", function()
            self.cursorDragging = true
            self:_UpdateSlotsVisibility()
        end)
        self.slotChangeWatcher:RegisterEventHandler("ACTIONBAR_HIDEGRID", function()
            self.cursorDragging = false
            self:_UpdateSlotsVisibility()
        end)
        self.slotChangeWatcher:RegisterEventHandler("PLAYER_REGEN_ENABLED", function()
            for _, bar in pairs(self.bars) do bar:ApplyPendingLayout() end
            if self._pendingBarsVisibility then
                self:_UpdateBarsVisibility()
            end
            self:_UpdateSlotsVisibility()
        end)
        self.slotChangeWatcher:RegisterEventHandler("ACTIONBAR_SLOT_CHANGED", function()
            self:_UpdateSlotsVisibility()
        end)
        self.slotChangeWatcher:RegisterEventHandler("PLAYER_ENTERING_WORLD", function()
            self:_UpdateSlotsVisibility()
        end)

		-- Update is a mixin method copied onto every action button, so hook each button.
		local actionButtons = {
			"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
			"MultiBarRightButton", "MultiBarLeftButton",
			"MultiBar5Button", "MultiBar6Button", "MultiBar7Button"
		}
		for _, buttonType in ipairs(actionButtons) do
			for i = 1, 12 do
				hooksecurefunc(getglobal(buttonType .. i), "Update", function(btn)
					self:_OnButtonUpdate(btn)
				end)
			end
		end

    end;

    _OnButtonUpdate = function(self, native)
        -- Hide default textures
        Texture(native.NormalTexture):SetVertexColor(0,0,0,0)

        -- Hide default hotkey
        FontString(native.HotKey):Hide()

        Texture(native.icon):SetAlpha(1)

        local name = Button(native):GetName()
        for _, bar in pairs(self.bars) do bar:SyncAutocast(name) end
        for _, bar in pairs(self.bars) do
            bar:UpdateSlotVisibility()
        end
    end;

    _SetupStanceBar = function(self)
        local stanceBar = self.bars.STANCE
        stanceBar:SetSpacing(4)
        stanceBar:SetSlotPadding(1)
        stanceBar:SetShowEmptySlots(false)

        for i = 1, 10 do
            local native = getglobal("StanceButton" .. i)
            if native then
                Button(native):SetScale(0.85)
                stanceBar:AddButton(native)
            end
        end

        self:_UpdateStanceCount()
        hooksecurefunc(StanceBar, "UpdateState", function()
            self:_UpdateStanceCount()
            stanceBar:UpdateSlotVisibility()
            stanceBar:RaiseBorders()
        end)

        stanceBar:UpdateSlotVisibility()
    end;

    -- Only the stances the class has take part in the stance bar's layout,
    -- as on Blizzard's bar: its rows are counted over the buttons shown.
    _UpdateStanceCount = function(self)
        self.bars.STANCE:SetNumIcons(math.max(GetNumShapeshiftForms(), 1))
    end;

    _SetupPetBar = function(self)
        local petBar = self.bars.PET
        petBar:SetSpacing(4)
        petBar:SetSlotPadding(1)
        petBar:SetShowEmptySlots(false)

        for i = 1, 10 do
            local native = getglobal("PetActionButton" .. i)
            if native then
                Button(native):SetScale(0.85)
                petBar:AddButton(native)
            end
        end

        -- Hide/Show of the MUI_PetBar frame from this secure-hook callback taints
        -- subsequent PetActionBar operations in combat. UpdateSlotVisibility only
        -- toggles our non-secure bg/border textures, which is safe.
        hooksecurefunc(PetActionBar, "Update", function()
            petBar:UpdateSlotVisibility()
            petBar:SyncAllAutocast()
        end)

        petBar:UpdateSlotVisibility()
    end;

    _SkinAllButtons = function(self)
        for _, buttonType in ipairs(BUTTON_TYPES) do
            local count = (buttonType == "PetActionButton"
                           or buttonType == "StanceButton") and 10 or 12
            for i = 1, count do
                local native = getglobal(buttonType .. i)
                if native and not native.MUI_Skinned then
                    self:_SkinButton(native)
                    native.MUI_Skinned = true
                end
            end
        end
    end;

    _SkinButton = function(self, native)

        local btn  = Button(native)
        local name = btn:GetName()

        Texture(native.NormalTexture):SetVertexColor(0,0,0,0)

        -- Every button carries a SlotBackground (UI-Quickslot @ 0.4) that shows as a
        -- dark half-transparent square on empty slots. Kill it.
        Texture(native.SlotBackground):SetVertexColor(0,0,0,0)

        local icon = Texture(native.icon)
        icon:SetTexCoord(0.05, 0.96, 0.06, 0.96)

        local hlRegion = MUI_AtlasRegistry.ActionBar:GetRegion("IconFrameMouseover")
        if hlRegion then
            btn:SetHighlightTexture(hlRegion.file)
            local hl = btn:GetHighlightTexture()
            if hl then
                local bw, bh = btn:GetWidth(), btn:GetHeight()
                local isStance = string.find(name, "^StanceButton")
                local padW = isStance and 3 or 6
                local padH = isStance and 2 or 4
                local offsetX = isStance and 0 or 1
                local offsetY = isStance and 1 or 0
                hl:SetTexCoord(hlRegion.left, hlRegion.right, hlRegion.top, hlRegion.bottom)
                hl:SetBlendMode("ADD")
                hl:ClearAllPoints()
                hl:CenterAt(btn, offsetX, offsetY)
                hl:SetSize(bw + padW, bh + padH)
            end
        end

        local pushedRegion = MUI_AtlasRegistry.ActionBar:GetRegion("IconFrameDown")
        if pushedRegion then
            btn:SetPushedTexture(pushedRegion.file)
            local pt = btn:GetPushedTexture()
            if pt then
                local bw, bh = btn:GetWidth(), btn:GetHeight()
                pt:SetTexCoord(pushedRegion.left, pushedRegion.right, pushedRegion.top, pushedRegion.bottom)
                pt:ClearAllPoints()
                pt:CenterAt(btn)
                pt:SetWidth(bw + 3)
                pt:SetHeight(bh + 3)
            end
        end
    end;

    _UpdateBarsVisibility = function(self)
        -- MUI_MultiBar*/PetBar/StanceBar have Blizzard's secure buttons anchored to them,
        -- which makes Show/SetPoint on them protected. Defer visibility changes to after combat.
        if InCombatLockdown and InCombatLockdown() then
            self._pendingBarsVisibility = true
            return
        end
        self._pendingBarsVisibility = false

        local main = self.bars.MAIN1
        local mb1 = self.bars.MULTIBAR1
        local mb2 = self.bars.MULTIBAR2
        local mb3 = self.bars.MULTIBAR3
        local mb4 = self.bars.MULTIBAR4

        -- Read from Blizzard's settings (source of truth).
        -- Bar 2 = BottomLeft (page 6), Bar 3 = BottomRight (5), Bar 4 = Right (3), Bar 5 = Left (4).
        local show2 = MultiBar1_IsVisible and MultiBar1_IsVisible() and true or false
        local show3 = MultiBar2_IsVisible and MultiBar2_IsVisible() and true or false
        local show4 = MultiBar3_IsVisible and MultiBar3_IsVisible() and true or false
        local show5 = MultiBar4_IsVisible and MultiBar4_IsVisible() and true or false

        -- Bars 6-8 (MultiBar5-7, pages 13-15) are the ones 1.15.9 added. A bar
        -- that is switched off is out of edit mode too.
        local shown = { show2, show3, show4, show5,
            MultiBar5_IsVisible() and true or false,
            MultiBar6_IsVisible() and true or false,
            MultiBar7_IsVisible() and true or false }
        for i, show in ipairs(shown) do
            local bar = self.bars["MULTIBAR" .. i]
            bar:SetVisible(show)
            bar:EditModeEnabled(show)
        end
		
        -- Re-dock guard: a bar the user has moved in edit mode (EditModeIsMoved)
        -- keeps its custom/saved position instead of being snapped back here.
        if not mb2:EditModeIsMoved() then
            mb2:ClearAllPoints()
            if show3 and not show2 then
                mb2:Above(main, 8.5)
            else
                mb2:Above(mb1, 9)
            end
        end

        local stanceBar = self.bars.STANCE
        local petBar = self.bars.PET

        local ref, gap
        if show3 then ref, gap = mb2, 2.5
        elseif show2 then ref, gap = mb1, 2.5
        else ref, gap = main, 4 end

        if not stanceBar:EditModeIsMoved() then
            stanceBar:ClearAllPoints()
            stanceBar:Above(ref, gap)
            stanceBar:AlignLeft(ref)
        end
        if not petBar:EditModeIsMoved() then
            petBar:ClearAllPoints()
            petBar:Above(ref, gap)
            petBar:AlignLeft(ref)
        end
		
    end;
	
	-- Empty slots show while dragging; the per-bar "Always Show Buttons" choice lives on the bar.
	_UpdateSlotsVisibility = function(self)
        for i = 1, 7 do
            self.bars["MULTIBAR" .. i]:SetShowEmptySlots(self.cursorDragging)
        end
	end;
}
