-- Texture: Wraps a texture region — either creates new or wraps existing
-- Create: Texture(parentCFrame, name, layer)
-- Wrap:   Texture(existingNativeTexture)

-- Native texture -> its circular portrait MaskTexture. Keyed by the native because
-- wrappers are throwaway (GetNormalTexture() builds a new one on every call).
local portraitMasks = setmetatable({}, { __mode = "k" })

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

    -- Tile the texture across its bounds (backgrounds / streak bands). The
    -- texture must have been set with "REPEAT" wrap mode for tiling to show.
    SetHorizTile = function(self, enable)
        if self._native.SetHorizTile then
            self._native:SetHorizTile(enable and true or false)
        end
    end;

    SetVertTile = function(self, enable)
        if self._native.SetVertTile then
            self._native:SetVertTile(enable and true or false)
        end
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

		self:_SetTexCoord(l, r, t, b)
	end;

    -- Accepts the 4-arg form (left, right, top, bottom) and the 8-arg
    -- corner form (ULx, ULy, LLx, LLy, URx, URy, LRx, LRy) used for
    -- arbitrary affine cropping (rotated text textures, etc.).
    SetTexCoord = function(self, ...)
        self:_SetTexCoord(...)
    end;

    -- The engine throws "Cannot set tex coords when texture has mask", but a
    -- mask added AFTER the texcoords is fine — so lift our portrait mask around
    -- the call. Matters for reused icons that stay round between updates.
    _SetTexCoord = function(self, ...)
        local mask = portraitMasks[self._native]
        local masked = mask and self._native:GetNumMaskTextures() > 0
        if masked then self._native:RemoveMaskTexture(mask) end
        self._native:SetTexCoord(...)
        if masked then self._native:AddMaskTexture(mask) end
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
    -- Draw the texture as an arbitrary quad. Each corner is an offset from
    -- the parent's TOPLEFT (x right, y up, so on-screen points have y <= 0):
    -- the texture's upper-left, lower-left, upper-right and lower-right. The
    -- base rect is the quad's bounding box, so culling sees its true extent;
    -- vertex offsets then pull every corner onto its target. Two corners may
    -- coincide to make a triangle.
    SetQuad = function(self, ulx, uly, llx, lly, urx, ury, lrx, lry)
        local left   = math.min(ulx, llx, urx, lrx)
        local top    = math.max(uly, lly, ury, lry)
        local width  = math.max(math.max(ulx, llx, urx, lrx) - left, 1)
        local height = math.max(top - math.min(uly, lly, ury, lry), 1)
        local right, bottom = left + width, top - height
        local n = self._native
        n:ClearAllPoints()
        n:SetPoint("TOPLEFT", left, top)
        n:SetSize(width, height)
        n:SetVertexOffset(UPPER_LEFT_VERTEX,  ulx - left,  uly - top)
        n:SetVertexOffset(LOWER_LEFT_VERTEX,  llx - left,  lly - bottom)
        n:SetVertexOffset(UPPER_RIGHT_VERTEX, urx - right, ury - top)
        n:SetVertexOffset(LOWER_RIGHT_VERTEX, lrx - right, lry - bottom)
    end;

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
        self:_SetTexCoord(info.left, info.right, info.top, info.bottom)
        if not keepSize then
            if info.width then self._native:SetWidth(info.width) end
            if info.height then self._native:SetHeight(info.height) end
        end
    end;

    -- A Blizzard atlas by name. Returns false, leaving the texture as it was,
    -- when this client has no such atlas (each flavor ships its own set).
    SetBlizzardAtlas = function(self, name, useAtlasSize)
        if not C_Texture.GetAtlasInfo(name) then return false end
        self._native:SetAtlas(name, useAtlasSize)
        return true
    end;

    -- Set a round-cropped portrait texture from a file path. Uses a real MaskTexture
    -- anchored to our rect (as Blizzard's portrait templates do): the string form
    -- SetMask(file) samples the mask through the texture's own texcoords, so it
    -- distorts as soon as the icon is cropped with SetTexCoord. The mask stays on
    -- the texture; ClearPortrait to go back to a square icon.
    SetPortrait = function(self, path)
        local mask = portraitMasks[self._native]
        if not mask then
            mask = self._native:GetParent():CreateMaskTexture()
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(self._native)
            portraitMasks[self._native] = mask
        end
        if self._native:GetNumMaskTextures() == 0 then
            self._native:AddMaskTexture(mask)
        end
        self._native:SetTexture(path)
    end;

    ClearPortrait = function(self)
        local mask = portraitMasks[self._native]
        if mask and self._native:GetNumMaskTextures() > 0 then
            self._native:RemoveMaskTexture(mask)
        end
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
