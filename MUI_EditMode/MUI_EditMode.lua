
local ACTIVE_SETTING_PANEL = nil

class "Editable" {

    __init = function(self)

        self._editEnabled = true
        self._posCustomized = false   -- user dragged this frame (or a save was applied)
        self._defaultScale = 1        -- vanilla scale; owners override via EditModeSetDefaultScale
        self._editDragPoint = "BOTTOMLEFT"  -- corner the drag pins to; TOPLEFT for top-down-growing frames

        -- Parent the overlay to the root (a SIBLING of the edited frame), not the
        -- frame itself. A higher-strata CHILD of the minimap still can't sit above
        -- the minimap's engine blips/pins — they draw over child frames — but a
        -- sibling at a higher strata does. Anchored to self so it tracks the frame.
        self._editNS = NineSlice(MUI_Root)
        self._editNS:SetFromTextureRegion("editmode", 128, 128, 7, 58, 54, 38, 5, 5, 5, 5)
        self._editNS:SetFrameStrata("FULLSCREEN")
        self._editNS:SetDrawLayer("OVERLAY", 6)
        self._editNS:Hide()
        self._editNS:EnableMouse(true)
        self:_EditModeAnchorOverlay(3)

        self._editNSHighlight = Texture(self._editNS, nil, "OVERLAY")
        self._editNSHighlight:SetColorTexture(0.9, 0.9, 1, 0.3)
        self._editNSHighlight:Fill(self)
        self._editNSHighlight:Hide()

        self._editNS:SetScript("OnEnter", function()
            self._editNSHighlight:Show()
        end)

        self._editNS:SetScript("OnLeave", function()
            self._editNSHighlight:Hide()
        end)

        self._editNS:RegisterForDrag("LeftButton")
        self._editNS:SetScript("OnDragStart", function() self:_EditModeBeginDrag() end)
        self._editNS:SetScript("OnDragStop",  function() self:_EditModeEndDrag() end)

        self._editNS:SetScript("OnMouseDown", function()
            MUI_EditMode:Select(self)
        end)

        self._editLabel = FontString(self._editNS)
        self._editLabel:SetFontSize(18)
        self._editLabel:SetShadowOffset(1, -1)
        self._editLabel:CenterInParent()

        MUI_EditMode:Register(self)
    end;

    EditModeEnabled = function(self, enabled)
        self:_EditModeEnsureDefault()
        self._editEnabled = enabled
    end;

    EditModeSetLabel = function(self, text, rotation)
        self:_EditModeEnsureDefault()
        self._editLabel:SetText(text)
        self._editLabel:SetRotation(rotation or 0)
        self._editNS:SetTooltip("ANCHOR_CURSOR", function(tooltip)
            tooltip:AddLine(text, 1, 1, 1, false, 13)
        end)
    end;

    -- Override the overlay label's font size (default 18) for frames too small
    -- to fit it — e.g. the thin XP / reputation bars.
    EditModeSetLabelSize = function(self, size)
        self._editLabel:SetFontSize(size)
    end;

    EditModeGetLabelText = function(self)
        return self._editLabel:GetText()
    end;

    -- Scale hooks. The default scales the frame itself. Owners whose visual
    -- content lives in OTHER frames override these — e.g. the action bars, whose
    -- buttons keep their native parents to avoid taint, so SetScale on the bar
    -- never touches them. Such owners scale those children themselves.
    EditModeApplyScale = function(self, scale)
        self:SetScale(scale)
    end;

    EditModeGetScale = function(self)
        return self:GetScale()
    end;

    -- --- anchor snapshots --------------------------------------------------

    _EditModeCapturePoints = function(self)
        local pts = {}
        for i = 1, self:GetNumPoints() do
            pts[i] = { self:GetPoint(i) }
        end
        return pts
    end;

    _EditModeApplyPoints = function(self, pts)
        if not pts then return end
        self:ClearAllPoints()
        for _, p in ipairs(pts) do
            self:SetPoint(p[1], p[2], p[3], p[4], p[5])
        end
    end;

