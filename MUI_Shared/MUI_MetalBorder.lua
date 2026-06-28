-- MetalBorder: Retail-style metal frame border (used on Options, default panels)

class "MetalBorder" : extends "NineSlice" {
    __init = function(self, parent, name)
        NineSlice.__init(self, parent, name)

        local corners = MUI_AtlasRegistry.FrameMetalCorners
        local edgesTB = MUI_AtlasRegistry.FrameMetalEdgesTB
        local edgesLR = MUI_AtlasRegistry.FrameMetalEdgesLR

        self:SetLayout({
            TopLeft     = { atlas = corners, region = "CornerTopLeft",     width = 75, height = 75, x = -8, y = 16 },
            Top         = { atlas = edgesTB, region = "EdgeTop",          			   height = 75 },
            TopRight    = { atlas = corners, region = "CornerTopRight",    width = 75, height = 75, x = 4, y = 16 },
            Left        = { atlas = edgesLR, region = "EdgeLeft",          width = 75 },
            Right       = { atlas = edgesLR, region = "EdgeRight",         width = 75 },
            BottomLeft  = { atlas = corners, region = "CornerBottomLeft",  width = 32, height = 32, x = -8.5, y = -3 },
            Bottom      = { atlas = edgesTB, region = "EdgeBottom",        			   height = 32 },
            BottomRight = { atlas = corners, region = "CornerBottomRight", width = 32, height = 32, x = 4, y = -3 },
			
			Center      = { color = {0.12, 0.12, 0.12, 0.85}, insetLeft = 6, insetRight = 1, insetTop = 22, insetBottom = 4 },
        })
    end;
}

class "MetalBorderPortrait" : extends "NineSlice" {
    __init = function(self, parent, name, scale, small)
        NineSlice.__init(self, parent, name)

        local corners = MUI_AtlasRegistry.FrameMetalCorners
        local edgesTB = MUI_AtlasRegistry.FrameMetalEdgesTB
        local edgesLR = MUI_AtlasRegistry.FrameMetalEdgesLR

        local portrait = small and "CornerTopLeftPortraitSmall" or "CornerTopLeftPortrait"

        self:SetLayout({
            TopLeft     = { atlas = corners, region = portrait,                 width = 75, height = 75, x = -8, y = 16, scale = scale },
            Top         = { atlas = edgesTB, region = "EdgeTop",          					height = 75,                 scale = scale },
            TopRight    = { atlas = corners, region = "CornerTopRight",    		width = 75, height = 75, x = 4,  y = 16, scale = scale },
            Left        = { atlas = edgesLR, region = "EdgeLeft",          		width = 75,                              scale = scale },
            Right       = { atlas = edgesLR, region = "EdgeRight",         		width = 75,                              scale = scale },
            BottomLeft  = { atlas = corners, region = "CornerBottomLeft",  		width = 32, height = 32, x = -8.5, y = -3, scale = scale },
            Bottom      = { atlas = edgesTB, region = "EdgeBottom",        			   		height = 32,                 scale = scale },
            BottomRight = { atlas = corners, region = "CornerBottomRight", 		width = 32, height = 32, x = 4,  y = -3, scale = scale },
        })
    end;
}

