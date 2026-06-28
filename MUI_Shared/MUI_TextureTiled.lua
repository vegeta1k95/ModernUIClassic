-- TextureTiled: a Frame that fills its width with side-by-side copies of
-- an atlas region. Native SetHorizTile only works on whole textures, not
-- atlas sub-rects, so we stamp out N fixed-size tiles by hand and clip
-- the trailing overhang.
--
-- Usage:
--   local bar = TextureTiled(parent, "MUI_TopBar")
--   bar:SetSize(width, height)
--   bar:SetAtlasTile(MUI_AtlasRegistry.FrameBossPortrait, "Tile", 12, 10)
--
-- Re-tiles automatically on size change.

class "TextureTiled" : extends "Frame" {
    __init = function(self, parent, name)
        Frame.__init(self, "Frame", parent, name)
        self:SetClipsChildren(true)
        self._tiles = {}
        self:SetScript("OnSizeChanged", function() self:_RebuildTiles() end)
    end;

    -- Configure the repeating tile. tileW/tileH are the per-copy display
    -- size in pixels — each tile is laid out at this size and stamped
    -- across the frame's width starting from TOPLEFT. drawLayer is
    -- optional ("ARTWORK" by default).
    SetAtlasTile = function(self, atlas, regionName, tileW, tileH, drawLayer)
        self._atlas      = atlas
        self._regionName = regionName
        self._tileW      = tileW
        self._tileH      = tileH
        self._drawLayer  = drawLayer or "ARTWORK"
        self:_RebuildTiles()
    end;

    -- Hide every pooled tile (e.g. before re-issuing a new SetAtlasTile
    -- with a different region without inheriting old layout state).
    Clear = function(self)
        for _, t in ipairs(self._tiles) do t:Hide() end
    end;

    _RebuildTiles = function(self)
        local atlas, regionName = self._atlas, self._regionName
        local tileW, tileH      = self._tileW, self._tileH
        if not atlas or not regionName or not tileW or tileW <= 0 then return end

        local frameW = self:GetWidth() or 0
        local n      = (frameW > 0) and math.ceil(frameW / tileW) or 0

        for i = 1, n do
            local t = self._tiles[i]
            if not t then
                t = Texture(self, nil, self._drawLayer)
                self._tiles[i] = t
            end
            t:SetAtlas(atlas, regionName, true)
            t:SetSize(tileW, tileH)
            t:ClearAllPoints()
            if i == 1 then
                t:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
            else
                t:RightOf(self._tiles[i - 1], 0, 0)
            end
            t:Show()
        end
        for i = n + 1, #self._tiles do
            self._tiles[i]:Hide()
        end
    end;
}