    -- Choose which corner the drag pins the frame to. BOTTOMLEFT (default) keeps
    -- the bottom-left fixed; TOPLEFT keeps the top fixed (a frame whose height
    -- grows downward, e.g. the quest tracker); TOPRIGHT keeps the top-right fixed
    -- (a frame that grows left/down from a fixed right edge, e.g. the buff bar).
    EditModeSetDragAnchor = function(self, point)
        self._editDragPoint = point
    end;

    -- Manual drag. We do NOT use StartMoving: it re-derives the frame's position
    -- from its anchor, and for frames anchored by an edge midpoint (mb3 = RIGHT)
    -- or relative to a sibling (mb4 -> mb3) it flings them off-screen. Instead we
    -- track the cursor and re-anchor to a clean corner each frame. Cursor is raw
    -- pixels; divide by the frame's effective scale to match GetLeft/Right/Top/Bottom.
    _EditModeBeginDrag = function(self)
        local scale = self:GetEffectiveScale()
        if not scale or scale == 0 then return end
        local p = self._editDragPoint
        local right = (p == "TOPRIGHT" or p == "BOTTOMRIGHT")
        local top   = (p == "TOPLEFT"  or p == "TOPRIGHT")
        local edgeX = right and (self:GetRight() or 0) or (self:GetLeft() or 0)
        local edgeY = top   and (self:GetTop() or 0)   or (self:GetBottom() or 0)
        local mx, my = GetCursorPosition()
        self._dragGrabX = mx / scale - edgeX
        self._dragGrabY = my / scale - edgeY
        self._editNS:SetScript("OnUpdate", function() self:_EditModeDragUpdate() end)
    end;

    _EditModeDragUpdate = function(self)
        local scale = self:GetEffectiveScale()
        if not scale or scale == 0 then return end
        local p = self._editDragPoint
        local mx, my = GetCursorPosition()
        local x = mx / scale - self._dragGrabX
        local y = my / scale - self._dragGrabY
        -- The root's RIGHT/TOP edges aren't at 0; express them in this frame's
        -- coordinate space (handles a custom frame scale) and offset by them.
        local rootRel = MUI_Root:GetEffectiveScale() / scale
        if p == "TOPRIGHT" or p == "BOTTOMRIGHT" then
            x = x - MUI_Root:GetRight() * rootRel
        end
        if p == "TOPLEFT" or p == "TOPRIGHT" then
            y = y - MUI_Root:GetTop() * rootRel
        end
        self:ClearAllPoints()
        self:SetPoint(p or "BOTTOMLEFT", MUI_Root, p or "BOTTOMLEFT", x, y)
    end;

    _EditModeEndDrag = function(self)
        self._editNS:SetScript("OnUpdate", nil)
        self._posCustomized = true
        MUI_EditMode:NotifyChanged(self)
    end;

    -- Capture the VANILLA position once, while the owner is still configuring
    -- edit mode (i.e. after its default layout, before any saved positions are
    -- applied). This is what "Restore default position" returns to, regardless
    -- of what was saved this or a previous session.
    _EditModeEnsureDefault = function(self)
        if self._defaultPoints then return end
        if self:GetNumPoints() == 0 then return end
        self._defaultPoints = self:_EditModeCapturePoints()
    end;

    -- Track a setting so "Reset changes" can revert it: get() is snapshotted on
    -- edit-mode entry, set(value) restores it. The settings builder calls this
    -- when it adds a control that mutates state.
    EditModeTrackSetting = function(self, getFn, setFn)
        self._revertList = self._revertList or {}
        tinsert(self._revertList, { get = getFn, set = setFn })
    end;

    -- --- default position --------------------------------------------------

    -- The vanilla position of multibar/pet/stance frames depends on which other
    -- bars are currently enabled, so it can't be a captured snapshot. The owner
    -- supplies a callback that re-applies the state-dependent default layout.
    -- Without one, we fall back to the captured snapshot.
    EditModeSetDefaultPosition = function(self, fn)
        self._defaultFn = fn
    end;

    _EditModeApplyDefault = function(self)
        if self._defaultFn then
            self._defaultFn(self)
        else
            self:_EditModeApplyPoints(self._defaultPoints)
        end
    end;

