-- MUI_GameMenu: reskin-in-place of Blizzard's GameMenuFrame. Native buttons keep their
-- OnClick handlers (so secure call chain is preserved); we only overlay visuals on top.
-- Buttons are pooled and rebuilt on every show, then laid out a frame later: we act from the Layout hook.

local BUTTON_WIDTH    = 200
local BUTTON_HEIGHT   = 36
local BUTTON_SPACING  = 0
local SECTION_SPACING = 20
local PADDING_TOP     = 48
local PADDING_BOTTOM  = 20
local PADDING_SIDE    = 28

local RED_SCALE   = 36 / 128
local RED_LEFT_W  = math.floor(114 * RED_SCALE + 0.5)
local RED_RIGHT_W = math.floor(292 * RED_SCALE + 0.5)

object "GameMenuSkin" : extends "Module" {
    __init = function(self)
        Module.__init(self, "GameMenu")
    end;

    OnEnable = function(self)
        self:Apply()
    end;

    Apply = function(self)
        if self._applied then return end
        self._applied = true

        self._menuFrame = Frame(GameMenuFrame)
        self._skins = {}

        self:_HideUnused()

        self._border = DiamondBorder(self._menuFrame, "MUI_GameMenuBorder")
        self._border:CenterInParent()
        self._border:SetWidth(230)
        self._border:FillHeight()
        self._border:SetFrameLevel(self._menuFrame:GetFrameLevel())

        self._header = DiamondHeader(self._menuFrame, nil, "Game Menu")
        self._header:AlignTop(self._border, -26)

        self._btnEditMode = ButtonRed(self._menuFrame, "MUI_GameMenuEditMode", "Edit Mode")
        self._btnEditMode:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
        self._btnEditMode:SetScale(0.9)
        self._btnEditMode.OnClick = function()
            if not InCombatLockdown() then
               HideUIPanel(GameMenuFrame)
               MUI_EditMode:Start()
            end
        end;

        hooksecurefunc(GameMenuFrame, "Layout", function() self:RelayoutButtons() end)
    end;

    -- Native chrome, plus the Blizzard Edit Mode tutorial dot (re-shown on every rebuild)
    _HideUnused = function(self)
        Frame(GameMenuFrame.Border):Hide()
        Frame(GameMenuFrame.Header):Hide()
        Frame(GameMenuFrame.EditModeNotification):Kill()
    end;

    -- Overlay our visual on a native button. No SetParent, no secure forwarders — the
    -- native OnClick handler stays intact and runs in its original secure context.
    -- Skinned once per pooled button; the label is refreshed on every relayout.
    _ReskinButton = function(self, nativeBtn)
        local skin = self._skins[nativeBtn]
        if skin then return skin end

        local atlas = MUI_AtlasRegistry.ButtonRed
        local btn = Button(nativeBtn)

        -- Hide all existing regions (backdrop textures, label, state textures).
        for _, region in ipairs(btn:GetRegions()) do
            region:SetAlpha(0)
        end

        btn:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
        btn:SetScale(0.9)

        local texLeft = Texture(btn, nil, "ARTWORK")
        texLeft:SetAtlas(atlas, "LeftNormal", true)
        texLeft:SetSize(RED_LEFT_W, BUTTON_HEIGHT)
        texLeft:AlignParentTopLeft()

        local texRight = Texture(btn, nil, "ARTWORK")
        texRight:SetAtlas(atlas, "RightNormal", true)
        texRight:SetSize(RED_RIGHT_W, BUTTON_HEIGHT)
        texRight:AlignParentTopRight()

        local texCenter = Texture(btn, nil, "BACKGROUND")
        texCenter:SetAtlas(atlas, "CenterNormal", true)
        texCenter:FillBetweenH(texLeft, texRight, 3)

        local hlRegion = atlas:GetRegion("Highlight")
        if hlRegion then
            btn:SetHighlightTexture(hlRegion.file)
            local hl = btn:GetHighlightTexture()
            if hl then
                hl:SetTexCoord(hlRegion.left, hlRegion.right, hlRegion.top, hlRegion.bottom)
                hl:SetBlendMode("ADD")
                hl:SetAlpha(1)  -- we SetAlpha(0) on all regions earlier; restore for highlight
            end
        end

        local label = FontString(btn, nil, "OVERLAY")
        label:SetFontSize(14)
        label:CenterInParent()
        label:SetShadowOffset(1, -1)
        label:SetShadowColor(0, 0, 0, 1)

        local function setState(state)
            texLeft:SetAtlas(atlas, "Left" .. state, true)
            texLeft:SetSize(RED_LEFT_W, BUTTON_HEIGHT)
            texRight:SetAtlas(atlas, "Right" .. state, true)
            texRight:SetSize(RED_RIGHT_W, BUTTON_HEIGHT)
            texCenter:SetAtlas(atlas, "Center" .. state, true)
        end

        btn:HookScript("OnMouseDown", function()
            setState("Pressed")
            label:ClearAllPoints()
            label:CenterInParent(-2, 1)
        end)
        btn:HookScript("OnMouseUp", function()
            setState("Normal")
            label:ClearAllPoints()
            label:CenterInParent()
        end)

        skin = { button = btn, label = label }
        self._skins[nativeBtn] = skin
        return skin
    end;

    -- Anchor each button to GameMenuFrame's TOP with absolute Y offsets. Anchoring to
    -- border directly or chaining between siblings creates a cycle because Blizzard's
    -- layout sizes GameMenuFrame based on its buttons.
    -- Blizzard's Edit Mode entry is hidden, ours sits above Support; topPadding marks a section start.
    RelayoutButtons = function(self)
        local natives = {}
        for native in GameMenuFrame.buttonPool:EnumerateActive() do
            table.insert(natives, native)
        end
        table.sort(natives, function(a, b) return a.layoutIndex < b.layoutIndex end)

        local y, count, sections, newSection = PADDING_TOP, 0, 0, false
        local function place(r)
            if newSection then
                y = y + SECTION_SPACING
                sections = sections + 1
                newSection = false
            end
            r:ClearAllPoints()
            r:SetPoint("TOP", self._menuFrame, "TOP", 0, -y)
            r:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
            y = y + BUTTON_HEIGHT + BUTTON_SPACING
            count = count + 1
        end

        for _, native in ipairs(natives) do
            local skin = self:_ReskinButton(native)
            local text = skin.button:GetNativeText()
            newSection = newSection or native.topPadding ~= nil
            if text == HUD_EDIT_MODE_MENU then
                skin.button:Hide()
            else
                if text == GAMEMENU_SUPPORT then place(self._btnEditMode) end
                skin.label:SetText(text)
                place(skin.button)
            end
        end

        self._menuFrame:SetSize(BUTTON_WIDTH + PADDING_SIDE * 2,
            PADDING_TOP + (count * BUTTON_HEIGHT*0.9) + (sections * SECTION_SPACING) + PADDING_BOTTOM)
    end;
}
