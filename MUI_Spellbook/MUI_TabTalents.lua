-- Colored status suffixes for the talent-group dropdown button + menu rows.
local STATUS_ACTIVE   = " |cff00ff00(Active)|r"
local STATUS_INACTIVE = " |cff808080(Inactive)|r"

local SPEC_BACKGROUNDS = {
    [1] = {                 -- WARRIOR
        { file = "bg-warrior-1", w=2048, h=2048, x = 0, y = 0   },
        { file = "bg-warrior-1", w=2048, h=2048, x = 0, y = 776 },
        { file = "bg-warrior-2", w=2048, h=1024, x = 0, y = 0   },
    },
    [2] = {                 -- PALADIN
        { file = "bg-paladin-1", w=2048, h=2048, x = 0, y = 0   },
        { file = "bg-paladin-1", w=2048, h=2048, x = 0, y = 776 },
        { file = "bg-paladin-2", w=2048, h=1024, x = 0, y = 0   },
    },
    [3] = {                 -- HUNTER
        { file = "bg-hunter-1",  w=2048, h=2048, x = 0, y = 0   },
        { file = "bg-hunter-1",  w=2048, h=2048, x = 0, y = 776 },
        { file = "bg-hunter-2",  w=2048, h=1024, x = 0, y = 0   },
    },
    [4] = {                 -- ROGUE
        { file = "bg-rogue-1",   w=2048, h=2048, x = 0, y = 0   },
        { file = "bg-rogue-1",   w=2048, h=2048, x = 0, y = 776 },
        { file = "bg-rogue-2",   w=2048, h=1024, x = 0, y = 0   },
    },
    [5] = {                 -- PRIEST
        { file = "bg-priest-1",  w=2048, h=2048, x = 0, y = 0   },
        { file = "bg-priest-1",  w=2048, h=2048, x = 0, y = 776 },
        { file = "bg-priest-2",  w=2048, h=1024, x = 0, y = 0   },
    },
    [6] = {                 -- DK (reserved)
        {},
        {},
        {},
    },
    [7] = {                 -- SHAMAN
        { file = "bg-shaman-1",  w=2048, h=2048, x = 0, y = 0   },
        { file = "bg-shaman-1",  w=2048, h=2048, x = 0, y = 776 },
        { file = "bg-shaman-2",  w=2048, h=1024, x = 0, y = 0   },
    },
    [8] = {                 -- MAGE
        { file = "bg-mage-1",    w=2048, h=2048, x = 0, y = 0   },
        { file = "bg-mage-1",    w=2048, h=2048, x = 0, y = 776 },
        { file = "bg-mage-2",    w=2048, h=1024, x = 0, y = 0   },
    },
    [9] = {                 -- WARLOCK
        { file = "bg-warlock-1", w=2048, h=2048, x = 0, y = 0   },
        { file = "bg-warlock-1", w=2048, h=2048, x = 0, y = 776 },
        { file = "bg-warlock-2", w=2048, h=1024, x = 0, y = 0   },
    },
    [11] = {                -- DRUID
        { file = "bg-druid-1",   w=2048, h=2048, x = 0, y = 0   },
        { file = "bg-druid-2",   w=2048, h=2048, x = 0, y = 0   },
        { file = "bg-druid-2",   w=2048, h=2048, x = 0, y = 776 },
    },
}

-- Our own learn-preview confirmation. Blizzard's CONFIRM_LEARN_PREVIEW_TALENTS
-- dialog is registered inside the load-on-demand Blizzard_TalentUI addon,
-- which never loads since we rebuild the talent frame from scratch. Define
-- our own so it always exists.
StaticPopupDialogs["MUI_CONFIRM_LEARN_PREVIEW_TALENTS"] = {
    text = CONFIRM_LEARN_PREVIEW_TALENTS or "Learn these preview talents?",
    button1 = YES,
    button2 = NO,
    OnAccept = function() LearnPreviewTalents(false) end,
    hideOnEscape = 1,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
}

class "SpecGridColumn" : extends "Frame" {

    __init = function(self, parent, name, spec)
        Frame.__init(self, "Frame", parent, name)

        local _, _, classID = UnitClass("player")
        local bgTex = SPEC_BACKGROUNDS[classID][spec]
        local coeff = 2.209
        local w = 1459 / 3

