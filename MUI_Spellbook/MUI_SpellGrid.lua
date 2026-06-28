local TEX = MUI.TEX_SKIN .. "talents\\talents"

SPEC_HAZE_COLORS = {
	[1]  = {{0.000, 0.800, 1.000}, {1.000, 0.600, 0.000}, {1.000, 0.240, 0.000}},  -- Arms, Fury, Protection
	[2]  = {{1.000, 1.000, 0.000}, {1.000, 0.230, 0.000}, {1.000, 0.800, 0.000}},  -- Holy, Protection, Retribution
	[3]  = {{0.000, 0.500, 1.000}, {1.000, 1.000, 0.000}, {1.000, 0.300, 0.000}},  -- Beast Mastery, Marksmanship, Survival
	[4]  = {{0.400, 1.000, 0.000}, {0.000, 0.800, 1.000}, {0.540, 0.000, 1.000}},  -- Assassination, Combat, Subtlety
	[5]  = {{0.000, 0.750, 1.000}, {1.000, 1.000, 0.000}, {0.637, 0.000, 1.000}},  -- Discipline, Holy, Shadow
	[7]  = {{1.000, 0.500, 0.000}, {0.300, 0.170, 1.000}, {0.000, 1.000, 0.600}},  -- Elemental, Enhancement, Restoration
	[8]  = {{0.850, 0.545, 1.000}, {1.000, 0.350, 0.000}, {0.000, 0.350, 1.000}},  -- Arcane, Fire, Frost
	[9]  = {{0.620, 0.420, 1.000}, {0.860, 0.170, 0.110}, {1.000, 0.700, 0.000}},  -- Affliction, Demonology, Destruction
	[11] = {{0.350, 0.000, 1.000}, {1.000, 0.100, 0.150}, {0.000, 1.000, 0.000}},  -- Balance, Feral Combat, Restoration
}

class "SpellGridSlot" : extends "Button" {

    __init = function(self, parent, name, passive)
        Button.__init(self, parent, name)

        self:SetSize(40, 40)
        -- Both buttons; left = stage learn (preview +1), right = unstage (-1)
        self:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        -- 0 -- unavailable
        -- 1 -- locked
        -- 2 -- known
        -- 3 -- available
        self._state = 0
        self._isNext = false

        self._isPassive = passive or false

        self._halo = Texture(self, nil, "BACKGROUND")
        self._halo:SetTexture(MUI.TEX_SKIN .. "talents\\talent-glow")
        self._halo:FillParent(-30)
        self._halo:SetVertexColor(0, 0, 0, 1)

        self._bg = Texture(self, nil, "BACKGROUND")
        self._bg:FillParent()
        self._bg:SetDrawLayer("BACKGROUND", 1)

        self._bgHl = Texture(self, nil, "HIGHLIGHT")
        self._bgHl:FillParent()
        self._bgHl:SetBlendMode("ADD")
        self._bgHl:SetAlpha(0.15)

        self._border = Texture(self, nil, "OVERLAY")
        self._border:FillParent()

        self._hl = Texture(self, nil, "HIGHLIGHT")
        self._hl:FillParent()
        self._hl:SetBlendMode("ADD")
        self._hl:SetAlpha(0.6)

        self._icon = Texture(self, nil, "ARTWORK")
        self._icon:FillParent(2)
        self:SetIcon("Interface\\Icons\\Spell_Holy_CrusaderStrike")


        self._label = FontString(self)
        self._label:AlignParentBottomRight(3, 2)
        self._label:SetFont(MUI.FONT, 14, "THICKOUTLINE")
        self._label:SetJustifyH("RIGHT")
        self._label:SetTextColor(1, 1, 0, 1)

        self:_RefreshVisual()

    end;

    IsPassive = function(self)
        return self._isPassive
    end;

    SetIsNext = function(self, isNext)
        self._isNext = isNext
        self:_RefreshVisual()
    end;

