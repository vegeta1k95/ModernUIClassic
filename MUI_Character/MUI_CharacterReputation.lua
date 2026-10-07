-- MUI_CharacterReputation: the Reputation tab — the faction list in one
-- scrolling column on retail's panel, each faction on Era's reputation plate
-- (name, standing bar, the swords of a faction at war), with the detail
-- panel beside the window for the faction that is clicked.
--
-- The list is the client's own (GetFactionInfo by index), so collapsing a
-- header, the selection and a watched faction are shared with everything
-- else that reads it.

local PLATE     = "Interface\\PaperDollInfoFrame\\UI-Character-ReputationBar"
local PLATE_LIT = "Interface\\PaperDollInfoFrame\\UI-Character-ReputationBar-Highlight"

local ROW_W, ROW_H = 326, 26
local BAR_X, BAR_W, BAR_H = 146, 137, 13
local VIEW_H = 352

-- ---------------------------------------------------------------------
-- CharacterBarRow: a row of the reputation list, and of the skill list: a
-- header that folds, or a name on a plate with a bar. `pane` hears the
-- clicks (OnRowClicked).
-- ---------------------------------------------------------------------
class "CharacterBarRow" : extends "Button" {
    __init = function(self, parent, pane)
        Button.__init(self, parent)
        self:SetSize(ROW_W, ROW_H)
        self:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self.index = nil          -- the faction's place in the client's list

        -- header
        self._toggle = Texture(self, nil, "ARTWORK")
        self._toggle:SetSize(16, 16)
        self._toggle:AlignParentLeft(2)
        self._title = FontString(self, nil, "ARTWORK")
        self._title:SetFontSize(11)
        self._title:SetTextColor(1, 0.82, 0, 1)
        self._title:AlignParentLeft(22)

        -- faction: the plate under a bar, the name on the plate's left part
        self._faction = Frame("Frame", self)
        self._faction:FillParent()
        self._bar = StatusBar(self._faction)
        self._bar:SetSize(BAR_W, BAR_H)
        self._bar:AlignParentLeft(BAR_X)
        self._bar:GetStatusBarTexture():SetDrawLayer("BACKGROUND", 1)
        local plate = Texture(self._bar, nil, "ARTWORK")
        plate:SetTexture(PLATE)
        plate:SetTexCoord(0, 1, 0, 0.34375)
        plate:SetSize(256, 22)
        plate:AlignParentTopLeft(-4, -126)
        local cap = Texture(self._bar, nil, "ARTWORK")
        cap:SetTexture(PLATE)
        cap:SetTexCoord(0, 0.0625, 0.34375, 0.71875)
        cap:SetSize(16, 24)
        cap:AlignParentTopLeft(-4, 130)

        self._lit = Frame("Frame", self._bar)
        self._lit:FillParent()
        local litLeft = Texture(self._lit, nil, "OVERLAY")
        litLeft:SetTexture(PLATE_LIT)
        litLeft:SetTexCoord(0, 1, 0, 0.4375)
        litLeft:SetBlendMode("ADD")
        litLeft:SetSize(256, 28)
        litLeft:AlignParentTopLeft(-7, -128)
        local litRight = Texture(self._lit, nil, "OVERLAY")
        litRight:SetTexture(PLATE_LIT)
        litRight:SetTexCoord(0, 0.06640625, 0.4375, 0.875)
        litRight:SetBlendMode("ADD")
        litRight:SetSize(17, 28)
        litRight:AlignParentTopLeft(-7, 128)

        self._name = FontString(self._bar, nil, "OVERLAY")
        self._name:SetFontSize(10)
        self._name:SetTextColor(1, 1, 1, 1)
        self._name:SetJustifyH("LEFT")
        self._name:SetSize(110, 10)
        self._name:AlignParentLeft(-119)
        self._watched = Texture(self._bar, nil, "OVERLAY")
        self._watched:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        self._watched:SetSize(16, 16)
        self._standing = FontString(self._bar, nil, "OVERLAY")
        self._standing:SetFontSize(10)
        self._standing:SetTextColor(1, 1, 1, 1)
        self._standing:CenterInParent()
        self._atWar = Texture(self._bar, nil, "OVERLAY")
        self._atWar:SetTexture(PLATE)
        self._atWar:SetTexCoord(0.0625, 0.15625, 0.34375, 0.71875)
        self._atWar:SetSize(24, 22)
        self._atWar:AlignParentLeft(BAR_W + 7)

        -- Under the cursor the bar reads its second text.
        self.OnEnter = function()
            if not self.isHeader then self._standing:SetText(self._hoverText) end
        end
        self.OnLeave = function()
            if not self.isHeader then self._standing:SetText(self._text) end
        end
        self.OnClick = function() pane:OnRowClicked(self) end
    end;

    SetHeader = function(self, index, name, collapsed)
        self.index, self.isHeader = index, true
        self.collapsed = collapsed
        self._faction:Hide()
        self._toggle:Show()
        self._toggle:SetTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        self._title:Show()
        self._title:SetText(name)
    end;

    -- The bar at `value` of `max` in r, g, b, reading `text` (and
    -- `hoverText` under the cursor).
    SetEntry = function(self, index, name, value, max, text, hoverText, r, g, b, selected)
        self.index, self.isHeader = index, false
        self._toggle:Hide()
        self._title:Hide()
        self._faction:Show()