        self._spec = spec

        self._bg = Texture(self, nil, "BACKGROUND")
        self._bg:FillParent()
        self._bg:SetTextureRegion(MUI.TEX_SKIN .. "talents\\" .. bgTex.file, bgTex.w, bgTex.h, bgTex.x + w*coeff, bgTex.y, 1614 - w*coeff, 776)
        self._bg:SetVertexColor(0.6, 0.6, 0.6, 1)

        self._vignette = Texture(self, nil, "ARTWORK")
        self._vignette:FillParent()
        self._vignette:SetTexture(MUI.TEX_BASE .. "frame-inner-shadow")

        self._icon = Texture(self, nil, "OVERLAY")
        self._icon:SetSize(64, 64)
        self._icon:AlignParentTop(70)
        self._icon:SetTexture(MUI_SPEC_ICONS[MUI.GetClassID()][spec])

        self._iconOverlay = Texture(self, nil, "OVERLAY")
        self._iconOverlay:SetDrawLayer("OVERLAY", 1)
        self._iconOverlay:SetTextureRegion(MUI.TEX_SKIN .. "talents\\talents-hero", 2048, 1024, 405, 825, 160, 160)
        self._iconOverlay:SetSize(96, 96)
        self._iconOverlay:CenterAt(self._icon)

        self:HookScript("OnShow", function()
            self._icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        end)

        local _, specName = GetTalentTabInfo(spec)
        self._name = FontString(self)
        self._name:Below(self._icon, 10)
        self._name:SetFont(MUI.FONT, 22, "")
        self._name:SetShadowOffset(2, -2)
        self._name:SetText(string.upper(specName))

        self._points = FontString(self)
        self._points:SetFont(MUI.FONT, 28, "")
        self._points:SetShadowOffset(2, -2)
        self._points:SetText(0)
        self._points:SetTextColor(0.5, 0.5, 0.5, 1)
        self._points:Below(self._name, 10)

        self._grid = TalentGrid(self, nil, 7, 4, true)
        self._grid:Below(self._points, 20)
        self._grid.OnUpdate = function(pointsSpent)
            self._points:SetText(pointsSpent)
            if pointsSpent > 0 then
                self._points:SetTextColor(0, 1, 0, 1)
            else
                self._points:SetTextColor(1, 1, 1, 1)
            end
        end

    end;

    Update = function(self)
        self._grid:UpdateFromSpec(self._spec)
    end;

    SetGroup = function(self, group)
        self._grid:SetGroup(group)
        self._bg:SetDesaturated(group ~= GetActiveTalentGroup())
    end
}

class "SpecDot" : extends "Texture" {

    _TEX = MUI.TEX_SKIN .. "talents\\talent-spec-dots";

    __init = function(self, parent)
        Texture.__init(self, parent, nil, "ARTWORK")
        self:SetSize(16, 16)
    end;

    SetActive = function(self, active)
        if active then
            self:SetTextureRegion(self._TEX, 128, 64, 12, 12, 40, 40)
        else
            self:SetTextureRegion(self._TEX, 128, 64, 77, 12, 40, 40)
        end
    end
}


class "TabTalents" : extends "SecureFrame" {

    __init = function(self, parent)
        SecureFrame.__init(self, parent, "MUI_TabTalentsFrame")
        self:FillParent()

        self._showSpec = 0
        self:_CreateBottomBar()

        -- Subscribe to updates to spells and talents
        self:RegisterEventHandler("PLAYER_LEVEL_UP", function() self:_UpdateLevel() end)
        self:RegisterEventHandler("ACTIVE_TALENT_GROUP_CHANGED", function()
            if self._specGrid then self:SetPreviewGroup(GetActiveTalentGroup()) end
        end)
        self:RegisterEventHandler("PLAYER_ENTERING_WORLD", function()

            self:_CreateSpecView()
            self:_CreateFullView()
            self:SetPreviewGroup(GetActiveTalentGroup())

            local className, _, classID = UnitClass("player")
            self._className:SetText(string.upper(className))
            self:_UpdateLevel();

            self._specIcon1 = MUI_SPEC_ICONS[classID][1]
            self._specIcon2 = MUI_SPEC_ICONS[classID][2]
            self._specIcon3 = MUI_SPEC_ICONS[classID][3]

            local spec = MUI_Talents:GetPrimarySpec()
            self._showSpec = spec and spec.index or 0

            self:_UpdateContainers()
            self:_UpdateBackground()
            self:_UpdateTalents()
            self:_UpdateSpells()

        end)