    SetHalo = function(self, r, g, b, a)
        self._halo:SetVertexColor(r, g, b, a)
    end;

    SetLabel = function(self, text)
        self._label:SetText(text)
    end;

    SetLabelColor = function(self, r, g, b, a)
        self._label:SetTextColor(r, g, b, a)
    end;

    SetIcon = function(self, icon)
        if self._isPassive then
            self._icon:SetPortrait(icon)
        else
            self._icon:SetTexture(icon)
        end
    end;

    SetIconTint = function(self, r, g, b, a)
        self._icon:SetVertexColor(r, g, b, a)
    end;

    SetIconDesaturated = function(self, desaturated)
        self._icon:SetDesaturated(desaturated)
    end;

    SetState = function(self, state)
        self._state = state
        self:_RefreshVisual()

        if self._state == 0 then
            self._bgHl:SetAlpha(0.15)
        else
            self._bgHl:SetAlpha(0.0)
        end
    end;

    GetState = function(self)
        return self._state
    end;

    SetPassive = function(self, passive)
        self._isPassive = passive
        self:_RefreshVisual()
    end;

    _RefreshVisual = function(self)

        if self._isPassive then

            self._bg:SetTexture(MUI.TEX_SKIN .. "talents\\talent-socket-circle")
            self._bgHl:SetTexture(MUI.TEX_SKIN .. "talents\\talent-socket-circle")

            if self._isNext then
                self._border:SetTextureRegion(TEX, 2048, 1024, 1636, 182, 50, 50)
                self._hl:SetTextureRegion(TEX, 2048, 1024, 1636, 182, 50, 50)
            elseif self._state == 0 then
                self._border:SetTextureRegion(TEX, 2048, 1024, 219, 569, 50, 50)
                self._hl:SetTextureRegion(TEX, 2048, 1024, 219, 569, 50, 50)
            elseif self._state == 1 then
                self._border:SetTextureRegion(TEX, 2048, 1024, 219, 569, 50, 50)
                self._hl:SetTextureRegion(TEX, 2048, 1024, 219, 569, 50, 50)
            elseif self._state == 2 then
                self._border:SetTextureRegion(TEX, 2048, 1024, 1389, 110, 50, 50)
                self._hl:SetTextureRegion(TEX, 2048, 1024, 1389, 110, 50, 50)
            elseif self._state == 3 then
                self._border:SetTextureRegion(TEX, 2048, 1024, 219, 621, 50, 50)
                self._hl:SetTextureRegion(TEX, 2048, 1024, 219, 621, 50, 50)
            end
        else

            self._bg:SetTexture(MUI.TEX_SKIN .. "talents\\talent-socket-square")
            self._bgHl:SetTexture(MUI.TEX_SKIN .. "talents\\talent-socket-square")

            if self._isNext then
                self._border:SetTextureRegion(TEX, 2048, 1024, 1176, 750, 80, 80)
                self._hl:SetTextureRegion(TEX, 2048, 1024, 11176, 750, 80, 80)
            elseif self._state == 0 then
                self._border:SetTextureRegion(TEX, 2048, 1024, 1005, 819, 80, 80)
                self._hl:SetTextureRegion(TEX, 2048, 1024, 1005, 819, 80, 80)
            elseif self._state == 1 then
                self._border:SetTextureRegion(TEX, 2048, 1024, 1005, 819, 80, 80)
                self._hl:SetTextureRegion(TEX, 2048, 1024, 1005, 819, 80, 80)
            elseif self._state == 2 then
                self._border:SetTextureRegion(TEX, 2048, 1024, 1094, 750, 80, 80)
                self._hl:SetTextureRegion(TEX, 2048, 1024, 1094, 750, 80, 80)
            elseif self._state == 3 then
                self._border:SetTextureRegion(TEX, 2048, 1024, 1005, 901, 80, 80)
                self._hl:SetTextureRegion(TEX, 2048, 1024, 1005, 901, 80, 80)
            end
        end

