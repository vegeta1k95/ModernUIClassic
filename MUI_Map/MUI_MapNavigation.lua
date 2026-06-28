-- MUI_MapNavigation: NavBar widget for the WorldMapFrame reskin.
--
-- Mirrors retail's CS_HelpTextures-driven NavBar (World → Azeroth → …) but
-- wired against Era's MapCanvas API (C_Map.GetMapInfo / SetMapID). Single
-- sprite sheet pair: navigation-textures.tga (512×128, non-tile) +
-- navigation-textures-tile.tga (128×512, horiz-tile strips for bar bg
-- and button states).
--
-- Public surface used by MUI_Map:
--   MapNavBar(parent, name)  — instantiates the whole bar
--   navBar:Refresh()         — rebuild crumbs from current WorldMapFrame:GetMapID()

local NAV_TEX      = MUI.TEX_SKIN .. "worldmap\\navigation-textures"
local NAV_TEX_TILE = MUI.TEX_SKIN .. "worldmap\\navigation-textures-tile"

-- Texcoords copied verbatim from retail Blizzard_FrameXML/Mainline/
-- NavigationBar.xml (same source art, same crops).
local NAV_TC = {
    BarBG       = { 0.0,         1.0,        0.18750000, 0.25390625 },  -- tile
    BarOverlay  = { 0.0,         1.0,        0.25781250, 0.32421875 },  -- tile
    BtnUp       = { 0.0,         1.0,        0.06250000, 0.12109375 },  -- tile
    BtnDown     = { 0.0,         1.0,        0.12500000, 0.18359375 },  -- tile
    BtnHilite   = { 0.00195313,  0.25195313, 0.65625,    0.921875   },  -- non-tile
    BtnSelect   = { 0.00195313,  0.25195313, 0.375,      0.640625   },  -- non-tile
    ChevronUp   = { 0.88867188,  0.92968750, 0.296875,   0.53125    },  -- non-tile
    ChevronDown = { 0.63281250,  0.67382813, 0.75781250, 0.99218750 },  -- non-tile
    HomeUp      = { 0.453125,    0.703125,   0.0078125,  0.2421875  },  -- non-tile
    HomeDown    = { 0.453125,    0.703125,   0.2578125,  0.4921875  },  -- non-tile
    HomeHilite  = { 0.453125,    0.713125,   0.5078125,  0.7421875  },  -- non-tile
}

local NAVBAR_H        = 21.5
local NAVBAR_BTN_H    = 20
local NAVBAR_BTN_PADX = 16
local NAVBAR_CHEV_W   = 14
local NAVBAR_CHEV_H   = 20
local NAVBAR_W        = 403

-- Per-crumb dropdown menu arrow: only the small down-arrow is visible at
-- rest, the stone bezel fades in on hover. Mirrors retail's NavButtonTemplate
-- DropdownButton (NavigationBar.xml:151-201). Three Blizzard shared assets:
--   * Interface\Buttons\SquareButtonTextures — small Art arrow tip
--   * Interface\Buttons\UI-SquareButton-Up   — idle bezel (alpha 0 default)
--   * Interface\Buttons\UI-SquareButton-Down — pressed bezel (alpha 0 default)
--   * Interface\Buttons\UI-Common-MouseHilight — hover halo (ADD blend)
local DROP_BTN_W      = 14
local DROP_BTN_H      = 18
local DROP_BEZEL_SIZE = 22
local DROP_ARROW_SIZE = 8

class "MapNavDropdownButton" : extends "Button" {
    __init = function(self, parent, name)
        Button.__init(self, parent, name)
        self:SetSize(DROP_BTN_W, DROP_BTN_H)

        -- Bezel state textures: drawn UNDER the arrow, alpha-toggled
        -- by OnEnter/OnLeave so the bezel only appears on hover.
        self:SetNormalTexture("Interface\\Buttons\\UI-SquareButton-Up")
        local nt = self:GetNormalTexture()
        nt:ClearAllPoints()
        nt:CenterInParent()
        nt:SetSize(DROP_BEZEL_SIZE, DROP_BEZEL_SIZE)
        nt:SetAlpha(0)

