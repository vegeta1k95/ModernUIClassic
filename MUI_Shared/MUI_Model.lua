class "Model" : extends "Frame" {
    __init = function(self, typeOrNative, parent, name)

        local isNative = type(typeOrNative) == "table"
                     and typeOrNative.GetObjectType
                     and not typeOrNative._native
        local objType  = isNative and typeOrNative:GetObjectType()
        if objType == "Model" or objType == "PlayerModel" then
            Frame.__init(self, parentOrNative)
            return
        end

        -- CREATE new button
        Frame.__init(self, typeOrNative, parent, name)
    end;

    ClearModel = function(self)
        self._native:ClearModel()
    end;

    SetFacing = function(self, facing)
        self._native:SetFacing(facing)
    end;

    SetTransform = function(self, translation, rotation, scale)
        self._native:SetTransform(translation, rotation, scale)
    end;

    -- When true, SetTransform pivots around the model's bounding-box
    -- center instead of its origin. Also fixes a Classic Era rendering
    -- bug where alpha-tested textures (fur / hair / cloth) ghost out
    -- after SetTransform — call this ONCE per Model frame after
    -- creation, then SetTransform renders cleanly.
    UseModelCenterToTransform = function(self, useCenter)
        self._native:UseModelCenterToTransform(useCenter)
    end;

    -- Portrait camera zoom: 0 = full body, 1 = head closeup. Retail's
    -- QuestNPCModelFrameMixin uses 0.6.
    SetPortraitZoom = function(self, zoom)
        self._native:SetPortraitZoom(zoom)
    end;

    -- Multiplier on the model's default camera distance. >1 pulls the
    -- camera back (model appears smaller); <1 pushes it in. ONLY works
    -- after SetCustomCamera has switched the model out of the auto-fit
    -- portrait framing — calling it on a default camera throws
    -- "Not using a custom camera".
    SetCameraDistance = function(self, distance)
        self._native:SetCameraDistance(distance)
    end;

    -- Multiplier on the auto-fit camera distance. Unlike
    -- SetCameraDistance this works WITHOUT switching to a custom camera
    -- — it just pulls the auto-framed portrait camera back. >1 = smaller
    -- model on screen, <1 = closer/bigger.
    SetCamDistanceScale = function(self, scale)
        self._native:SetCamDistanceScale(scale)
    end;

    -- Scale the model itself (not the camera). Cheaper alternative to
    -- camera-distance tweaking — Blizzard uses this for things like
    -- inset 3D portraits where the camera is fixed and the model
    -- shrinks instead.
    SetModelScale = function(self, scale)
        self._native:SetModelScale(scale)
    end;

    -- Switch from the auto-fit portrait camera to an addon-controlled
    -- one. Required before SetCameraPosition / SetCameraTarget /
    -- SetCameraDistance take effect. Pass 0 for the default custom slot.
    SetCustomCamera = function(self, idx)
        self._native:SetCustomCamera(idx)
    end;

    -- World-space camera position in model-local units. Origin (0,0,0)
    -- is the model's feet. +X is in front of the model (its facing
    -- direction); +Z is up. So (4, 0, 1) puts the camera 4 units in
    -- front of the model, at chest height.
    SetCameraPosition = function(self, x, y, z)
        self._native:SetCameraPosition(x, y, z)
    end;

    -- Look-at point for the custom camera, in the same coord space as
    -- SetCameraPosition. (0, 0, 1) aims at the model's mid-torso.
    SetCameraTarget = function(self, x, y, z)
        self._native:SetCameraTarget(x, y, z)
    end;

    -- Move the model itself within its 3D space, in model-local units.
    -- Useful for re-centering after a camera change pulls the model
    -- toward an edge of the frame.
    SetPosition = function(self, x, y, z)
        self._native:SetPosition(x, y, z)
    end;

}

class "PlayerModel" : extends "Model" {

    __init = function(self, parentOrNative, name)

        local isNative = type(parentOrNative) == "table"
                     and parentOrNative.GetObjectType
                     and not parentOrNative._native

        local objType  = isNative and parentOrNative:GetObjectType()
        if objType == "PlayerModel" then
            Model.__init(self, parentOrNative)
            return
        end

        Model.__init(self, "PlayerModel", parentOrNative, name)

    end;

    SetDisplayInfo = function(self, displayId, mountDisplayID)
        self._native:SetDisplayInfo(displayId, mountDisplayID)
    end;

    SetCreature = function(self, creatureId, displayId)
        self._native:SetCreature(creatureId, displayId)
    end;
}