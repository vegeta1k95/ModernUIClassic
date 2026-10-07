-- MUI_CharacterPet: the Pet tab — the pet's model where the character's
-- stands, with its level and loyalty in the strip under the title, its
-- happiness, experience and training points under the model, and its stat
-- sheet in the side pane.

local HAPPINESS = "Interface\\PetPaperDollFrame\\UI-PetHappiness"

-- The pet's sheet, as CharacterStatSheet takes it.
local SECTIONS = {
    { "Attributes", {
        { "Attribute", 1 }, { "Attribute", 2 }, { "Attribute", 3 }, { "Attribute", 4 }, { "Attribute", 5 },
    } },
    { "Combat", {
        { "Damage" }, { "AttackPower" }, { "Attack" }, { "Armor" }, { "Defense" },
    } },
    { "Resistances", {
        { "Resistance", 6 }, { "Resistance", 2 }, { "Resistance", 3 }, { "Resistance", 4 }, { "Resistance", 5 },
    } },
}

-- The happiness face, by GetPetHappiness: unhappy, content, happy.
local FACES = {
    { 0.375,  0.5625, 0, 0.359375 },
    { 0.1875, 0.375,  0, 0.359375 },
    { 0,      0.1875, 0, 0.359375 },
}

local EVENTS = {
    "UNIT_PET", "PET_UI_UPDATE", "PET_BAR_UPDATE", "UNIT_PET_EXPERIENCE", "UNIT_PET_TRAINING_POINTS",
    "UNIT_HAPPINESS", "UNIT_LEVEL", "UNIT_NAME_UPDATE",
}

class "CharacterPetPane" : extends "CharacterPane" {

    wide = true,

    __init = function(self, window)
        CharacterPane.__init(self, window)

        self:_BuildStage()
        self:_BuildFooter()
        self:_BuildLevelText()

        local side = Frame("Frame", self)
        side:Fill(window.insetRight, 3, 3, 3, 2)
        self._stats = CharacterStatSheet(side, "pet", SECTIONS, false)

        self:HookScript("OnShow", function() self:Refresh() end)
        for _, event in ipairs(EVENTS) do
            self:RegisterEventHandler(event, function()
                if self:IsVisible() then self:Refresh() end
            end)
        end
    end;

    GetTitle = function(self)
        return UnitName("pet") or PET, 1, 1, 1
    end;

    GetPortrait = function(self)
        return "pet"
    end;

    -- The model, on a dark stage inside the inset.
    _BuildStage = function(self)
        local stage = Frame("Frame", self)
        stage:FillParentPadding(6, 6, 6, 60)
        stage:SetClipsChildren(true)
        local shade = Texture(stage, nil, "BACKGROUND")
        shade:SetColorTexture(0, 0, 0, 0.55)
        shade:FillParent()
        self.model = CharacterModel(stage, "MUI_CharacterPetModel", "pet", 0.35)
    end;

    -- Under the model: the happiness face, the experience bar, the training
    -- points. A pet that gains no experience (a warlock's) has none of them.
    _BuildFooter = function(self)
        local footer = Frame("Frame", self)
        footer:SetHeight(48)
        footer:AlignParentBottomLeft(6, 6)
        footer:AlignParentBottomRight(6, 6)
        self._footer = footer

        self._face = Frame("Frame", footer)
        self._face:SetSize(24, 23)
        self._face:AlignParentTopLeft(2, 4)
        self._faceArt = Texture(self._face, nil, "ARTWORK")
        self._faceArt:SetTexture(HAPPINESS)
        self._faceArt:FillParent()
        self._face:SetTooltip("ANCHOR_RIGHT", function(tooltip) self:_BuildHappinessTooltip(tooltip) end)

        self._xp = StatusBar(footer)
        self._xp:SetHeight(11)
        self._xp:AlignParentTopLeft(8, 38)
        self._xp:AlignParentTopRight(8, 6)
        self._xp:SetStatusBarColor(0.58, 0, 0.55)
        local edge = Frame("Frame", self._xp, nil, "ThinGoldEdgeTemplate")
        edge:FillParentPadding(-3, -3, -3, -3)
        self._xpText = FontString(edge, nil, "OVERLAY")
        self._xpText:SetFontSize(9)
        self._xpText:SetTextColor(1, 1, 1, 1)
        self._xpText:CenterInParent()

        self._points = FontString(footer, nil, "ARTWORK")
        self._points:SetFontSize(10)
        self._points:SetTextColor(1, 0.82, 0, 1)
        self._points:AlignParentBottomRight(4, 6)
    end;

    -- "Level 60 Cat", and a hunter pet's loyalty under it.
    _BuildLevelText = function(self)
        self._level = FontString(self, nil, "ARTWORK")
        self._level:SetFontSize(11)
        self._level:SetTextColor(1, 0.82, 0, 1)
        self._level:SetSize(260, 24)

        self._loyalty = FontString(self, nil, "ARTWORK")
        self._loyalty:SetFontSize(10)
        self._loyalty:SetTextColor(1, 0.82, 0, 1)
        self._loyalty:Below(self._level, -6)
    end;

    _BuildHappinessTooltip = function(self, tooltip)
        local happiness, damage, loyaltyRate = GetPetHappiness()
        if not happiness then return end
        tooltip:AddLine(getglobal("PET_HAPPINESS" .. happiness), 1, 1, 1, false, 13)
        tooltip:AddLine(PET_DAMAGE_PERCENTAGE:format(damage), 1, 0.82, 0, true)
        if loyaltyRate < 0 then
            tooltip:AddLine(LOSING_LOYALTY, 1, 0.82, 0, true)
        elseif loyaltyRate > 0 then
            tooltip:AddLine(GAINING_LOYALTY, 1, 0.82, 0, true)
        end
    end;

    Refresh = function(self)
        local hasPet, gainsExperience = HasPetUI()
        if not hasPet then return end
        self.model:Refresh()

        local family = UnitCreatureFamily("pet")
        local text = UNIT_LEVEL_TEMPLATE:format(UnitLevel("pet"))
        if family then text = text .. " " .. family end
        self._level:SetText(text)
        local loyalty = gainsExperience and GetPetLoyalty() or nil
        self._loyalty:SetText(loyalty or "")
        self._loyalty:SetVisible(loyalty ~= nil)
        self._level:ClearAllPoints()
        self._level:AlignTop(self.window.canvas, loyalty and 24 or 30)

        self._footer:SetVisible(gainsExperience and true or false)
        if gainsExperience then
            local happiness = GetPetHappiness()
            local face = FACES[happiness or 2]
            self._faceArt:SetTexCoord(face[1], face[2], face[3], face[4])

            local current, needed = GetPetExperience()
            self._xp:SetVisible(needed > 0)
            self._xp:SetMinMaxValues(0, math.max(needed, 1))
            self._xp:SetValue(current)
            self._xpText:SetText(current .. " / " .. needed)

            local total, spent = GetPetTrainingPoints()
            self._points:SetText(TRAINING_POINTS .. " " .. (total - spent))
        end
    end;
}
