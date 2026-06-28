local TEX = MUI.TEX_SKIN .. "spellbook\\spellbook-elements"

local preloadTip
local function PreloadSpellTooltip(spellID)
    if not spellID then return end
    if not preloadTip then
        preloadTip = Frame("GameTooltip", nil, "MUI_SpellPreloadTip", "GameTooltipTemplate")
        preloadTip._native:SetOwner(UIParent, "ANCHOR_NONE")
    end
    preloadTip._native:SetSpellByID(spellID)
end

-- One SpellbookItem per group name, reused across re-layouts so we never
-- churn secure frames. Created under `parent` the first time; on later
-- acquires it is reparented to the requested container (out of combat only —
-- SetParent on a secure frame taints, but the in-combat path is pure
-- show/hide of the per-spread containers, never a reparent).
object "SpellbookItemPool" {

    __init = function(self)
        self._items = {}
    end;

    Acquire = function(self, name, parent)
        local item = self._items[name]
        if not item then
            item = SpellbookItem(parent)
            self._items[name] = item
        elseif parent then
            item:SetParent(parent)
        end
        return item
    end;

    Get = function(self, name)
        return self._items[name]
    end;
}

class "SpellButton" : extends "SecureActionButton" {

    __init = function(self, parent)
        SecureActionButton.__init(self, parent)
        self:SetAttribute("type", "spell")

        -- Drag a known, active spell onto the action bars — pick it up to the
        -- cursor on drag-start (mirrors Blizzard's spellbook). Passives and
        -- unlearned spells aren't draggable; pickup is protected in combat,
        -- where bars can't be rearranged anyway.
        self:RegisterForDrag("LeftButton")
        self:SetScript("OnDragStart", function()
            local spell = self._spell
            if spell and spell.isKnown and not spell.isPassive
               and spell.spellID and not InCombatLockdown() then
                PickupSpell(spell.spellID)
            end
        end)

        -- Hover glow.
        local hl = self:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        hl:SetBlendMode("ADD")

        -- Push feedback: the icon is this button's NormalTexture, so a real
        -- PushedTexture would hide it — overlay a depress texture on press.
        self._pushTex = Texture(self, nil, "OVERLAY")
        self._pushTex:FillParentPadding(-1, -1, -1, -1)
        self._pushTex:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
        self._pushTex:Hide()
        self:SetScript("OnMouseDown", function() if not self._spell.isPassive then self._pushTex:Show() end end)
        self:SetScript("OnMouseUp",   function() self._pushTex:Hide() end)
        -- OnMouseUp only fires if released over the button; clear on leave too
        -- so a press-then-drag-off doesn't leave the depress stuck on.
        self:SetScript("OnLeave",     function() self._pushTex:Hide() end)

        -- Cooldown radial sweep + timer. Reading/setting a cooldown isn't
        -- protected, so this stays valid in combat. Refresh on show (a swipe
        -- that started while the book was hidden) and on cooldown events.
        self._cooldown = Cooldown(self)
        self._cooldown:FillParentPadding(1, 0, 1, 0)
        self:SetScript("OnShow", function() self:_UpdateCooldown() end)
        self:RegisterEventHandler("SPELL_UPDATE_COOLDOWN", function()
            if self:IsVisible() then self:_UpdateCooldown() end
        end)
    end;

    _UpdateCooldown = function(self)
        local spell = self._spell
        if spell and spell.isKnown and spell.spellID then
            local info = C_Spell.GetSpellCooldown(spell.spellID)
            if info then
                self._cooldown:SetCooldown(info.startTime, info.duration, info.isEnabled)
                return
            end
        end
        self._cooldown:Clear()
    end;

    SetSpell = function(self, spell, cutBorder)
        self._spell = spell
        self:_UpdateCooldown()

        local icon = spell.icon
        if not icon and spell.spellID then
            local _, _, ic = GetSpellInfo(spell.spellID)
            icon = ic
        end
        icon = MUI_IconOverrides:GetOverride(spell.spellID) or icon

        local tex = self:SetNormalTexture(icon)
        tex:SetDesaturated(not spell.isKnown)
        tex:SetAlpha(spell.isKnown and 1.0 or 0.6)
        tex:SetTexCoord(0.04, 0.96, 0.04, 0.96)

        if spell.isPassive then
            tex:SetPortrait(icon)
            self:GetHighlightTexture():SetPortrait("Interface\\Buttons\\ButtonHilight-Square")
        end

        PreloadSpellTooltip(spell.spellID)

        local name = spell.name .. "(" .. spell.rank .. ")"
        self:SetAttribute("spell", name)
        self:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            if spell.spellID then
                tooltip:SetSpellByID(spell.spellID)
            elseif spell.source == "talent" then
                tooltip:SetTalent(spell.talentID, false)
            end

            -- Rank on the right of the first line (SetSpellByID fills only the
            -- left column with the name).
            if spell.rank and spell.rank ~= "" then
                tooltip:SetLineRight(1, spell.rank, 0.6, 0.6, 0.6)
            end

            if not spell.isKnown then
                tooltip:AddBlank()
                if spell.source == "talent" then
                    tooltip:AddLine("Talent at level |cffFFFFFF" .. spell.levelReq .. "|cff00ff00", 0, 1, 0, false, 10.5)
                elseif spell.source == "quest" then
                    tooltip:AddLine("Quest at level |cffFFFFFF" .. spell.levelReq .. "|cff00ff00", 0, 1, 0, false, 10.5)
                else
                    tooltip:AddLine("Learned at level |cffFFFFFF" .. spell.levelReq .. "|cff00ff00", 0, 1, 0, false, 10.5)
                end
            end
        end)

