-- MUI_QuestFrame: the quest giver's window, Era's QuestFrame (a quest being
-- offered, asked after or handed in, and the list of an NPC's quests), as
-- retail's: the metal-framed 338 x 496 window, its parchment page, the
-- minimal scroll bar and the panel buttons.
--
-- Era's frame stays the real panel, and everything on it that does something
-- stays Blizzard's: the four pages, their scroll frames, the text and rewards
-- QuestInfo lays out in them, the buttons. Blizzard's own event handler opens
-- the window, in combat too, so nothing here writes a field or a table its
-- Lua reads on the way (the QUEST_TEMPLATE layouts, the panel manager's entry
-- for the frame): the pieces are moved and re-textured, and what has to follow
-- Blizzard's updates follows from hooks.

-- Retail's QuestFrame. Era's is 384 x 512 with its art inset in it: the panel
-- manager puts the frame 16 px left of and 12 px above where a window's art
-- begins.
local WIDTH, HEIGHT = 338, 496
local NATIVE_DX, NATIVE_DY = 16, 12

-- Retail's page, QuestBG-Parchment, and where it lies in the window.
local PAGE = MUI.TEX_SKIN .. "questframe\\parchment"
local PAGE_X, PAGE_Y, PAGE_W, PAGE_H = 7, 62, 299, 407
-- The quarters of a page of another material (a stone tablet, a bronze
-- plate), which Blizzard textures and shows for a quest that has one, at
-- retail's sizes: Era's are for its shorter page.
local MATERIAL = {
    TopLeft = { 239, 300 }, TopRight = { 64, 300 },
    BotLeft = { 239, 138 }, BotRight = { 64, 138 },
}

-- Retail's scroll frame, and its bar: 9 right of the frame, from 2 below its
-- top to 5 above its bottom.
local SCROLL_X, SCROLL_Y, SCROLL_W, SCROLL_H = 5, 65, 300, 403
local BAR_X, BAR_Y, BAR_H = 314, 67, 396
-- Where retail starts a quest's text in the scroll frame; Era starts 5
-- further left.
local TEXT_X, TEXT_Y = 10, 10

-- Retail's buttons: 22 high, 6 in from a bottom corner and 4 up.
local BUTTON_H, BUTTON_X, BUTTON_Y = 22, 6, 4
-- Era's four pages and their buttons at retail's widths; true for the button
-- in the right corner.
local PAGES = {
    Detail   = { { "QuestFrameAcceptButton", 77 }, { "QuestFrameDeclineButton", 78, true } },
    Progress = { { "QuestFrameCompleteButton", 120 }, { "QuestFrameGoodbyeButton", 78, true } },
    Reward   = { { "QuestFrameCompleteQuestButton", 120 } },
    Greeting = { { "QuestFrameGreetingGoodbyeButton", 78, true } },
}

-- What Era shows where nobody is talking (a quest from an item).
local BOOK = "Interface\\QuestFrame\\UI-QuestLog-BookIcon"

-- ---------------------------------------------------------------------
-- QuestPanel: one of Era's four pages, QuestFrame<kind>Panel.
-- ---------------------------------------------------------------------
class "QuestPanel" : extends "Frame" {

    __init = function(self, window, kind)
        Frame.__init(self, _G["QuestFrame" .. kind .. "Panel"])
        -- Over the window, whose rect is retail's frame: what follows is in
        -- retail's own numbers.
        self:ClearAllPoints()
        self:Fill(window)

        self:_BuildPage()
        self:_BuildScroll(kind)
        for _, spec in ipairs(PAGES[kind]) do
            self:_SkinButton(spec[1], spec[2], spec[3])
        end
    end;

    -- Era's page is part of the classic frame's art, drawn in four quarters
    -- on every panel (plus a patch on the greeting's). All of it goes, for
    -- retail's parchment; the BORDER layer stays, the material quarters.
    _BuildPage = function(self)
        for _, region in ipairs(self:GetRegions()) do
            if region:GetDrawLayer() ~= "BORDER" then
                region:Hide()
            end
        end

        local page = Texture(self, nil, "BACKGROUND")
        page:SetTextureRegion(PAGE, 512, 512, 0, 0, PAGE_W, PAGE_H)
        page:SetSize(PAGE_W, PAGE_H)
        page:AlignParentTopLeft(PAGE_Y, PAGE_X)

        -- The other three quarters hang off the top left one.
        for part, size in pairs(MATERIAL) do
            Texture(_G[self:GetName() .. "Material" .. part]):SetSize(size[1], size[2])
        end
        local corner = Texture(_G[self:GetName() .. "MaterialTopLeft"])
        corner:ClearAllPoints()
        corner:AlignParentTopLeft(PAGE_Y, PAGE_X)
    end;

    -- The page's scroll frame, which Era hangs from QuestFrame's own corner,
    -- and retail's bar on its slider.
    _BuildScroll = function(self, kind)
        local name = "Quest" .. kind .. "ScrollFrame"
        local scroll = Frame(_G[name])
        scroll:ClearAllPoints()
        scroll:AlignParentTopLeft(SCROLL_Y, SCROLL_X)
        scroll:SetSize(SCROLL_W, SCROLL_H)

        local bar = NativeScrollBar(self, _G[name], _G[name .. "ScrollBar"], BAR_H)
        bar:AlignParentTopLeft(BAR_Y, BAR_X)
    end;

    -- One of Era's buttons in the gold button's art, in its corner. A label
    -- longer than retail's width has room for (another language) widens it.
    _SkinButton = function(self, name, width, right)
        local button = ButtonGold(_G[name])
        button:SetSize(math.max(width, button.label:GetStringWidth() + 30), BUTTON_H)
        button:ClearAllPoints()
        if right then
            button:AlignParentBottomRight(BUTTON_Y, BUTTON_X)
        else
            button:AlignParentBottomLeft(BUTTON_Y, BUTTON_X)
        end
    end;
}

-- ---------------------------------------------------------------------
-- QuestWindow
-- ---------------------------------------------------------------------
class "QuestWindow" : extends "Frame" {

    __init = function(self)
        self._blizzard = Frame(QuestFrame)
        -- A frame of Era's own window template inside Era's frame, which has
        -- none of that template: PanelChrome gives it the look every
        -- reskinned window has.
        Frame.__init(self, "Frame", self._blizzard, "MUI_QuestFrame", "ButtonFrameTemplate")
        self:FillParentPadding(NATIVE_DX, NATIVE_DY, 0, 0)
        -- Under Era's pages, which are children of its frame as this is.
        self:SetFrameLevel(self._blizzard:GetFrameLevel())

        -- Era's frame takes the window's size, and the mouse over it only.
        self._blizzard:SetSize(NATIVE_DX + WIDTH, NATIVE_DY + HEIGHT)
        self._blizzard:SetHitRectInsets(NATIVE_DX, 0, NATIVE_DY, 0)

        self:_BuildChrome()
        self:_BuildHeader()
        for kind in pairs(PAGES) do
            QuestPanel(self, kind)
        end
        self:_LayoutPages()
    end;

    -- ---- frame ---------------------------------------------------------

    _BuildChrome = function(self)
        MUI_PanelChrome:Apply(MUI_QuestFrame, { skipClose = true })
        -- What the template brings that retail's window has not: the classic
        -- strip under the bottom buttons, and a close button that would close
        -- this frame instead of Era's panel. Era's own closes that.
        Texture(MUI_QuestFrameBtnCornerLeft):Hide()
        Texture(MUI_QuestFrameBtnCornerRight):Hide()
        Texture(MUI_QuestFrameButtonBottomBorder):Hide()
        Frame(MUI_QuestFrameCloseButton):Hide()
        MUI_PanelChrome:ModernizeCloseButton(MUI_QuestFrame, QuestFrameCloseButton)
    end;

    -- Era's own portrait and NPC name are placed for the classic art.
    -- Blizzard sets them whenever a page opens and when the NPC's portrait
    -- changes; the window's ring and title follow.
    _BuildHeader = function(self)
        Texture(QuestFramePortrait):Hide()
        Frame(QuestNpcNameFrame):Hide()
        hooksecurefunc("QuestFrame_SetPortrait", function() self:_UpdateHeader() end)
    end;

    -- A quest from an item has nobody talking: the book, as Era shows there,
    -- and no name.
    _UpdateHeader = function(self)
        if UnitExists("questnpc") then
            self:SetPortraitToUnit("questnpc")
        else
            self:SetPortraitToAsset(BOOK)
        end
        MUI_PanelChrome:SetTitle(MUI_QuestFrame, UnitName("questnpc") or "")
    end;

    -- ---- pages ---------------------------------------------------------

    -- Retail's offsets inside the pages. Era lays a quest's text out from a
    -- table its own code reads, 5 from the scroll frame's edge; the title
    -- every other line hangs from is moved after each layout instead.
    _LayoutPages = function(self)
        local title = FontString(QuestInfoTitleHeader)
        hooksecurefunc("QuestInfo_Display", function(_, parent)
            if parent == QuestDetailScrollChildFrame or parent == QuestRewardScrollChildFrame then
                title:ClearAllPoints()
                title:AlignParentTopLeft(TEXT_Y, TEXT_X)
            end
        end)
        local progress = FontString(QuestProgressTitleText)
        progress:ClearAllPoints()
        progress:AlignParentTopLeft(TEXT_Y, TEXT_X)

        -- A row of the greeting's list: retail has its icon 4 in, centred on
        -- the row.
        for i = 1, MAX_NUM_QUESTS do
            local icon = Texture(_G["QuestTitleButton" .. i .. "QuestIcon"])
            icon:ClearAllPoints()
            icon:AlignParentLeft(4)
        end

        -- Retail's reward page has no Cancel beside Complete Quest.
        Frame(QuestFrameCancelButton):Hide()
    end;
}

object "ModuleQuestFrame" : extends "Module" {
    __init = function(self)
        Module.__init(self, "QuestFrame")
    end;

    OnEnable = function(self)
        self.window = QuestWindow()
    end;
}