    -- True if the frame is at its (state-dependent) default. Probes by applying
    -- the default and comparing the resulting screen position, restoring the
    -- current position when they differ. The probe is synchronous, so the
    -- intermediate move is never drawn.
    EditModeIsAtDefault = function(self)
        local L1, B1 = self:GetLeft(), self:GetBottom()
        if not L1 then return true end
        local cur = self:_EditModeCapturePoints()
        self:_EditModeApplyDefault()
        local L2, B2 = self:GetLeft(), self:GetBottom()
        local atDefault = L2 and math.abs(L1 - L2) < 0.5 and math.abs(B1 - B2) < 0.5
        if not atDefault then self:_EditModeApplyPoints(cur) end
        return atDefault and true or false
    end;

    -- True if position or any tracked setting changed since edit mode opened.
    EditModeIsDirty = function(self)
        local L, B = self:GetLeft(), self:GetBottom()
        if self._sessionLeft and L
           and (math.abs(L - self._sessionLeft) > 0.5 or math.abs(B - self._sessionBottom) > 0.5) then
            return true
        end
        if self._revertList then
            for _, e in ipairs(self._revertList) do
                if e.saved ~= nil and e.get() ~= e.saved then return true end
            end
        end
        return false
    end;

    -- Settings controls call this after mutating a tracked value so the reset
    -- buttons re-evaluate.
    EditModeNotifyChanged = function(self)
        MUI_EditMode:NotifyChanged(self)
    end;

    -- --- persistence -------------------------------------------------------

    -- Vanilla scale, used to tell whether the scale is customised and for
    -- restore. Default 1; the minimap (scaled 1.25 by its module) sets its own.
    EditModeSetDefaultScale = function(self, scale)
        self._defaultScale = scale
    end;

    -- True once the user has dragged this frame (or a saved layout was applied).
    -- The action bars use it to skip auto-re-docking a user-moved bar.
    EditModeIsMoved = function(self)
        return self._posCustomized and true or false
    end;

    -- Re-snapshot the "no unsaved changes" baseline. Called on edit-mode entry
    -- and again after Save, so "Reset changes" reverts to the last saved state.
    EditModeCommitBaseline = function(self)
        self._sessionPoints = self:_EditModeCapturePoints()
        self._sessionLeft, self._sessionBottom = self:GetLeft(), self:GetBottom()
        self._sessionPosCustomized = self._posCustomized
        if self._revertList then
            for _, e in ipairs(self._revertList) do e.saved = e.get() end
        end
    end;

    -- Serialize layout for SavedVariables: anchor points only if the user moved
    -- it (otherwise it keeps its state-dependent default), scale only if changed
    -- from default. Returns nil when there's nothing to persist.
    EditModeGetLayout = function(self)
        local data
        if self._posCustomized then
            local points = {}
            for i = 1, self:GetNumPoints() do
                local p, rel, rp, x, y = self:GetPoint(i)
                points[i] = { p, rel and rel:GetName() or nil, rp, x, y }
            end
            data = { points = points }
        end
        local s = self:EditModeGetScale()
        if math.abs(s - (self._defaultScale or 1)) > 0.001 then
            data = data or {}
            data.scale = s
        end
        return data
    end;

    -- Re-apply a saved layout. Points mark the frame user-moved (so auto-dock
    -- leaves it alone); scale goes through the owner's scale hook.
    EditModeApplyLayout = function(self, data)
        if not data then return end
        if data.points then
            self:ClearAllPoints()
            for _, p in ipairs(data.points) do
                self:SetPoint(p[1], p[2] and getglobal(p[2]) or MUI_Root, p[3], p[4], p[5])
            end
            self._posCustomized = true
        end
        if data.scale then
            self:EditModeApplyScale(data.scale)
        end
    end;

    -- Position the overlay over the edited frame. It's a sibling of that frame
    -- (not a child), so it can't use FillParentPadding; `pad` extends it outward.
    _EditModeAnchorOverlay = function(self, pad)
        self._editNS:ClearAllPoints()
        self._editNS:SetPoint("TOPLEFT", self, "TOPLEFT", -pad, pad)
        self._editNS:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", pad, -pad)
    end;

    EditModeSelect = function(self)
        self:_EditModeAnchorOverlay(10)
        self._editNS:SetFromTextureRegion("editmode", 128, 128, 0, 0, 68, 52, 15, 15, 15, 15)

