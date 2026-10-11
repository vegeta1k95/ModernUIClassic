
local ACTIVE_SETTING_PANEL = nil

-- Width of the label column in a settings panel: the panel's own Scale row
-- and the rows an editable adds under it line up on it.
local SETTING_LABEL_WIDTH = 86

-- How far a frame's edit overlay stands out around it while it is not the
-- selected one, in the screen's units. Frames snap by that box.
local OVERLAY_PAD = 3

-- The anchor points a saved layout places a frame by.
local ANCHOR_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

-- Whether `value` can be an anchor offset: a number, and not one only a
-- broken layout text would carry (NaN, somewhere far off the screen).
local function IsOffset(value)
    return type(value) == "number" and value > -100000 and value < 100000
end

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
        self:_EditModeAnchorOverlay(OVERLAY_PAD)

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

    -- Whether the owner has this frame in edit mode at all (EditModeEnabled).
    EditModeIsEnabled = function(self)
        return self._editEnabled
    end;

    -- Put this frame under one of the edit mode window's checkboxes (its
    -- OPTIONS, by key): edit mode leaves the frame out while that one is
    -- unticked.
    EditModeSetOption = function(self, key)
        MUI_EditMode:SetOption(self, key)
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
        MUI_EditMode:BeginDrag(self)
    end;

    _EditModeDragUpdate = function(self)
        local scale = self:GetEffectiveScale()
        if not scale or scale == 0 then return end
        local mx, my = GetCursorPosition()
        self:_EditModePlace(mx / scale - self._dragGrabX, my / scale - self._dragGrabY)
        MUI_EditMode:UpdateDrag(self)
    end;

    -- Pin the drag corner at (x, y): this frame's own units, from the screen's
    -- bottom left.
    _EditModePlace = function(self, x, y)
        local p = self._editDragPoint
        -- The root's RIGHT/TOP edges aren't at 0; express them in this frame's
        -- coordinate space (handles a custom frame scale) and offset by them.
        local rootRel = MUI_Root:GetEffectiveScale() / self:GetEffectiveScale()
        if p == "TOPRIGHT" or p == "BOTTOMRIGHT" then
            x = x - MUI_Root:GetRight() * rootRel
        end
        if p == "TOPLEFT" or p == "TOPRIGHT" then
            y = y - MUI_Root:GetTop() * rootRel
        end
        self:ClearAllPoints()
        self:SetPoint(p, MUI_Root, p, x, y)
    end;

    -- Letting go snaps the frame to what it was dragged up against, when
    -- snapping is on (MUI_EditMode:EndDrag).
    _EditModeEndDrag = function(self)
        self._editNS:SetScript("OnUpdate", nil)
        MUI_EditMode:EndDrag(self)
        self._posCustomized = true
        MUI_EditMode:NotifyChanged(self)
    end;

    -- The rect the frame snaps by, in screen pixels: left, right, bottom, top;
    -- nil while it has none. It is the edit overlay's at rest, the frame's
    -- with a margin around it: as in retail it is the boxes that meet, which
    -- keeps what a frame draws past its own edges (an action bar's slot art)
    -- off its neighbour.
    EditModeGetRect = function(self)
        local left, bottom = self:GetLeft(), self:GetBottom()
        if not left or not bottom then return end
        local scale = self:GetEffectiveScale()
        local pad = OVERLAY_PAD * MUI_Root:GetEffectiveScale()
        return left * scale - pad, self:GetRight() * scale + pad,
               bottom * scale - pad, self:GetTop() * scale + pad
    end;

    -- Move the frame by (dx, dy) screen pixels, pinned by its drag corner as a
    -- drag leaves it.
    EditModeMoveBy = function(self, dx, dy)
        if not self:GetLeft() then return end
        local scale = self:GetEffectiveScale()
        local p = self._editDragPoint
        local x = (p == "TOPRIGHT" or p == "BOTTOMRIGHT") and self:GetRight() or self:GetLeft()
        local y = (p == "TOPLEFT"  or p == "TOPRIGHT")    and self:GetTop()   or self:GetBottom()
        self:_EditModePlace(x + dx / scale, y + dy / scale)
    end;

    -- A step with the arrow keys, in screen pixels: a move the user made, like
    -- a drag.
    EditModeNudge = function(self, dx, dy)
        self:EditModeMoveBy(dx, dy)
        self._posCustomized = true
        MUI_EditMode:NotifyChanged(self)
    end;

    -- Whether this frame's edit overlay is up.
    EditModeIsShown = function(self)
        return self._editNS:IsShown()
    end;

    -- Whether this frame hangs from `other`, however many frames lie between:
    -- it then moves along with it.
    EditModeIsAnchoredTo = function(self, other)
        local name = other:GetName()
        local function hangs(region)
            for i = 1, region:GetNumPoints() do
                local _, relativeTo = region:GetPoint(i)
                if relativeTo and (relativeTo:GetName() == name or hangs(Frame(relativeTo))) then
                    return true
                end
            end
            return false
        end
        return hangs(self)
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
    -- when it adds a control that mutates state. `default` is what a layout
    -- that does not hold the setting leaves it at (EditModeSetLayout).
    EditModeTrackSetting = function(self, getFn, setFn, default)
        self._revertList = self._revertList or {}
        tinsert(self._revertList, { get = getFn, set = setFn, default = default })
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
                -- false, not nil: a point stays a list without a gap, which
                -- is what a shared layout's text is made from.
                points[i] = { p, rel and rel:GetName() or false, rp, x, y }
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

    -- Stand as a layout has this frame: `data` as EditModeGetLayout gives
    -- it, nil when the layout leaves the frame as it comes. EditModeApplyLayout
    -- only adds what a layout holds, so the frame is first taken back to its
    -- defaults: this is for going from one layout to another.
    EditModeSetLayout = function(self, data)
        for _, e in ipairs(self._revertList or {}) do
            if e.default ~= nil then e.set(e.default) end
        end
        self:EditModeApplyScale(data and data.scale or self._defaultScale)
        self._posCustomized = false
        self:_EditModeApplyDefault()
        self:EditModeApplyLayout(data)
    end;

    -- A layout for this frame that came from outside (an import), cut down
    -- to what the frame itself would save: points on the screen and a scale
    -- within the slider's reach. Owners with settings of their own add them.
    EditModeCleanLayout = function(self, data)
        local clean = {}
        if type(data.scale) == "number" and data.scale >= 0.5 and data.scale <= 2 then
            clean.scale = data.scale
        end
        if type(data.points) == "table" then
            local points = {}
            for i, p in ipairs(data.points) do
                if type(p) ~= "table" or not ANCHOR_POINTS[p[1]] or not ANCHOR_POINTS[p[3]]
                        or not IsOffset(p[4]) or not IsOffset(p[5]) then
                    return clean
                end
                points[i] = { p[1], false, p[3], p[4], p[5] }
            end
            if points[1] then clean.points = points end
        end
        return clean
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
        self:_EditModeAnchorOverlay(OVERLAY_PAD)
        self._editNS:SetFromTextureRegion("editmode", 128, 128, 7, 58, 54, 38, 5, 5, 5, 5)
    end;

    -- Put the overlay up. What "Reset changes" goes back to is MUI_EditMode's
    -- to say (EditModeCommitBaseline): a frame can be put away and up again
    -- in the middle of a session, by its checkbox in the window.
    EditModeShow = function(self)

        if not self._editEnabled then
            return
        end

        self:_EditModeEnsureDefault()
        self._editNS:Show()
    end;

    -- Reset changes: revert position + tracked settings to this session's start
    -- (i.e. the last saved state).
    EditModeResetChanges = function(self)
        -- Registered since edit mode last opened: there is no baseline to
        -- go back to.
        if not self._sessionPoints then return end
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

        -- Closing the panel lets the frame go, as in retail: the arrow keys
        -- are the game's again.
        self._close = CloseButton(self)
        self._close:SetScale(0.9)
        self._close.OnClick = function() MUI_EditMode:Select(nil) end

        self._label = FontString(self)
        self._label:SetFont(MUI.FONT, 14, "")
        self._label:AlignParentTop(12)
        self._label:SetText(editable:EditModeGetLabelText() .. " Settings")

        local labelScale = FontString(self)
        labelScale:Below(self._label, 20)
        labelScale:AlignParentLeft(20)
        labelScale:SetSize(SETTING_LABEL_WIDTH, 10)
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

-- A labelled slider for an editable's settings (the builder passed to
-- EditModeSetupSettings), laid out like the panel's Scale row: label,
-- stepper slider, value. Whole numbers.
--   row.OnChanged(row, value)    the user moved it
--   row:SetValue(value)          show a value set elsewhere; OnChanged stays quiet
class "EditModeSliderRow" : extends "Frame" {
    __init = function(self, parent, text, min, max)
        Frame.__init(self, "Frame", parent)
        self:SetHeight(20)
        self:FillWidth(0)
        self.value = min

