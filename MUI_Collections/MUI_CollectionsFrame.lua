-- MUI_CollectionsFrame: the Collections window — retail's CollectionsJournal
-- (703x606, drawn at nine tenths like the other portrait windows) with the
-- pages Era has something for hanging off its tabs below.
--
-- A window of our own: Era loads no collections frame to keep, and nothing in
-- it is protected, so it opens and closes in combat. Escape closes it through
-- UISpecialFrames.
--
--   CollectionsWindow()
--     :Toggle()
--     .canvas          retail's frame rect, at retail's scale: everything on
--                      it is laid out in retail's own numbers

local Style = MUI_CollectionsStyle
local S     = Style.S

local FRAME_W, FRAME_H = 703, 606

class "CollectionsWindow" : extends "PanelPortrait" {
    __init = function(self)
        PanelPortrait.__init(self, nil, "MUI_CollectionsFrame", COLLECTIONS)
        -- Retail's frame less its border art (2 px a side, the 23 px title
        -- bar) at nine tenths, inside this window's border.
        self:SetSize((FRAME_W - 4) * S + 6, (FRAME_H - 23) * S + 21)
        self:AlignParentTopLeft(104, 16)
        self:SetFrameStrata("MEDIUM")
        self:SetToplevel(true)
        self:SetPortrait(Style.ART .. "portrait")
        self:Hide()

        self._closeButton = CloseButton(self, "MUI_CollectionsFrameClose")
        self._closeButton:PutInfront(self._border, 1)
        self._closeButton:SetScale(0.9)
        tinsert(UISpecialFrames, "MUI_CollectionsFrame")

        self.canvas = Frame("Frame", self)
        self.canvas:SetScale(S)
        self.canvas:Fill(self._content, -2, -21, -2, -2)

        -- The streak band under the title bar.
        local streaks = Texture(self.canvas, nil, "BACKGROUND")
        streaks:SetBlizzardAtlas("_UI-Frame-TopTileStreaks")
        streaks:SetHorizTile(true)
        streaks:SetHeight(43)
        streaks:AlignParentTopLeft(21, 6)
        streaks:AlignParentTopRight(21, 2)

        self._sets = CollectionsSets(self.canvas)
        self._sets:AlignParentTopRight(60, 4)
        self._sets:AlignParentBottomLeft(5, 4)

        -- One page so far, and its tab under the window's bottom edge.
        local tab = AuctionHouseTab(self, "Sets")
        tab:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 12, 1)
        tab:SetSelected(true)

        self:SetScript("OnShow", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        end)
        self:SetScript("OnHide", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
            self._sets:Reset()
        end)
    end;

    Toggle = function(self)
        self:SetVisible(not self:IsShown())
    end;
}
