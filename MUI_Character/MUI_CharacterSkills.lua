-- MUI_CharacterSkills: the Skills tab — Era's skill list in the reputation
-- list's rows, the selected skill's description under it, and the button
-- that unlearns a profession.
--
-- The list is the client's own (GetSkillLineInfo by index), and the
-- selection is shared with it. Folding a header is this pane's own doing,
-- though: the client's list is kept unfolded (the profession module unfolds
-- it on every skill event, to read every line), and a folded header's
-- lines are left out here.

local ROW_H    = 26
local DETAIL_H = 78
local LIST_H   = 352 - DETAIL_H

class "CharacterSkills" : extends "CharacterPane" {
    __init = function(self, window)
        CharacterPane.__init(self, window)
        self._rows = {}
        self._folded = {}         -- the headers folded here, by name

        self._scroll = CharacterScrollArea(self, LIST_H, ROW_H)
        self._scroll:FillParentPadding(4, 4, 4, 4 + DETAIL_H)
        self:_BuildDetail()

        self:HookScript("OnShow", function()
            ExpandSkillHeader(0)
            self:Refresh()
        end)
        local function refresh() if self:IsVisible() then self:Refresh() end end
        self:RegisterEventHandler("SKILL_LINES_CHANGED", refresh)
        self:RegisterEventHandler("CHARACTER_POINTS_CHANGED", refresh)
    end;

    GetTitle = function(self)
        return SKILLS, 1, 0.82, 0
    end;

    -- The strip under the list: the selected skill's name and description.
    _BuildDetail = function(self)
        local detail = Frame("Frame", self)
        detail:SetHeight(DETAIL_H)
        detail:AlignParentBottomLeft(4, 10)
        detail:AlignParentBottomRight(4, 10)

        local rule = Texture(detail, nil, "ARTWORK")
        rule:SetColorTexture(1, 1, 1, 0.12)
        rule:SetHeight(1)
        rule:AlignParentTopLeft(0, 0)
        rule:AlignParentTopRight(0, 0)

        self._name = FontString(detail, nil, "ARTWORK")
        self._name:SetFontSize(11)
        self._name:SetTextColor(1, 0.82, 0, 1)
        self._name:AlignParentTopLeft(8, 4)
        self._text = FontString(detail, nil, "ARTWORK")
        self._text:SetFontSize(10)
        self._text:SetTextColor(1, 1, 1, 1)
        self._text:SetJustifyH("LEFT")
        self._text:SetJustifyV("TOP")
        self._text:SetWordWrap(true)
        self._text:AlignParentTopLeft(24, 4)
        self._text:AlignParentBottomRight(2, 4)

        self._unlearn = ButtonGold(detail, nil, "Unlearn")
        self._unlearn:SetSize(80, 20)
        self._unlearn:AlignParentTopRight(4, 4)
        self._unlearn.OnClick = function()
            local index = GetSelectedSkill()
            StaticPopup_Show("UNLEARN_SKILL", (GetSkillLineInfo(index)), nil, index)
        end
    end;

    OnRowClicked = function(self, row)
        if row.isHeader then
            local name = GetSkillLineInfo(row.index)
            self._folded[name] = not self._folded[name] or nil
        else
            SetSelectedSkill(row.index)
        end
        self:Refresh()
    end;

    Refresh = function(self)
        local selected = GetSelectedSkill()
        local shown, folded = 0, false
        for i = 1, GetNumSkillLines() do
            local name, header, _, rank, temp, modifier, maxRank = GetSkillLineInfo(i)
            if header then folded = self._folded[name] == true end
            if header or not folded then
                shown = shown + 1
                local row = self._rows[shown]
                if not row then
                    row = CharacterBarRow(self._scroll.content, self)
                    row:AlignParentTop((shown - 1) * ROW_H)
                    self._rows[shown] = row
                end
                if header then
                    row:SetHeader(i, name, folded)
                elseif maxRank == 1 then
                    -- A proficiency: known or not, nothing to count.
                    row:SetEntry(i, name, 1, 1, "", "", 0.5, 0.5, 0.5, i == selected)
                else
                    local text = rank + temp
                    if modifier > 0 then
                        text = text .. " (|cff20ff20+" .. modifier .. "|r)"
                    elseif modifier < 0 then
                        text = text .. " (|cffff2020" .. modifier .. "|r)"
                    end
                    text = text .. "/" .. maxRank
                    row:SetEntry(i, name, rank, maxRank, text, text, 0.1, 0.2, 0.7, i == selected)
                end
                row:Show()
            end
        end
        for i = shown + 1, #self._rows do
            self._rows[i]:Hide()
        end
        self._scroll:SetContentHeight(shown * ROW_H)
        self:_UpdateDetail(selected)
    end;

    _UpdateDetail = function(self, index)
        local name, header, _, _, _, _, _, abandonable, _, _, _, _, description = GetSkillLineInfo(index)
        if not name or name == "" or header then
            self._name:SetText("")
            self._text:SetText("")
            self._unlearn:Hide()
            return
        end
        self._name:SetText(name)
        self._text:SetText(description or "")
        self._unlearn:SetVisible(abandonable and true or false)
    end;
}