        self._icon:SetDesaturated(self._state <= 1)
        self._border:SetDesaturated(self._state <= 1)
        self._bg:SetDesaturated(self._state <= 1)
        self._bgHl:SetDesaturated(self._state <= 1)
        self._hl:SetDesaturated(self._state <= 1)

        if self._state == 0 then
            self._icon:SetVertexColor(0.5, 0.5, 0.5, 0.4)
            self._border:SetVertexColor(0.5, 0.5, 0.5, 0.5)
            self._bg:SetVertexColor(0.7, 0.7, 0.7, 0.9)
            self._hl:SetAlpha(0.2)
        elseif self._state == 1 then
            self._icon:SetVertexColor(1, 1, 1, 0.8)
            self._border:SetVertexColor(1, 1, 1, 1)
            self._bg:SetVertexColor(1, 1, 1, 1)
            self._hl:SetAlpha(0.6)
        else
            self._icon:SetVertexColor(1, 1, 1, 1)
            self._border:SetVertexColor(1, 1, 1, 1)
            self._bg:SetVertexColor(1, 1, 1, 1)
            self._hl:SetAlpha(0.6)
        end

        if self._isNext then
            self._border:SetVertexColor(1, 1, 1, 1)
            self._border:SetDesaturated(false)
        end

    end;

}

class "SpellGridLine" : extends "Frame" {

    _ANGLES = {
        [1]=-3*math.pi/4, [2]=-math.pi/2, [3]=-math.pi/4,
        [4]=math.pi,                      [6]=0,
        [7]=3*math.pi/4,  [8]=math.pi/2,  [9]=math.pi/4 };

    __init = function(self, parent, direction, size)
        Frame.__init(self, "Frame", parent)

        self:SetSize(20, 20)

        self._direction = direction

        self._line = Texture(self, nil, "BACKGROUND")
        self._line:SetHeight(size or 6)
        self._line:SetDrawLayer("BACKGROUND", 0)
        self._line:CenterInParent()

        self._tip = Texture(self, nil, "BACKGROUND")
        self._tip:SetDrawLayer("BACKGROUND", 1)
        self._tip:SetSize(self._line:GetHeight() * 3 / 2)

        self:SetScript("OnSizeChanged", function() self:_Layout() end)
        self:SetDirection(direction)
        self:SetActive(false)
    end;

    SetActive = function(self, active, alpha)
        alpha = alpha or 0.7
        if active then
            self._line:SetTextureRegion(MUI.TEX_SKIN .. "talents\\arrow-line", 32, 128, 0, 55, 16, 16)
            self._line:SetVertexColor(1.0, 1.0, 1.0, 1.0)
            self._tip:SetTextureRegion(TEX, 2048, 1024, 956, 148, 22, 22)
            self._tip:SetVertexColor(1.0, 1.0, 1.0, 1.0)
        else
            self._line:SetTextureRegion(MUI.TEX_SKIN .. "talents\\arrow-line", 32, 128, 0, 19, 16, 16)
            self._line:SetVertexColor(alpha, alpha, alpha, 1.0)
            self._tip:SetTextureRegion(TEX, 2048, 1024, 866, 148, 22, 22)
            self._tip:SetVertexColor(alpha, alpha, alpha, 1.0)
        end
    end;

    SetShowTip = function(self, show)
        if show then
            self._tip:Show()
        else
            self._tip:Hide()
        end
    end;

    SetDirection = function(self, direction)
        self._direction = direction
        self._angle = self._ANGLES[direction] or 0
        self._line:SetRotation(self._angle)
        self._tip:SetRotation(self._angle + math.pi/2)
        self:_Layout()
    end;

    _Layout = function(self)
        local w = self:GetWidth()
        local h = self:GetHeight()
        if w == 0 or h == 0 then return end
        local l

