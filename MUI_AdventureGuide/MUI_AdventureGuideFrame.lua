-- MUI_AdventureGuideFrame: the Adventure Guide's window — retail's
-- EncounterJournal (800x496, drawn at nine tenths like the other portrait
-- windows): the breadcrumb bar and the search box under the title, the grid
-- of dungeons or raids or an instance's pages in the inset, the Dungeons and
-- Raids tabs hanging below.
--
-- A window of our own: Era has no journal frame to keep, and nothing in it
-- is protected, so it opens and closes in combat. Escape closes it through
-- UISpecialFrames.
--
--   AdventureGuideWindow()
--     :Toggle()
--     :ShowHome()                the grid of the tab last on
--     :ShowInstance(instance)
--     :ShowEncounter(instance, encounter[, display])
--     .canvas                    retail's frame rect, at retail's scale:
--                                everything on it is laid out in retail's
--                                own numbers
--     .page                      the instance pages (AdventureGuideEncounter)

local Style = MUI_AdventureGuideStyle
local S     = Style.S

local FRAME_W, FRAME_H = 800, 496

class "AdventureGuideWindow" : extends "PanelPortrait" {
    __init = function(self)
        PanelPortrait.__init(self, nil, "MUI_AdventureGuideFrame", ADVENTURE_JOURNAL)
        -- Retail's frame less its border art (2 px a side, the 23 px title
        -- bar) at nine tenths, inside this window's border.
        self:SetSize((FRAME_W - 4) * S + 6, (FRAME_H - 23) * S + 21)
        self:AlignParentTopLeft(104, 16)
        self:SetFrameStrata("MEDIUM")
        self:SetToplevel(true)
        self:SetPortrait(Style.ART .. "portrait")
        self:Hide()
        self._raids = false           -- the bottom tab that is on
        self._instanceItems = {}      -- by raids: the instance crumb's dropdown
        self._bossItems = {}          -- by instance: the boss crumb's

        self._closeButton = CloseButton(self, "MUI_AdventureGuideFrameClose")
        self._closeButton:PutInfront(self._border, 1)
        self._closeButton:SetScale(0.9)
        tinsert(UISpecialFrames, "MUI_AdventureGuideFrame")

        self.canvas = Frame("Frame", self)
        self.canvas:SetScale(S)
        self.canvas:Fill(self._content, -2, -21, -2, -2)

        self:_BuildBody()
        self:_BuildTabs()

        self:SetScript("OnShow", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        end)
        self:SetScript("OnHide", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
            self._search:Reset()
        end)

        self:ShowHome()
    end;

    -- The streak band under the title bar with the breadcrumbs and the
    -- search box on it, and the recessed area the pages show in.
    _BuildBody = function(self)
        local canvas = self.canvas

        local streaks = Texture(canvas, nil, "BACKGROUND")
        streaks:SetBlizzardAtlas("_UI-Frame-TopTileStreaks")
        streaks:SetHorizTile(true)
        streaks:SetHeight(43)
        streaks:AlignParentTopLeft(21, 6)
        streaks:AlignParentTopRight(21, 2)

        self._navBar = AdventureGuideNavBar(canvas)
        self._navBar:SeatAt(22, 61)
        self._navBar.OnHome = function() self:ShowHome() end

        self._search = AdventureGuideSearch(canvas, self)
        self._search.box:AlignParentTopRight(32, 10)

        self._inset = InnerFrame(canvas)
        self._inset:HideBg()
        self._inset:AlignParentTopRight(60, 4)
        self._inset:AlignParentBottomLeft(5, 4)

        self._instances = AdventureGuideInstances(self._inset, self)
        self._instances:FillParentPadding(0, 2, 3, 0)

        self.page = AdventureGuideEncounter(self._inset, self)
        self.page:FillParentPadding(0, 0, 3, 0)
        self.page:Hide()
    end;

    -- Dungeons and Raids, hanging under the window's bottom edge.
    _BuildTabs = function(self)
        self._tabs = {}
        local x = 12
        for _, raids in ipairs({ false, true }) do
            local tab = AuctionHouseTab(self, raids and RAIDS or DUNGEONS)
            tab:SetPoint("TOPLEFT", self, "BOTTOMLEFT", x, 1)
            tab.OnClick = function()
                self._raids = raids
                self:ShowHome()
            end
            self._tabs[raids] = tab
            x = x + tab:GetWidth() - 4
        end
    end;

    Toggle = function(self)
        self:SetVisible(not self:IsShown())
    end;

    -- ---- what shows -----------------------------------------------------

    ShowHome = function(self)
        self.page:Hide()
        self._instances:SetRaids(self._raids)
        self._instances:Show()
        self:_SelectTab()
        self._navBar:SetPath({})
    end;

    ShowInstance = function(self, instance)
        self._instances:Hide()
        self.page:Show()
        self.page:ShowInstance(instance)
    end;

    ShowEncounter = function(self, instance, encounter, display)
        if self.page.instance ~= instance or not self.page:IsShown() then
            self:ShowInstance(instance)
        end
        self.page:ShowEncounter(encounter, display)
    end;

    -- The instance pages show something else: the tab below and the
    -- breadcrumbs follow. Each crumb's dropdown lists its neighbours.
    OnPageChanged = function(self)
        local page = self.page
        local instance, encounter = page.instance, page.encounter
        self._raids = instance.raid or false
        self:_SelectTab()

        local instances = self._instanceItems[self._raids]
        if not instances then
            instances = {}
            for i, other in ipairs(self._instances:Ordered(self._raids)) do
                instances[i] = { label = other.name, OnClick = function() self:ShowInstance(other) end }
            end
            self._instanceItems[self._raids] = instances
        end
        local crumbs = {
            { text = instance.name, items = instances, OnClick = function() page:ShowInstance(instance) end },
        }
        if encounter then
            local bosses = self._bossItems[instance]
            if not bosses then
                bosses = {}
                for i, boss in ipairs(instance.encounters) do
                    bosses[i] = { label = boss.name, OnClick = function() page:ShowEncounter(boss) end }
                end
                self._bossItems[instance] = bosses
            end
            crumbs[2] = { text = encounter.name, items = bosses }
        end
        self._navBar:SetPath(crumbs)
    end;

    _SelectTab = function(self)
        self._tabs[false]:SetSelected(not self._raids)
        self._tabs[true]:SetSelected(self._raids)
    end;
}
