-- PanelChrome: reskin an EXISTING Era ButtonFrameTemplate / PortraitFrameTemplate
-- window IN PLACE to retail's modern chrome:
--   * keep & re-texture f.NineSlice  → retail metal frame (portrait ring or plain)
--   * keep & re-texture f.Bg         → tiled rock body
--   * keep & re-texture f.TopTileStreaks → the streak band under the title
--   * hide the classic border pieces; modern red X close button.
--
-- We never replace the native frame or its logic — only swap visuals — so the
-- window stays ESC / UIPanel-managed. Every op is texture SetTexture/SetAtlas +
-- Show/Hide + frame level (never protected), so callers may re-assert on OnShow.
--
-- MUI ships the same source sheets retail uses (FrameMetal* = FDIDs
-- 2406979/2406984/2406987; rock = 374155; TopTileStreaks = 1723833), so this is
-- pure data + wrappers — no new art.
--
-- Apply(native, opts) — opts (all optional):
--   noPortrait    use the plain metal top-left corner (no portrait ring) and hide
--                 the (empty) PortraitContainer. For frames with no meaningful
--                 portrait — AddonList, SettingsPanel, HelpFrame, etc.
--   skipClose     don't modernize a close button here — the caller reskins a
--                 non-default X itself via ModernizeCloseButton(frame, button)
--                 (e.g. SettingsPanel's X is .ClosePanelButton, not .CloseButton).

local ROCK = MUI.TEX_BASE .. "frame-background-rock"

-- ButtonFrameTemplate / PortraitFrameTemplate classic border pieces to hide so
-- our modern nineslice shows through. NineSlice / Bg / TopTileStreaks /
-- PortraitContainer / Inset are deliberately ABSENT — we KEEP and re-texture them.
local BORDER_KEYS = {
    "PortraitFrame", "TopRightCorner", "TopBorder", "TopLeftCorner",
    "BotLeftCorner", "BotRightCorner", "BottomBorder", "LeftBorder",
    "RightBorder", "TitleBg",
}

-- A native field may be a Texture on one template and a Frame on another
-- (ButtonFrameTemplate.Bg is a Texture; SettingsFrameTemplate.Bg is a flat-panel
-- Frame). Only wrap/re-texture when it's the type we expect.
local function isType(obj, objType)
    return obj and obj.GetObjectType and obj:GetObjectType() == objType
end

-- Retail metal nineslice over MUI's metal atlases (the same source sheets retail
-- ships). Only the top-left corner art + left overhang differ between the
-- portrait (ring, x=-13) and plain (x=-8) variants; the rest is shared.
local function metalLayout(topLeftRegion, leftX)
    local corners = MUI_AtlasRegistry.FrameMetalCorners
    local edgesTB = MUI_AtlasRegistry.FrameMetalEdgesTB
    local edgesLR = MUI_AtlasRegistry.FrameMetalEdgesLR
    return {
        TopLeft     = { atlas = corners, region = topLeftRegion,       width = 75, height = 75, x = leftX, y = 16 },
        Top         = { atlas = edgesTB, region = "EdgeTop",                       height = 75 },
        TopRight    = { atlas = corners, region = "CornerTopRight",    width = 75, height = 75, x = 4, y = 16 },
        Left        = { atlas = edgesLR, region = "EdgeLeft",          width = 75 },
        Right       = { atlas = edgesLR, region = "EdgeRight",         width = 75 },
        BottomLeft  = { atlas = corners, region = "CornerBottomLeft",  width = 32, height = 32, x = leftX, y = -3 },
        Bottom      = { atlas = edgesTB, region = "EdgeBottom",                    height = 32 },
        BottomRight = { atlas = corners, region = "CornerBottomRight", width = 32, height = 32, x = 4, y = -3 },
    }
end

object "PanelChrome" {

    -- Idempotent full re-assert. Safe to call on every frame open.
    Apply = function(self, native, opts)
        opts = opts or {}
        self:HideClassicChrome(native, opts)
        self:ApplyChrome(native, opts)
        if not opts.skipClose then
            self:ModernizeCloseButton(native)
        end
    end;

