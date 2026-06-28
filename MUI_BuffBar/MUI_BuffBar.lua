local BUFF_WIDTH = 29
local BUFF_HEIGHT = 29
local BUFF_SCALE = 0.95

local PADDING_HORIZONTAL = 5
local PADDING_VERTICAL = 14
-- Retail capacities: 32 buffs at 11 per row (3 rows), 16 debuffs at 8 per row
-- (2 rows). Each bar is fixed to its full grid so the editable box never resizes.
local BUFFS_PER_ROW = 11
local DEBUFFS_PER_ROW = 8

-- Pixel size of a `perRow` × ceil(maxCount/perRow) icon grid.
local function GridSize(perRow, maxCount)
    local cols = math.min(maxCount, perRow)
    local rows = math.ceil(maxCount / perRow)
    return BUFF_WIDTH * cols + PADDING_HORIZONTAL * (cols - 1),
           BUFF_HEIGHT * rows + PADDING_VERTICAL * (rows - 1)
end

local function CollectButtons()
    local buffs, debuffs = {}, {}
    for i = 1, BUFF_MAX_DISPLAY or 32 do
        local btn = getglobal("BuffButton" .. i)
        if btn then table.insert(buffs, btn) end
    end
    for i = 1, DEBUFF_MAX_DISPLAY or 16 do
        local btn = getglobal("DebuffButton" .. i)
        if btn then table.insert(debuffs, btn) end
    end
    return buffs, debuffs
end

object "ModuleBuffBar" : extends "Module" {
    __init = function(self)
        Module.__init(self, "BuffBar")

        self._visible = true

        -- Buffs and debuffs are independent editable frames, each pinned by its
        -- TOP-RIGHT corner and fixed to its full grid size, so auras always fill
        -- from the same top-right origin and the editable box never resizes.
        self.buffFrame = EditableFrame("Frame", "Buff Bar", nil, "MUI_BuffBar")
        self.buffFrame:SetSize(GridSize(BUFFS_PER_ROW, BUFF_MAX_DISPLAY or 32))
        self.buffFrame:EditModeSetDragAnchor("TOPRIGHT")
        self.buffFrame:LeftOf(MUI_Minimap, 56)
        self.buffFrame:AlignTop(MUI_Root, 10)
        self.buffFrame:EditModeSetDefaultPosition(function(f)
            f:ClearAllPoints()
            f:LeftOf(MUI_Minimap, 56)
            f:AlignTop(MUI_Root, 10)
        end)

        self.debuffFrame = EditableFrame("Frame", "Debuff Bar", nil, "MUI_DebuffBar")
        self.debuffFrame:SetSize(GridSize(DEBUFFS_PER_ROW, DEBUFF_MAX_DISPLAY or 16))
        self.debuffFrame:EditModeSetDragAnchor("TOPRIGHT")
        self.debuffFrame:Below(self.buffFrame, 8)
        self.debuffFrame:AlignRight(self.buffFrame)
        self.debuffFrame:EditModeSetDefaultPosition(function(f)
            f:ClearAllPoints()
            f:Below(self.buffFrame, 8)
            f:AlignRight(self.buffFrame)
        end)

        self:CreateToggleButton()
    end;

    OnEnable = function(self)
        self:ApplyLayout()

        -- Blizzard re-anchors buttons on aura change; re-apply our layout after.
        hooksecurefunc("BuffFrame_UpdateAllBuffAnchors", function()
            self:ApplyLayout()
        end)
        hooksecurefunc("DebuffButton_UpdateAnchors", function()
            self:ApplyLayout()
        end)
    end;

    CreateToggleButton = function(self)

        local TEX = MUI.TEX_SKIN .. "bags\\expand"

        self.toggleBtn = Button(nil, "MUI_BagToggleButton")
        self.toggleBtn:SetSize(20, 20)
        self.toggleBtn:SetScale(0.75)
        self.toggleBtn:RightOf(self.buffFrame, -2)
        self.toggleBtn:AlignTop(self.buffFrame, 6)
        self.toggleBtn:SetNormalTexture(TEX)
        self.toggleBtn:SetPushedTexture(TEX)
        self.toggleBtn:SetHighlightTexture(TEX)
        self.toggleBtn.OnClick = function()
        
            local normalT = self.toggleBtn:GetNormalTexture()
            local hlT = self.toggleBtn:GetHighlightTexture()
            local pushedT = self.toggleBtn:GetPushedTexture()

            self._visible = not self._visible

            if self._visible then
                self.buffFrame:Show()

                if normalT then normalT:SetTexCoord(0, 1, 0, 1) end
                if hlT then hlT:SetTexCoord(0, 1, 0, 1) end
                if pushedT then pushedT:SetTexCoord(0, 1, 0, 1) end

            else
                self.buffFrame:Hide()

                if normalT then normalT:SetTexCoord(1, 0, 0, 1) end
                if hlT then hlT:SetTexCoord(1, 0, 0, 1) end
                if pushedT then pushedT:SetTexCoord(1, 0, 0, 1) end

            end
        end
    end;

    -- Anchor one aura into its grid. Blizzard wraps using its own per-row count,
    -- which doesn't match ours, so we place every icon explicitly: chain
    -- RIGHT→LEFT within a row, TOPRIGHT→BOTTOMRIGHT to the row-start above on
    -- each row break. `list` is the native-button array; `parentFrame` is the
    -- fixed-size bar the icon's origin (top-right) sits in.
    AnchorAuraButton = function(self, button, list, i, parentFrame, perRow)
        button:SetParent(parentFrame)
        button:SetSize(BUFF_WIDTH, BUFF_HEIGHT)
        button:SetScale(BUFF_SCALE)
        button:ClearAllPoints()

        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)
        if col == 0 then
            if row == 0 then
                button:AlignParentTopRight()
            else
                local rowStart = list[(row - 1) * perRow + 1]
                button:SetPoint("TOPRIGHT", rowStart, "BOTTOMRIGHT", 0, -PADDING_VERTICAL)
            end
        else
            button:SetPoint("RIGHT", list[i - 1], "LEFT", -PADDING_HORIZONTAL, 0)
        end
    end;

    ApplyLayout = function(self)
        local buffs, debuffs = CollectButtons()

        for i, btn in ipairs(buffs) do
            local button = Frame(btn)
            self:AnchorAuraButton(button, buffs, i, self.buffFrame, BUFFS_PER_ROW)

            local duration = getglobal(button:GetName() .. "Duration")
            if duration then
                FontString(duration):SetFontSize(9)
            end
        end

        for i, btn in ipairs(debuffs) do
            local button = Frame(btn)
            self:AnchorAuraButton(button, debuffs, i, self.debuffFrame, DEBUFFS_PER_ROW)

            local duration = getglobal(button:GetName() .. "Duration")
            if duration then
                local fs = FontString(duration)
                fs:SetFontSize(9)
                fs:ClearAllPoints()
                fs:AlignBottom(button, -12)
            end
        end

        -- Hide the collapse toggle when there's nothing to collapse.
        -- `buffs` counts EXISTING BuffButtonN frames, not active auras —
        -- Blizzard keeps the frame around for the session and just :Hide()s
        -- it when the slot empties. Count visible buttons instead so the
        -- toggle disappears the moment the last buff drops.
        local activeBuffs = 0
        for _, btn in ipairs(buffs) do
            if btn:IsShown() then activeBuffs = activeBuffs + 1 end
        end
        if activeBuffs > 0 then
            self.toggleBtn:Show()
        else
            self.toggleBtn:Hide()
        end
    end;
}