        self:SetPushedTexture("Interface\\Buttons\\UI-SquareButton-Down")
        local pt = self:GetPushedTexture()
        pt:ClearAllPoints()
        pt:CenterInParent()
        pt:SetSize(DROP_BEZEL_SIZE, DROP_BEZEL_SIZE)
        pt:SetAlpha(0)

        self:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        local hl = self:GetHighlightTexture()
        hl:ClearAllPoints()
        hl:CenterInParent()
        hl:SetSize(DROP_BEZEL_SIZE, DROP_BEZEL_SIZE)
        hl:SetBlendMode("ADD")

        -- Down-arrow tip — Y texcoord inverted to flip the source up-arrow.
        self._art = Texture(self, nil, "OVERLAY")
        self._art:SetTexture("Interface\\Buttons\\SquareButtonTextures")
        self._art:SetTexCoord(0.45312500, 0.64062500, 0.20312500, 0.01562500)
        self._art:SetSize(DROP_ARROW_SIZE, DROP_ARROW_SIZE)
        self._art:CenterInParent(0, -1)

        self:SetScript("OnEnter",     function() nt:SetAlpha(1); pt:SetAlpha(1) end)
        self:SetScript("OnLeave",     function() nt:SetAlpha(0); pt:SetAlpha(0) end)
        self:SetScript("OnMouseDown", function()
            self._art:ClearAllPoints()
            self._art:CenterInParent(-1, -2)
        end)
        self:SetScript("OnMouseUp",   function()
            self._art:ClearAllPoints()
            self._art:CenterInParent(0, -1)
        end)
    end;
}

-- Crumb button: tiled bg from the _Tile sheet for each state, non-tile
-- chevron sprite anchored at LEFT-to-RIGHT so it sticks past the button's
-- right edge. Two chevron textures (up + down) — only one shown at a
-- time, swapped on OnMouseDown / OnMouseUp like retail's NavButtonTemplate.
class "MapNavButton" : extends "Button" {
    __init = function(self, parent, name)
        Button.__init(self, parent, name)
        self:SetSize(40, NAVBAR_BTN_H)

        self:SetNormalTexture(NAV_TEX_TILE, "REPEAT", "CLAMPTOEDGE")
        self:GetNormalTexture():SetTexCoord(unpack(NAV_TC.BtnUp))

        self:SetPushedTexture(NAV_TEX_TILE, "REPEAT", "CLAMPTOEDGE")
        self:GetPushedTexture():SetTexCoord(unpack(NAV_TC.BtnDown))

        self:SetHighlightTexture(NAV_TEX)
        self:GetHighlightTexture():SetTexCoord(unpack(NAV_TC.BtnHilite))

        self._chevronUp = Texture(self, nil, "OVERLAY")
        self._chevronUp:SetTexture(NAV_TEX)
        self._chevronUp:SetTexCoord(unpack(NAV_TC.ChevronUp))
        self._chevronUp:SetSize(NAVBAR_CHEV_W, NAVBAR_CHEV_H)
        self._chevronUp:SetPoint("LEFT", self, "RIGHT", 0, 0)
        self._chevronUp:SetDrawLayer("OVERLAY", 2)

        self._chevronDown = Texture(self, nil, "OVERLAY")
        self._chevronDown:SetTexture(NAV_TEX)
        self._chevronDown:SetTexCoord(unpack(NAV_TC.ChevronDown))
        self._chevronDown:SetSize(NAVBAR_CHEV_W, NAVBAR_CHEV_H)
        self._chevronDown:SetPoint("LEFT", self, "RIGHT", 0, 0)
        self._chevronDown:SetDrawLayer("OVERLAY", 2)
        self._chevronDown:Hide()

        -- "Selected" overlay — full-fill, shown only on the current/leaf
        -- crumb. Source art sits just above BtnHilite in the atlas.
        self._selected = Texture(self, nil, "OVERLAY")
        self._selected:SetTexture(NAV_TEX)
        self._selected:SetTexCoord(unpack(NAV_TC.BtnSelect))
        self._selected:FillParent()
        self._selected:Hide()

        self._label = FontString(self, nil, "OVERLAY")
        self._label:SetFontSize(7.5)
        self._label:SetTextColor(1, 0.82, 0, 1)
        self._label:SetShadowOffset(1, -1)
        self._label:AlignParentLeft(14, 0)