    -- Hide the classic chrome: the named border pieces + every BACKGROUND-layer
    -- texture (Era's classic bg + name-collision backgrounds). ApplyChrome
    -- re-textures and re-shows f.Bg afterwards.
    HideClassicChrome = function(self, native, opts)
        if not native then return end
        opts = opts or {}
        for _, key in ipairs(BORDER_KEYS) do
            local r = native[key]
            if r and r.Hide then Frame(r):Hide() end
        end
        -- No portrait → drop the (now empty) portrait holder too.
        if opts.noPortrait and native.PortraitContainer then
            Frame(native.PortraitContainer):Hide()
        end
        for _, r in ipairs(Frame(native):GetRegions()) do
            if r:GetObjectType() == "Texture" and r:GetDrawLayer() == "BACKGROUND" then
                r:Hide()
            end
        end
    end;

    ApplyChrome = function(self, native, opts)
        if not native then return end
        opts = opts or {}
        local frame = Frame(native)

        -- Body → tiled rock. Only when Bg is a TEXTURE (ButtonFrameTemplate);
        -- SettingsFrameTemplate's Bg is a flat-panel FRAME — leave it as the dark
        -- backing (that's the retail Settings look anyway).
        if isType(native.Bg, "Texture") then
            local bg = Texture(native.Bg)
            bg:SetTexture(ROCK, "REPEAT", "REPEAT")
            bg:SetHorizTile(true)
            bg:SetVertTile(true)
            bg:Show()
        end

        -- Metal nineslice, hosted INSIDE the inherited NineSlice container (classic
        -- pieces hidden, modern pieces added) — re-textured in place, not overlaid.
        if native.NineSlice then
            local ns = Frame(native.NineSlice)
            ns:Show()
            -- Hide only TEXTURE regions (the classic nineslice pieces) so a title
            -- FontString living on the nineslice (SettingsFrameTemplate.NineSlice.Text)
            -- isn't destroyed.
            for _, r in ipairs(ns:GetRegions()) do
                if r:GetObjectType() == "Texture" then r:Hide() end
            end
            if not native._muiChromeBorder then
                local layout = opts.noPortrait
                    and metalLayout("CornerTopLeft", -8)
                    or  metalLayout("CornerTopLeftPortrait", -13)
                local border = NineSlice(ns)
                border:FillParent()
                border:SetLayout(layout)
                native._muiChromeBorder = border
            end
        end

        -- Streak band under the title (ButtonFrameTemplate only; not on SettingsFrameTemplate).
        if isType(native.TopTileStreaks, "Texture") then
            local streaks = Texture(native.TopTileStreaks)
            streaks:SetAtlas(MUI_AtlasRegistry.FrameInnerHorizontal, "TopTileStreaks", true)
            streaks:SetHorizTile(true)
            streaks:SetHeight(43)
            streaks:Show()
        end

        -- Retail PortraitFrameMixin layering (nineslice above content). No-op if
        -- Era's frame lacks the mixin.
        frame:SetFrameLevelsFromBaseLevel(1)
    end;

    -- Modern red X (retail RedButton-Exit family). Reskins the native close button
    -- in place so its secure OnClick keeps working in combat. `override` lets the
    -- caller point at a non-default X (SettingsPanel.ClosePanelButton).
    ModernizeCloseButton = function(self, native, override)
        local cb = override or (native and native.CloseButton)
        if not cb then return end
        local btn = Button(cb)
        local atlas = MUI_AtlasRegistry.ButtonRedControl
        btn:SetStateAtlas(atlas, "ExitNormal", "ExitPressed", "ExitDisabled")
        btn:SetHighlightAtlas(atlas, "Highlight", true)
        btn:SetSize(24, 24)
        btn:ClearAllPoints()
        btn:SetPoint("TOPRIGHT", Frame(native), "TOPRIGHT", 1, 0)
        -- Above the metal frame so the X is never buried under the nineslice.
        if native._muiChromeBorder then
            btn:SetFrameLevel(native._muiChromeBorder:GetFrameLevel() + 5)
        end
    end;

    -- Re-host the window title above the border. The template's own title
    -- FontString draws UNDER our nineslice (ButtonFrameTemplate's .TitleText is on
    -- the frame's OVERLAY; SettingsFrameTemplate's is NineSlice.Text), so we hide
    -- it and put our own on a high-level child. Pass `text` to set it explicitly
    -- (Era's MailFrame title path is dead → caller passes INBOX, etc.); omit it to
    -- mirror whatever the native title currently says (AddonList, SettingsPanel —
    -- Blizzard sets those).
    SetTitle = function(self, native, text)
        if not native then return end

        -- The native title FontString(s) — location varies by template.
        local natives = {}
        local tc = native.TitleContainer
        if tc and tc.TitleText then natives[#natives + 1] = tc.TitleText end
        if native.TitleText then natives[#natives + 1] = native.TitleText end
        if native.NineSlice and native.NineSlice.Text then natives[#natives + 1] = native.NineSlice.Text end

        -- Mirror the native text when the caller doesn't pass one.
        if text == nil then
            for _, fs in ipairs(natives) do
                local t = fs.GetText and fs:GetText()
                if t and t ~= "" then text = t; break end
            end
        end

        -- Hide the natives (they draw under our border) and host our own above it.
        for _, fs in ipairs(natives) do
            if fs.Hide then Frame(fs):Hide() end
        end

        if not native._muiTitle then
            local host = Frame("Frame", Frame(native))
            host:FillParent()
            local base = (native._muiChromeBorder and native._muiChromeBorder:GetFrameLevel())
                         or Frame(native):GetFrameLevel()
            host:SetFrameLevel(base + 10)
            -- Anchors mirror the retail title (TOP -5, 60px side insets, centered).
            local fs = FontString(host, nil, "OVERLAY")
            fs:SetFontSize(12)
            fs:SetTextColor(1, 0.82, 0, 1)
            fs:SetJustifyH("CENTER")
            fs:AlignParentTop(6, 0)
            fs:AlignParentLeft(60)
            fs:AlignParentRight(60)
            native._muiTitleHost = host
            native._muiTitle = fs
        end
        native._muiTitle:SetText(text or "")
    end;
}