        if ACTIVE_SETTING_PANEL then
            ACTIVE_SETTING_PANEL:Hide()
        end

        if self._editSettings then
            ACTIVE_SETTING_PANEL = self._editSettings
            ACTIVE_SETTING_PANEL:Show()
        end

    end;

    EditModeDeselect = function(self)
        self:_EditModeAnchorOverlay(3)
        self._editNS:SetFromTextureRegion("editmode", 128, 128, 7, 58, 54, 38, 5, 5, 5, 5)
    end;

    EditModeShow = function(self)

        if not self._editEnabled then
            return
        end

        self:_EditModeEnsureDefault()
        self:EditModeCommitBaseline()
        self._editNS:Show()
    end;

    -- Reset changes: revert position + tracked settings to this session's start
    -- (i.e. the last saved state).
    EditModeResetChanges = function(self)
        self:_EditModeApplyPoints(self._sessionPoints)
        self._posCustomized = self._sessionPosCustomized
        if self._revertList then
            for _, e in ipairs(self._revertList) do
                if e.saved ~= nil then e.set(e.saved) end
            end
        end
        MUI_EditMode:NotifyChanged(self)
    end;

    -- Restore default position: re-apply the state-dependent default layout and
    -- hand the frame back to auto-layout (re-dock allowed, position not saved).
    EditModeRestoreDefault = function(self)
        self:_EditModeApplyDefault()
        self._posCustomized = false
        MUI_EditMode:NotifyChanged(self)
    end;

    EditModeHide = function(self)
        self._editNS:Hide()
    end;

    EditModeSetupSettings = function(self, content)
        self:_EditModeEnsureDefault()
        self._editSettings = EditModePanelSettings(self, content)
    end
}

-- Generic editable: wrap a native frame (whose content is all children, so the
-- default drag + scale handlers suffice) and add the edit overlay.
-- Either wraps a native frame -- EditableFrame(nativeFrame, label) -- or creates
-- a fresh one -- EditableFrame("Frame", label, parent, name) -- mirroring the
-- Frame constructor's wrap-vs-create branch.
class "EditableFrame" : extends {"Frame", "Editable"} {
    __init = function(self, nativeOrType, label, parent, name)
        Frame.__init(self, nativeOrType, parent, name)
        Editable.__init(self)
        self:EditModeSetLabel(label)
        self:EditModeSetupSettings(function(content) end)
    end;
}

class "EditModePanelSettings" : extends "DiamondBorder" {

    __init = function(self, editable, content)
        DiamondBorder.__init(self, MUI_Root, "MUI_EditModePanel" .. editable:GetName())

        self._editable = editable

        self:SetFrameStrata("FULLSCREEN_DIALOG")
        self:SetFrameLevel(100)
        self:SetSize(342, 500)
        self:AlignParentBottomRight(181, 227)
        self:MakeDraggable()

        self:Hide()

        self._close = CloseButton(self)
        self._close:SetScale(0.9)

        self._label = FontString(self)
        self._label:SetFont(MUI.FONT, 14, "")
        self._label:AlignParentTop(12)
        self._label:SetText(editable:EditModeGetLabelText() .. " Settings")

        local labelScale = FontString(self)
        labelScale:Below(self._label, 20)
        labelScale:AlignParentLeft(20)
        labelScale:SetSize(70, 10)
        labelScale:SetText("Scale")
        labelScale:SetJustifyH("LEFT")

        -- Value readout sits to the right of the slider, e.g. "100%".
        self._lblScaleValue = FontString(self)
        self._lblScaleValue:SetFontSize(10.5)
        self._lblScaleValue:SetTextColor(1, 0.82, 0)
        self._lblScaleValue:Below(self._label, 20)
        self._lblScaleValue:AlignParentRight(20)
        self._lblScaleValue:SetSize(30, 10)
        self._lblScaleValue:SetJustifyH("RIGHT")