        self._label = FontString(self)
        self._label:SetSize(SETTING_LABEL_WIDTH, 10)
        self._label:SetJustifyH("LEFT")
        self._label:AlignParentLeft(0)
        self._label:SetText(text)

        self._readout = FontString(self)
        self._readout:SetFontSize(10.5)
        self._readout:SetTextColor(1, 0.82, 0)
        self._readout:SetSize(30, 10)
        self._readout:SetJustifyH("RIGHT")
        self._readout:AlignParentRight(0)
        self._readout:SetText(min)

        self._slider = StepSlider(self)
        self._slider:SetHeight(20)
        self._slider:RightOf(self._label, 10)
        self._slider:LeftOf(self._readout, 10)
        self._slider:SetMinMax(min, max)
        self._slider:SetValueStep(1)
        self._slider:SetObeyStepOnDrag(true)
        self._slider:SetValue(min)
        self._slider.OnValueChanged = function(_, value)
            value = math.floor(value + 0.5)
            self._readout:SetText(value)
            if value ~= self.value then
                self.value = value
                if self.OnChanged then self:OnChanged(value) end
            end
        end
    end;

    SetValue = function(self, value)
        self.value = value
        self._slider:SetValue(value)
        self._readout:SetText(value)
    end;

    SetLabel = function(self, text)
        self._label:SetText(text)
    end;
}

-- A labelled dropdown for an editable's settings. `options` is a list of
-- { value = ..., text = ... }.
--   row.OnChanged(row, value)    the user picked another one
--   row:SetValue(value)          show a value set elsewhere; OnChanged stays quiet
class "EditModeDropdownRow" : extends "Frame" {
    __init = function(self, parent, text, options)
        Frame.__init(self, "Frame", parent)
        self:SetHeight(22)
        self:FillWidth(0)
        self._options = options

        self._label = FontString(self)
        self._label:SetSize(SETTING_LABEL_WIDTH, 10)
        self._label:SetJustifyH("LEFT")
        self._label:AlignParentLeft(0)
        self._label:SetText(text)

        self._button = DropdownSimple(self)
        self._button:SetHeight(22)
        self._button:RightOf(self._label, 10)
        self._button:AlignParentRight(0)

        -- The menu's popup is a root frame in the panels' own strata: lift it
        -- over them before its rows are made.
        self._menu = DropdownMenu(self._button, nil, self._button)
        self._menu.popup:SetFrameLevel(200)
        self._menu:SetMenuWidth(150)
        local items = {}
        for i, option in ipairs(options) do
            items[i] = { label = option.text, OnClick = function()
                if option.value ~= self.value then
                    self:SetValue(option.value)
                    if self.OnChanged then self:OnChanged(option.value) end
                end
            end }
        end
        self._menu:SetItems(items)
        self._button.OnClick = function() self._menu:Toggle() end

        self:SetValue(options[1].value)
    end;

    SetValue = function(self, value)
        self.value = value
        for _, option in ipairs(self._options) do
            if option.value == value then self._button:SetText(option.text) end
        end
    end;
}

-- Layouts, as retail has them: named sets of every frame's place and
-- settings, one of them applied. The preset is every frame as it comes: it
-- is not written to, and saving it makes a new layout instead.
local PRESET_NAME = HUD_EDIT_MODE_PRESET_LAYOUT:format(LAYOUT_STYLE_MODERN)
local MAX_LAYOUTS = Constants.EditModeConsts.EditModeMaxLayoutsPerType
local MAX_LAYOUTS_TEXT = "Only " .. MAX_LAYOUTS .. " layouts are allowed."
-- What the text of a shared layout starts with: ours, and how it is packed.
local SHARE_PREFIX = "MUI1:"
local NEW_LAYOUT          = HUD_EDIT_MODE_NEW_LAYOUT:format(CreateAtlasMarkup("editmode-new-layout-plus"))
local NEW_LAYOUT_DISABLED = HUD_EDIT_MODE_NEW_LAYOUT_DISABLED:format(CreateAtlasMarkup("editmode-new-layout-plus-disabled"))