    end;

}

class "SpellbookSpecHeader" : extends "Frame" {

    __init = function(self, parent, name)
        Frame.__init(self, "Frame", parent, name)

        self:FillWidth()
        self:SetHeight(64)

        self._separator = Texture(self, nil, "ARTWORK")
        self._separator:SetTextureRegion(TEX, 1024, 1024, 255, 421, 658, 11)
        self._separator:AlignParentLeft(7)
        self._separator:AlignParentRight(45)
        self._separator:AlignParentBottom(7)
        self._separator:SetHeight(10)

        self._icon = Texture(self, nil, "ARTWORK")
        self._icon:Above(self._separator, 13)
        self._icon:AlignParentLeft(39)
        self._icon:SetWidth(0.1)
        self._icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")

        self._iconBorder = Texture(self, nil, "OVERLAY")
        self._iconBorder:SetTextureRegion(MUI.TEX_SKIN .. "talents\\talents-hero", 2048, 1024, 405, 825, 160, 160)
        self._iconBorder:Fill(self._icon, -8, -8, -8, -8)
        self._iconBorder:Hide()

        self._name = FontString(self)
        self._name:RightOf(self._icon, 10)
        self._name:Above(self._separator, 15)
        self._name:SetFont(MUI.FONT, 22, "")
        self._name:SetTextColor(0.141, 0.118, 0.078, 1)

        self._glow = Texture(self, nil, "BACKGROUND")
        self._glow:SetTextureRegion(TEX, 1024, 1024, 24, 326, 224, 70)
        self._glow:AlignLeft(self._name, -40)
        self._glow:Above(self._separator, -4)
        self._glow:SetSize(260, 66)
        self._glow:SetAlpha(0.6)

    end;

    SetText = function(self, text)
        self._name:SetText(text)
    end;

    SetIcon = function(self, icon)
        if icon then
            self._icon:Show()
            self._icon:SetSize(28, 28)
            self._icon:SetTexture(icon)
            self._iconBorder:Show()
            self._name:RightOf(self._icon, 10)
        else
            self._icon:Hide()
            self._icon:SetSize(0.1, 28)
            self._iconBorder:Hide()
            self._name:AlignParentLeft(29)
        end
    end;
}

class "SpellbookRankGroup" : extends "SecureFrame" {

    _ICON_SIZE = 25;
    _ICON_PADDING = 6;

    __init = function(self, parent, name)
        SecureFrame.__init(self, parent, name)
        self._border = NineSlice(self)
        self._border:FillParent()
        self._border:SetFromAtlas(MUI_AtlasRegistry.Dropdown, "Bg", 34, 30, 64, 50, 0.20)
        self._border:SetAlpha(0.7)
        self._border:EnableMouse(true)

        self._spells = {}

        self:SetHeight(44)
        self:EnableMouse(true)
    end;

    SetGroup = function(self, group)
        local spells = group:GetSpells()

