-- TextureAtlas: Represents a single texture file with named sub-regions
-- Tex coords from the dumper are used as-is (user stretches textures to power-of-2)
--
-- Usage:
--   TextureAtlas("filename", origW, origH, resizedW, resizedH, {
--       RegionName = { w = 75, h = 75, l = 0.0, r = 0.25, t = 0.0, b = 0.25 },
--       ...
--   })

local MUI_TEX_PATH = "Interface\\AddOns\\ModernUI\\assets\\textures\\"

class "TextureAtlas" {
    __init = function(self, fileName, origWidth, origHeight, resizedWidth, resizedHeight, regions)
        self._file = MUI_TEX_PATH .. tostring(fileName)
        self._regions = {}

        if regions then
            for name, r in pairs(regions) do
                self._regions[name] = {
                    file = self._file,
                    width = r.w,
                    height = r.h,
                    left = r.l,
                    right = r.r,
                    top = r.t,
                    bottom = r.b,
                }
            end
        end
    end;

    GetRegion = function(self, name)
        return self._regions[name]
    end;
}