-- The checkboxes of the window's list, in retail's order: frames edit mode
-- puts up only while theirs is ticked. An editable comes under one by its
-- key (Editable:EditModeSetOption). The `basic` ones are listed without
-- "Advanced Options" too; with it all are, under OPTION_CATEGORIES' headings.
local OPTION_CATEGORIES = {
    HUD_EDIT_MODE_SETTINGS_CATEGORY_TITLE_FRAMES,
    HUD_EDIT_MODE_SETTINGS_CATEGORY_TITLE_COMBAT,
    HUD_EDIT_MODE_SETTINGS_CATEGORY_TITLE_MISC,
}
local OPTIONS = {
    { key = "target",     category = 1, basic = true, text = HUD_EDIT_MODE_TARGET_FRAME_LABEL },
    { key = "pet",        category = 1,               text = HUD_EDIT_MODE_PET_FRAME_LABEL },
    { key = "buffs",      category = 2, basic = true, text = HUD_EDIT_MODE_BUFFS_AND_DEBUFFS_LABEL },
    { key = "castBar",    category = 2, basic = true, text = HUD_EDIT_MODE_CAST_BAR_LABEL },
    { key = "stanceBar",  category = 2,               text = HUD_EDIT_MODE_STANCE_BAR_LABEL },
    { key = "petBar",     category = 2,               text = HUD_EDIT_MODE_PET_ACTION_BAR_LABEL },
    { key = "repBar",     category = 3,               text = "Reputation Bar" },
    { key = "durability", category = 3,               text = HUD_EDIT_MODE_DURABILITY_FRAME_LABEL },
    { key = "loot",       category = 3,               text = HUD_EDIT_MODE_LOOT_FRAME_LABEL },
}
local OPTION_PAD, OPTION_ROW_H, OPTION_COLUMN_W, OPTION_HEADING_H = 10, 29, 198, 24

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

        self:_BuildLayoutRow(label)

        -- Grid row: toggle + spacing slider. The grid is a display aid, so it
        -- persists immediately (separate from the layout Save/Reset flow). The
        -- checkbox and value readout share the slider's height and top so the
        -- slider stays level between them.
        self._chkGrid = CheckBox(self, nil, "Grid")
        self._chkGrid.label:SetFontSize(12)
        self._chkGrid:SetSize(64, 29)
        self._chkGrid:SetBoxSize(24, 24)
        self._chkGrid:Below(self._layoutButton, 8)
        self._chkGrid:AlignParentLeft    (20)
        self._chkGrid.OnChanged = function(_, checked)
            MUI_EditMode:SetGridEnabled(checked)
        end

        self._lblGridValue = FontString(self)
        self._lblGridValue:SetFontSize(10.5)
        self._lblGridValue:SetTextColor(1, 0.82, 0)
        self._lblGridValue:SetSize(34, 29)
        self._lblGridValue:Below(self._layoutButton, 8)
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

        -- Retail's "Snap to Elements". Like the grid it is no part of a
        -- layout: it persists as it is set.
        self._chkSnap = CheckBox(self, nil, HUD_EDIT_MODE_ENABLE_SNAP)
        self._chkSnap.label:SetFontSize(12)
        self._chkSnap:SetSize(200, 29)
        self._chkSnap:SetBoxSize(24, 24)
        self._chkSnap:Below(self._chkGrid, 4)
        self._chkSnap:AlignParentLeft(20)
        self._chkSnap.OnChanged = function(_, checked)
            MUI_EditMode:SetSnapEnabled(checked)
        end

        -- Retail's "Advanced Options": the list below holds every checkbox,
        -- under headings, where it otherwise holds only the few most used.
        self._chkAdvanced = CheckBox(self, nil, HUD_EDIT_MODE_ENABLE_ADVANCED_OPTIONS)
        self._chkAdvanced.label:SetFontSize(12)
        self._chkAdvanced:SetSize(200, 29)
        self._chkAdvanced:SetBoxSize(24, 24)
        self._chkAdvanced:Below(self._chkGrid, 4)
        self._chkAdvanced:AlignParentLeft(228)
        self._chkAdvanced.OnChanged = function(_, checked)
            MUI_DB.settings.editmodeAdvanced = checked
            self:_LayoutOptions()
        end

        self:_BuildOptions()

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

        -- Reflect the persisted state every time the panel opens: it is built
        -- before the saved settings are loaded.
        self:HookScript("OnShow", function() self:SyncControls() end)

    end;

    -- Retail's Layout dropdown: the preset and the saved layouts, to pick the
    -- one applied, then what can be done with them. Retail's rows carry
    -- buttons to copy, rename and delete each layout; here "New Layout",
    -- "Change Name" and "Delete Layout" act on the one applied.
    _BuildLayoutRow = function(self, title)
        local caption = FontString(self)
        caption:SetSize(200, 12)
        caption:SetJustifyH("LEFT")
        caption:SetTextColor(1, 0.82, 0)
        caption:SetText(HUD_EDIT_MODE_LAYOUT)
        caption:Below(title, 12)
        caption:AlignParentLeft(22)

        self._layoutButton = DropdownSimple(self)
        self._layoutButton:SetSize(220, 22)
        self._layoutButton:Below(caption, 4)
        self._layoutButton:AlignParentLeft(20)

        -- The menu's popup is a root frame in this window's own strata: lift
        -- it over the window before its rows are made.
        self._layoutMenu = DropdownMenu(self._layoutButton, nil, self._layoutButton)
        self._layoutMenu.popup:SetFrameLevel(200)
        self._layoutMenu:SetMenuWidth(240)
        self._layoutButton.OnClick = function()
            self:_RefreshLayoutMenu()
            self._layoutMenu:Toggle()
        end
    end;

    -- The menu's rows. They are built again only when the layouts' names
    -- have changed: a menu's rows are frames, and frames are never freed.
    _RefreshLayoutMenu = function(self)
        local names = { PRESET_NAME }
        for i, layout in ipairs(MUI_DB.settings.editmodeLayouts.list) do
            names[i + 1] = layout.name
        end
        local signature = table.concat(names, "\n")
        if signature ~= self._menuSignature then
            self._menuSignature = signature

            local items = {}
            for i, name in ipairs(names) do
                items[i] = { type = "checkbox", label = name, closeOnClick = true, OnChanged = function()
                    -- The click ticked the row. The tick belongs on the
                    -- layout applied, which this one may not become (the
                    -- question about unsaved changes can be cancelled).
                    self:_SyncLayoutMenu()
                    MUI_EditMode:RequestLayout(i - 1)
                end }
            end
            tinsert(items, { type = "separator" })
            tinsert(items, { label = NEW_LAYOUT, OnClick = function() MUI_EditMode:PromptNewLayout() end })
            tinsert(items, { label = HUD_EDIT_MODE_RENAME_LAYOUT, OnClick = function() MUI_EditMode:PromptRenameLayout() end })
            tinsert(items, { label = HUD_EDIT_MODE_DELETE_LAYOUT, OnClick = function() MUI_EditMode:PromptDeleteLayout() end })
            tinsert(items, { type = "separator" })
            tinsert(items, { label = HUD_EDIT_MODE_IMPORT_LAYOUT, OnClick = function() MUI_EditMode:PromptImportLayout() end })
            tinsert(items, { label = HUD_EDIT_MODE_SHARE_LAYOUT, OnClick = function() MUI_EditMode:ShareLayout() end })
            self._layoutMenu:SetItems(items)
        end
        self:_SyncLayoutMenu()
    end;

    -- What the built rows show: the tick on the layout applied, and greyed
    -- what cannot be done now. As in retail a new layout takes there being
    -- room for one and nothing unsaved, and the preset can be neither renamed
    -- nor deleted.
    _SyncLayoutMenu = function(self)
        local layouts = MUI_DB.settings.editmodeLayouts
        local count = #layouts.list
        for index = 0, count do
            self._layoutMenu:SetItemChecked(index + 1, index == layouts.active)
        end

        -- Past the layouts' rows and the divider under them.
        local first = count + 3
        local full = count >= MAX_LAYOUTS
        local canAdd = not full and not MUI_EditMode:AnyDirty()
        self._layoutMenu:SetItemLabel(first, canAdd and NEW_LAYOUT or NEW_LAYOUT_DISABLED)
        self._layoutMenu:SetItemEnabled(first, canAdd)
        self._layoutMenu:SetItemEnabled(first + 1, layouts.active > 0)
        self._layoutMenu:SetItemEnabled(first + 2, layouts.active > 0)
        self._layoutMenu:SetItemEnabled(first + 4, not full)
    end;

    -- The dropdown names the layout that is applied.
    RefreshLayouts = function(self)
        local layouts = MUI_DB.settings.editmodeLayouts
        local layout = layouts.list[layouts.active]
        self._layoutButton:SetText(layout and layout.name or PRESET_NAME)
    end;

    -- Retail's list of checkboxes: the frames edit mode puts up only while
    -- theirs is ticked. Like the grid they are no part of a layout, and are
    -- kept as they are set.
    _BuildOptions = function(self)
        self._list = InnerFrame(self)
        self._list:HideBg()
        self._list:FillWidth(20)
        self._list:SetHeight(1)
        self._list:Below(self._chkSnap, 8)

        self._headings, self._checks = {}, {}
        for i, text in ipairs(OPTION_CATEGORIES) do
            local heading = FontString(self._list)
            heading:SetFontSize(13)
            heading:SetTextColor(1, 0.82, 0)
            heading:SetText(text)
            self._headings[i] = heading
        end
        for i, option in ipairs(OPTIONS) do
            local check = CheckBox(self._list, nil, option.text)
            check.label:SetFontSize(12)
            check:SetSize(OPTION_COLUMN_W - 8, OPTION_ROW_H)
            check:SetBoxSize(24, 24)
            check.OnChanged = function(_, checked)
                MUI_EditMode:SetOptionShown(option.key, checked)
            end
            self._checks[i] = check
        end
    end;

    -- Lay the list out and fit the window to it: the basic checkboxes in two
    -- columns or, with "Advanced Options", all of them under retail's
    -- headings. One with no frame to put up for this character (a pet bar, a
    -- stance bar) is left out.
    _LayoutOptions = function(self)
        local settings = MUI_DB.settings
        local advanced = settings.editmodeAdvanced
        for _, heading in ipairs(self._headings) do heading:Hide() end

        local y, column, category = OPTION_PAD, 0, nil
        for i, option in ipairs(OPTIONS) do
            local check = self._checks[i]
            local listed = (advanced or option.basic) and MUI_EditMode:HasOption(option.key)
            check:SetVisible(listed)
            if listed then
                if advanced and option.category ~= category then
                    -- A heading starts a line of its own.
                    category = option.category
                    if column > 0 then y, column = y + OPTION_ROW_H, 0 end
                    local heading = self._headings[category]
                    heading:ClearAllPoints()
                    heading:AlignParentTopLeft(y + 6, OPTION_PAD + 4)
                    heading:Show()
                    y = y + OPTION_HEADING_H
                end
                check:SetChecked(settings.editmodeShown[option.key])
                check:ClearAllPoints()
                check:AlignParentTopLeft(y, OPTION_PAD + column * OPTION_COLUMN_W)
                column = column + 1
                if column == 2 then y, column = y + OPTION_ROW_H, 0 end
            end
        end
        if column > 0 then y = y + OPTION_ROW_H end

        local height = y + OPTION_PAD
        self._list:SetHeight(height)
        -- Under the list: a gap, the two buttons, their margin.
        self:SetHeight(self:GetTop() - self._list:GetTop() + height + 50)
    end;

    -- Seed the controls from saved settings.
    SyncControls = function(self)
        local g = MUI_DB and MUI_DB.settings and MUI_DB.settings.editmodeGrid
        if not g then return end
        self._chkGrid:SetChecked(g.enabled)
        self._sliderGrid:SetValue(g.spacing)
        self._lblGridValue:SetText(g.spacing)
        self._chkSnap:SetChecked(MUI_DB.settings.editmodeSnap)
        self._chkAdvanced:SetChecked(MUI_DB.settings.editmodeAdvanced)
        self:RefreshLayouts()
        self:_LayoutOptions()
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

