-- InnerBorder: U-shape inner-shadow border (no top). Mirrors retail's
-- WorldMapNavBarTemplate inset-border pattern — corners at the bottom
-- only, vertical strips up the sides, horizontal strip across the
-- bottom. Top stays open since the bordered frame is typically flush
-- against another panel above.

class "InnerBorder" : extends "NineSlice" {
    __init = function(self, parent, name)
        NineSlice.__init(self, parent, name)

        local corners = MUI_AtlasRegistry.FrameInner
        local edgesV  = MUI_AtlasRegistry.FrameInnerVertical
        local edgesH  = MUI_AtlasRegistry.FrameInnerHorizontal

        self:SetLayout({
            -- Top corners stay degenerate (no atlas data, no size) at
            -- offsets that line up with the side strips; they exist only
            -- so NineSlice's anchor chain places the side strips at -3/+3
            -- horizontally and y=0 at the parent's top edge.
            TopLeft     = { x = -3, y =  0 },
            TopRight    = { x =  3, y =  0 },
            BottomLeft  = { atlas = corners, region = "InnerCornerBottomLeft",  width = 8, height = 8, x = -1.5, y = -1.5, scale = 0.4 },
            BottomRight = { atlas = corners, region = "InnerCornerBottomRight", width = 8, height = 8, x =  2,   y = -1.5, scale = 0.4 },

            Left        = { atlas = edgesV, region = "InnerLeft",   width  = 3, height = 34, scale = 0.5 },
            Right       = { atlas = edgesV, region = "InnerRight",  width  = 3, height = 24, scale = 0.8 },
            Bottom      = { atlas = edgesH, region = "InnerBottom", height = 3, scale = 0.5 },
        })
    end;
}

class "InnerFrame" : extends "Frame" {
    __init = function(self, parent, name)
        Frame.__init(self, "Frame", parent, name, "InsetFrameTemplate")

        -- InsetFrameTemplate has `useParentLevel="true"`, which folds the
        -- frame into the parent's draw order. That makes the inset's Bg
        -- (BACKGROUND sublevel -5) compete with the parent's own BACKGROUND
        -- content — and lose, because everyone else uses sublevel 0. Bump
        -- our level by 1 so all our content (Bg + NineSlice border) draws
        -- cleanly above the parent's regions, like a normal child frame.

        if parent then
            self:SetFrameLevel(parent:GetFrameLevel() + 10)
        end

        if self._native.Bg        then self._bg        = Texture(self._native.Bg) end
        if self._native.NineSlice then self._nineSlice = Frame(self._native.NineSlice) end
    end;

    HideBg = function(self)
        if self._bg then self._bg:Hide() end
    end;

    GetBg = function(self)
        return self._bg
    end;
}