        -- Dropdown menu arrow on the right side of the crumb. Hidden
        -- until SetDropdownItems supplies a non-empty sibling list.
        self._dropdownBtn = MapNavDropdownButton(self, name and (name .. "Dropdown") or nil)
        self._dropdownBtn:ClearAllPoints()
        self._dropdownBtn:AlignParentRight()
        self._dropdownBtn:Hide()

        self:SetScript("OnMouseDown", function()
            self._chevronUp:Hide()
            self._chevronDown:Show()
        end)
        self:SetScript("OnMouseUp", function()
            self._chevronDown:Hide()
            self._chevronUp:Show()
        end)
    end;

    SetText = function(self, text)
        self._label:SetText(text or "")
        self:SetWidth(math.max(40, self._label:GetStringWidth() + NAVBAR_BTN_PADX * 2))
    end;

    -- The leaf crumb (rightmost) shows the "selected" overlay — and
    -- since we're already viewing that zone, clicks would be a no-op.
    -- EnableMouse(false) on the button body disables both OnClick and
    -- the hover highlight (highlight only triggers when the frame
    -- receives mouse-enter). The dropdown child has its own
    -- EnableMouse(true), so its sibling-list arrow still works.
    SetSelected = function(self, isSelected)
        if isSelected then
            self._selected:Show()
            self:EnableMouse(false)
        else
            self._selected:Hide()
            self:EnableMouse(true)
        end
    end;

    -- items: array of DropdownMenu item-tables (or nil to hide). Lazily
    -- builds a DropdownMenu the first time a non-empty list arrives.
    SetDropdownItems = function(self, items)
        if not items or #items == 0 then
            if self._menu then self._menu:Close() end
            self._dropdownBtn:Hide()
            return
        end
        if not self._menu then
            self._menu = DropdownMenu(self, nil, self._dropdownBtn)
            self._menu:SetMenuWidth(160)
            self._menu:SetAnchor(function(popup, anchor)
                -- Drop straight down from the dropdown arrow, left edges
                -- aligned (popup.TOPLEFT at anchor.BOTTOMLEFT).
                popup:Below(anchor)
                popup:AlignLeft(anchor, -10)
            end)
            self._dropdownBtn.OnClick = function() self._menu:Toggle() end
        end
        self._menu:SetItems(items)
        self._dropdownBtn:Show()
    end;
}

-- Home button (leftmost): structurally distinct from regular crumbs in
-- retail. Uses the non-tile sheet's right-middle band — the red rounded-
-- cap art at texcoord X 0.453..0.703. The right edge of the texcoord is
-- pinned at 0.703125 (the rounded cap) and the left edge slides with
-- button width: left = 0.703125 - (width/128)*0.25. Keeps the cap
-- anchored while the body fills the dynamic label width.
class "MapNavHomeButton" : extends "Button" {
    __init = function(self, parent, name)
        Button.__init(self, parent, name)
        self:SetSize(60, NAVBAR_BTN_H)

        self:SetNormalTexture(NAV_TEX)
        self:SetPushedTexture(NAV_TEX)
        self:SetHighlightTexture(NAV_TEX)
        self:GetHighlightTexture():SetBlendMode("ADD")