        self._sliderScale = StepSlider(self)
        self._sliderScale:SetHeight(20)
        self._sliderScale:RightOf(labelScale, 10)
        self._sliderScale:LeftOf(self._lblScaleValue, 10)
        self._sliderScale:SetMinMax(0.5, 2.0)
        self._sliderScale:SetValueStep(0.05)
        self._sliderScale.OnValueChanged = function(_, value)
            editable:EditModeApplyScale(value)
            self._lblScaleValue:SetText(math.floor(value * 100 + 0.5) .. "%")
            editable:EditModeNotifyChanged()
        end
        self._sliderScale:SetValue(editable:EditModeGetScale())
        self._lblScaleValue:SetText(math.floor(editable:EditModeGetScale() * 100 + 0.5) .. "%")

        -- Make scale revertible by "Reset changes".
        editable:EditModeTrackSetting(
            function() return editable:EditModeGetScale() end,
            function(v) self._sliderScale:SetValue(v) end)

        self._content = Frame("Frame", self)
        self._content:FillWidth(20)
        self._content:SetHeight(1)
        self._content:Below(self._sliderScale, 10)
        content(self._content, editable)

        self._btnResetChanges = ButtonGold(self, nil, "Reset changes")
        self._btnResetChanges:SetSize(140, 24)
        self._btnResetChanges.label:SetFontSize(10.5)
        self._btnResetChanges:Below(self._content, 10)
        self._btnResetChanges:AlignParentLeft(20)
        self._btnResetChanges.OnClick = function() editable:EditModeResetChanges() end
        self._btnResetChanges:SetEnabled(false)

        self._btnResetPosition = ButtonGold(self, nil, "Restore default position")
        self._btnResetPosition:FillWidth(20)
        self._btnResetPosition:SetHeight(24)
        self._btnResetPosition.label:SetFontSize(10.5)
        self._btnResetPosition:Below(self._btnResetChanges, 10)
        self._btnResetPosition.OnClick = function() editable:EditModeRestoreDefault() end
        self._btnResetPosition:SetEnabled(false)

        self:RecalculateHeight()
        self:HookScript("OnShow", function()
            -- Re-seed from the live scale: it may have changed since construction
            -- (a saved scale applied at login, or an edit earlier this session).
            self._sliderScale:SetValue(self._editable:EditModeGetScale())
            self:RecalculateHeight()
            self:RefreshButtons()
        end)
    end;

    -- Enable the reset buttons only when there's something to reset.
    RefreshButtons = function(self)
        self._btnResetChanges:SetEnabled(self._editable:EditModeIsDirty())
        self._btnResetPosition:SetEnabled(not self._editable:EditModeIsAtDefault())
    end;

    -- Size _content to fit the builder's children, then size the whole panel.
    --
    -- Content children are anchored to _content (TOP/LEFT/RIGHT only — no BOTTOM),
    -- and the anchor chain resolves to UIParent, so their rects are valid even
    -- while the panel is hidden. Content height = the gap from _content's top
    -- edge down to its lowest child/region.
    --
    -- The panel is bottom-anchored (AlignParentBottomRight) while label/content/
    -- buttons are top-anchored, so they all shift together when the panel's
    -- height changes. That makes the measured top→last-button distance invariant
    -- under the resize, so a single pass converges: measure the offset, add
    -- bottom padding, set the height.
    RecalculateHeight = function(self)
        local content = self._content
        local top = content:GetTop()
        if not top then return end

        local lowest = top
        for _, child in ipairs(content:GetChildren()) do
            if child:IsShown() then
                local b = child:GetBottom()
                if b and b < lowest then lowest = b end
            end
        end
        for _, region in ipairs(content:GetRegions()) do
            if region:IsShown() then
                local b = region:GetBottom()
                if b and b < lowest then lowest = b end
            end
        end
        content:SetHeight(math.max(top - lowest, 1))

        local offset = self:GetTop() - self._btnResetPosition:GetBottom()
        self:SetHeight(offset + 18)
    end;
}

class "EditModeSettings" : extends "DiamondBorder" {

    __init = function(self)
        DiamondBorder.__init(self, MUI_Root, "MUI_EditModeSettings")
        self:SetFrameStrata("FULLSCREEN_DIALOG")
        self:SetFrameLevel(20)
        self:SetSize(456, 506)
        self:AlignParentTop(107)
        self:MakeDraggable()

        tinsert(UISpecialFrames, "MUI_EditModeSettings")

