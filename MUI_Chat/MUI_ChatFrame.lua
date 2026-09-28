-- ChatFrame: wrapper for native FCF chat frames (ScrollingMessageFrame).
-- Owns the chat-specific native methods (scrolling, message access, clamp,
-- movability) so callers never need self._native: access.
--
-- Wrap an existing native chat frame: ChatFrame(_G["ChatFrame1"])

class "ChatFrame" : extends "Frame" {
    __init = function(self, native)
        Frame.__init(self, native)
    end;

    -- ===== Scroll =====

    GetScrollOffset = function(self)
        return self._native:GetScrollOffset()
    end;

    SetScrollOffset = function(self, offset)
        self._native:SetScrollOffset(offset)
    end;

    ScrollUp = function(self)
        self._native:ScrollUp()
    end;

    ScrollDown = function(self)
        self._native:ScrollDown()
    end;

    ScrollToTop = function(self)
        self._native:ScrollToTop()
    end;

    ScrollToBottom = function(self)
        self._native:ScrollToBottom()
    end;
	
	-- ========================
	
	GetMaxScrollLines = function(self)
		local cur = self:GetScrollOffset()
		self:ScrollToTop()
		local mx = self:GetScrollOffset()
		self:SetScrollOffset(cur)
		return mx
	end;

    GetNumMessages = function(self)
        return self._native:GetNumMessages()
    end;

    AddMessage = function(self, msg)
        self._native:AddMessage(msg)
    end;

    -- Hook the native AddMessage; the wrapped fn receives (nativeFrame, ...).
    HookAddMessage = function(self, fn)
        local orig = self._native.AddMessage
        self._native.AddMessage = function(frame, ...)
            orig(frame, ...)
            fn(frame, ...)
        end
    end;

    -- ===== Geometry =====

    -- ChatFrame1 is a Blizzard Edit Mode system: its instance SetPoint / ClearAllPoints are
    -- Lua overrides that write Edit Mode state. Drive the geometry through the C methods.
    SetPoint = function(self, point, relativeTo, relativePoint, x, y)
        self:RawAddPoint(point, relativeTo, relativePoint, x, y)
    end;

    ClearAllPoints = function(self)
        self:RawClearAllPoints()
    end;

    -- ===== Movability / clamping =====

    SetClampedToScreen = function(self, clamped)
        self._native:SetClampedToScreen(clamped)
    end;

    SetClampRectInsets = function(self, l, r, t, b)
        self._native:SetClampRectInsets(l, r, t, b)
    end;

    SetUserPlaced = function(self, placed)
        self._native:SetUserPlaced(placed)
    end;

    IsMovable = function(self)
        return self._native:IsMovable()
    end;

    IsResizable = function(self)
        return self._native:IsResizable()
    end;
}