        self:RegisterEventHandler("CHARACTER_POINTS_CHANGED", function() self:_UpdateTalents() end)
        self:RegisterEventHandler("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", function() self:_UpdateTalents() end)
        self:RegisterEventHandler("PREVIEW_TALENT_POINTS_CHANGED", function() self:_UpdateTalentsPreview() end)

        EventRegistry:RegisterCallback("MUI_SPELLS_UPDATED", function() self:_UpdateSpells() end, self)

    end;

    SetSpec = function(self, index)
        self._showSpec = index
        self:_UpdateContainers()
        self:_UpdateBackground()
        self:_UpdateSpells()
        self:_UpdateTalents()
    end;

    _UpdateContainers = function(self)
        if self._showSpec > 0 then
            self._containerSpec:Show()
            self._containerFull:Hide()
            self._specIcon:SetTexture(MUI_SPEC_ICONS[MUI.GetClassID()][self._showSpec])
            self._specIconHl:SetTexture(MUI_SPEC_ICONS[MUI.GetClassID()][self._showSpec])
            self._specDot1:SetActive(self._showSpec == 1)
            self._specDot2:SetActive(self._showSpec == 2)
            self._specDot3:SetActive(self._showSpec == 3)
        else
            self._containerSpec:Hide()
            self._containerFull:Show()
        end
    end;

    _UpdateSpells = function(self)
        if self._showSpec > 0 then
            self._classTree:SetSpecFocus(self._showSpec)
            self._classTree:Refresh()
            self._classTree:UpdateLines()

            if MUI_DB.data.spells.trainerServiceCount <= 15 then
                self._classMessage:Show()
            else
                self._classMessage:Hide()
            end
        end

    end;

    _UpdateTalents = function(self)
        if self._showSpec > 0 then
            local _, name = GetTalentTabInfo(self._showSpec)
            self._specName:SetText(string.upper(name))
            self._specHeader:SetWidth(self._specName:GetStringWidth() + self._specPoints:GetStringWidth() + 20)
            self._specGrid:UpdateFromSpec(self._showSpec)
        end
        self._spec1:Update()
        self._spec2:Update()
        self._spec3:Update()

        self:_UpdateTalentsPreview()
    end;

    _UpdateTalentsPreview = function(self)
        local stashed = GetGroupPreviewTalentPointsSpent(false, GetActiveTalentGroup())
        local unspent = GetUnspentTalentPoints()
        local available = unspent - stashed
        local color = (available > 0) and "|cff00ff00" or "|cff666666"
        self._btnApply:SetEnabled(stashed > 0)
        self._btnReset:SetEnabled(stashed > 0)
        self._pointsAvailable:SetText("AVAILABLE TALENT POINTS: " .. color .. available)
    end;

    _UpdateBackground = function(self)
        if self._showSpec > 0 then
            local _, _, classID = UnitClass("player")
            local bg = SPEC_BACKGROUNDS[classID][self._showSpec]
            self._bg:SetTextureRegion(MUI.TEX_SKIN .. "talents\\" .. bg.file, bg.w, bg.h, bg.x, bg.y, 1614, 776)
        end
    end;

    _UpdateLevel = function(self)
        self._classPoints:SetText(UnitLevel("player"))
        self._classHeader:SetWidth(self._className:GetStringWidth() + self._classPoints:GetStringWidth() + 20)
    end;

    _CreateBottomBar = function(self)
        self._bottomBar = NineSlice(self)
        self._bottomBar:PutInfront(self, 5)
        self._bottomBar:AlignParentBottom()
        self._bottomBar:FillWidth()
        self._bottomBar:SetHeight(74.5)
        self._bottomBar:SetFromTextureRegion("skin\\talents\\talents", 2048, 2048, 0, 0, 1614, 84, 1, 20, 1, 2, 0.37)

