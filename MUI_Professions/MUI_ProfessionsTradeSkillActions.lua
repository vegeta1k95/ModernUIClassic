-- Bottom-right action cluster: Create, qty editbox + arrows, Create All.
--
-- DoTradeSkill is fine to invoke from an addon-created Button, but DoCraft
-- is protected in Era 1.15.x — calling it from our handler triggers
-- "ADDON_ACTION_BLOCKED". For Crafts we reparent the native CraftCreateButton
-- and let Blizzard's own click handler call DoCraft from its secure context,
-- mirroring DFUI (ProfessionFrame.mixin.lua:2294-2298).

class "ProfessionsActionBar" : extends "Frame" {

    __init = function(self, parent)
        Frame.__init(self, "Frame", parent)
        self:SetSize(1, 1)

        self._btnCreate = ButtonGold(parent, nil, "Create")
        self._btnCreate:SetSize(85.5, 21)
        self._btnCreate:AlignParentBottomRight(7.5, 8.5)
        self._btnCreate:SetScale(0.9)
        self._btnCreate:SetEnabled(false)

        self._btnIncrement = Button(parent)
        self._btnIncrement:SetSize(20.5, 19.5)
        self._btnIncrement:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        self._btnIncrement:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
        self._btnIncrement:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
        self._btnIncrement:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        self._btnIncrement:LeftOf(self._btnCreate, 7.5, 0.5)
        self._btnIncrement:SetEnabled(false)

        self._editQuantity = EditBoxQuantity(parent)
        self._editQuantity:SetNumber(0)
        self._editQuantity:LeftOf(self._btnIncrement, 1)
        self._editQuantity:EnableMouse(false)

        self._btnDecrement = Button(parent)
        self._btnDecrement:SetSize(20.5, 19.5)
        self._btnDecrement:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
        self._btnDecrement:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
        self._btnDecrement:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
        self._btnDecrement:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        self._btnDecrement:LeftOf(self._editQuantity, 0.5)
        self._btnDecrement:SetEnabled(false)

        self._btnCreateAll = ButtonGold(parent, nil, "Create All [0]")
        self._btnCreateAll:SetSize(124, 21)
        self._btnCreateAll:LeftOf(self._btnDecrement, 2)
        self._btnCreateAll:SetScale(0.9)
        self._btnCreateAll:SetEnabled(false)

        self._parent = parent

        self._btnIncrement.OnClick = function()
            local max = self._numAvailable or 1
            local n   = self._editQuantity:GetNumber() or 0
            if n < max then self._editQuantity:SetNumber(n + 1) end
            self._editQuantity:ClearFocus()
        end
        self._btnDecrement.OnClick = function()
            local n = self._editQuantity:GetNumber() or 0
            if n > 1 then self._editQuantity:SetNumber(n - 1) end
            self._editQuantity:ClearFocus()
        end

        -- Clamp typed values to [1, _numAvailable] so the user can't queue
        -- more crafts than reagents allow.
        self._editQuantity.OnTextChanged = function()
            local max = self._numAvailable or 1
            local n   = self._editQuantity:GetNumber() or 0
            if n > max then self._editQuantity:SetNumber(max) end
        end

        self._btnCreate.OnClick = function()
            self._editQuantity:ClearFocus()
            if self._isUnlearned then return end
            local a = self._adapter
            if not a or not a.CanQueue then return end
            local idx = a:GetSelectionIndex()
            if idx <= 0 then return end
            local n = self._editQuantity:GetNumber() or 1
            if n < 1 then n = 1 end
            a:DoCraft(idx, n)
        end

        self._btnCreateAll.OnClick = function()
            self._editQuantity:ClearFocus()
            if self._isUnlearned then return end
            local a = self._adapter
            if not a or not a.CanQueue then return end
            local idx = a:GetSelectionIndex()
            local n   = self._numAvailable or 0
            if idx > 0 and n > 0 then
                self._editQuantity:SetNumber(n)
                a:DoCraft(idx, n)
            end
        end
    end;

    -- Anchor for the recipe pane's BOTTOMRIGHT.
    GetCreateButton = function(self) return self._btnCreate end;

    -- Reset the editbox to 1 — called from the overlay on cast failure /
    -- interrupt so the displayed pending count doesn't lag behind reality.
    ResetQuantity = function(self)
        if (self._editQuantity:GetNumber() or 0) > 1 then
            self._editQuantity:SetNumber(1)
        end
    end;