        -- Walk from the end: known spells add their trainer requirement string
        -- (spellReq) to a pool. An UNKNOWN spell whose name AND rank both occur
        -- in some pooled spellReq is the prereq of a known spell — a replaced
        -- lower rank — so skip it. Unrelated spells in a conflated group (e.g.
        -- different portals) never match another's spellReq, so they stay.
        local pool, keep = {}, {}
        for i = #spells, 1, -1 do
            local spell = spells[i]
            keep[i] = true
            if not spell.isKnown and spell.name and spell.rank then
                for _, req in ipairs(pool) do
                    if string.find(req, spell.name, 1, true) and string.find(req, spell.rank, 1, true) then
                        keep[i] = false
                        break
                    end
                end
            end
            -- Add to the pool for known spells AND just-removed ones, so an
            -- obsolete rank's own prereq keeps the chain going downward.
            if (spell.isKnown or not keep[i]) and spell.spellReq then
                table.insert(pool, spell.spellReq)
            end
        end

        local count = 0
        for i = 1, #spells do
            if keep[i] then
                count = count + 1
                self:_SetSpell(count, spells[i])
            end
        end
        self._count = count

        -- Hide buttons left from a previously longer group (pooled reuse, or a
        -- rank that just became obsolete).
        for i = count + 1, #self._spells do
            self._spells[i]:Hide()
        end

        self:_Relayout()
        return count
    end;

    _SetSpell = function(self, index, spell)
        local button = self._spells[index]
        if not button then
            button = SpellButton(self)
            button:SetSize(self._ICON_SIZE, self._ICON_SIZE)
            button:PutInfront(self._border, 3)

            local border = Texture(button, nil, "OVERLAY")
            border:FillParentPadding(-2, -2, -2, -2)
            border:SetTextureRegion(MUI.TEX_SKIN .. "talents\\talents", 2048, 1024, 1005, 819, 80, 80)

            self._spells[index] = button
        end
        button:SetSpell(spell)
    end;

    _Relayout = function(self)
        -- Stack the visible rank buttons left-to-right, padded; AlignParentLeft
        -- / RightOf anchor on the LEFT point so they stay vertically centered.
        local pad = self._ICON_PADDING
        local count = self._count or 0
        local prev = nil
        for i = 1, count do
            local btn = self._spells[i]
            btn:Show()
            btn:ClearAllPoints()
            if prev then
                btn:RightOf(prev, pad)
            else
                btn:AlignParentLeft(11, 1)
            end
            prev = btn
        end
        self:SetWidth(count * self._ICON_SIZE + (count + 1) * pad + 8)
    end;

}

class "SpellbookItem" : extends "SecureFrame" {

    _ITEM_H    = 60;
    _ITEM_W    = 209;
    _ICON_SIZE = 28;

    __init = function(self, parent, name)
        SecureFrame.__init(self, parent, name)

        self:SetSize(self._ITEM_W, self._ITEM_H)

        self._actionButton = SpellButton(self)
        self._actionButton:AlignParentLeft()
        self._actionButton:HookScript("OnEnter", function()
            self._bg:SetAlpha(1.0)
        end)
        self._actionButton:HookScript("OnLeave", function()
            self._bg:SetAlpha(0.3)
        end)

        self._bg = Texture(self, nil, "BACKGROUND")
        self._bg:SetTextureRegion(TEX, 1024, 1024, 313, 314, 256, 64)
        self._bg:SetPoint("LEFT", self._actionButton, "CENTER", -20, -2)
        self._bg:SetSize(200, 54)
        self._bg:SetAlpha(0.3)

        self._textGroup = Frame("Frame", self)
        self._textGroup:RightOf(self._actionButton, 12)
        self._textGroup:AlignParentRight(14)

        self._displayName = FontString(self._textGroup)
        self._displayName:SetFont(MUI.FONT, 14, "")
        self._displayName:SetJustifyH("LEFT")
        self._displayName:SetJustifyV("MIDDLE")
        self._displayName:SetTextColor(0.141, 0.118, 0.078, 1)
        self._displayName:AlignParentTopLeft()
        self._displayName:SetWidth(self._ITEM_W - self._ICON_SIZE - 14 - 12)
        self._displayName:SetWordWrap(true)

        self._displayRank = FontString(self._textGroup)
        self._displayRank:SetFont(MUI.FONT, 10.5, "")
        self._displayRank:SetJustifyH("LEFT")
        self._displayRank:SetTextColor(0.141, 0.118, 0.078, 1)
        self._displayRank:FillWidth()
        self._displayRank:Below(self._displayName, 1)
        self._displayRank:SetHeight(0)