        self:Hide()

        self._close = CloseButton(self)
        self._close:SetScale(0.9)

        local label = FontString(self)
        label:SetFont(MUI.FONT, 14, "")
        label:AlignParentTop(12)
        label:SetText("Interface Settings")

        -- Grid row: toggle + spacing slider. The grid is a display aid, so it
        -- persists immediately (separate from the layout Save/Reset flow). The
        -- checkbox and value readout share the slider's height and top so the
        -- slider stays level between them.
        self._chkGrid = CheckBox(self, nil, "Grid")
        self._chkGrid.label:SetFontSize(12)
        self._chkGrid:SetSize(64, 29)
        self._chkGrid:SetBoxSize(24, 24)
        self._chkGrid:Below(label, 14)
        self._chkGrid:AlignParentLeft    (20)
        self._chkGrid.OnChanged = function(_, checked)
            MUI_EditMode:SetGridEnabled(checked)
        end

        self._lblGridValue = FontString(self)
        self._lblGridValue:SetFontSize(10.5)
        self._lblGridValue:SetTextColor(1, 0.82, 0)
        self._lblGridValue:SetSize(34, 29)
        self._lblGridValue:Below(label, 14)
        self._lblGridValue:AlignParentRight(20)
        self._lblGridValue:SetJustifyH("RIGHT")
        self._lblGridValue:SetJustifyV("MIDDLE")

        self._sliderGrid = StepSlider(self)
        self._sliderGrid:SetHeight(20)
        self._sliderGrid:RightOf(self._chkGrid, 10)
        self._sliderGrid:LeftOf(self._lblGridValue, 10)
        self._sliderGrid:SetMinMax(20, 300)
        self._sliderGrid:SetValueStep(10)
        self._sliderGrid.OnValueChanged = function(_, value)
            value = math.floor(value + 0.5)
            self._lblGridValue:SetText(value)
            MUI_EditMode:SetGridSpacing(value)
        end

        -- This button persistently saves all changes made during this session
        self._btnSave = ButtonGold(self, nil, "Save")
        self._btnSave:SetSize(200, 24)
        self._btnSave.label:SetFontSize(10.5)
        self._btnSave:AlignParentBottomRight(14, 20)
        self._btnSave.OnClick = function() MUI_EditMode:Save() end
        self._btnSave:SetEnabled(false)

        -- This button resets all changes made during this session
        self._btnReset = ButtonGold(self, nil, "Reset all changes")
        self._btnReset:SetSize(200, 24)
        self._btnReset.label:SetFontSize(10.5)
        self._btnReset:AlignParentBottomLeft(14, 20)
        self._btnReset.OnClick = function() MUI_EditMode:ResetAll() end
        self._btnReset:SetEnabled(false)

        -- Reflect the persisted grid state every time the panel opens.
        self:HookScript("OnShow", function() self:SyncGridControls() end)

    end;

    -- Seed the grid controls from saved settings.
    SyncGridControls = function(self)
        local g = MUI_DB and MUI_DB.settings and MUI_DB.settings.editmodeGrid
        if not g then return end
        self._chkGrid:SetChecked(g.enabled)
        self._sliderGrid:SetValue(g.spacing)
        self._lblGridValue:SetText(g.spacing)
    end;

    SetResetEnabled = function(self, enabled)
        self._btnReset:SetEnabled(enabled)
    end;

    SetSaveEnabled = function(self, enabled)
        self._btnSave:SetEnabled(enabled)
    end;
}

-- Alignment grid drawn while edit mode is active, mirroring retail: a fullscreen
-- pool of pixel-thin Line regions marching outward from screen center, with a
-- brighter pair of center axes. Spacing (px between lines) is user-set; lines are
-- pixel-snapped so they stay crisp at any UI scale. Sits at BACKGROUND strata so
-- real UI frames render on top of it.
local GRID_LINE_COLOR        = { 1, 1, 1, 0.20 }
local GRID_CENTER_LINE_COLOR = { 1, 0.82, 0, 0.55 }
local GRID_LINE_PIXEL_WIDTH  = 1.2

