-- AnimationGroup / Animation: thin wrappers so callers never need raw native
-- access to set anim targets.
--   AnimationGroup(parentFrame)         -- creates AG on parentFrame's native
--   Animation(group, "Alpha"|"Scale"|…) -- creates an Animation in group
-- Methods exposed are the subset the addon actually uses; extend as needed.

class "Animation" {
    __init = function(self, group, animType)
        self._native = group._native:CreateAnimation(animType)
    end;

    SetTarget = function(self, widget)
        self._native:SetTarget(widget._native)
    end;

    SetDuration = function(self, seconds)
        self._native:SetDuration(seconds)
    end;

    SetStartDelay = function(self, seconds)
        self._native:SetStartDelay(seconds)
    end;

    SetOrder = function(self, order)
        self._native:SetOrder(order)
    end;

    SetSmoothing = function(self, smoothing)
        self._native:SetSmoothing(smoothing)
    end;

    -- Alpha-animation properties
    SetFromAlpha = function(self, alpha)
        self._native:SetFromAlpha(alpha)
    end;

    SetToAlpha = function(self, alpha)
        self._native:SetToAlpha(alpha)
    end;

    -- Scale-animation properties
    SetScaleFrom = function(self, sx, sy)
        self._native:SetScaleFrom(sx, sy)
    end;

    SetScaleTo = function(self, sx, sy)
        self._native:SetScaleTo(sx, sy)
    end;

    -- Translation-animation property
    SetOffset = function(self, x, y)
        self._native:SetOffset(x, y)
    end;

    -- Rotation-animation property (rotates around SetOrigin)
    SetDegrees = function(self, degrees)
        self._native:SetDegrees(degrees)
    end;

    SetOrigin = function(self, point, x, y)
        self._native:SetOrigin(point, x, y)
    end;

    -- FlipBook-animation properties (animType == "FlipBook"). Cycles the
    -- target texture's TexCoord through `rows × columns` cells of a sprite
    -- sheet across `duration` seconds. frameWidth / frameHeight 0 means
    -- auto-compute as texW/cols, texH/rows.
    SetFlipBookRows = function(self, rows)
        self._native:SetFlipBookRows(rows)
    end;

    SetFlipBookColumns = function(self, cols)
        self._native:SetFlipBookColumns(cols)
    end;

    SetFlipBookFrames = function(self, frames)
        self._native:SetFlipBookFrames(frames)
    end;

    SetFlipBookFrameWidth = function(self, w)
        self._native:SetFlipBookFrameWidth(w)
    end;

    SetFlipBookFrameHeight = function(self, h)
        self._native:SetFlipBookFrameHeight(h)
    end;
}

class "AnimationGroup" {
    __init = function(self, parent)
        self._native = parent._native:CreateAnimationGroup()
    end;

    CreateAnimation = function(self, animType)
        return Animation(self, animType)
    end;

    Play = function(self)
        self._native:Play()
    end;

    Stop = function(self)
        self._native:Stop()
    end;

    IsPlaying = function(self)
        return self._native:IsPlaying()
    end;

    SetLooping = function(self, mode)
        self._native:SetLooping(mode)
    end;

    SetScript = function(self, name, func)
        self._native:SetScript(name, func)
    end;

    Restart = function(self)
        self._native:Stop()
        self._native:Play()
    end;
}