-- Retail's magnetism (EditModeMagnetismManager): a frame let go within reach
-- of something lines up with it, and while it is dragged red lines show where
-- it would land. What pulls, the nearest within SNAP_RANGE:
--   * along each axis, the screen's edges and middle and the grid's lines,
--     for the frame's edges and its middle;
--   * along each axis, another frame's edge for the edge turned to it, the
--     two frames level with each other on the other axis and apart on this;
--   * a corner of such a frame, for a corner of this one.
-- A corner comes first. Screen and grid lines pull along both axes at once;
-- when a frame is what pulls, only the nearer of the two axes' pulls is taken.
--
-- Rects are { left, right, bottom, top } in screen pixels.
local SNAP_RANGE       = 8
local SNAP_LINE_PIXELS = 1.5

class "EditModeSnap" : extends "Frame" {
    __init = function(self)
        Frame.__init(self, "Frame", MUI_Root, "MUI_EditModeSnap")
        -- Over the frames' edit overlays, under the settings panels.
        self:SetFrameStrata("FULLSCREEN")
        self:SetFrameLevel(100)
        self:FillParent()
        self._lines = {}
    end;

    -- Where a frame at `rect` would go if let go now. `targets` are the rects
    -- of the other frames, `spacing` the grid's (nil while it is off).
    -- Returns the move (dx, dy) and where the lines it would line up with run
    -- (x of an upright one, y of a level one; either may be nil). Nothing
    -- when nothing is within reach.
    Find = function(self, rect, targets, spacing)
        local scale = self:GetEffectiveScale()
        local screen = { self:GetLeft() * scale, self:GetRight() * scale,
                         self:GetBottom() * scale, self:GetTop() * scale }
        local step = spacing and spacing * scale

        local h, hFrame = self:_Axis(rect, screen, targets, 1, 3, step)
        local v, vFrame = self:_Axis(rect, screen, targets, 3, 1, step)

        local corner = self:_Corner(rect, hFrame)
        local other  = self:_Corner(rect, vFrame)
        if other and (not corner or other.distance <= corner.distance) then
            corner = other
        end
        if corner then
            return corner.dx, corner.dy, corner.x, corner.y
        end

        if h and v and h.onScreen and v.onScreen then
            return h.delta, v.delta, h.line, v.line
        elseif h and (not v or h.distance < v.distance) then
            return h.delta, 0, h.line, nil
        elseif v then
            return 0, v.delta, nil, v.line
        end
    end;