        if self._direction == 2 or self._direction == 8 then
            l = h
        else
            l = w
        end

        self._line:SetWidth(l)
        local r = l/2 - 2.5
        local a = self._angle or 0
        self._tip:ClearAllPoints()
        self._tip:SetPoint("CENTER", self, "CENTER",
                            r * math.cos(a), r * math.sin(a))
    end;
}


class "SpellGrid" : extends "Frame" {

    _CELL_SIZE = 50;
    _CELL_ICON_SIZE = 37;
    _CELL_SPACING_H = 3.5;
    _CELL_SPACING_V = 4;

    __init = function(self, parent, name, numRows, numColumns, hideTips)

        Frame.__init(self, "Frame", parent, name)

        local totalW = self._CELL_SIZE * numColumns + self._CELL_SPACING_H * (numColumns - 1)
        local totalH = self._CELL_SIZE * numRows    + self._CELL_SPACING_V * (numRows - 1)

        self._numRows = numRows
        self._numCols = numColumns

        self._slots = {}
        self._lines = {}

        for i=1, numRows do
            for j=1, numColumns do

                local x = self._CELL_SIZE / 2 + (self._CELL_SIZE + self._CELL_SPACING_H) * (j - 1)
                local y = self._CELL_SIZE / 2 + (self._CELL_SIZE + self._CELL_SPACING_V) * (i - 1)

                local slot = SpellGridSlot(self, nil, false)
                slot:SetSize(self._CELL_ICON_SIZE, self._CELL_ICON_SIZE)
                slot:SetPoint("CENTER", self, "TOPLEFT", x, -y)
                slot:Hide()

                if not self._slots[i] then self._slots[i] = {} end

                self._slots[i][j] = slot
            end
        end

        for i=1, numRows do
            for j=1, numColumns do

                local slot = self._slots[i][j]

                local line = {}

                -- Horizontal
                if j > 1 then
                   local left = SpellGridLine(self, 4)
                    left:SetPoint("RIGHT", slot, "LEFT", 0, 0)
                    left:RightOf(self._slots[i][j - 1])
                    left:SetShowTip(false)
                    line.left = left
                end

                if j < numColumns then
                    local right = SpellGridLine(self, 6)
                    right:SetPoint("LEFT", slot, "RIGHT", 0, 0)
                    right:LeftOf(self._slots[i][j + 1])
                    right:SetShowTip(false)
                    line.right = right
                end

                if i < numRows then

                    -- Down
                    local ver = SpellGridLine(self, 2)
                    ver:SetPoint("TOP", slot, "BOTTOM", 0, 0)
                    ver:Above(self._slots[i+1][j], 1)
                    ver:SetShowTip(not hideTips)
                    line.bottom = ver

                    -- Down-Left
                    if j > 1 then
                        local dl = SpellGridLine(self, 1)
                        dl:SetPoint("TOPRIGHT", slot, "BOTTOMLEFT", 8, 8)
                        dl:SetPoint("BOTTOMLEFT", self._slots[i+1][j-1], "TOPRIGHT", -8, -8)
                        dl:SetShowTip(not hideTips)
                        line.dl = dl
                    end

                    -- Down-Right
                    if j < numColumns then
                        local dr = SpellGridLine(self, 3)
                        dr:SetPoint("TOPLEFT", slot, "BOTTOMRIGHT", -8, 8)
                        dr:SetPoint("BOTTOMRIGHT", self._slots[i+1][j+1], "TOPLEFT", 8, -8)
                        dr:SetShowTip(not hideTips)
                        line.dr = dr
                    end
                end

                if not self._lines[i] then self._lines[i] = {} end
                self._lines[i][j] = line

            end
        end

        self:SetSize(totalW, totalH)
    end;

    UpdateLines = function(self)

        local numRows = self._numRows
        local numCols = self._numCols

        for i=1, numRows do
            for j=1, numCols do

