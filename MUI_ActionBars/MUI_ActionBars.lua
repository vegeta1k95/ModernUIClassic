-- Retail-style action bar reskin

local BUTTON_TYPES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "BonusActionButton",
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
        local mb1 = self.bars.MULTIBAR1
        local mb2 = self.bars.MULTIBAR2
        local mb3 = self.bars.MULTIBAR3
        local mb4 = self.bars.MULTIBAR4
        local pet = self.bars.PET
        local stance = self.bars.STANCE

        main:EditModeSetLabel("Action Bar 1")
        mb1:EditModeSetLabel("Action Bar 2")
        mb2:EditModeSetLabel("Action Bar 3")
        mb3:EditModeSetLabel("Action Bar 4", math.pi/2)
        mb4:EditModeSetLabel("Action Bar 5", math.pi/2)
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


        main:EditModeSetupSettings(function(content)
            
        end)

        mb1:EditModeSetupSettings(function(content)
            
        end)

        mb2:EditModeSetupSettings(function(content)
            
        end)

        mb3:EditModeSetupSettings(function(content)
            
        end)

        mb4:EditModeSetupSettings(function(content)
            
        end)

        pet:EditModeSetupSettings(function(content)
            
        end)

        stance:EditModeSetupSettings(function(content)

        end)

        -- "Restore default position" must re-run the real, state-dependent layout
        -- (mb3 → right edge, mb4 → left of mb3, stance/pet → above whichever
        -- bottom bar is shown), not replay a captured snapshot.
        for _, bar in ipairs({ main, mb1, mb2, mb3, mb4, pet, stance }) do
            bar:EditModeSetDefaultPosition(function(b) self:_ApplyBarDefault(b) end)
        end

    end;

    -- Default anchor for a single bar, mirroring _SetupMultiBars + the
    -- _UpdateBarsVisibility re-anchoring. Reads current bar visibility so the
    -- result tracks which bars are enabled right now.
    _ApplyBarDefault = function(self, bar)
        local main, mb1, mb2 = self.bars.MAIN1, self.bars.MULTIBAR1, self.bars.MULTIBAR2
        local mb3, mb4 = self.bars.MULTIBAR3, self.bars.MULTIBAR4
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

    _CheckButtonRange = function(self, button)
        if not button or not button:IsVisible() then return true end
        local slot = ActionButton_GetPagedID(button)
        if not slot or slot == 0 then return true end
        if not UnitExists("target") then return true end
        if not UnitCanAttack("player", "target") then return true end
        local inRange = IsActionInRange(slot)
        if inRange == 0 then return false end
        return true
    end;

    _UpdateRangeIndicators = function(self)
        local canAttack = UnitExists("target") and UnitCanAttack("player", "target")

        for key, bar in pairs(self.bars) do
            if key ~= "PET" and key ~= "STANCE" and bar:IsShown() then
                for _, slot in ipairs(bar.slots) do
                    if slot.button:IsShown() then
                        local actionSlot = slot.button:GetActionID()
                        local outOfRange = false

                        local inRange = IsActionInRange(actionSlot)
                        if canAttack and HasAction(actionSlot) and (inRange == 0 or inRange == false) then
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
        local textures = {
            "MainMenuBarTexture0", "MainMenuBarTexture1",
            "MainMenuBarTexture2", "MainMenuBarTexture3",
            "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
            "BonusActionBarTexture0", "BonusActionBarTexture1",
            "SlidingActionBarTexture0", "SlidingActionBarTexture1",
        }
        for _, name in ipairs(textures) do
            local tex = getglobal(name)
            if tex then
                local t = Texture(tex)
                t:SetTexture(nil)
                t:Hide()
            end
        end

        Frame(MainMenuBar):EnableMouse(false)
        Frame(MainMenuBarArtFrame):EnableMouse(false)
        Frame(PetActionBarFrame):EnableMouse(false)

        local stanceArt = { "StanceBarLeft", "StanceBarMiddle", "StanceBarRight" }
        for _, name in ipairs(stanceArt) do
            local tex = getglobal(name)
            if tex then
                local t = Texture(tex)
                t:Hide()
                t:SetAlpha(0)
            end
        end

        if StanceBarFrame then
            Frame(StanceBarFrame):HideAllRegions()
        end

        for i = 1, 10 do
            local btn = getglobal("StanceButton" .. i)
            if btn then
                local bg = getglobal(btn:GetName() .. "Background")
                if bg then Texture(bg):Hide() end
            end
        end

        Frame(PetActionBarFrame):HideAllRegions()

        UIPARENT_MANAGED_FRAME_POSITIONS["MultiBarBottomLeft"] = nil

        Frame(ReputationWatchBar):Kill()
        Frame(MainMenuBarPerformanceBarFrame):Kill()
        Frame(ActionBarUpButton):Kill()
        Frame(ActionBarDownButton):Kill()
        Frame(MainMenuBarPageNumber):Hide()
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
        for i = 1, 11 do
            local ab = getglobal("ActionButton" .. i)

            local div = Frame("Frame", mainBar1, "MUI_Divider" .. i)
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
    end;

    _UpdatePageNum = function(self)
        local page = (GetActionBarPage and GetActionBarPage()) or 1
        self.pageNumText:SetText(tostring(page))
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
        end

        mb1:Above(main, 8.5)
        mb2:Above(mb1, 9)
        mb3:AlignParentRight(6.5, -70)
        mb4:LeftOf(mb3, 9)

		hooksecurefunc("MultiActionBar_Update", function()
			self:_UpdateBarsVisibility()
        end)

        hooksecurefunc("MultiActionBar_UpdateGridVisibility", function()
			self:_UpdateSlotsVisibility()
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
            if self._pendingBarsVisibility then
                self:UpdateBarsVisibility()
            end
            self:_UpdateSlotsVisibility()
        end)
        self.slotChangeWatcher:RegisterEventHandler("ACTIONBAR_SLOT_CHANGED", function()
            self:_UpdateSlotsVisibility()
        end)
        self.slotChangeWatcher:RegisterEventHandler("PLAYER_ENTERING_WORLD", function()
            self:_UpdateSlotsVisibility()
        end)

		hooksecurefunc("ActionButton_Update", function(btn)
			if btn and btn.GetName then
				local name = Button(btn):GetName()

				-- Hide default textures
				local nt = getglobal(name .. "NormalTexture")
				local nt2 = getglobal(name .. "NormalTexture2")
				if nt then Texture(nt):SetVertexColor(0,0,0,0) end
				if nt2 then Texture(nt2):SetVertexColor(0,0,0,0) end

				-- Hide default hotkey
				local hotkey = getglobal(name .. "HotKey")
				if hotkey then FontString(hotkey):Hide() end

				local icon = Texture(getglobal(name .. "Icon"))
				if icon then icon:SetAlpha(1) end

				for _, bar in pairs(self.bars) do bar:SyncAutocast(name) end
			end
			for _, bar in pairs(self.bars) do
				bar:UpdateSlotVisibility()
			end
		end)
		
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

        hooksecurefunc("StanceBar_UpdateState", function()
            stanceBar:UpdateSlotVisibility()
            stanceBar:RaiseBorders()
        end)

        stanceBar:UpdateSlotVisibility()
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
        -- subsequent PetActionBarFrame operations in combat. UpdateSlotVisibility only
        -- toggles our non-secure bg/border textures, which is safe.
        hooksecurefunc("PetActionBar_Update", function()
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

        -- Action buttons: $parentNormalTexture. Stance buttons: $parentNormalTexture2.
        for _, suffix in ipairs({ "NormalTexture", "NormalTexture2" }) do
            local normalTex = getglobal(name .. suffix)
            if normalTex then
                Texture(normalTex):SetVertexColor(0,0,0,0)
            end
        end

        -- Multibar buttons add a $parentFloatingBG (UI-Quickslot @ 0.4) that shows as a
        -- dark half-transparent square on empty slots. Kill it.
        local floatingBG = getglobal(name .. "FloatingBG")
        if floatingBG then
            Texture(floatingBG):SetVertexColor(0,0,0,0)
        end

        local icon = Texture(getglobal(name .. "Icon"))
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

        if show2 then mb1:Show() else mb1:Hide() end
        if show3 then mb2:Show() else mb2:Hide() end
        if show4 then mb3:Show() else mb3:Hide() end
        if show5 then mb4:Show() else mb4:Hide() end
		
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
	
	_UpdateSlotsVisibility = function(self)
		local showEmptySlots = self.cursorDragging or Settings.GetValue("alwaysShowActionBars")
        for _, key in ipairs({"MULTIBAR1", "MULTIBAR2", "MULTIBAR3", "MULTIBAR4"}) do
            self.bars[key]:SetShowEmptySlots(showEmptySlots)
        end
	end;
}