class "EditModeGrid" : extends "Frame" {
    __init = function(self)
        Frame.__init(self, "Frame", MUI_Root, "MUI_EditModeGrid")
        self:SetFrameStrata("BACKGROUND")
        self:FillParent()
        self:Hide()

        self._lines = {}
        self._spacing = 50

        self:RegisterEventHandler("DISPLAY_SIZE_CHANGED", function() self:UpdateGrid() end)
        self:RegisterEventHandler("UI_SCALE_CHANGED", function() self:UpdateGrid() end)
    end;

    SetSpacing = function(self, spacing)
        self._spacing = spacing
        self:UpdateGrid()
    end;

    -- Acquire/reuse the i-th pooled line, coloured and oriented in place. A
    -- vertical line spans top→bottom offset horizontally from centre; a
    -- horizontal line spans left→right offset vertically from centre.
    _DrawLine = function(self, index, vertical, offset, center)
        local line = self._lines[index]
        if not line then
            line = Line(self, nil, "ARTWORK")
            self._lines[index] = line
        end
        local c = center and GRID_CENTER_LINE_COLOR or GRID_LINE_COLOR
        line:SetColorTexture(c[1], c[2], c[3], c[4])
        line:SetThickness(PixelUtil.GetNearestPixelSize(
            GRID_LINE_PIXEL_WIDTH, self:GetEffectiveScale(), GRID_LINE_PIXEL_WIDTH))
        if vertical then
            line:SetStartPoint("TOP", self, offset, 0)
            line:SetEndPoint("BOTTOM", self, offset, 0)
        else
            line:SetStartPoint("LEFT", self, 0, offset)
            line:SetEndPoint("RIGHT", self, 0, offset)
        end
        line:Show()
    end;

    UpdateGrid = function(self)
        if not self:IsShown() then return end

        for _, line in ipairs(self._lines) do line:Hide() end

        local w, h = self:GetWidth(), self:GetHeight()
        if not w or w == 0 or not h or h == 0 then return end

        local spacing = self._spacing
        local n = 1

        -- Centre axes (brighter), then symmetric pairs marching outward.
        self:_DrawLine(n, true,  0, true);  n = n + 1
        self:_DrawLine(n, false, 0, true);  n = n + 1

        for i = 1, math.floor((w / spacing) / 2) do
            self:_DrawLine(n, true,  i * spacing, false); n = n + 1
            self:_DrawLine(n, true, -i * spacing, false); n = n + 1
        end
        for i = 1, math.floor((h / spacing) / 2) do
            self:_DrawLine(n, false,  i * spacing, false); n = n + 1
            self:_DrawLine(n, false, -i * spacing, false); n = n + 1
        end
    end;
}

object "EditMode" {

    __init = function(self)
        self._registeredFrames = {}
        self._isActive = false

        self._grid = EditModeGrid()

        self._settings = EditModeSettings()
        self._settings:HookScript("OnHide", function()
            self:_Stop()
        end)

        -- Apply saved layouts once everything has registered (module OnEnable runs
        -- at PLAYER_LOGIN, before the first PLAYER_ENTERING_WORLD). Re-running on
        -- later world entries re-asserts user positions over any auto-relayout.
        self._watcher = Frame("Frame", nil, "MUI_EditModeWatcher")
        self._watcher:RegisterEventHandler("PLAYER_ENTERING_WORLD", function()
            self:LoadLayouts()
        end)
        -- A revert that hit combat (closed edit mode mid-fight) runs once safe.
        self._watcher:RegisterEventHandler("PLAYER_REGEN_ENABLED", function()
            if self._pendingRevert then self:_RevertSession() end
        end)
    end;

    Register = function(self, editable)
        local name = editable:GetName()
        self._registeredFrames[name] = editable
    end;

    Select = function(self, editable)
        self._selected = editable
        for _, e in pairs(self._registeredFrames) do
            if e == editable then
                e:EditModeSelect()
            else
                e:EditModeDeselect()
            end

        end
    end;

    -- Re-evaluate the Save / Reset buttons after a frame moved or a setting
    -- changed.
    NotifyChanged = function(self, editable)
        local dirty = self:AnyDirty()
        self._settings:SetResetEnabled(dirty)
        self._settings:SetSaveEnabled(dirty)
        if ACTIVE_SETTING_PANEL and editable == self._selected then
            ACTIVE_SETTING_PANEL:RefreshButtons()
        end
    end;

