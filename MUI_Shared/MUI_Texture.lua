-- Texture: Wraps a texture region — either creates new or wraps existing
-- Create: Texture(parentCFrame, name, layer)
-- Wrap:   Texture(existingNativeTexture)

class "Texture" : extends "Widget" {
    __init = function(self, parentOrNative, name, layer)
        Widget.__init(self)

        if IsNativeObject(parentOrNative, "Texture") then
            -- WRAP existing native texture
            self._native = parentOrNative
        else
            self._native = parentOrNative._native:CreateTexture(name, layer or "ARTWORK")
        end
    end;

    -- horizWrap / vertWrap: "REPEAT" to tile (texcoord values > 1 wrap)
    -- or "CLAMPTOEDGE" / "CLAMPTOBLACKADDITIVE" — defaults clamp.
    SetTexture = function(self, path, horizWrap, vertWrap)
        self._native:SetTexture(path, horizWrap, vertWrap)
    end;

    GetTexture = function(self)
        return self._native:GetTexture()
    end;
	
	SetTextureRegion = function(self, path, fileW, fileH, x, y, w, h, invertH, invertV)
		fileW = fileW or 512
		fileH = fileH or 512
		self._native:SetTexture(path)

        local l, r, t, b
        if invertH == true then
            l = (x + w) / fileW
            r = x / fileW
        else
            l = x / fileW
            r = (x + w) / fileW
        end

        if invertV == true then
            t = (y + h) / fileH
            b = y / fileH
        else
            t = y / fileH
            b = (y + h) / fileH
        end

		self._native:SetTexCoord(l, r, t, b)
	end;

    -- Accepts the 4-arg form (left, right, top, bottom) and the 8-arg
    -- corner form (ULx, ULy, LLx, LLy, URx, URy, LRx, LRy) used for
    -- arbitrary affine cropping (rotated text textures, etc.).
    SetTexCoord = function(self, ...)
        self._native:SetTexCoord(...)
    end;

    GetTexCoord = function(self)
        return self._native:GetTexCoord()
    end;

    SetColorTexture = function(self, r, g, b, a)
        self._native:SetColorTexture(r, g, b, a or 1)
    end;

    SetVertexColor = function(self, r, g, b, a)
        self._native:SetVertexColor(r, g, b, a or 1)
    end;

    GetVertexColor = function(self)
        return self._native:GetVertexColor()
    end;

    SetBlendMode = function(self, mode)
        self._native:SetBlendMode(mode)
    end;

    -- orientation = "HORIZONTAL" or "VERTICAL"
    -- minColor / maxColor = ColorMixin (CreateColor(r,g,b,a))
    -- VERTICAL: min = bottom, max = top. HORIZONTAL: min = left, max = right.
    SetGradient = function(self, orientation, minColor, maxColor)
        self._native:SetGradient(orientation, minColor, maxColor)
    end;

    SetRotation = function(self, radians, rotationPoint)
        self._native:SetRotation(radians, rotationPoint)
    end;

    SetDrawLayer = function(self, layer, subLevel)
        self._native:SetDrawLayer(layer, subLevel)
    end;

    GetDrawLayer = function(self)
        return self._native:GetDrawLayer()
    end;

    -- Disable the default pixel-grid snapping so the texture renders at
    -- fractional positions smoothly. Needed for things like minimap pins
    -- whose SetPoint offsets update at fractional-pixel precision each
    -- frame — otherwise the engine rounds to the nearest pixel and motion
    -- looks jagged.
    SetSubpixelRendering = function(self, enable)
        if self._native.SetTexelSnappingBias then
            self._native:SetTexelSnappingBias(enable and 0 or 0.5)
        end
        if self._native.SetSnapToPixelGrid then
            self._native:SetSnapToPixelGrid(not enable)
        end
    end;

    SetAtlas = function(self, atlas, regionName, keepSize)
        local info = atlas:GetRegion(regionName)
        if not info then
            MUI.Print("ModernUI: Atlas region not found: " .. tostring(regionName))
            return
        end
        self._native:SetTexture(info.file)
        self._native:SetTexCoord(info.left, info.right, info.top, info.bottom)
        if not keepSize then
            if info.width then self._native:SetWidth(info.width) end
            if info.height then self._native:SetHeight(info.height) end
        end
    end;

    -- Set a round-cropped portrait texture from a file path
    SetPortrait = function(self, path)
        SetPortraitToTexture(self._native, path)
    end;

    -- Set a portrait texture from a live unit (player/target/etc).
    SetPortraitFromUnit = function(self, unit)
        SetPortraitTexture(self._native, unit)
    end;

    SetDesaturated = function(self, desaturated)
        if self._native.SetDesaturated then
            self._native:SetDesaturated(desaturated)
        end
    end;
	
	SetMask = function(self, mask)
		if self._native.SetMask then
			self._native:SetMask(mask)
		end
	end;
}
