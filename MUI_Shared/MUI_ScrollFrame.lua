-- ScrollFrame: thin wrapper around WoW's native "ScrollFrame" frame type.
-- The native frame stores a single ScrollChild and a vertical/horizontal
-- scroll offset; the ScrollFrame clips to its own size and the child
-- renders translated by the scroll offset. No scroll bar UI here —
-- callers attach a MinimalScrollBar (or whatever) and drive
-- SetVerticalScroll from its OnScroll callback.

class "ScrollFrame" : extends "Frame" {
    __init = function(self, parent, name)
        Frame.__init(self, "ScrollFrame", parent, name)
    end;

    SetScrollChild = function(self, child)
        self._native:SetScrollChild(child._native)
    end;

    GetScrollChild = function(self)
        local n = self._native:GetScrollChild()
        return n and Frame(n) or nil
    end;

    SetVerticalScroll = function(self, offset)
        self._native:SetVerticalScroll(offset)
    end;

    GetVerticalScroll = function(self)
        return self._native:GetVerticalScroll()
    end;

    GetVerticalScrollRange = function(self)
        return self._native:GetVerticalScrollRange()
    end;

    SetHorizontalScroll = function(self, offset)
        self._native:SetHorizontalScroll(offset)
    end;

    GetHorizontalScroll = function(self)
        return self._native:GetHorizontalScroll()
    end;

    GetHorizontalScrollRange = function(self)
        return self._native:GetHorizontalScrollRange()
    end;

    -- Recompute scroll bounds based on the ScrollChild's current size.
    -- Call this after content changes (adding rows, resizing FontStrings,
    -- etc.) so GetVerticalScrollRange returns a fresh value.
    UpdateScrollChildRect = function(self)
        self._native:UpdateScrollChildRect()
    end;
}