    -- The pull along one axis: `along` is 1 for x (a rect's [1], [2]) and 3
    -- for y ([3], [4]), `across` the other one; `step` is the distance
    -- between grid lines, counted out from the screen's middle.
    -- Returns the nearest pull within reach { delta, line, distance,
    -- onScreen }, and the nearest frame within reach, for its corners.
    _Axis = function(self, rect, screen, targets, along, across, step)
        local low, high = rect[along], rect[along + 1]
        local screenLow, screenHigh = screen[along], screen[along + 1]
        local mid, screenMid = (low + high) / 2, (screenLow + screenHigh) / 2

        -- The screen's edges and middle, then any grid line that is nearer.
        local distance, delta, line = math.huge, 0, nil
        local function try(source, target)
            local reach = math.abs(target - source)
            if reach < distance then
                distance, delta, line = reach, target - source, target
            end
        end
        try(low, screenLow)
        try(high, screenHigh)
        try(mid, screenMid)
        try(low, screenMid)
        try(high, screenMid)
        if step then
            local count = math.floor((screenHigh - screenLow) / step / 2)
            for _, source in ipairs({ low, high, mid }) do
                local index = math.floor((source - screenMid) / step + 0.5)
                try(source, screenMid + math.max(-count, math.min(count, index)) * step)
            end
        end

        local pull
        if distance <= SNAP_RANGE then
            pull = { delta = delta, line = line, distance = distance, onScreen = true }
        end

        -- Another frame's edge, for the edge of this one turned to it.
        local nearest, nearestDistance
        for _, target in ipairs(targets) do
            if rect[across + 1] >= target[across] and rect[across] <= target[across + 1] then
                local edge, source
                if target[along + 1] < low then
                    edge, source = target[along + 1], low
                elseif target[along] > high then
                    edge, source = target[along], high
                end
                local reach = edge and math.abs(edge - source)
                if reach and reach <= SNAP_RANGE then
                    if not pull or reach < pull.distance then
                        pull = { delta = edge - source, line = edge, distance = reach }
                    end
                    if not nearest or reach < nearestDistance then
                        nearest, nearestDistance = target, reach
                    end
                end
            end
        end
        return pull, nearest
    end;

    -- The nearest pair of corners of `rect` and `target` within reach. A pair
    -- on opposite sides both ways (top left to bottom right) is no snap: the
    -- frames would only touch at a point.
    _Corner = function(self, rect, target)
        if not target then return end
        local best
        for x = 1, 2 do
            for y = 3, 4 do
                for tx = 1, 2 do
                    for ty = 3, 4 do
                        if x == tx or y == ty then
                            local dx, dy = target[tx] - rect[x], target[ty] - rect[y]
                            local distance = math.sqrt(dx * dx + dy * dy)
                            if distance <= SNAP_RANGE * math.sqrt(2)
                                    and (not best or distance < best.distance) then
                                best = { dx = dx, dy = dy, x = target[tx], y = target[ty], distance = distance }
                            end
                        end
                    end
                end
            end
        end
        return best
    end;

    -- The lines a dragged frame would line up with: upright at screen `x`,
    -- level at screen `y`. Nil for none.
    ShowGuides = function(self, x, y)
        local scale = self:GetEffectiveScale()
        self:_Guide(1, x and x / scale - self:GetLeft(), true)
        self:_Guide(2, y and y / scale - self:GetBottom(), false)
    end;

    _Guide = function(self, index, offset, upright)
        local line = self._lines[index]
        if not offset then
            if line then line:Hide() end
            return
        end
        if not line then
            line = Line(self, nil, "OVERLAY")
            line:SetColorTexture(1, 0, 0, 1)
            self._lines[index] = line
        end
        line:SetThickness(PixelUtil.GetNearestPixelSize(
            SNAP_LINE_PIXELS, self:GetEffectiveScale(), SNAP_LINE_PIXELS))
        if upright then
            line:SetStartPoint("BOTTOMLEFT", self, offset, 0)
            line:SetEndPoint("TOPLEFT", self, offset, 0)
        else
            line:SetStartPoint("BOTTOMLEFT", self, 0, offset)
            line:SetEndPoint("BOTTOMRIGHT", self, 0, offset)
        end
        line:Show()
    end;
}

-- Arrow keys to the step they move the selected frame by.
local NUDGE = {
    UP    = {  0,  1 },
    DOWN  = {  0, -1 },
    LEFT  = { -1,  0 },
    RIGHT = {  1,  0 },
}

-- Edit mode's dialogs, all in one window: retail's questions (changes that
-- are not saved, deleting a layout) and its boxes for naming a layout and
-- for the text of one that is imported or shared. Blizzard's static popups
-- will not do here: they sit a strata under the settings window.
--
-- Open(options):
--   title                       the text across the top
--   code, codeLabel, codeHint   the wide box: its text to begin with, the
--                               caption over it, the hint in it while empty
--   readOnly                    the wide box holds on to its text, which is
--                               there to be copied
--   name, nameLabel             the name box: its text to begin with, the
--                               caption over it
--   accept, alt, cancel         the buttons' texts; one with none is left out
--   validate(name, code)        whether accept may be pressed and, when not,
--                               what to say about it (which may be nothing)
--   OnAccept(name, code), OnAlt()
local PROMPT_WIDTH, PROMPT_INNER = 400, 352
local PROMPT_BUTTON_W = 112

class "EditModePrompt" : extends "DiamondBorder" {
    __init = function(self)
        DiamondBorder.__init(self, MUI_Root, "MUI_EditModePrompt")
        -- Over the settings window (20), the frames' panels (100) and the
        -- dropdowns' menus (200).
        self:SetFrameStrata("FULLSCREEN_DIALOG")
        self:SetFrameLevel(300)
        self:SetWidth(PROMPT_WIDTH)
        self:AlignParentTop(190)
        self:EnableMouse(true)
        self:Hide()
        self._options = {}

        self._title = FontString(self)
        self._title:SetWidth(PROMPT_INNER)

        self._codeLabel = self:_Caption()
        self._code = self:_Box()
        self._nameLabel = self:_Caption()
        self._name = self:_Box()
        self._name:SetMaxLetters(30)

        self._error = FontString(self)
        self._error:SetFontSize(10.5)
        self._error:SetTextColor(1, 0.13, 0.13)
        self._error:SetWidth(PROMPT_INNER)

        self._accept = self:_Button(function() self:_Accept() end)
        self._alt = self:_Button(function()
            local options = self._options
            self:Hide()
            options.OnAlt()
        end)
        self._cancel = self:_Button(function() self:Hide() end)
    end;

    _Caption = function(self)
        local caption = FontString(self)
        caption:SetFontSize(10.5)
        caption:SetTextColor(1, 0.82, 0)
        caption:SetJustifyH("LEFT")
        caption:SetSize(PROMPT_INNER, 12)
        return caption
    end;

    -- An edit box: what is typed in it is checked, Enter accepts, Escape
    -- puts the dialog away.
    _Box = function(self)
        local box = EditBox(self)
        box:SetSize(PROMPT_INNER, 22)
        box.OnTextChanged = function() self:_OnTextChanged() end
        box.OnEnterPressed = function() self:_Accept() end
        box:HookScript("OnEscapePressed", function() self:Hide() end)
        return box
    end;

    _Button = function(self, onClick)
        local button = ButtonGold(self, nil, "")
        button:SetSize(PROMPT_BUTTON_W, 22)
        button.label:SetFontSize(10.5)
        button.OnClick = onClick
        return button
    end;

    Open = function(self, options)
        self._options = options
        self:Show()

