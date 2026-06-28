-- Tooltip: wrapper for a GameTooltip-style native tooltip frame.
-- Singleton MUI_Tooltip wraps GameTooltip; module code goes through it
-- (MUI_Tooltip:AddLine(...), :ShowFor(...), …), never touching GameTooltip.

local function _unwrap(owner)
    if type(owner) == "table" and owner._native then
        return owner._native
    end
    return owner
end

class "TooltipBase" : extends "Frame" {

    __init = function(self, native, prefix)
        Frame.__init(self, native)

        self._prefix = prefix or ""

        -- Refont policy:
        --   * Watermark `_refontedAt` = "lines 1.._refontedAt have
        --     already been handled". On any event we only refont
        --     slots beyond it — so lines added LATER (after
        --     OnTooltipSetItem) get caught on the next tick without
        --     re-stomping fonts on lines we already own.
        --   * Reset to 0 on OnTooltipCleared (Blizzard's SetX path
        --     calls ClearLines first, so every populate cycle starts
        --     virgin — including tick refreshes and new items).
        --   * Wrapper writes (AddLine, AddDoubleLine, InsertLine, etc.)
        --     bump _refontedAt to current NumLines after they apply
        --     their own per-line size. That marks "we own this line,
        --     don't re-default it."
        --
        -- The default rule (line 1 = 13 pt, rest = 10.5 pt) only ever
        -- applies to slots Blizzard added that we haven't touched yet.
        -- Custom-built tooltips (ShowFor) go straight through wrapper
        -- writes that watermark each line as they go, so the blanket
        -- refont never fires on them.
        --
        -- Hooks registered HERE in __init run BEFORE any caller-
        -- registered OnTooltipSet* hooks (HookScript fires in
        -- registration order). Caller hooks therefore see an already-
        -- refonted tooltip and apply per-line sizes on top.
        self._refontedAt = 0

        local function _maybeRefont()
            local n = self._native:NumLines()
            if n > self._refontedAt then
                self:_RefontRange(self._refontedAt + 1, n)
                self._refontedAt = n
            end
        end

        self:HookScript("OnTooltipCleared", function()
            self._refontedAt = 0
        end)
        self:HookScript("OnTooltipSetItem",  _maybeRefont)
        self:HookScript("OnTooltipSetUnit",  _maybeRefont)
        self:HookScript("OnTooltipSetSpell", _maybeRefont)
        self:HookScript("OnShow",            _maybeRefont)
        -- OnUpdate catches lines that get appended AFTER OnTooltipSet*
        -- fired (concrete case: comparison shopping tooltips' "If you
        -- replace this item..." delta-stat block, which Blizzard
        -- appends to ShoppingTooltip1/2 after the SetCompareItem flow
        -- has already fired its events). Per-frame `n > _refontedAt`
        -- check is a cheap integer compare and a no-op when nothing
        -- new has been added.
        self:HookScript("OnUpdate", _maybeRefont)
    end;

    -- Apply the default refont rule (line 1 = 13 pt, line N>1 = 10.5
    -- pt) to a closed range of slots. `from`/`to` are 1-based line
    -- indices, inclusive. Used by the watermark refont path.
    _RefontRange = function(self, from, to)
        local prefixLeft  = (self:GetName() or self._prefix) .. "TextLeft"
        local prefixRight = (self:GetName() or self._prefix) .. "TextRight"
        for i = from, to do
            local fsL = _G[prefixLeft  .. i]
            local fsR = _G[prefixRight .. i]
            local size = (i == 1) and 13 or 10.5
            if fsL then
                fsL:SetFont(MUI.FONT, size, "")
                -- SetFont can flip the FontString's word-wrap state. Force
                -- it back on so long "Use:" lines and similar wrap across
                -- multiple display lines instead of being truncated with
                -- "..." at the tooltip's frame edge.
                if fsL.SetWordWrap then fsL:SetWordWrap(true) end
            end
            if fsR then
                fsR:SetFont(MUI.FONT, size, "")
                if fsR.SetWordWrap then fsR:SetWordWrap(true) end
            end
        end
    end;

    -- Whole-tooltip refont. Kept for callers that want to force a
    -- full reset (Refresh()).
    _RefreshFont = function(self)
        self:_RefontRange(1, self:NumLines())
    end;

    _GetLastLine = function(self)
        return self:GetLine(self:NumLines())
    end;

    -- ===== Content =====

    AddTitle = function(self, text, wrap)
        self:AddLine(text, 1, 0.82, 0, wrap, 13)
    end;

    AddLine = function(self, text, r, g, b, wrap, size)
        self._native:AddLine(text, r, g, b, wrap)