    AnyDirty = function(self)
        for _, e in pairs(self._registeredFrames) do
            if e:EditModeIsDirty() then return true end
        end
        return false
    end;

    -- Revert the currently-selected frame's changes (position + settings).
    ResetSelected = function(self)
        if self._selected then self._selected:EditModeResetChanges() end
    end;

    -- Revert every registered frame's changes (position + settings).
    ResetAll = function(self)
        for _, editable in pairs(self._registeredFrames) do
            editable:EditModeResetChanges()
        end
    end;

    -- Persist every frame's current layout to SavedVariables, then re-baseline
    -- so "Reset changes" now reverts to this saved state.
    Save = function(self)
        local store = MUI_DB.settings.editmode
        for name, editable in pairs(self._registeredFrames) do
            store[name] = editable:EditModeGetLayout()   -- nil clears the entry
            editable:EditModeCommitBaseline()
        end
        self._settings:SetSaveEnabled(false)
        self._settings:SetResetEnabled(false)
        if ACTIVE_SETTING_PANEL then ACTIVE_SETTING_PANEL:RefreshButtons() end
    end;

    -- Apply persisted layouts to registered frames (PLAYER_ENTERING_WORLD).
    LoadLayouts = function(self)
        local store = MUI_DB and MUI_DB.settings and MUI_DB.settings.editmode
        if not store then return end
        for name, data in pairs(store) do
            local editable = self._registeredFrames[name]
            if editable then editable:EditModeApplyLayout(data) end
        end
    end;

    -- Re-apply one frame's persisted (or default) position. For frames Blizzard
    -- re-anchors behind our back (e.g. DurabilityFrame via UIParent_ManageFrame-
    -- Positions on zone change), call this right after the offending function to
    -- reclaim our layout.
    ReassertLayout = function(self, editable)
        if editable:EditModeIsMoved() then
            local store = MUI_DB and MUI_DB.settings and MUI_DB.settings.editmode
            local data = store and store[editable:GetName()]
            if data then editable:EditModeApplyLayout(data) end
        else
            editable:_EditModeApplyDefault()
        end
    end;

    -- The grid is a display aid: persist the setting immediately and reflect it
    -- live (only actually visible while edit mode is active).
    ApplyGrid = function(self)
        local g = MUI_DB and MUI_DB.settings and MUI_DB.settings.editmodeGrid
        if not g then return end
        if self._isActive and g.enabled then
            self._grid:Show()
            self._grid:SetSpacing(g.spacing)
        else
            self._grid:Hide()
        end
    end;

    SetGridEnabled = function(self, enabled)
        MUI_DB.settings.editmodeGrid.enabled = enabled
        self:ApplyGrid()
    end;

    SetGridSpacing = function(self, spacing)
        MUI_DB.settings.editmodeGrid.spacing = spacing
        self:ApplyGrid()
    end;

    Start = function(self)
        self._isActive = true
        for _, editable in pairs(self._registeredFrames) do
            editable:EditModeShow()
        end
        self:ApplyGrid()
        self._settings:SetResetEnabled(false)
        self._settings:SetSaveEnabled(false)
        self._settings:Show()
    end;

    _Stop = function(self)
        self._isActive = false
        self._selected = nil
        self._grid:Hide()

        -- Closing without Save discards the session's changes.
        self:_RevertSession()

        if ACTIVE_SETTING_PANEL then
            ACTIVE_SETTING_PANEL:Hide()
            ACTIVE_SETTING_PANEL = nil
        end
        for _, editable in pairs(self._registeredFrames) do
            editable:EditModeDeselect()
            editable:EditModeHide()
        end
    end;

    -- Revert every frame to its baseline (last saved/loaded state). Reverting a
    -- bar's position SetPoints a frame that secure buttons are anchored to, which
    -- is protected in combat — defer to PLAYER_REGEN_ENABLED if needed.
    _RevertSession = function(self)
        if not self:AnyDirty() then return end
        if InCombatLockdown() then
            self._pendingRevert = true
            return
        end
        self._pendingRevert = false
        self:ResetAll()
    end;

}