        self._btnApply = ButtonGold(self._bottomBar, nil, "Apply changes")
        self._btnApply:CenterInParent(0, 3)
        self._btnApply:SetSize(146, 20)
        self._btnApply.label:SetFontSize(10.5)
        self._btnApply:SetEnabled(false)
        self._btnApply.OnClick = function()
            StaticPopup_Show("MUI_CONFIRM_LEARN_PREVIEW_TALENTS")
        end

        local TEX = MUI.TEX_SKIN .. "talents\\talents"
        self._btnReset = ButtonSimple(self._bottomBar)
        self._btnReset:SetSize(17, 17)
        self._btnReset:RightOf(self._btnApply, 17)
        self._btnReset:SetTexture(TEX, 2048, 1024, 1535, 111, 38, 38)
        self._btnReset:SetEnabled(false)
        self._btnReset.OnClick = function()
            ResetGroupPreviewTalentPoints(false, GetActiveTalentGroup())
        end

        self._pointsAvailable = FontString(self._bottomBar, nil, "OVERLAY")
        self._pointsAvailable:SetFont(MUI.FONT, 20, "")
        self._pointsAvailable:Above(self._bottomBar, 30)
        self._pointsAvailable:SetSize(300, 20)
        self._pointsAvailable:SetJustifyH("LEFT")
        self._pointsAvailable:SetText("AVAILABLE TALENT POINTS: 0")

        self._btnMode = ButtonGold(self._bottomBar, nil, "Full view")
        self._btnMode:AlignParentRight(30)
        self._btnMode:SetSize(120, 20)
        self._btnMode.label:SetFontSize(10.5)
        self._btnMode.OnClick = function()
            if self._showSpec == 0 then
                self:SetSpec(1)
                self._btnMode:SetText("Full view")
            else
                self:SetSpec(0)
                self._btnMode:SetText("Detail view")
            end
        end

        self._ddPreset = DropdownSimple(self._bottomBar)
        self._ddPreset:SetSize(184, 26)
        self._ddPreset:AlignParentLeft(43, 1)

        -- Talent-group (dual-spec) selector, opening above the dropdown.
        -- Secondary is greyed out / unclickable until dual spec is bought.
        self._presetMenu = DropdownMenu(self._ddPreset, "MUI_TalentPresetMenu", self._ddPreset, 0.45)
        self._presetMenu:SetMenuWidth(200)
        self._presetMenu:SetAnchor(function(popup, anchor)
            popup:Above(anchor, -10)
        end)
        -- Build the rows ONCE; _RefreshPresetMenu only re-texts them afterward.
        self._presetItems = {
            { label = "Primary",   OnClick = function() self:SetPreviewGroup(1) end },
            { label = "Secondary", OnClick = function() self:SetPreviewGroup(2) end },
        }
        self._presetMenu:SetItems(self._presetItems)
        self._ddPreset.OnClick = function()
            self:_RefreshPresetMenu()
            self._presetMenu:Toggle()
        end

        self._btnPresetActivate = ButtonGold(self._bottomBar, nil, "Activate")
        self._btnPresetActivate:RightOf(self._ddPreset, 10)
        self._btnPresetActivate:SetSize(100, 20)
        self._btnPresetActivate.label:SetFontSize(10.5)
        self._btnPresetActivate:SetEnabled(false)
        self._btnPresetActivate.OnClick = function()
            if InCombatLockdown() then return end
            C_SpecializationInfo.SetActiveSpecGroup(self._previewGroup)
        end

    end;

    -- Switch the previewed talent group (1 = primary, 2 = secondary): retitle
    -- the dropdown, point every TalentGrid at that group, and enable Activate
    -- only when previewing a group that isn't currently active.
    SetPreviewGroup = function(self, group)
        self._previewGroup = group
        local desat = group ~= GetActiveTalentGroup()
        self._ddPreset:SetText((group == 1 and "Primary" or "Secondary")
                               .. (desat and STATUS_INACTIVE or STATUS_ACTIVE))
        self._btnPresetActivate:SetEnabled(desat)
        self._bg:SetDesaturated(desat)
        self._specGrid:SetGroup(group)
        self._spec1:SetGroup(group)
        self._spec2:SetGroup(group)
        self._spec3:SetGroup(group)
    end;