        size = size or 10.5
        local left, right = self:_GetLastLine()
        -- SetFont resets the FontString's word-wrap state, so re-apply `wrap`
        -- after it — otherwise a long wrapped line gets truncated with "..."
        -- (same gotcha handled in _RefontRange).
        if left then
            left:SetFont(MUI.FONT, size, "")
            if left.SetWordWrap then left:SetWordWrap(wrap and true or false) end
        end
        if right then
            right:SetFont(MUI.FONT, size, "")
            if right.SetWordWrap then right:SetWordWrap(wrap and true or false) end
        end

        self._refontedAt = self._native:NumLines()
    end;

    AddDoubleLine = function(self, left, right, lr, lg, lb, rr, rg, rb, size)
        self._native:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)

        size = size or 13
        local l, r = self:_GetLastLine()
        if l then l:SetFont(MUI.FONT, size, "") end
        if r then r:SetFont(MUI.FONT, size, "") end

        self._refontedAt = self._native:NumLines()
    end;

    AddBlank = function(self, size)
        self:AddLine(" ")
    end;

    -- Insert a line at 1-based `index`, shifting every line at and below
    -- that index down by one. Native GameTooltip only appends, so the
    -- algorithm is:
    --
    --   1) PRE-PASS: snapshot the full state of every existing line
    --      (text + color + font/size for both Left and Right columns).
    --   2) Append a dummy line via AddLine to grow NumLines by 1.
    --      Its content is irrelevant — gets overwritten.
    --   3) RESTORE: write snapshot[k-1] into slot k for k > index, so
    --      every shifted line keeps its original text + color + font.
    --   4) APPLY: write the caller's params into slot `index`, last —
    --      so the inserted line's color/font win cleanly.
    --
    -- Slots 1..index-1 are untouched and keep their state implicitly.
    --
    -- index out of range:
    --   < 1               clamps to 1 (push everything down).
    --   > NumLines + 1    clamps to NumLines + 1 (append).
    InsertLine = function(self, index, text, r, g, b, wrap, size)
        local prefix = self:GetName() or self._prefix
        local n = self:NumLines()
        size = size or 10.5

        if not index or index < 1 then index = 1 end
        if index > n + 1 then index = n + 1 end

        -- Append-at-end fast path: no shift, just AddLine.
        if index == n + 1 then
            self:AddLine(text, r, g, b, wrap, size)
            return
        end

        -- Step 1: snapshot every existing line.
        local snap = {}
        for k = 1, n do
            local L = _G[prefix .. "TextLeft"  .. k]
            local R = _G[prefix .. "TextRight" .. k]
            local s = {}
            if L then
                s.lText = L:GetText()
                s.lR, s.lG, s.lB, s.lA = L:GetTextColor()
                s.lFont, s.lSize, s.lFlags = L:GetFont()
                if L.GetWordWrap then s.lWrap = L:GetWordWrap() end
            end
            if R then
                s.rText = R:GetText()
                s.rR, s.rG, s.rB, s.rA = R:GetTextColor()
                s.rFont, s.rSize, s.rFlags = R:GetFont()
                if R.GetWordWrap then s.rWrap = R:GetWordWrap() end
            end
            snap[k] = s
        end

        -- Step 2: grow NumLines by 1. Pass the caller's params so
        -- AddLine's wrap handling stamps the requested wrap on the
        -- newly-allocated FontString slot — slot n+1 inherits any
        -- internal wrap-state Blizzard tracks. (We overwrite its text
        -- with snap[n] in step 3, but the wrap state stays put.)
        self._native:AddLine(text,1,1,1,true)

        -- Step 3: shift slots index+1..n+1 ← snap[index..n].
        for k = index + 1, n + 1 do
            local s = snap[k - 1]
            if s then
                local L = _G[prefix .. "TextLeft"  .. k]
                local R = _G[prefix .. "TextRight" .. k]
                if L then
                    L:SetText(s.lText)
                    if s.lR then L:SetTextColor(s.lR, s.lG, s.lB, s.lA) end
                    if s.lFont then L:SetFont(s.lFont, s.lSize, s.lFlags or "") end
                    if s.lWrap ~= nil and L.SetWordWrap then L:SetWordWrap(s.lWrap) end
                    L:SetShown(s.lText ~= nil)
                end
                if R then
                    R:SetText(s.rText)
                    if s.rR then R:SetTextColor(s.rR, s.rG, s.rB, s.rA) end
                    if s.rFont then R:SetFont(s.rFont, s.rSize, s.rFlags or "") end
                    if s.rWrap ~= nil and R.SetWordWrap then R:SetWordWrap(s.rWrap) end
                    R:SetShown(s.rText ~= nil)
                end
            end
        end

        -- Step 4: apply caller's params at slot `index`. Last write
        -- wins, so this overwrites whatever state slot `index` had
        -- before (which was originally the line we just shifted into
        -- slot index+1).
        local atL = _G[prefix .. "TextLeft"  .. index]
        local atR = _G[prefix .. "TextRight" .. index]
        if atL then
            atL:SetText(text)
            atL:SetTextColor(r or 1, g or 1, b or 1, 1)
            atL:SetFont(MUI.FONT, size, "")
            if atL.SetWordWrap then atL:SetWordWrap(wrap == true) end
            atL:SetShown(text ~= nil)
        end
        if atR then
            -- AddLine never sets a right-column value, so clear here
            -- (the previous slot may have carried right-column text
            -- from whatever lived at slot `index` before).
            atR:SetText(nil)
            atR:SetShown(false)
        end

        -- Relayout — line widths need recomputing after SetText.
        self._refontedAt = self._native:NumLines()
        self._native:Show()
    end;

    -- Remove the line at 1-based `index`, shifting every line below up
    -- by one. Native GameTooltip has no per-line removal API, so we
    -- mirror InsertLine's snapshot-and-restore pattern in reverse:
    --
    --   1) PRE-PASS: snapshot lines `index+1..n` (those that will move).
    --   2) RESTORE: write snapshot[k+1] into slot k for k = index..n-1.
    --   3) BLANK the trailing slot n — there's no API to shrink
    --      NumLines, so the slot stays allocated but hidden + empty.
    --      Layout typically collapses it to ~0 height after Show().
    --
    -- Caveat: NumLines() will still report n after the call (Blizzard
    -- tracks it internally and exposes no shrink). A subsequent
    -- AddLine would append to slot n+1, leaving the empty slot n
    -- between the live content and the new line. If you need clean
    -- shrink semantics, follow up with ClearLines + rebuild.
    --
    -- index out of range:
    --   nil / < 1 / > NumLines  →  no-op.
    RemoveLine = function(self, index)
        local prefix = self:GetName() or self._prefix
        local n = self:NumLines()
        if not index or index < 1 or index > n then return end

        -- Step 1: snapshot lines below `index`.
        local snap = {}
        for k = index + 1, n do
            local L = _G[prefix .. "TextLeft"  .. k]
            local R = _G[prefix .. "TextRight" .. k]
            local s = {}
            if L then
                s.lText = L:GetText()
                s.lR, s.lG, s.lB, s.lA = L:GetTextColor()
                s.lFont, s.lSize, s.lFlags = L:GetFont()
                if L.GetWordWrap then s.lWrap = L:GetWordWrap() end
            end
            if R then
                s.rText = R:GetText()
                s.rR, s.rG, s.rB, s.rA = R:GetTextColor()
                s.rFont, s.rSize, s.rFlags = R:GetFont()
                if R.GetWordWrap then s.rWrap = R:GetWordWrap() end
            end
            snap[k] = s
        end

        -- Step 2: shift snap[k+1] → slot k for k = index..n-1.
        for k = index, n - 1 do
            local s = snap[k + 1]
            if s then
                local L = _G[prefix .. "TextLeft"  .. k]
                local R = _G[prefix .. "TextRight" .. k]
                if L then
                    L:SetText(s.lText)
                    if s.lR then L:SetTextColor(s.lR, s.lG, s.lB, s.lA) end
                    if s.lFont then L:SetFont(s.lFont, s.lSize, s.lFlags or "") end
                    if s.lWrap ~= nil and L.SetWordWrap then L:SetWordWrap(s.lWrap) end
                    L:SetShown(s.lText ~= nil)
                end
                if R then
                    R:SetText(s.rText)
                    if s.rR then R:SetTextColor(s.rR, s.rG, s.rB, s.rA) end
                    if s.rFont then R:SetFont(s.rFont, s.rSize, s.rFlags or "") end
                    if s.rWrap ~= nil and R.SetWordWrap then R:SetWordWrap(s.rWrap) end
                    R:SetShown(s.rText ~= nil)
                end
            end
        end

        -- Step 3: blank the trailing slot.
        local lastL = _G[prefix .. "TextLeft"  .. n]
        local lastR = _G[prefix .. "TextRight" .. n]
        if lastL then
            lastL:SetText("")
            lastL:SetShown(false)
        end
        if lastR then
            lastR:SetText("")
            lastR:SetShown(false)
        end

        self._refontedAt = self._native:NumLines()
        self._native:Show()
    end;

    ClearLines = function(self)
        self._native:ClearLines()
    end;

    -- True when any existing left-column line equals `text`. Used when
    -- appending to an already-populated tooltip so identical title/objective
    -- rows don't get duplicated by stacked hover targets.
    HasLine = function(self, text)
        if not text then return false end
        local prefix = (self:GetName() or self._prefix) .. "TextLeft"
        for i = 1, self._native:NumLines() do
            local fs = _G[prefix .. i]
            if fs and fs:GetText() == text then return true end
        end
        return false
    end;

    GetLine = function(self, index)
        local left = _G[self._prefix .. "TextLeft" .. index]
        local right = _G[self._prefix .. "TextRight" .. index]
        return left, right
    end;

    -- Put text in the RIGHT column of an existing line (1-based). The SetX
    -- populators (SetSpellByID, SetTalent) only fill the left column, so this
    -- adds e.g. the spell rank to the right of the first line. Re-shows so the
    -- tooltip widens for the new column.
    SetLineRight = function(self, index, text, r, g, b, size)
        local _, right = self:GetLine(index)
        if not right then return end
        right:SetFont(MUI.FONT, size or ((index == 1) and 13 or 10.5), "")
        right:SetText(text)
        right:SetTextColor(r or 1, g or 1, b or 1, 1)
        right:Show()
        self._native:Show()
    end;

    NumLines = function(self)
        return self._native:NumLines()
    end;

    -- Native passthrough getters for callers using the wrapper inside
    -- OnTooltipSet* hooks (where `self` would otherwise need to be the
    -- raw native frame to call these). GetItem returns (name, link)
    -- when an item is set; GetUnit returns (name, unit) when a unit is.
    GetItem = function(self)
        return self._native:GetItem()
    end;

    GetUnit = function(self)
        return self._native:GetUnit()
    end;

    GetSpell = function(self)
        if self._native.GetSpell then
            return self._native:GetSpell()
        end
    end;

    SetHyperlink = function(self, link)
        self._native:SetHyperlink(link)
    end;

    SetText = function(self, text, r,g,b,a, wrap)
        self._native:SetText(text, r,g,b,a, wrap)
    end;

    SetTalent = function(self, talentID, isInspect, talentGroup, inspectedUnit, classID)
        self._native:SetTalent(talentID, isInspect, talentGroup, inspectedUnit, classID)
    end;

    SetSpellByID = function(self, spellID)
        self._native:SetSpellByID(spellID)
    end;

    SetTradeSkillItem = function(self, index, reagentIndex)
        if self._native.SetTradeSkillItem then
            self._native:SetTradeSkillItem(index, reagentIndex)
        end
    end;

    SetCraftSpell = function(self, index)
        if self._native.SetCraftSpell then
            self._native:SetCraftSpell(index)
        end
    end;

    -- ===== Owner =====

    SetOwner = function(self, owner, anchor)
        self._native:SetOwner(_unwrap(owner), anchor or "ANCHOR_RIGHT")
    end;

    GetOwner = function(self)
        return self._native:GetOwner()
    end;

    IsOwnedBy = function(self, owner)
        return self._native:GetOwner() == _unwrap(owner)
    end;

    -- ===== Convenience =====

    -- Set owner, populate via buildFunc, show.
    ShowFor = function(self, owner, anchor, buildFunc)
        self:SetOwner(owner, anchor)
        if buildFunc then buildFunc(self) end
        
        self:Show()
    end;

    -- Recalculate tooltip size after appending lines outside of ShowFor.
    -- Native :Show() on an already-shown tooltip just re-lays it out.
    Refresh = function(self)
        self:_RefreshFont()
        self:Show()
    end;

    -- ===== Sizing =====

    -- Floor the tooltip to at least this many pixels wide (it still
    -- grows to fit longer wrapped lines). Persists on tooltip
    -- across hides; pass 0 to clear.
    SetMinimumWidth = function(self, width)
        self._native:SetMinimumWidth(width or 0)
    end;

}

object "Tooltip" : extends "TooltipBase" {
    __init = function(self)
        TooltipBase.__init(self, GameTooltip, "GameTooltip")
    end
}

object "TooltipComparison1" : extends "TooltipBase" {
    __init = function(self)
        TooltipBase.__init(self, ShoppingTooltip1, "ShoppingTooltip1")
    end
}

object "TooltipComparison2" : extends "TooltipBase" {
    __init = function(self)
        TooltipBase.__init(self, ShoppingTooltip2, "ShoppingTooltip2")
    end
}

object "TooltipItemRef" : extends "TooltipBase" {
    __init = function(self)
        TooltipBase.__init(self, ItemRefTooltip, "ItemRefTooltip")
    end
}

object "TooltipItemRefComparison1" : extends "TooltipBase" {
    __init = function(self)
        TooltipBase.__init(self, ItemRefShoppingTooltip1, "ItemRefShoppingTooltip1")
    end
}

object "TooltipItemRefComparison2" : extends "TooltipBase" {
    __init = function(self)
        TooltipBase.__init(self, ItemRefShoppingTooltip2, "ItemRefShoppingTooltip2")
    end
}
