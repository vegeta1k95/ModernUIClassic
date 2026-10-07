-- MUI_Bank: retail's bank window on Classic Era.
--
--   MUI_BankFrame    the window, on Era's own bank frame
--   MUI_BankGrid     every bank slot in one grid
--   MUI_BankTabs     the bag slots, as tabs down the right edge
--
-- The bank bags' contents are part of the grid, so their own bag windows are
-- kept shut. Not carried over from retail, which Era has nothing for: bank
-- tabs, the warband bank, deposit settings.
--
-- Stands down when a bag addon is loaded: those bring their own bank.

local RIVALS = { "Bagnon", "Bagshui", "ArkInventory", "AdiBags", "Baganator", "Combuctor", "OneBag3", "tdBag2", "Sorted" }

object "ModuleBank" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Bank")
    end;

    OnEnable = function(self)
        for _, addon in ipairs(RIVALS) do
            if C_AddOns.IsAddOnLoaded(addon) then return end
        end
        self.window = BankWindow()
        self:_KeepBagWindowsShut()
    end;

    -- A container frame that comes up for a bank bag goes straight back down.
    _KeepBagWindowsShut = function(self)
        local first, last = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS
        for i = 1, NUM_CONTAINER_FRAMES do
            local frame = Frame(getglobal("ContainerFrame" .. i))
            frame:HookScript("OnShow", function()
                local id = frame:GetID()
                if id >= first and id <= last then
                    self._shutAt = GetTime()
                    frame:Hide()
                end
            end)
        end

        -- "Open all bags", pressed at the bank with every bag open, closes
        -- them and then, finding the bank bags closed, opens the lot again.
        -- With the bank bags never open, the key could not close the bags at
        -- all: when it has just tried a bank bag, close them as it set out to.
        hooksecurefunc("ToggleAllBags", function()
            if self._shutAt == GetTime() then CloseAllBags() end
        end)
    end;
}