        self._title:SetText(options.title)
        self._title:ClearAllPoints()
        self._title:AlignParentTop(20)
        local y = 20 + self._title:GetStringHeight() + 12

        self._code:SetHint(options.codeHint or "")
        y = self:_Seat(self._codeLabel, self._code, options.codeLabel, options.code, y)
        y = self:_Seat(self._nameLabel, self._name, options.nameLabel, options.name, y)

        self._error:SetVisible(options.validate ~= nil)
        if options.validate then
            self._error:ClearAllPoints()
            self._error:AlignParentTop(y)
            y = y + 18
        end

        -- The buttons it has, side by side and centred.
        local buttons = {}
        for _, pair in ipairs({ { self._accept, options.accept }, { self._alt, options.alt }, { self._cancel, options.cancel } }) do
            pair[1]:SetVisible(pair[2] ~= nil)
            if pair[2] then
                pair[1]:SetText(pair[2])
                tinsert(buttons, pair[1])
            end
        end
        for i, button in ipairs(buttons) do
            button:ClearAllPoints()
            button:AlignParentBottom(20, (i - (#buttons + 1) / 2) * (PROMPT_BUTTON_W + 8))
        end

        self:SetHeight(y + 48)
        self:_Validate()

        local focus = options.code and self._code or options.name and self._name
        if focus then
            focus:SetFocus()
            focus:HighlightText()
        end
    end;

    -- Put an edit box `y` down the dialog, under its caption when it has
    -- one, or both away when the dialog has no `text` for it. Returns where
    -- the next thing goes.
    _Seat = function(self, caption, box, captionText, text, y)
        caption:SetVisible(text ~= nil and captionText ~= nil)
        box:SetVisible(text ~= nil)
        if not text then return y end
        if captionText then
            caption:SetText(captionText)
            caption:ClearAllPoints()
            caption:AlignParentTop(y)
            y = y + 16
        end
        box:SetText(text)
        box:ClearAllPoints()
        box:AlignParentTop(y)
        return y + 30
    end;

    _OnTextChanged = function(self)
        local options = self._options
        if options.readOnly and self._code:GetText() ~= options.code then
            self._code:SetText(options.code)
            self._code:HighlightText()
        end
        self:_Validate()
    end;

    -- Accept can be pressed when the dialog checks nothing, or what it
    -- checks passes.
    _Validate = function(self)
        local validate = self._options.validate
        local ok, message = true, nil
        if validate then
            ok, message = validate(strtrim(self._name:GetText()), self._code:GetText())
        end
        self._accept:SetEnabled(ok)
        self._error:SetText(message or "")
    end;

    -- The dialog goes before what it was for is done: that may put up the
    -- next one.
    _Accept = function(self)
        local options = self._options
        local name, code = strtrim(self._name:GetText()), self._code:GetText()
        if options.validate and not options.validate(name, code) then return end
        self:Hide()
        if options.OnAccept then options.OnAccept(name, code) end
    end;
}

object "EditMode" {

    __init = function(self)
        self._registeredFrames = {}
        self._optionOf = {}       -- frame name → the key of the window checkbox it is under
        self._isActive = false

        self._grid = EditModeGrid()
        self._snap = EditModeSnap()
        self._prompt = EditModePrompt()

        self._settings = EditModeSettings()
        self._settings:HookScript("OnHide", function()
            self:_OnSettingsHidden()
        end)

        -- The arrow keys move the selected frame, as in retail. Only they are
        -- taken; every other key goes on to the game. A frame cannot change
        -- what it lets through once a fight is on, so the catcher shows out
        -- of combat only.
        self._keys = Frame("Frame", MUI_Root, "MUI_EditModeKeys")
        self._keys:SetSize(1, 1)
        self._keys:AlignParentTopLeft()
        self._keys:Hide()
        self._keys:SetScript("OnKeyDown", function(_, key) self:_OnKey(key) end)
        -- Every release goes through: a key held when an arrow was taken must
        -- still be let go of in the game.
        self._keys:SetScript("OnKeyUp", function() self._keys:SetPropagateKeyboardInput(true) end)

        -- Apply saved layouts once everything has registered: this watcher is
        -- created at file load, so it sees the first PLAYER_ENTERING_WORLD, after
        -- the module registry (MUI_Core, registered earlier) has run every
        -- OnEnable from that same event. Re-running on later world entries
        -- re-asserts user positions over any auto-relayout.
        self._watcher = Frame("Frame", nil, "MUI_EditModeWatcher")
        self._watcher:RegisterEventHandler("PLAYER_ENTERING_WORLD", function()
            self:LoadLayouts()
        end)
        -- A revert that hit combat (closed edit mode mid-fight) runs once safe.
        self._watcher:RegisterEventHandler("PLAYER_REGEN_ENABLED", function()
            if self._pendingRevert then self:_RevertSession() end
            self:_UpdateKeys()
        end)
        -- Fires before the lockdown does.
        self._watcher:RegisterEventHandler("PLAYER_REGEN_DISABLED", function()
            self._keys:Hide()
        end)
    end;

    Register = function(self, editable)
        local name = editable:GetName()
        self._registeredFrames[name] = editable
    end;

    -- Select `editable`; nil lets go of the one selected and puts its
    -- settings panel away.
    Select = function(self, editable)
        self._selected = editable
        for _, e in pairs(self._registeredFrames) do
            if e == editable then
                e:EditModeSelect()
            else
                e:EditModeDeselect()
            end

        end
        if not editable and ACTIVE_SETTING_PANEL then
            ACTIVE_SETTING_PANEL:Hide()
            ACTIVE_SETTING_PANEL = nil
        end
        self:_UpdateKeys()
    end;

    -- ---- arrow keys --------------------------------------------------------

    _UpdateKeys = function(self)
        local armed = self._selected ~= nil and not InCombatLockdown()
        if armed then self._keys:EnableKeyboard(true) end
        self._keys:SetVisible(armed)
    end;

    -- A step for an arrow key, ten with Shift held, in the screen's units.
    _OnKey = function(self, key)
        local step = NUDGE[key]
        self._keys:SetPropagateKeyboardInput(step == nil)
        if step then
            local reach = (IsShiftKeyDown() and 10 or 1) * MUI_Root:GetEffectiveScale()
            self._selected:EditModeNudge(step[1] * reach, step[2] * reach)
        end
    end;

    -- ---- snapping ----------------------------------------------------------

    SetSnapEnabled = function(self, enabled)
        MUI_DB.settings.editmodeSnap = enabled
    end;

    -- A drag of `editable` began. What it can snap to stays put for the
    -- drag's length, so it is listed once: the other frames in edit mode,
    -- less those that hang from the dragged one and move along with it.
    BeginDrag = function(self, editable)
        self._dragTargets = {}
        for _, other in pairs(self._registeredFrames) do
            if other ~= editable and other:EditModeIsShown() and not other:EditModeIsAnchoredTo(editable) then
                local rect = { other:EditModeGetRect() }
                if rect[1] then tinsert(self._dragTargets, rect) end
            end
        end
    end;

    -- Where the dragged frame would snap to, as EditModeSnap:Find returns it.
    _FindSnap = function(self, editable)
        if not (self._dragTargets and MUI_DB.settings.editmodeSnap) then return end
        local rect = { editable:EditModeGetRect() }
        if not rect[1] then return end
        local grid = MUI_DB.settings.editmodeGrid
        return self._snap:Find(rect, self._dragTargets, grid.enabled and grid.spacing)
    end;

    UpdateDrag = function(self, editable)
        local _, _, x, y = self:_FindSnap(editable)
        self._snap:ShowGuides(x, y)
    end;

    EndDrag = function(self, editable)
        local dx, dy = self:_FindSnap(editable)
        self._dragTargets = nil
        self._snap:ShowGuides(nil, nil)
        if dx then editable:EditModeMoveBy(dx, dy) end
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

    -- How the frames stand is the saved state now: there is nothing left to
    -- save or to reset, and "Reset changes" comes back to this.
    _CommitBaselines = function(self)
        for _, editable in pairs(self._registeredFrames) do
            editable:EditModeCommitBaseline()
        end
        self._settings:SetSaveEnabled(false)
        self._settings:SetResetEnabled(false)
        if ACTIVE_SETTING_PANEL then ACTIVE_SETTING_PANEL:RefreshButtons() end
    end;

    -- Persist every frame's current layout into the layout that is applied.
    -- The preset is not written to: as in retail, saving it asks for a name
    -- and makes a new layout of how the frames stand. `done` runs once the
    -- saving is done, which it is not when that naming is called off.
    Save = function(self, done)
        local frames = self:_ActiveFrames()
        if not frames then
            self:PromptNewLayout(done)
            return
        end
        for name, editable in pairs(self._registeredFrames) do
            frames[name] = editable:EditModeGetLayout()   -- nil clears the entry
        end
        self:_CommitBaselines()
        if done then done() end
    end;

    -- Apply persisted layouts to registered frames (PLAYER_ENTERING_WORLD).
    LoadLayouts = function(self)
        local frames = self:_ActiveFrames()
        if not frames then return end
        for name, data in pairs(frames) do
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
            local frames = self:_ActiveFrames()
            local data = frames and frames[editable:GetName()]
            if data then editable:EditModeApplyLayout(data) end
        else
            editable:_EditModeApplyDefault()
        end
    end;

    -- ---- layouts -----------------------------------------------------------

    -- The frames of the layout that is applied, by frame name; nil while
    -- that is the preset.
    _ActiveFrames = function(self)
        local layouts = MUI_DB and MUI_DB.settings and MUI_DB.settings.editmodeLayouts
        local layout = layouts and layouts.list[layouts.active]
        return layout and layout.frames
    end;

    -- A layout's name: `index` among the saved ones, 0 for the preset.
    GetLayoutName = function(self, index)
        local layout = MUI_DB.settings.editmodeLayouts.list[index]
        return layout and layout.name or LAYOUT_STYLE_MODERN
    end;

    -- Every frame's layout as it stands, by frame name: what a layout holds.
    _Capture = function(self)
        local frames = {}
        for name, editable in pairs(self._registeredFrames) do
            frames[name] = editable:EditModeGetLayout()
        end
        return frames
    end;

    -- Add a layout. Returns its index.
    _AddLayout = function(self, name, frames)
        local list = MUI_DB.settings.editmodeLayouts.list
        tinsert(list, { name = name, frames = frames })
        return #list
    end;

    -- Whether a layout may take `name`, and when not, what to say about it
    -- (nothing for a name not yet typed).
    _CheckName = function(self, name)
        if name == "" then return false end
        for _, layout in ipairs(MUI_DB.settings.editmodeLayouts.list) do
            if layout.name == name then return false, HUD_EDIT_MODE_ERROR_DUPLICATE_NAME end
        end
        return true
    end;

    -- The same for a layout that is yet to be made: there has to be room.
    _CheckNewName = function(self, name)
        if #MUI_DB.settings.editmodeLayouts.list >= MAX_LAYOUTS then
            return false, MAX_LAYOUTS_TEXT
        end
        return self:_CheckName(name)
    end;

    -- A layout was picked in the window's dropdown. Changes that are not
    -- saved are asked about first, as in retail.
    RequestLayout = function(self, index)
        if index == MUI_DB.settings.editmodeLayouts.active then return end
        if self:AnyDirty() then
            self:_AskUnsaved(index)
        else
            self:SelectLayout(index)
        end
    end;

    -- Apply the layout at `index` (0: the preset): every frame stands as it
    -- has it, and that is the saved state. Changes that were not saved are
    -- gone. Not in a fight: bars with secure buttons on them cannot move.
    SelectLayout = function(self, index)
        if InCombatLockdown() then
            UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1)
            return
        end
        self:Select(nil)
        MUI_DB.settings.editmodeLayouts.active = index
        local frames = self:_ActiveFrames() or {}
        for name, editable in pairs(self._registeredFrames) do
            editable:EditModeSetLayout(frames[name])
        end
        self:_CommitBaselines()
        self._settings:RefreshLayouts()
        MUI.Print(YELLOW_FONT_COLOR:WrapTextInColorCode(HUD_EDIT_MODE_LAYOUT_APPLIED:format(self:GetLayoutName(index))))
    end;

    -- Retail's question before changes that are not saved are dropped: on
    -- the way out of edit mode, or on the way to the layout at `index`.
    _AskUnsaved = function(self, index)
        local function proceed()
            if index then self:SelectLayout(index) else self:Exit() end
        end
        self:Select(nil)
        self._prompt:Open({
            title    = index and HUD_EDIT_MODE_UNSAVED_CHANGES_LAYOUT_CHANGE_DIALOG_TITLE
                              or HUD_EDIT_MODE_UNSAVED_CHANGES_EXIT_DIALOG_TITLE,
            accept   = index and HUD_EDIT_MODE_SAVE_AND_SWITCH or HUD_EDIT_MODE_SAVE_AND_EXIT,
            alt      = index and HUD_EDIT_MODE_SWITCH or HUD_EDIT_MODE_EXIT,
            cancel   = CANCEL,
            OnAccept = function() self:Save(proceed) end,
            OnAlt    = proceed,
        })
    end;

    -- Retail's "Name the New Layout": a layout of how the frames stand now,
    -- which becomes the one applied. `done` runs once it is made.
    PromptNewLayout = function(self, done)
        self:Select(nil)
        self._prompt:Open({
            title    = HUD_EDIT_MODE_NAME_LAYOUT_DIALOG_TITLE,
            name     = "",
            accept   = SAVE,
            cancel   = CANCEL,
            validate = function(name) return self:_CheckNewName(name) end,
            OnAccept = function(name)
                MUI_DB.settings.editmodeLayouts.active = self:_AddLayout(name, self:_Capture())
                self:_CommitBaselines()
                self._settings:RefreshLayouts()
                if done then done() end
            end,
        })
    end;

    -- Another name for the layout that is applied.
    PromptRenameLayout = function(self)
        local layouts = MUI_DB.settings.editmodeLayouts
        local layout = layouts.list[layouts.active]
        self:Select(nil)
        self._prompt:Open({
            title    = HUD_EDIT_MODE_RENAME_LAYOUT_DIALOG_TITLE:format(layout.name),
            name     = layout.name,
            accept   = SAVE,
            cancel   = CANCEL,
            -- The name it has is no error, only nothing to save.
            validate = function(name)
                if name == layout.name then return false end
                return self:_CheckName(name)
            end,
            OnAccept = function(name)
                layout.name = name
                self._settings:RefreshLayouts()
            end,
        })
    end;

    -- Delete the layout that is applied, once the user is sure. The preset
    -- takes its place, as in retail.
    PromptDeleteLayout = function(self)
        local layouts = MUI_DB.settings.editmodeLayouts
        local index = layouts.active
        self:Select(nil)
        self._prompt:Open({
            title    = HUD_EDIT_MODE_DELETE_LAYOUT_DIALOG_TITLE:format(layouts.list[index].name),
            accept   = YES,
            cancel   = NO,
            OnAccept = function()
                -- The frames go back to the preset with it, which they
                -- cannot in a fight.
                if InCombatLockdown() then
                    UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1)
                    return
                end
                tremove(layouts.list, index)
                self:SelectLayout(0)
            end,
        })
    end;

    -- Retail's "Import Layout": a layout from its text, under a name of the
    -- user's choosing, applied at once.
    PromptImportLayout = function(self)
        self:Select(nil)
        self._prompt:Open({
            title     = HUD_EDIT_MODE_IMPORT_LAYOUT_DIALOG_TITLE,
            code      = "",
            codeLabel = HUD_EDIT_MODE_IMPORT_LAYOUT_DIALOG_EDIT_BOX_LABEL,
            codeHint  = HUD_EDIT_MODE_IMPORT_LAYOUT_INSTRUCTIONS,
            name      = "",
            nameLabel = HUD_EDIT_MODE_IMPORT_LAYOUT_LINK_DIALOG_EDIT_BOX_LABEL,
            accept    = HUD_EDIT_MODE_IMPORT_LAYOUT,
            cancel    = CANCEL,
            validate  = function(name, code)
                if strtrim(code) == "" then return false end
                if not self:_Decode(code) then
                    return false, HUD_EDIT_MODE_ERROR_ENTER_IMPORT_STRING_AND_NAME
                end
                return self:_CheckNewName(name)
            end,
            OnAccept  = function(name, code)
                self:SelectLayout(self:_AddLayout(name, self:_Decode(code)))
            end,
        })
    end;

    -- Retail's "Share": the frames as they stand, as text. Retail puts it on
    -- the clipboard; an addon may not, so it is shown selected, to be copied.
    ShareLayout = function(self)
        self:Select(nil)
        self._prompt:Open({
            title     = HUD_EDIT_MODE_COPY_TO_CLIPBOARD,
            code      = self:_Encode(self:_Capture()),
            codeLabel = "Press Ctrl+C to copy:",
            readOnly  = true,
            cancel    = CLOSE,
        })
    end;

    -- A layout's frames as text that can be passed around.
    _Encode = function(self, frames)
        return SHARE_PREFIX .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.SerializeCBOR(frames))
    end;

