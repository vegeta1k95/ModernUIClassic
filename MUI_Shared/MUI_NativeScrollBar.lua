-- NativeScrollBar: retail's minimal scroll bar art on the slider of one of
-- Blizzard's scroll frames (FauxScrollFrame, HybridScrollFrame, and the plain
-- UIPanelScrollFrameTemplate a window's text scrolls in).
--
-- The slider, its thumb and its two arrow buttons stay Blizzard's and keep
-- taking the mouse. A scroll started from addon code would run Blizzard's
-- list update tainted, and what that writes — the scroll offset, the selected
-- tab — is read again by the code that opens the window. So this is art only:
-- the slider is moved onto a track of ours, its buttons are re-textured, and
-- its one-piece thumb is made transparent under three pieces that ride on it.
--
-- The track is a frame of ours, so it stays up when Blizzard hides the slider
-- of a list too short to scroll.

local ARROWS       = MUI_AtlasRegistry.ScrollbarMinimalProportional
local TRACK_MIDDLE = MUI_AtlasRegistry.ScrollbarMinimalVertical
local THUMB_CAPS   = MUI_AtlasRegistry.ScrollbarMinimalSmallProportional
local THUMB_MIDDLE = MUI_AtlasRegistry.ScrollbarMinimalSmallVertical

local WIDTH = 8
local ARROW_W, ARROW_H, ARROW_GAP = 17, 11, 4
local THUMB_MIN = 23

-- Bars by the scroll frame they belong to, for the hooks below.
local bars = {}

local function UpdateFor(scrollFrame)
    local bar = bars[scrollFrame]
    if bar then bar:Update() end
end

class "NativeScrollBar" : extends "Frame" {

    -- `scrollFrame` / `slider`: Blizzard's pair. `height`: the whole bar's,
    -- arrows included.
    __init = function(self, parent, scrollFrame, slider, height)
        Frame.__init(self, "Frame", parent)
        self:SetSize(WIDTH, height)
        self._scroll = Frame(scrollFrame)
        self._slider = Slider(slider)

        -- The classic track is drawn on the scroll frame itself; the slider
        -- has its thumb and, on some templates, a backing.
        for _, region in ipairs(self._scroll:GetRegions()) do
            region:Hide()
        end
        for _, region in ipairs(self._slider:GetRegions()) do
            region:SetAlpha(0)
        end

        self:_BuildTrack()
        self._slider:ClearAllPoints()
        self._slider:Fill(self, 0, ARROW_H + ARROW_GAP, 0, ARROW_H + ARROW_GAP)
        self:_SkinButton("ScrollUpButton", "ArrowTop", true)
        self:_SkinButton("ScrollDownButton", "ArrowBottom", false)
        self:_BuildThumb()

        if not next(bars) then self:_HookTemplates() end
        bars[scrollFrame] = self
        -- A plain scroll frame sets its slider's range from its own script,
        -- as its content grows and shrinks.
        self._scroll:HookScript("OnScrollRangeChanged", function() self:Update() end)
        self:Update()
    end;

    -- Once, for every bar: the two functions that set a list's slider range.
    _HookTemplates = function(self)
        hooksecurefunc("FauxScrollFrame_Update", UpdateFor)
        hooksecurefunc("HybridScrollFrame_Update", UpdateFor)
    end;

    -- The track, and the arrows greyed for while Blizzard's own are hidden.
    _BuildTrack = function(self)
        local up = Texture(self, nil, "ARTWORK")
        up:SetAtlas(ARROWS, "ArrowTop")
        up:AlignParentTop(0)
        up:SetAlpha(0.5)
        local down = Texture(self, nil, "ARTWORK")
        down:SetAtlas(ARROWS, "ArrowBottom")
        down:AlignParentBottom(0)
        down:SetAlpha(0.5)

        local top = Texture(self, nil, "BACKGROUND")
        top:SetAtlas(ARROWS, "TrackTop")
        top:Below(up, ARROW_GAP)
        local bottom = Texture(self, nil, "BACKGROUND")
        bottom:SetAtlas(ARROWS, "TrackBottom")
        bottom:Above(down, ARROW_GAP)
        local middle = Texture(self, nil, "BACKGROUND")
        middle:SetAtlas(TRACK_MIDDLE, "TrackMiddle")
        middle:FillBetweenV(top, bottom)
    end;

    -- One of the slider's arrow buttons, at either end of the track.
    _SkinButton = function(self, name, art, above)
        local button = Button(_G[self._slider:GetName() .. name])
        button:SetStateAtlas(ARROWS, art, art .. "Down", art)
        button:SetHighlightAtlas(ARROWS, art .. "Over")
        button:GetDisabledTexture():SetAlpha(0.5)
        button:SetSize(ARROW_W, ARROW_H)
        button:ClearAllPoints()
        if above then
            button:Above(self._slider, ARROW_GAP)
        else
            button:Below(self._slider, ARROW_GAP)
        end
    end;