        -- Left-edge shadow on the home button (retail's ShadowOverlay-Left).
        -- Parented to overlayFrame (above all crumb buttons) so it draws
        -- on top of the home button's body — matches retail's NavigationBar
        -- HomeButton OVERLAY child texture.
        local homeShadow = Texture(self, nil, "OVERLAY")
        homeShadow:SetTexture("Interface\\Common\\ShadowOverlay-Left")
        homeShadow:SetSize(30, NAVBAR_BTN_H)
        homeShadow:AlignParentLeft()

        self._label = FontString(self, nil, "OVERLAY")
        self._label:SetFontSize(7.5)
        self._label:SetTextColor(1, 0.82, 0, 1)
        self._label:SetShadowOffset(1, -1)
        self._label:AlignParentLeft(7, 0)

        self:_ApplyTexCoords()
    end;

    SetText = function(self, text)
        self._label:SetText(text or "")
        self:_ApplyTexCoords()
    end;

    -- Crop from NAV_TC.HomeUp/Down/Hilite. Each entry is { L, R, T, B };
    -- max source span is (R - L) of texcoord ≈ 128 source pixels. Right
    -- edge (R, the rounded cap) stays pinned; left edge slides toward R
    -- as the button gets narrower.
    _ApplyTexCoords = function(self)
        local w     = self:GetWidth() or 80
        local up    = NAV_TC.HomeUp
        local down  = NAV_TC.HomeDown
        local hi    = NAV_TC.HomeHilite
        local span  = up[2] - up[1]
        local off   = math.min(span, (w / 84) * span)
        self:GetNormalTexture()   :SetTexCoord(up[2]   - off, up[2],   up[3],   up[4])
        self:GetPushedTexture()   :SetTexCoord(down[2] - off, down[2], down[3], down[4])
        self:GetHighlightTexture():SetTexCoord(hi[2]   - off, hi[2],   hi[3],   hi[4])
    end;
}

-- MapNavBar: the breadcrumb bar. Owns the bar frame, the manual-tile
-- bg/overlay strips, the inner-shadow border, the home button, and the
-- crumb-button pool. Refresh() rebuilds the chain from
-- WorldMapFrame:GetMapID().
class "MapNavBar" : extends "Frame" {
    __init = function(self, parent, name)
        Frame.__init(self, "Frame", parent, name)
        self:SetSize(NAVBAR_W, NAVBAR_H)
        self:SetFrameLevel(parent:GetFrameLevel() + 5)

        self:_BuildBars()
        self:_BuildBorder()

        self._navButtons = {}

        -- Home button: fixed at the bar's left edge, navigates to the
        -- topmost map in the current chain (set per Refresh).
        self.homeBtn = MapNavHomeButton(self, name and (name .. "Home") or nil)
        self.homeBtn:SetText(WORLD or "World")
        self.homeBtn:ClearAllPoints()
        self.homeBtn:SetPoint("LEFT", self, "LEFT", 0, 0)
        self.homeBtn:Show()
        self.homeBtn.OnClick = function(b)
            if b._mapID then WorldMapFrame:SetMapID(b._mapID) end
        end

        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            self:Refresh()
        end)

        self:Refresh()
    end;

    -- Manual horizontal tile. Era ignores REPEAT wrap on SetTexture
    -- (texcoords > 1 just clamp), so the bar bg / overlay strips are
    -- laid out as N side-by-side Texture instances. The bar width
    -- rarely divides cleanly by 128, so every tile is stretched by
    -- the same small fraction to fill the bar exactly — no overhang,
    -- no gap. Distributing the stretch across all tiles keeps the
    -- bar uniformly periodic instead of a jarring partial last tile.
    _BuildBars = function(self)
        local barW  = self:GetWidth()
        local tiles = math.max(1, math.ceil(barW / 128))
        local tileW = barW / tiles

        for i = 1, tiles do
            local bg = Texture(self, nil, "BACKGROUND")
            bg:SetTexture(NAV_TEX_TILE)
            bg:SetTexCoord(0, 1, NAV_TC.BarBG[3], NAV_TC.BarBG[4])
            bg:SetSize(tileW, NAVBAR_H)
            bg:SetPoint("TOPLEFT", self, "TOPLEFT", (i - 1) * tileW, 0)
        end

        -- Overlay sheen — retail parents these to a child frame at
        -- OVERLAY/sublevel 5 so they stay above the crumb buttons.
        local overlayFrame = Frame("Frame", self)
        overlayFrame:FillParent()
        overlayFrame:SetFrameLevel(self:GetFrameLevel() + 150)

        for i = 1, tiles do
            local ov = Texture(overlayFrame, nil, "OVERLAY")
            ov:SetTexture(NAV_TEX_TILE)
            ov:SetTexCoord(0, 1, NAV_TC.BarOverlay[3], NAV_TC.BarOverlay[4])
            ov:SetSize(tileW, NAVBAR_H)
            ov:SetPoint("TOPLEFT", overlayFrame, "TOPLEFT", (i - 1) * tileW, 0)
        end
    end;

