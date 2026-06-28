-- Reagent display widgets for the tradeskill recipe pane.
--
--   ReagentIcon   — single icon + quality border + hover highlight; wraps a
--                   tooltip dispatcher so the parent can pop the formula /
--                   item link on hover.
--   ReagentRow    — icon + "owned/required name" text line, one per reagent.

local TEX_QUALITY_BORDER = MUI.TEX_SKIN .. "professions\\professions"

class "ReagentIcon" : extends "Frame" {

    _QUALITY_BORDER = {
        [1] = { 675, 1,   39, 39},
        [2] = { 843, 28,  39, 39},
        [3] = { 773, 28,  39, 39},
        [4] = { 1186, 36, 39, 39},
        [5] = { 1144, 36, 39, 39}
    },

    __init = function(self, parentOrNative, name, layer)
        Frame.__init(self, "Frame", parentOrNative, name)

        self._icon = Texture(self, nil, layer)
        self._icon:FillParent()
        self._icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)

        self._qualityBorder = Texture(self, nil, "OVERLAY")
        self._qualityBorder:Fill(self, -2, -2, -2, -2)

        self._hl = Texture(self, nil, "OVERLAY")
        self._hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        self._hl:SetBlendMode("ADD")
        self._hl:Fill(self._icon)
        self._hl:Hide()

        self:EnableMouse(true)
        self:SetScript("OnEnter", function() self._hl:Show() end)
        self:SetScript("OnLeave", function() self._hl:Hide() end)
    end;

    SetTexture = function(self, icon)
        self._icon:SetTexture(icon)
    end;

    SetQuality = function(self, quality)
        quality = quality or 1
        local border = self._QUALITY_BORDER[quality] or self._QUALITY_BORDER[1]
        self._qualityBorder:SetTextureRegion(TEX_QUALITY_BORDER, 2048, 1024,
            border[1], border[2], border[3], border[4])
    end;
}

class "ReagentRow" : extends "Frame" {
    __init = function(self, parent)
        Frame.__init(self, "Frame", parent)
        self:SetSize(160, 36)

        self._icon = ReagentIcon(self, nil, "BACKGROUND")
        self._icon:SetSize(36, 36)
        self._icon:AlignParentLeft()
        self._icon:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            if self._link then tooltip:SetHyperlink(self._link) end
        end)

        self._text = FontString(self, nil, "OVERLAY")
        self._text:SetFontSize(12)
        self._text:RightOf(self._icon, 10)
        self._text:AlignParentRight()
        self._text:SetJustifyH("LEFT")
    end;

    SetData = function(self, iconPath, quality, owned, required, name, link)
        self._icon:SetTexture(iconPath or "")
        self._icon:SetQuality(quality)
        self._link = link
        owned    = owned or 0
        required = required or 0
        local color = (owned < required) and "|cff808080" or "|cffffffff"
        self._text:SetText(color .. owned .. "/" .. required .. " " .. (name or "") .. "|r")
    end;
}