    -- Enable / disable buttons + editbox based on the currently-selected
    -- recipe. A recipe is "craftable" when it is learned (not isUnlearned)
    -- AND the native reports numAvailable > 0 (reagents are satisfied).
    -- DoCraft has no quantity arg in Era, so for CraftFrame only Create
    -- is enabled — multi-craft widgets stay disabled even with reagents.
    Refresh = function(self, adapter, isUnlearned)
        self._adapter     = adapter
        self._isUnlearned = isUnlearned

        local available, idx, isCraft = 0, 0, false
        if adapter and not isUnlearned then
            isCraft = not adapter.CanQueue
            idx = adapter:GetSelectionIndex()
            if idx > 0 then
                local _, _, n = adapter:GetRecipeInfo(idx)
                available = n or 0
            end
        end

        self._numAvailable = available
        local craftable    = idx > 0 and available > 0
        local multi        = craftable and not isCraft

        self._btnCreate:SetEnabled(craftable)
        self._btnCreateAll:SetEnabled(multi)
        self._btnIncrement:SetEnabled(multi)
        self._btnDecrement:SetEnabled(multi)
        self._editQuantity:SetEnabled(multi)
        self._editQuantity:EnableMouse(multi)

        -- Craft frame uses the reparented native CraftCreateButton instead
        -- of our gold _btnCreate; mirror the same enable state onto it.
        if isCraft and self._craftBtnWrapper then
            self._craftBtnWrapper:SetEnabled(craftable)
        end

        self._btnCreateAll:SetText("Create All [" .. available .. "]")

        -- Editbox flow:
        --   1. Selection changed         → reset to 1 (or 0 if not craftable).
        --   2. Same recipe, available ↓  → a craft consumed reagents; subtract
        --                                  the delta from the editbox so it
        --                                  reflects the remaining queued count.
        --   3. Same recipe, no drop      → leave the user's value alone, just
        --                                  clamp down if it's now above max.
        local nativeKey = adapter and tostring(adapter.nativeFrame) or "nil"
        local selKey = nativeKey .. "#" .. idx
        if self._lastSelKey ~= selKey then
            self._editQuantity:SetNumber(multi and 1 or 0)
        else
            local prev = self._lastAvailable or available
            local delta = prev - available
            if delta > 0 then
                local cur = (self._editQuantity:GetNumber() or 0) - delta
                if cur < 0 then cur = 0 end
                self._editQuantity:SetNumber(cur)
            end
            if multi then
                local n = self._editQuantity:GetNumber() or 0
                if n > available then self._editQuantity:SetNumber(available) end
                -- Queue just drained — pop back up to 1 so the user can
                -- click Create again without first hitting the up-arrow.
                if (self._editQuantity:GetNumber() or 0) <= 0 then
                    self._editQuantity:SetNumber(1)
                end
            elseif not craftable then
                self._editQuantity:SetNumber(0)
            end
        end
        self._lastSelKey    = selKey
        self._lastAvailable = available
    end;

    -- Move Blizzard's CraftCreateButton onto our overlay so its OnClick
    -- (the only legal way to call protected DoCraft) drives Enchanting
    -- crafts. Our gold _btnCreate is hidden while the Craft button is in use.
    InstallCraftButton = function(self)
        if not CraftCreateButton then return end
        if not self._craftBtnWrapper then
            self._craftBtnWrapper = Button(CraftCreateButton)
        end
        self._craftBtnWrapper:SetScale(0.9)
        self._craftBtnWrapper:SetParent(self._parent)
        self._craftBtnWrapper:ClearAllPoints()
        self._craftBtnWrapper:AlignParentBottomRight(7.5, 8.5)
        self._craftBtnWrapper:SetFrameLevel(self._parent:GetFrameLevel() + 10)
        self._craftBtnWrapper:Show()
        self._btnCreate:Hide()
        self._btnCreateAll:Hide()
        self._editQuantity:Hide()
        self._btnIncrement:Hide()
        self._btnDecrement:Hide()
    end;

    -- Hide the reparented CraftCreateButton; show our own gold button again
    -- (used when the active native flips back to TradeSkillFrame, or close).
    RemoveCraftButton = function(self)
        if self._craftBtnWrapper then self._craftBtnWrapper:Hide() end
        self._btnCreate:Show()
        self._btnCreateAll:Show()
        self._editQuantity:Show()
        self._btnIncrement:Show()
        self._btnDecrement:Show()
    end;

    HideCraftButton = function(self)
        if self._craftBtnWrapper then self._craftBtnWrapper:Hide() end
    end;
}