    -- Re-text the (already-built) menu rows in place and toggle Secondary's
    -- enabled state. The rows are created once via SetItems in _CreateBottomBar.
    _RefreshPresetMenu = function(self)
        local active = GetActiveTalentGroup()
        self._presetMenu:SetItemLabel(1, "Primary"   .. (active == 1 and STATUS_ACTIVE or STATUS_INACTIVE))
        self._presetMenu:SetItemLabel(2, "Secondary" .. (active == 2 and STATUS_ACTIVE or STATUS_INACTIVE))
        self._presetMenu:SetItemEnabled(2, GetNumTalentGroups() > 1)
    end;

    -- Retail's drifting "air particle" loop for one texture layer. The layer
    -- jumps +startX, drifts -2*startX over `dur`s (rotating `deg`, fading in
    -- 0->peak over 5s then peak->0 at `fadeDelay`s), then snaps back — the
    -- fade hides the snap. Looping. (Blizzard_ClassTalentsFrame.xml.)
    _BuildParticleAnim = function(self, host, tex, startX, dur, deg, peak, fadeDelay)
        local ag = AnimationGroup(host)
        ag:SetLooping("REPEAT")

        local function add(animType, order, length)
            local a = ag:CreateAnimation(animType)
            a:SetTarget(tex)
            a:SetOrder(order)
            a:SetDuration(length)
            return a
        end

        add("Translation", 1, 0):SetOffset(startX, 0)
        add("Translation", 2, dur):SetOffset(-2 * startX, 0)
        add("Translation", 3, 0):SetOffset(2 * startX, 0)

        local rot = add("Rotation", 2, dur)
        rot:SetDegrees(deg)
        rot:SetOrigin("CENTER", 0, 0)

        local fin = add("Alpha", 2, 5)
        fin:SetFromAlpha(0); fin:SetToAlpha(peak); fin:SetSmoothing("NONE")

        local fout = add("Alpha", 2, 5)
        fout:SetStartDelay(fadeDelay)
        fout:SetFromAlpha(peak); fout:SetToAlpha(0); fout:SetSmoothing("NONE")

        return ag
    end;

    -- Builds the additive drifting-particle pair (far + close) centered on
    -- `parent`, with looping anims hosted on `host`. Both views use this; the
    -- caller Play/Stops the returned groups on its show/hide. Far layer is
    -- flipped, smaller, slower and counter-rotating for parallax.
    _CreateParticles = function(self, parent, host)
        local pr = MUI_AtlasRegistry.TalentsAnimationParticles:GetRegion("Particles")

        local far = Texture(parent, nil, "ARTWORK")
        far:SetAtlas(MUI_AtlasRegistry.TalentsAnimationParticles, "Particles", true)
        far:SetSize(800, 473)
        far:SetTexCoord(pr.right, pr.left, pr.bottom, pr.top)  -- H+V flip
        far:SetDrawLayer("ARTWORK", 0)
        far:SetBlendMode("ADD")
        far:SetAlpha(0)
        far:CenterInParent()

        local close = Texture(parent, nil, "ARTWORK")
        close:SetAtlas(MUI_AtlasRegistry.TalentsAnimationParticles, "Particles")
        close:SetDrawLayer("ARTWORK", 1)
        close:SetBlendMode("ADD")
        close:SetAlpha(0)
        close:CenterInParent()

        local farAnim   = self:_BuildParticleAnim(host, far,   100, 36, -20, 0.14, 31)
        local closeAnim = self:_BuildParticleAnim(host, close, 300, 27,  20, 0.15, 22)
        return farAnim, closeAnim
    end;

    _CreateSpecView = function(self)

        self._containerSpec = Frame("Frame", self)
        self._containerSpec:FillWidth()
        self._containerSpec:AlignParentTop()
        self._containerSpec:Above(self._bottomBar)
        self._containerSpec:Hide()