        self._text, self._hoverText = text, hoverText
        self._standing:SetText(self:IsMouseOver() and hoverText or text)
        self._bar:SetMinMaxValues(0, max)
        self._bar:SetValue(value)
        self._bar:SetStatusBarColor(r, g, b)
        self._name:SetText(name)
        self._lit:SetVisible(selected)
        self:SetMarks(false, false)
    end;

    -- A faction's marks: the swords of one at war, a tick on the watched one.
    SetMarks = function(self, atWar, watched)
        self._atWar:SetVisible(atWar)
        self._watched:SetVisible(watched)
        if watched then
            self._watched:ClearAllPoints()
            self._watched:AlignParentLeft(-119 + math.min(self._name:GetStringWidth(), 96))
        end
    end;
}

-- ---------------------------------------------------------------------
-- CharacterReputationDetail: the selected faction, beside the window.
-- ---------------------------------------------------------------------
class "CharacterReputationDetail" : extends "Panel" {
    __init = function(self, pane)
        Panel.__init(self, pane, "MUI_CharacterReputationDetail", "")
        self:SetSize(232, 216)
        self:RightOf(pane.window, 2, 60)
        self:Hide()
        self._closeButton.OnClick = function()
            self:Hide()
            pane:Refresh()
        end

        self._name = FontString(self, nil, "ARTWORK")
        self._name:SetFontSize(12)
        self._name:SetTextColor(1, 0.82, 0, 1)
        self._name:SetJustifyH("LEFT")
        self._name:SetSize(196, 14)
        self._name:AlignParentTopLeft(34, 18)
        self._text = FontString(self, nil, "ARTWORK")
        self._text:SetFontSize(10)
        self._text:SetTextColor(1, 1, 1, 1)
        self._text:SetJustifyH("LEFT")
        self._text:SetJustifyV("TOP")
        self._text:SetWordWrap(true)
        self._text:SetSize(196, 76)
        self._text:AlignParentTopLeft(54, 18)

        local function check(label, y)
            local box = CheckBox(self, nil, label)
            box:SetSize(190, 24)
            box:SetBoxSize(24, 23)
            box:AlignParentTopLeft(y, 14)
            box.label:SetFontSize(10.5)
            return box
        end
        self._atWar    = check("At War", 132)
        self._inactive = check("Move to Inactive", 156)
        self._watch    = check("Show as Experience Bar", 180)
        self._atWar.OnChanged = function()
            FactionToggleAtWar(GetSelectedFaction())
        end
        self._inactive.OnChanged = function(_, checked)
            if checked then
                SetFactionInactive(GetSelectedFaction())
            else
                SetFactionActive(GetSelectedFaction())
            end
        end
        self._watch.OnChanged = function(_, checked)
            SetWatchedFactionIndex(checked and GetSelectedFaction() or 0)
        end
    end;

    Update = function(self)
        local index = GetSelectedFaction()
        local name, description, _, _, _, _, atWar, canToggleAtWar, isHeader, _, _, watched = GetFactionInfo(index)
        if not name or isHeader then
            self:Hide()
            return
        end
        self._name:SetText(name)
        self._text:SetText(description)
        self._atWar:SetChecked(atWar)
        self._atWar:SetEnabled(canToggleAtWar)
        self._inactive:SetChecked(IsFactionInactive(index))
        self._watch:SetChecked(watched)
    end;
}

-- ---------------------------------------------------------------------
-- CharacterReputation
-- ---------------------------------------------------------------------
class "CharacterReputation" : extends "CharacterPane" {
    __init = function(self, window)
        CharacterPane.__init(self, window)
        self._rows = {}

        self._scroll = CharacterScrollArea(self, VIEW_H, ROW_H)
        self._scroll:FillParentPadding(4, 4, 4, 4)
        self._detail = CharacterReputationDetail(self)

        self:HookScript("OnShow", function() self:Refresh() end)
        self:RegisterEventHandler("UPDATE_FACTION", function()
            if self:IsVisible() then self:Refresh() end
        end)
    end;

    GetTitle = function(self)
        return REPUTATION, 1, 0.82, 0
    end;

    -- A header folds; a faction opens the detail panel, and closes it again.
    OnRowClicked = function(self, row)
        if row.isHeader then
            if row.collapsed then
                ExpandFactionHeader(row.index)
            else
                CollapseFactionHeader(row.index)
            end
        elseif self._detail:IsShown() and GetSelectedFaction() == row.index then
            self._detail:Hide()
        else
            SetSelectedFaction(row.index)
            self._detail:Show()
        end
        self:Refresh()
    end;

    Refresh = function(self)
        local count = GetNumFactions()
        local selected = self._detail:IsShown() and GetSelectedFaction() or 0
        for i = 1, count do
            local row = self._rows[i]
            if not row then
                row = CharacterBarRow(self._scroll.content, self)
                row:AlignParentTop((i - 1) * ROW_H)
                self._rows[i] = row
            end
            local name, _, standing, low, high, value, atWar, _, isHeader, collapsed, _, watched = GetFactionInfo(i)
            if isHeader then
                row:SetHeader(i, name, collapsed)
            else
                local color = FACTION_BAR_COLORS[standing]
                row:SetEntry(i, name, value - low, high - low,
                    GetText("FACTION_STANDING_LABEL" .. standing, UnitSex("player")),
                    (value - low) .. " / " .. (high - low),
                    color.r, color.g, color.b, i == selected)
                row:SetMarks(atWar, watched)
            end
            row:Show()
        end
        for i = count + 1, #self._rows do
            self._rows[i]:Hide()
        end
        self._scroll:SetContentHeight(count * ROW_H)
        if self._detail:IsShown() then self._detail:Update() end
    end;
}
