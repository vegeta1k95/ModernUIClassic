-- Cooldown: radial sweep + countdown timer (CooldownFrameTemplate). Size it
-- over an icon and feed it SetCooldown(start, duration) — e.g. from
-- C_Spell.GetSpellCooldown. The template animates the swipe and draws the
-- timer text on its own.

class "Cooldown" : extends "Frame" {

    __init = function(self, parent, name)
        Frame.__init(self, "Cooldown", parent, name, "CooldownFrameTemplate")
    end;

    -- start / duration are GetTime()-based seconds. Clears (no swipe) when the
    -- spell isn't actually on cooldown, so a zero/disabled cooldown shows
    -- nothing instead of a stuck full swipe.
    SetCooldown = function(self, start, duration, enable, modRate)
        if enable ~= false and enable ~= 0
           and start and start > 0 and duration and duration > 0 then
            self._native:SetCooldown(start, duration, modRate)
        else
            self._native:Clear()
        end
    end;

    Clear = function(self)
        self._native:Clear()
    end;

    SetHideCountdownNumbers = function(self, hide)
        self._native:SetHideCountdownNumbers(hide)
    end;

    SetSwipeColor = function(self, r, g, b, a)
        self._native:SetSwipeColor(r, g, b, a or 1)
    end;

    SetDrawEdge = function(self, draw)
        self._native:SetDrawEdge(draw)
    end;
}