    -- Inner-shadow U-border around the bar. Sits above the crumb
    -- buttons (which Refresh bumps up relative to the bar) so the
    -- inner shadow is drawn over the button artwork at the bar's edges.
    _BuildBorder = function(self)
        self._border = InnerBorder(self)
        self._border:FillParent()
        self._border:SetFrameLevel(self:GetFrameLevel() + 200)
    end;

    -- Acquire (or reuse) a crumb button at the i-th slot.
    _NavButton = function(self, i)
        local btn = self._navButtons[i]
        if not btn then
            btn = MapNavButton(self)
            btn.OnClick = function(b)
                if b._mapID then WorldMapFrame:SetMapID(b._mapID) end
            end
            self._navButtons[i] = btn
        end
        return btn
    end;

    Refresh = function(self)
        -- Walk the parent chain end-to-end. The topmost ancestor (the
        -- planet — Azeroth in Era, Outland on TBC, etc.) is INCLUDED as
        -- the first crumb after the fixed "World" home button. The home
        -- button keeps its static label and just navigates to that
        -- topmost map.
        local crumbs = {}
        local mapID  = WorldMapFrame:GetMapID()
        local info   = mapID and C_Map.GetMapInfo(mapID)
        while info do
            table.insert(crumbs, 1, info)  -- root-first order
            if info.parentMapID and info.parentMapID > 0 then
                info = C_Map.GetMapInfo(info.parentMapID)
            else
                break
            end
        end

        -- Home button click target: the planet (topmost / crumbs[1]).
        self.homeBtn._mapID = crumbs[1] and crumbs[1].mapID or nil

        -- Crumbs sit edge-to-edge — each next button's LEFT pinned at
        -- the previous button's RIGHT, no gap. The chevron texture
        -- extends past the right edge into the next button's body;
        -- left button gets a higher frame level than the right one
        -- (see below) so the chevron draws on top of that overlap,
        -- matching retail.
        local prev = self.homeBtn
        for i, ci in ipairs(crumbs) do
            local btn = self:_NavButton(i)
            btn._mapID = ci.mapID
            btn:SetText(ci.name)
            btn:SetSelected(i == #crumbs)
            btn:SetDropdownItems(self:_BuildSiblingItems(ci))
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", prev, "RIGHT", (i == 1) and -10 or 0, 0)
            btn:Show()
            prev = btn
        end
        for i = #crumbs + 1, #self._navButtons do
            self._navButtons[i]:Hide()
        end

        -- Frame-level layering: home highest, leaf lowest. Each leftward
        -- button stacks above the one to its right so its chevron, which
        -- extends past the right edge into the next button, draws on top
        -- of that next button's body.
        local base  = self:GetFrameLevel() + 1
        local total = #crumbs + 1
        self.homeBtn:SetFrameLevel(base + total - 1)
        for i = 1, #crumbs do
            self._navButtons[i]:SetFrameLevel(base + total - 1 - i)
        end
    end;

    -- Sibling-map list for a crumb's dropdown menu — every map sharing
    -- the same parentMapID AND the same mapType as the current crumb,
    -- sorted alphabetically. Same-mapType filter naturally excludes
    -- battlegrounds (mapType = Battleground) when listing zone siblings,
    -- and keeps the planet/continent/zone hierarchy clean. Returns nil
    -- when there are no usable siblings (root-level / single-child) so
    -- the dropdown arrow stays hidden on those crumbs.
    _BuildSiblingItems = function(self, mapInfo)
        if not mapInfo or not mapInfo.parentMapID or mapInfo.parentMapID == 0 then
            return nil
        end
        local children = C_Map.GetMapChildrenInfo(mapInfo.parentMapID)
        if not children or #children == 0 then return nil end

        local items = {}
        for _, child in ipairs(children) do
            if child.mapType == mapInfo.mapType then
                table.insert(items, {
                    type   = "text",
                    label  = child.name,
                    _mapID = child.mapID,
                    OnClick = function(item)
                        WorldMapFrame:SetMapID(item._mapID)
                    end,
                })
            end
        end
        if #items == 0 then return nil end
        table.sort(items, function(a, b) return a.label < b.label end)
        return items
    end;
}
