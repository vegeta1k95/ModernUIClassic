-- MUI_CollectionsFrame: the Collections window — retail's CollectionsJournal
-- (703x606, drawn at nine tenths like the other portrait windows) with the
-- pages Era has something for hanging off its tabs below: sets and mounts.
--
-- A window of our own: Era loads no collections frame to keep, and nothing in
-- it is protected, so it opens and closes in combat. Escape closes it through
-- UISpecialFrames.
--
--   CollectionsWindow()
--     :Toggle()
--     :ShowPage(index)   1: sets, 2: mounts
--     .canvas          retail's frame rect, at retail's scale: everything on
--                      it is laid out in retail's own numbers

local Style = MUI_CollectionsStyle
local S     = Style.S

local FRAME_W, FRAME_H = 703, 606
local TAB_LEFT, TAB_OVERLAP = 12, 9         -- the character window's

class "CollectionsWindow" : extends "PanelPortrait" {
    __init = function(self)
        PanelPortrait.__init(self, nil, "MUI_CollectionsFrame", COLLECTIONS)
        -- Retail's frame less its border art (2 px a side, the 23 px title
        -- bar) at nine tenths, inside this window's border.
        self:SetSize((FRAME_W - 4) * S + 6, (FRAME_H - 23) * S + 21)
        self:AlignParentTopLeft(104, 16)
        self:SetFrameStrata("MEDIUM")
        self:SetToplevel(true)
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

        self._mounts = CollectionsMounts(self.canvas)
        self._sets = CollectionsSets(self.canvas)
        self._sets:AlignParentTopRight(60, 4)
        self._sets:AlignParentBottomLeft(5, 4)

        -- A page to a tab under the window's bottom edge, the sets first,
        -- each with retail's portrait for it.
        self._pages = {
            { page = self._sets,   text = "Sets", portrait = "Interface\\Icons\\INV_Chest_Cloth_17" },
            { page = self._mounts, text = MOUNTS, portrait = Style.ART .. "portrait" },
        }
        local x = TAB_LEFT
        for i, entry in ipairs(self._pages) do
            entry.tab = AuctionHouseTab(self, entry.text)
            entry.tab:SetPoint("TOPLEFT", self, "BOTTOMLEFT", x, 1)
            entry.tab.OnClick = function() self:ShowPage(i) end
            x = x + entry.tab:GetWidth() - TAB_OVERLAP
        end
        self:ShowPage(1)

        self:SetScript("OnShow", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        end)
        self:SetScript("OnHide", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
            self._mounts:Reset()
            self._sets:Reset()
        end)
    end;

    Toggle = function(self)
        self:SetVisible(not self:IsShown())
    end;

    ShowPage = function(self, index)
        for i, entry in ipairs(self._pages) do
            entry.page:SetVisible(i == index)
            entry.tab:SetSelected(i == index)
        end
        self:SetPortrait(self._pages[index].portrait)
    end;
}
