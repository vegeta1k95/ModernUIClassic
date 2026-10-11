-- MUI_DressingRoomFrame: the dressing room window — retail's DressUpFrame
-- (450x545, or 334x423 from the button beside its close button; drawn at
-- nine tenths like the other portrait windows) on Era's own DressUpFrame.
--
-- Era's frame stays the real panel: a Ctrl-click opens it through the panel
-- manager and Escape closes it, in combat too. This window is its child and
-- covers it. Era's model, its Reset and Close buttons and its close button
-- stay the things that are used, wearing our art: DressUpVisual tries items
-- on that model by name, and a button of our own could not close the panel
-- in combat.
--
--   DressingRoomWindow()
--     .canvas   retail's frame rect, at retail's scale: everything on it is
--               laid out in retail's own numbers
--     .inset    the recessed area the model stands in
--     .model    Era's model (DressingRoomModel)

local S = 0.9
local ART = MUI.TEX_SKIN .. "dressingroom\\"

-- Retail's frame, whole and minimized.
local FRAME_W, FRAME_H = 450, 545
local SMALL_W, SMALL_H = 334, 423
-- Where retail's model scene lies in its frame: left, top, right, bottom.
local SCENE = { 7, 63, 9, 28 }

-- A window the size of retail's frame of `width` by `height`: its body (the
-- frame less the border art, 2 px a side and the 23 px title bar) at nine
-- tenths, inside this window's border.
local function WindowSize(width, height)
    return (width - 4) * S + 6, (height - 23) * S + 21
end

class "DressingRoomWindow" : extends "PanelPortrait" {
    __init = function(self)
        self._blizzard = Frame(DressUpFrame)
        PanelPortrait.__init(self, self._blizzard, "MUI_DressingRoomFrame", DRESSUP_FRAME)
        self:FillParent()

        -- Nothing of Era's frame shows: its art, title, portrait and hint,
        -- the backdrop quarters it textures again on every opening.
        self._blizzard:HideAllRegions()
        for _, key in ipairs({ "NineSlice", "Inset", "TitleContainer", "PortraitContainer" }) do
            Frame(DressUpFrame[key]):Hide()
        end

        self.canvas = Frame("Frame", self)
        self.canvas:SetScale(S)
        self.canvas:Fill(self._content, -2, -21, -2, -2)
        self:_BuildBody()
        self:_BuildTopButtons()

        -- Era's model is not on the canvas, so an offset of its own would not
        -- be in the canvas's scale: it takes the backdrop's rect as it is.
        self.model = DressingRoomModel(self.inset)
        self.model:ClearAllPoints()
        self.model:Fill(self._backdrop)

        -- Retail's two buttons under the model's right corner.
        local close = self:_SkinButton(DressUpFrameCancelButton)
        close:AlignBottomRight(self.canvas, 7, 4)
        local reset = self:_SkinButton(DressUpFrameResetButton)
        reset:LeftOf(close)

        self:_Fit()

        -- Era puts the player on the model after its frame has shown: the
        -- model goes back to how it first stands once that is done.
        self._blizzard:HookScript("OnShow", function()
            self._opening = true
            self:SetPortraitFromUnit("player")
        end)
        hooksecurefunc("DressUpFrame_Show", function()
            if self._opening then
                self._opening = false
                self.model:Reset()
            end
        end)
    end;

    -- The streak band under the title bar and the recessed area, the
    -- player's class backdrop where the model stands in it.
    _BuildBody = function(self)
        local streaks = Texture(self.canvas, nil, "BACKGROUND")
        streaks:SetBlizzardAtlas("_UI-Frame-TopTileStreaks")
        streaks:SetHorizTile(true)
        streaks:SetHeight(43)
        streaks:AlignParentTopLeft(21, 6)
        streaks:AlignParentTopRight(21, 2)

        self.inset = InnerFrame(self.canvas)
        self.inset:Fill(self.canvas, 4, 60, 6, 26)

        local _, class = UnitClass("player")
        self._backdrop = Texture(self.inset, nil, "BACKGROUND")
        self._backdrop:SetTextureRegion(ART .. "background-" .. strlower(class), 512, 512, 1, 1, 478, 500)
        self._backdrop:Fill(self.canvas, SCENE[1], SCENE[2], SCENE[3], SCENE[4])
    end;

    -- Era's close button, where and how the other windows have theirs (its
    -- own click closes the panel through the panel manager), and retail's
    -- button beside it that makes the window small and whole again.
    _BuildTopButtons = function(self)
        local atlas = MUI_AtlasRegistry.ButtonRedControl

        local close = Button(DressUpFrameCloseButton)
        close:SetStateAtlas(atlas, "ExitNormal", "ExitPressed", "ExitDisabled")
        close:SetHighlightAtlas(atlas, "Highlight", true)
        close:SetSize(23, 24.5)
        close:SetScale(S)
        close:ClearAllPoints()
        close:AlignParentTopRight(-2, -0.5)
        close:PutInfront(self._border, 1)

        self._sizeButton = Button(self)
        self._sizeButton:SetHighlightAtlas(atlas, "Highlight", true)
        self._sizeButton:SetSize(23, 24.5)
        self._sizeButton:SetScale(S)
        self._sizeButton:LeftOf(close)
        self._sizeButton:PutInfront(self._border, 1)
        self._sizeButton:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self._sizeButton.OnClick = function()
            local saved = MUI_DB.settings.dressingRoom
            saved.minimized = not saved.minimized
            self:_Fit()
        end
    end;

    -- One of Era's two panel buttons in the gold button's art, at the
    -- canvas's scale and over it.
    _SkinButton = function(self, native)
        local button = ButtonGold(native)
        button:SetSize(80, 22)
        button:SetScale(S)
        button:ClearAllPoints()
        button:PutInfront(self.canvas, 1)
        return button
    end;

    -- Era's frame takes the window's size, whole or minimized, and with it
    -- everything laid out on the canvas. The panel manager places the next
    -- panel by that size; it moves the open panels only out of combat.
    _Fit = function(self)
        local minimized = MUI_DB.settings.dressingRoom.minimized
        if minimized then
            self._blizzard:SetSize(WindowSize(SMALL_W, SMALL_H))
        else
            self._blizzard:SetSize(WindowSize(FRAME_W, FRAME_H))
        end

        local art = minimized and "Expand" or "Condense"
        self._sizeButton:SetStateAtlas(MUI_AtlasRegistry.ButtonRedControl,
            art .. "Normal", art .. "Pressed", art .. "Disabled")

        if self._blizzard:IsShown() and not InCombatLockdown() then
            UpdateUIPanelPositions(DressUpFrame)
        end
    end;
}