    -- The frames of a layout from its text, or nil when the text is not one
    -- of ours. It is someone else's text: only frames we have are taken,
    -- each cut down to what it would save itself (EditModeCleanLayout).
    _Decode = function(self, text)
        -- Copied off a page it can come with breaks and spaces in it.
        text = gsub(text, "%s+", "")
        if strsub(text, 1, #SHARE_PREFIX) ~= SHARE_PREFIX then return end
        local ok, data = pcall(function()
            return C_EncodingUtil.DeserializeCBOR(C_EncodingUtil.DecodeBase64(strsub(text, #SHARE_PREFIX + 1)))
        end)
        if not ok or type(data) ~= "table" then return end

        local frames = {}
        for name, editable in pairs(self._registeredFrames) do
            if type(data[name]) == "table" then
                local clean = editable:EditModeCleanLayout(data[name])
                if next(clean) then frames[name] = clean end
            end
        end
        return frames
    end;

    -- ---- the window's checkboxes -------------------------------------------

    SetOption = function(self, editable, key)
        self._optionOf[editable:GetName()] = key
    end;

    -- Whether a checkbox has anything to put up: one of the frames under it
    -- is in edit mode for this character.
    HasOption = function(self, key)
        for name, editable in pairs(self._registeredFrames) do
            if self._optionOf[name] == key and editable:EditModeIsEnabled() then return true end
        end
        return false
    end;

    -- A checkbox was ticked or unticked: its frames are put up for editing,
    -- or put away.
    SetOptionShown = function(self, key, shown)
        MUI_DB.settings.editmodeShown[key] = shown
        for name, editable in pairs(self._registeredFrames) do
            if self._optionOf[name] == key then
                if shown then
                    self:_Show(editable)
                else
                    if editable == self._selected then self:Select(nil) end
                    editable:EditModeHide()
                end
            end
        end
    end;

    -- Whether edit mode takes a frame: one under a checkbox of the window
    -- stays out while that is unticked.
    _IsWanted = function(self, name)
        local key = self._optionOf[name]
        return not key or MUI_DB.settings.editmodeShown[key]
    end;

    -- Put a frame up for editing. Showing may first set it up (the loot
    -- window is seated where it opens): where that leaves a frame with
    -- nothing unsaved is what "Reset changes" takes it back to.
    _Show = function(self, editable)
        local dirty = editable:EditModeIsDirty()
        editable:EditModeShow()
        if not dirty then editable:EditModeCommitBaseline() end
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

    -- How every frame stands as edit mode opens is what "Reset changes" goes
    -- back to, the frames that are not put up included: their checkbox may
    -- be ticked later.
    Start = function(self)
        self._isActive = true
        for name, editable in pairs(self._registeredFrames) do
            editable:EditModeCommitBaseline()
            if self:_IsWanted(name) then self:_Show(editable) end
        end
        self:ApplyGrid()
        self._settings:SetResetEnabled(false)
        self._settings:SetSaveEnabled(false)
        self._settings:Show()
    end;

    -- The settings window went away: its close button, or Escape. With a
    -- dialog up it is the dialog that goes; with changes that are not saved
    -- the window comes back and retail's question is asked.
    _OnSettingsHidden = function(self)
        if self._isActive and not self._exiting then
            if self._prompt:IsShown() then
                self._settings:Show()
                self._prompt:Hide()
                return
            elseif self:AnyDirty() then
                self._settings:Show()
                self:_AskUnsaved()
                return
            end
        end
        self:_Stop()
    end;

    -- Leave edit mode. Changes that are not saved are dropped.
    Exit = function(self)
        self._exiting = true
        self._settings:Hide()
        self._exiting = false
    end;

    _Stop = function(self)
        self._isActive = false
        self._selected = nil
        self._dragTargets = nil
        self._grid:Hide()
        self._snap:ShowGuides(nil, nil)
        self:_UpdateKeys()
        self._prompt:Hide()

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