        self._iconBg = Texture(self._actionButton, nil, "BACKGROUND")
        self._iconFrame = Texture(self._actionButton, nil, "OVERLAY")
        self._iconFrame:SetDrawLayer("OVERLAY", 2)

        self._expandGroup = SpellbookRankGroup(self)
        self._expandGroup:RightOf(self._actionButton, -1, -1)
        self._expandGroup:Hide()

        self._expand = SecureButton(self)
        self._expand:SetNormalTexture(MUI.TEX_SKIN .. "bags\\expand")
        self._expand:SetHighlightTexture(MUI.TEX_SKIN .. "bags\\expand")
        self._expand:SetSize(12, 14)
        self._expand:RightOf(self._actionButton, -1)
        self._expand:PutInfront(self._expandGroup, 3)
        self._expand:SetFrameRef("group", self._expandGroup)
        self._expand:SetOnClick([[ -- (self)
            if group:IsShown() then
                group:Hide()
            else
                group:Show()
            end
        ]])
        self._expand:HookScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            if self._expandGroup:IsShown() then
                self._expand:GetNormalTexture():SetRotation(math.pi)
                self._expand:GetHighlightTexture():SetRotation(math.pi)
            else
                self._expand:GetNormalTexture():SetRotation(0)
                self._expand:GetHighlightTexture():SetRotation(0)
            end
        end)
        self._expand:Hide()

    end;

    SetSpell = function(self, group)

        local name = group:GetName()
        local isKnown = group:IsKnown()

        local display
        if isKnown then
            display = group:GetLastKnown()
        else
            display = group:GetDisplayRank()
        end

        self._actionButton:SetSpell(display)
        self._displayName:SetText(name)

        if not isKnown then
            local source

            if display.source == "quest" then
                source = "Quest"
            elseif display.source == "talent" then
                source = "Talent"
            elseif display.source == "trainer" then
                source = "Trainer"
            end

            local sub  = "Level " .. display.levelReq .. " (" .. source .. ")"
            self._displayRank:SetText(sub)
        elseif not display.spec then
            self._displayRank:SetText(display.rank or nil)
        end

        self._textGroup:SetHeight(self._displayName:GetStringHeight() + self._displayRank:GetStringHeight() + 1)

        if display.isPassive then
            self._actionButton:SetSize(self._ICON_SIZE + 2, self._ICON_SIZE + 2)
            self._iconBg:ClearAllPoints()
            self._iconBg:FillParentPadding(0, 0, 0, 0)
            self._iconBg:SetTextureRegion(TEX, 1024, 1024, 144, 425, 105, 108)
        else
            self._actionButton:SetSize(self._ICON_SIZE + 2, self._ICON_SIZE + 2)
            self._iconBg:ClearAllPoints()
            self._iconBg:FillParentPadding(-12, -5, -5, -9)
            self._iconBg:SetTextureRegion(TEX, 1024, 1024, 0, 421, 138, 128)
        end

        self._displayName:SetAlpha(isKnown and 1.0 or 0.5)
        self._displayRank:SetAlpha(isKnown and 1.0 or 0.5)

        if isKnown then
            if display.isPassive then
                self._iconFrame:ClearAllPoints()
                self._iconFrame:FillParentPadding(-2.5, -2.5, -2, -2)
                self._iconFrame:SetTextureRegion(TEX, 1024, 1024, 273, 453, 50, 50)
            else
                self._iconFrame:ClearAllPoints()
                self._iconFrame:FillParentPadding(-12, -4, -5.5, -9)
                self._iconFrame:SetTextureRegion(TEX, 1024, 1024, 877, 141, 138, 128)
            end
        else
            if display.isPassive then
                self._iconFrame:ClearAllPoints()
                self._iconFrame:FillParentPadding(-2.5, -2.5, -2, -2)
                self._iconFrame:SetTextureRegion(TEX, 1024, 1024, 143, 540, 105, 108)
            else
                self._iconFrame:ClearAllPoints()
                self._iconFrame:FillParentPadding(-12, -5, -5, -9)
                self._iconFrame:SetTextureRegion(TEX, 1024, 1024, 0, 553, 138, 128)
            end
        end

        if group:GetTotalRanks() > 1 and self._expandGroup:SetGroup(group) > 1 then
            self._expand:Show()
        else
            self._expand:Hide()
        end

    end;


}