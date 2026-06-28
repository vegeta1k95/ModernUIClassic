-- UnitFrameTargetAuras: lays out target buffs / debuffs inside the
-- aura container created by UnitFrameTarget. Hooks
-- TargetFrame_UpdateAuras so re-layout happens whenever Blizzard's path
-- ticks (target change, buff add/remove, etc.).
--
-- Source-aware sizing: when `showDynamicBuffSize` is on, auras applied
-- by the player render larger on other players' frames; when the target
-- IS the player, everything is large. Container height grows when ToT
-- is visible and we have a small aura row count, since ToT bleeds into
-- the cast bar's anchor strip otherwise.

local MUI_MAX_BUFFS   = 16
local MUI_MAX_DEBUFFS = 16

local COLS        = 6
local SPACING     = 3
local ROW_SPACING = 4
local ICON_SIZE   = 22

local SCALE_SMALL = 0.70
local SCALE_LARGE = 0.85

-- Lazy cache for the TargetFrameBuff/Debuff globals. Blizzard creates
-- these on demand when the target gains buffs, so a single eager init
-- pass would miss later creations. Each slot fills on first lookup —
-- the next Update for that slot reads the cached refs without paying
-- the global-table + string-concat lookup.
local _buffBtn,   _buffIcon   = {}, {}
local _debuffBtn, _debuffIcon, _debuffCount, _debuffBorder = {}, {}, {}, {}

local function _buff(i)
    local btn = _buffBtn[i]
    if not btn then
        local nativeBtn = _G["TargetFrameBuff" .. i]
        if nativeBtn then
            btn = Frame(nativeBtn)
            _buffBtn[i]  = btn
            local nativeIcon = _G["TargetFrameBuff" .. i .. "Icon"]
            _buffIcon[i] = nativeIcon and Texture(nativeIcon) or nil
        end
    end
    return btn, _buffIcon[i]
end

local function _debuff(i)
    local btn = _debuffBtn[i]
    if not btn then
        local nativeBtn = _G["TargetFrameDebuff" .. i]
        if nativeBtn then
            btn = Frame(nativeBtn)
            _debuffBtn[i]      = btn
            local nativeIcon   = _G["TargetFrameDebuff" .. i .. "Icon"]
            local nativeCount  = _G["TargetFrameDebuff" .. i .. "Count"]
            local nativeBorder = _G["TargetFrameDebuff" .. i .. "Border"]
            _debuffIcon[i]   = nativeIcon   and Texture(nativeIcon)     or nil
            _debuffCount[i]  = nativeCount  and FontString(nativeCount) or nil
            _debuffBorder[i] = nativeBorder and Texture(nativeBorder)   or nil
        end
    end
    return btn, _debuffIcon[i], _debuffCount[i], _debuffBorder[i]
end


class "UnitFrameTargetAuras" {
    __init = function(self, target)
        self.target        = target
        self.auraContainer = target.auraContainer

        hooksecurefunc("TargetFrame_UpdateAuras", function() self:Update() end)
    end;

    Update = function(self)
        -- Dynamic Buff and Debuff Size: when on, auras applied by the player render larger
        -- on other players' target frames. When the target IS the player, everything is large.
        local dynamic      = GetCVarBool and GetCVarBool("showDynamicBuffSize")
        local targetIsSelf = UnitIsUnit("target", "player")
        local function scaleFor(source)
            if targetIsSelf then return SCALE_LARGE end
            if not dynamic then return SCALE_SMALL end
            return (source == "player") and SCALE_LARGE or SCALE_SMALL
        end

        local numBuffs = 0
        for i = 1, MUI_MAX_BUFFS do
            local _, icon, _, _, _, _, source = UnitBuff("target", i)
            local button, iconTex = _buff(i)
            if button then
                if icon then
                    if iconTex then iconTex:SetTexture(icon) end
                    button:Show()
                    button.id = i
                    button._muiSource = source
                    numBuffs = numBuffs + 1
                else
                    button:Hide()
                end
            end
        end