                local slot = self._slots[i][j]
                local line = self._lines[i][j]

                -- Hide all by default
                for _, l in pairs(line) do
                    l:Hide()
                    l:SetActive(false)
                end

                if slot:IsShown() then

                    local state = slot:GetState()
                    local active = state == 2 or state == 3

                    if j < numCols and self._slots[i][j+1]:IsShown() then 
                        --line.right:Show()
                        line.right:SetActive(active and (self._slots[i][j+1]:GetState() == 2))
                    end
                    if j > 1       and self._slots[i][j-1]:IsShown() then 
                        --line.left:Show()
                        line.left:SetActive(active and (self._slots[i][j-1]:GetState() == 2))
                    end
                    if i < numRows and self._slots[i+1][j]:IsShown() then
                        line.bottom:Show()
                        line.bottom:SetActive(active)
                        line.bottom:SetActive(active and (self._slots[i+1][j]:GetState() == 2))
                    end
                    if i < numRows and j < numCols and self._slots[i+1][j+1]:IsShown() then
                        line.dr:ClearAllPoints()

                        if slot:IsPassive() then
                            line.dr:SetPoint("TOPLEFT", slot, "BOTTOMRIGHT", -11, 11)
                        else
                            line.dr:SetPoint("TOPLEFT", slot, "BOTTOMRIGHT", -8, 8)
                        end

                        if self._slots[i+1][j+1]:IsPassive() then
                            line.dr:SetPoint("BOTTOMRIGHT", self._slots[i+1][j+1], "TOPLEFT", 10, -10)
                        else
                            line.dr:SetPoint("BOTTOMRIGHT", self._slots[i+1][j+1], "TOPLEFT", 7, -7)
                        end

                        line.dr:Show()
                        line.dr:SetActive(active and (self._slots[i+1][j+1]:GetState() == 2))
                    end
                    if i < numRows and j > 1 and self._slots[i+1][j-1]:IsShown() then

                        if slot:IsPassive() then
                            line.dl:SetPoint("TOPRIGHT", slot, "BOTTOMLEFT", 11, 11)
                        else
                            line.dl:SetPoint("TOPRIGHT", slot, "BOTTOMLEFT", 8, 8)
                        end

                        if self._slots[i+1][j-1]:IsPassive() then
                            line.dl:SetPoint("BOTTOMLEFT", self._slots[i+1][j-1], "TOPRIGHT", -10, -10)
                        else
                            line.dl:SetPoint("BOTTOMLEFT", self._slots[i+1][j-1], "TOPRIGHT", -7, -7)
                        end

                        line.dl:Show()
                        line.dl:SetActive(active and (self._slots[i+1][j-1]:GetState() == 2))
                        
                    end
                end

            end
        end

        -- Resolve diagonal crossings: in any 2x2 cell quad where both
        -- DR(i,j) and DL(i,j+1) are visible, the two arrows cross in the
        -- middle. Hide one, alternating L/R across the grid so the kept
        -- arrows zig-zag rather than all pointing the same way.
        local hideLeftNext = true
        for i = 1, numRows - 1 do
            for j = 1, numCols - 1 do
                local dr = self._lines[i][j]   and self._lines[i][j].dr
                local dl = self._lines[i][j+1] and self._lines[i][j+1].dl
                if dr and dl and dr:IsShown() and dl:IsShown() then
                    if hideLeftNext then
                        dl:Hide()
                    else
                        dr:Hide()
                    end
                    hideLeftNext = not hideLeftNext
                end
            end
        end
    end;

    GetSlot = function(self, row, col)
        return self._slots[row] and self._slots[row][col]
    end;

    Clear = function(self)
        for i=1, #self._slots do
            for j=1, #(self._slots[i]) do
                local slot = self._slots[i][j]
                if slot then
                    slot:Hide()
                    slot:SetHalo(0, 0, 0, 1)
                end
            end
        end
    end;

}