    -- Caps and a middle that follow Blizzard's thumb, whose height is ours
    -- to set: the client keeps it inside the slider whatever its size.
    _BuildThumb = function(self)
        self._nativeThumb = Texture(_G[self._slider:GetName() .. "ThumbTexture"])
        self._nativeThumb:SetWidth(WIDTH)

        local top = Texture(self._slider, nil, "ARTWORK")
        top:SetAtlas(THUMB_CAPS, "ThumbTop")
        top:AlignTop(self._nativeThumb)
        local bottom = Texture(self._slider, nil, "ARTWORK")
        bottom:SetAtlas(THUMB_CAPS, "ThumbBottom")
        bottom:AlignBottom(self._nativeThumb)
        local middle = Texture(self._slider, nil, "ARTWORK")
        middle:SetAtlas(THUMB_MIDDLE, "ThumbMiddle", true)
        middle:FillBetweenV(top, bottom)
        self._thumb = { top, middle, bottom }
    end;

    -- A list too short to scroll: Blizzard hides a faux scroll frame and
    -- disables a hybrid one's slider, leaving the old range on either.
    Update = function(self)
        local range = 0
        if self._scroll:IsShown() and self._slider:IsEnabled() then
            local _, max = self._slider:GetMinMaxValues()
            range = max
        end
        for _, piece in ipairs(self._thumb) do
            piece:SetVisible(range > 0)
        end
        if range > 0 then
            local view  = self._scroll:GetHeight()
            local track = self:GetHeight() - 2 * (ARROW_H + ARROW_GAP)
            local share = math.min(view / (view + range), 0.8)
            self._nativeThumb:SetHeight(math.max(THUMB_MIN, track * share))
        end
    end;
}

-- ---------------------------------------------------------------------
-- ScrollBoxBar: the same art on a WowClassicScrollBar, the classic-skinned
-- bar Era gives its ScrollBox lists. That bar's Lua sets its art again, by
-- atlas, on every state change, so its pieces are made transparent rather
-- than re-textured and ours sit on the same frames: the track, the thumb
-- button (a fixed 24 tall on this template) and the two steppers.
-- ---------------------------------------------------------------------
class "ScrollBoxBar" : extends "Frame" {

    __init = function(self, native)
        Frame.__init(self, native)
        self:SetWidth(ARROW_W)
        self:_Clear(self)
        Frame(native.Background):SetAlpha(0)

        local track = Frame(native.Track)
        track:ClearAllPoints()
        track:SetWidth(WIDTH)
        track:AlignParentTop(ARROW_H + ARROW_GAP)
        track:AlignParentBottom(ARROW_H + ARROW_GAP)
        self:_Pieces(track, ARROWS, "TrackTop", ARROWS, "TrackBottom", TRACK_MIDDLE, "TrackMiddle")

        -- The bar's Lua seats the thumb by its top left corner on every
        -- update; the template's own anchor holds it right of the track.
        local thumb = Frame(native.Track.Thumb)
        self:_Clear(thumb)
        thumb:ClearAllPoints()
        thumb:AlignParentTopLeft()
        thumb:SetWidth(WIDTH)
        self:_Pieces(thumb, THUMB_CAPS, "ThumbTop", THUMB_CAPS, "ThumbBottom", THUMB_MIDDLE, "ThumbMiddle")

        self:_Stepper(native.Back, "ArrowTop", true)
        self:_Stepper(native.Forward, "ArrowBottom", false)
    end;

    _Clear = function(self, frame)
        for _, region in ipairs(frame:GetRegions()) do
            region:SetAlpha(0)
        end
    end;

    -- A top cap, a bottom cap and the run between, down the middle of `frame`.
    _Pieces = function(self, frame, topAtlas, top, bottomAtlas, bottom, middleAtlas, middle)
        local first = Texture(frame, nil, "ARTWORK")
        first:SetAtlas(topAtlas, top)
        first:AlignParentTop()
        local last = Texture(frame, nil, "ARTWORK")
        last:SetAtlas(bottomAtlas, bottom)
        last:AlignParentBottom()
        local run = Texture(frame, nil, "ARTWORK")
        run:SetAtlas(middleAtlas, middle, true)
        run:FillBetweenV(first, last)
    end;

    _Stepper = function(self, native, art, top)
        local button = Frame(native)
        self:_Clear(button)
        button:SetSize(ARROW_W, ARROW_H)
        button:ClearAllPoints()
        if top then
            button:AlignParentTop()
        else
            button:AlignParentBottom()
        end

        local arrow = Texture(button, nil, "ARTWORK")
        arrow:SetAtlas(ARROWS, art)
        arrow:CenterInParent()
        local hover = Texture(button, nil, "HIGHLIGHT")
        hover:SetAtlas(ARROWS, art .. "Over")
        hover:CenterInParent()
        button:HookScript("OnMouseDown", function() arrow:SetAtlas(ARROWS, art .. "Down") end)
        button:HookScript("OnMouseUp", function() arrow:SetAtlas(ARROWS, art) end)
    end;
}