        local numDebuffs = 0
        for i = 1, MUI_MAX_DEBUFFS do
            local _, icon, debuffStack, debuffType, _, _, source = UnitDebuff("target", i)
            local button, iconTex, debuffCount, debuffBorder = _debuff(i)
            if button then
                if icon then
                    if iconTex then iconTex:SetTexture(icon) end
                    local color = (debuffType and DebuffTypeColor and DebuffTypeColor[debuffType])
                                  or (DebuffTypeColor and DebuffTypeColor["none"])
                                  or { r=0.8, g=0, b=0 }
                    if debuffStack and debuffStack > 1 then
                        if debuffCount then debuffCount:SetText(debuffStack); debuffCount:Show() end
                    else
                        if debuffCount then debuffCount:Hide() end
                    end
                    if debuffBorder then
                        debuffBorder:SetVertexColor(color.r, color.g, color.b)
                    end
                    button:Show()
                    button.id = i
                    button._muiSource = source
                    numDebuffs = numDebuffs + 1
                else
                    button:Hide()
                end
            end
        end

        local buffRows   = math.ceil(numBuffs / COLS)
        local debuffRows = math.ceil(numDebuffs / COLS)

        -- Use the larger scale for container sizing so the cast bar anchored Below it doesn't
        -- overlap even when mixed-size rows are present.
        local sizingScale = (targetIsSelf or dynamic) and SCALE_LARGE or SCALE_SMALL
        local totalRows     = buffRows + debuffRows
        local totalSpacings = math.max(totalRows - 1, 0)

        local isToTVisible = TargetFrameToT:IsShown()

        local buffContainerW = COLS * (ICON_SIZE * sizingScale + SPACING)
        local buffContainerH = totalRows * ICON_SIZE * sizingScale
                             + totalSpacings * ROW_SPACING

        if isToTVisible and (totalRows <= 3) then
            buffContainerH = buffContainerH + 40
        end

        self.auraContainer:SetSize(buffContainerW, buffContainerH)

        -- Don't reparent TargetFrameBuff/Debuff* — SetParent marks them addon-modified
        -- and any subsequent Blizzard read (TargetFrame_UpdateAuras) taints the secure
        -- call chain that led us here. Anchor via SetPoint cross-parent instead.

        -- SetPoint offsets are in the positioned frame's own scale, so a uniform
        -- col * (ICON_SIZE + SPACING) collapses the visual gap between mixed-scale
        -- icons. Accumulate x per row in parent coords and divide by each button's
        -- scale at anchor time.
        local rowHeight = ICON_SIZE * sizingScale + ROW_SPACING
        local rowX      = {}
        local buffIdx   = 0
        for i = 1, MUI_MAX_BUFFS do
            local button = _buffBtn[i]
            if button and button:IsShown() then
                local col = mod(buffIdx, COLS)
                local row = math.floor(buffIdx / COLS)
                local s   = scaleFor(button._muiSource)
                if col == 0 then rowX[row] = 0 end
                button:SetScale(s)
                button:SetSize(ICON_SIZE, ICON_SIZE)
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", self.auraContainer, "TOPLEFT",
                    rowX[row] / s,
                    -(row * rowHeight) / s)
                rowX[row] = rowX[row] + ICON_SIZE * s + SPACING
                buffIdx = buffIdx + 1
            end
        end

        local debuffTopOffset = buffRows * rowHeight
        local debuffRowX      = {}
        local debuffIdx       = 0
        for i = 1, MUI_MAX_DEBUFFS do
            local button = _debuffBtn[i]
            if button and button:IsShown() then
                local col = mod(debuffIdx, COLS)
                local row = math.floor(debuffIdx / COLS)
                local s   = scaleFor(button._muiSource)
                if col == 0 then debuffRowX[row] = 0 end
                button:SetScale(s)
                button:SetSize(ICON_SIZE, ICON_SIZE)
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", self.auraContainer, "TOPLEFT",
                    debuffRowX[row] / s,
                    -(debuffTopOffset + row * rowHeight) / s)
                debuffRowX[row] = debuffRowX[row] + ICON_SIZE * s + SPACING
                debuffIdx = debuffIdx + 1
            end
        end
    end;
}