        -- Mouse wheel over the spec view cycles specs 1-2-3, wrapping.
        -- Wheel up -> previous spec; wheel down -> next.
        self._containerSpec:EnableMouseWheel(true)
        self._containerSpec:EnableMouse(true)
        self._containerSpec:SetScript("OnMouseWheel", function(_, delta)
            local cur = self._showSpec
            local next = ((cur - 1 + (delta > 0 and -1 or 1)) % 3) + 1
            if next ~= cur then
                self:SetSpec(next)
                PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)
            end
        end)

        self._bg = Texture(self._containerSpec, nil, "BACKGROUND")
        self._bg:FillParent()

        -- Drifting "air particle" layers in front of the bg art, under the
        -- talent content (child frames). Played while the spec view is shown.
        self._farAnim, self._closeAnim = self:_CreateParticles(self._containerSpec, self._containerSpec)

        -- Right part
        local containerR = Frame("Frame", self._containerSpec)
        containerR:FillHeight()
        containerR:AlignParentRight()
        containerR:SetWidth(730)

        self._specHeader = Frame("Frame", containerR)
        self._specHeader:AlignParentTop(28)
        self._specHeader:SetHeight(24)

        self._specName = FontString(self._specHeader)
        self._specName:AlignParentLeft()
        self._specName:SetFontSize(17)
        self._specName:SetShadowOffset(1, -1)

        self._specPoints = FontString(self._specHeader)
        self._specPoints:SetFont(MUI.FONT_CAL, 28, "")
        self._specPoints:SetShadowOffset(2, -2)
        self._specPoints:SetText(0)
        self._specPoints:SetTextColor(0.5, 0.5, 0.5, 1)
        self._specPoints:RightOf(self._specName, 20, 3)

        self._specGrid = TalentGrid(containerR, nil, 7, 4, true)
        self._specGrid:Below(self._specHeader, 140)
        self._specGrid.OnUpdate = function(pointsSpent)
            self._specPoints:SetText(pointsSpent)
            if pointsSpent > 0 then
                self._specPoints:SetTextColor(0, 1, 0, 1)
            else
                self._specPoints:SetTextColor(0.5, 0.5, 0.5, 1)
            end
        end

        -- Left part
        local containerL = Frame("Frame", self._containerSpec)
        containerL:FillHeight()
        containerL:AlignParentLeft()
        containerL:SetWidth(730)

        self._classHeader = Frame("Frame", containerL)
        self._classHeader:AlignParentTop(28)
        self._classHeader:SetHeight(24)

        self._className = FontString(self._classHeader)
        self._className:AlignParentLeft()
        self._className:SetFontSize(17)
        self._className:SetShadowOffset(1, -1)

        self._classPoints = FontString(self._classHeader)
        self._classPoints:SetFont(MUI.FONT_CAL, 28, "")
        self._classPoints:SetShadowOffset(2, -2)
        self._classPoints:SetText(0)
        self._classPoints:SetTextColor(1, 0.82, 0, 1)
        self._classPoints:RightOf(self._className, 20, 3)

        self._classTree = ClassTree(containerL, "MUI_TalentsClassTree")
        self._classTree:CenterInParent()

        self._classMessage = FontString(containerL)
        self._classMessage:SetFont(MUI.FONT, 20, "")
        self._classMessage:SetWidth(300)
        self._classMessage:SetText("Visit one of the class trainers in a major city to unlock the full tree")
        self._classMessage:SetTextColor(1, 0.82, 0, 1)
        self._classMessage:CenterAt(self._classTree)

        -- Middle

        -- Mouse-enabled host sized to the icon, so hover is detected over
        -- the icon, not the whole tab. The highlight lives in ARTWORK (not
        -- HIGHLIGHT) so it draws BELOW the OVERLAY hero ring; toggle it
        -- manually on enter/leave since it's no longer auto-managed.
        self._specIconHost = Frame("Frame", self._containerSpec)
        self._specIconHost:SetSize(90, 90)
        self._specIconHost:EnableMouse(true)
        self._specIconHost:AlignParentTop(64)

        self._maskOverlay = Texture(self._specIconHost, nil, "OVERLAY")
        self._maskOverlay:SetTextureRegion(MUI.TEX_SKIN .. "talents\\talents-hero", 2048, 1024, 405, 825, 160, 160)
        self._maskOverlay:SetSize(130, 130)
        self._maskOverlay:CenterInParent()

        self._specIcon = Texture(self._specIconHost, nil, "ARTWORK")
        self._specIcon:Fill(self._maskOverlay, 20, 20, 20, 20)

        self._specIconHl = Texture(self._specIconHost, nil, "ARTWORK")
        self._specIconHl:SetDrawLayer("ARTWORK", 1)   -- above icon, below OVERLAY ring
        self._specIconHl:Fill(self._maskOverlay, 20, 20, 20, 20)
        self._specIconHl:SetAlpha(0.3)
        self._specIconHl:SetBlendMode("ADD")
        self._specIconHl:Hide()

        self._specIconHost:SetScript("OnEnter", function() self._specIconHl:Show() end)
        self._specIconHost:SetScript("OnLeave", function() self._specIconHl:Hide() end)

        self._containerSpec:HookScript("OnShow", function()
            self._specIcon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
            self._specIconHl:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
            self._farAnim:Play()
            self._closeAnim:Play()
        end)
        self._containerSpec:HookScript("OnHide", function()
            self._farAnim:Stop()
            self._closeAnim:Stop()
        end)

        self._specPrev = ButtonSimple(self._containerSpec)
        self._specPrev:SetTexture(MUI.TEX_SKIN .. "talents\\talent-spec-steps", 64, 32, 32, 0, 32, 32)
        self._specPrev:SetSize(32, 32)
        self._specPrev:LeftOf(self._maskOverlay, -20)
        self._specPrev.OnClick = function()
            self:SetSpec(((self._showSpec - 1 - 1) % 3) + 1)
        end

        self._specNext = ButtonSimple(self._containerSpec)
        self._specNext:SetTexture(MUI.TEX_SKIN .. "talents\\talent-spec-steps", 64, 32, 0, 0, 32, 32)
        self._specNext:SetSize(32, 32)
        self._specNext:RightOf(self._maskOverlay, -20)
        self._specNext.OnClick = function()
            self:SetSpec(((self._showSpec - 1 + 1) % 3) + 1)
        end

        self._specDot2 = SpecDot(self._containerSpec)
        self._specDot2:Below(self._specIcon, 10)
        self._specDot1 = SpecDot(self._containerSpec)
        self._specDot1:LeftOf(self._specDot2, 12)
        self._specDot3 = SpecDot(self._containerSpec)
        self._specDot3:RightOf(self._specDot2, 12)

    end;

    _CreateFullView = function(self)

        self._containerFull = Frame("Frame", self)
        self._containerFull:FillWidth()
        self._containerFull:AlignParentTop()
        self._containerFull:Above(self._bottomBar)

        local w = 1459 / 3

        self._spec1 = SpecGridColumn(self._containerFull, nil, 1)
        self._spec1:AlignParentTop()
        self._spec1:AlignParentLeft()
        self._spec1:Above(self._bottomBar)
        self._spec1:SetWidth(w)

        self._spec3 = SpecGridColumn(self._containerFull, nil, 3)
        self._spec3:AlignParentTop()
        self._spec3:AlignParentRight()
        self._spec3:Above(self._bottomBar)
        self._spec3:SetWidth(w)

        self._spec2 = SpecGridColumn(self._containerFull, nil, 2)
        self._spec2:AlignParentTop()
        self._spec2:LeftOf(self._spec3)
        self._spec2:RightOf(self._spec1)
        self._spec2:Above(self._bottomBar)

        local overlay = Frame("Frame", self._containerFull)
        overlay:FillParent()
        overlay:PutInfront(self._containerFull)

        -- Same drifting particles as the spec view. Parented to the overlay so
        -- they draw in front of the three spec backgrounds (the columns are
        -- separate child frames); the vignette (OVERLAY) stays on top.
        self._farAnimFull, self._closeAnimFull = self:_CreateParticles(overlay, self._containerFull)

        local vign = Texture(overlay, nil, "OVERLAY")
        vign:SetTexture(MUI.TEX_BASE .. "frame-inner-shadow")
        vign:FillParent()

        self._containerFull:HookScript("OnShow", function()
            self._farAnimFull:Play()
            self._closeAnimFull:Play()
        end)
        self._containerFull:HookScript("OnHide", function()
            self._farAnimFull:Stop()
            self._closeAnimFull:Stop()
        end)

    end;

}