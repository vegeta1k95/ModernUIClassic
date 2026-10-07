-- MUI_BankGrid: every slot of the bank in one grid — the bank's own slots,
-- then each bank bag's — laid out as retail lays out a bank tab: columns of
-- seven filled downward, set in pairs. Retail's tab holds 98 slots; a fuller
-- Era bank scrolls sideways with the mouse wheel, a pair of columns a notch.
--
-- A slot is one of Era's own bag item buttons (ContainerFrameItemButtonTemplate).
-- Its handlers take the container from GetParent():GetID() and the slot from
-- GetID(), so each container has a holder frame carrying its id and a slot is
-- a child of its container's holder for good: a click, a drag, a split or a
-- use is Era's own code, exactly as in a bag window. Nothing of Era's updates
-- these buttons, though (they belong to no ContainerFrame), so BankSlot fills
-- them in.
--
--   BankGrid(parent)
--     :Refresh()                 re-read every container
--     :Highlight(container)      light one container's slots; nil for none
--     :ResetScroll()             back to the first column
--     .containers                the container ids, in grid order

local SLOT_W, SLOT_H = 33, 34     -- the bag windows' slot
local ROWS     = 7
local ROW_GAP  = 8
local PAIR_GAP = 7                -- inside a pair of columns
local BIG_GAP  = 17               -- between pairs
local COLUMNS  = 14               -- on screen at once

-- Left edge of a column, counted from 0.
local function ColumnX(column)
    return column * SLOT_W + math.ceil(column / 2) * PAIR_GAP + math.floor(column / 2) * BIG_GAP
end

local VIEW_W = ColumnX(COLUMNS - 1) + SLOT_W
local VIEW_H = ROWS * SLOT_H + (ROWS - 1) * ROW_GAP
local NOTCH  = ColumnX(2)

-- ---------------------------------------------------------------------
-- BankSlot: one slot of one container, looking like a bag window's slot.
-- ---------------------------------------------------------------------
class "BankSlot" {
    __init = function(self, holder, container, slot)
        self.container = container
        self.slot      = slot
        self.index     = nil      -- its place in the grid, kept by BankGrid

        local name = holder:GetName() .. "Item" .. slot
        Frame("Button", holder, name, "ContainerFrameItemButtonTemplate")
        local native = getglobal(name)

        local skin = MUI_ModuleBags:SkinBagSlot(native)
        self.button = skin.button
        self._icon  = skin.icon
        self._focus = skin.focus
        self.button:SetSize(SLOT_W, SLOT_H)
        self.button:SetID(slot)
        self.button:ClearAllPoints()

        -- A bag window puts this away on every update.
        Texture(native.BattlepayItemTexture):Hide()
        self._search   = Texture(native.searchOverlay)
        self._cooldown = Cooldown(getglobal(name .. "Cooldown"))

        -- The template's tooltip is SetBagItem, which shows nothing for the
        -- bank's own slots: to the tooltip those are inventory slots. Its
        -- periodic refresh goes through UpdateTooltip.
        if container == BANK_CONTAINER then
            self.button:HookScript("OnEnter", function() self:_ShowBankItem() end)
            self.button:SetNativeMethod("UpdateTooltip", function() self:_ShowBankItem() end)
        end
    end;

    Update = function(self)
        local info = C_Container.GetContainerItemInfo(self.container, self.slot)
        if info then
            self._icon:SetTexture(info.iconFileID)
            self._icon:SetDesaturated(info.isLocked)
            self._icon:SetQuality(info.quality)
            self._icon:Show()
        else
            self._icon:Hide()
            self._icon:SetQuality(nil)
        end
        self.button:SetItemButtonCount(info and info.stackCount)
        self._search:SetVisible(info and info.isFiltered)
        self:_UpdateCooldown(info)
    end;

    -- Only an item with a use effect is given a cooldown: NewEra's grid, built
    -- the same way, found the client reporting the global cooldown for the
    -- rest as well.
    _UpdateCooldown = function(self, info)
        local dimmed = false
        if info and C_Item.GetItemSpell(info.itemID) then
            local start, duration, enable = C_Container.GetContainerItemCooldown(self.container, self.slot)
            self._cooldown:SetCooldown(start, duration, enable)
            dimmed = duration > 0 and enable == 0
        else
            self._cooldown:Clear()
        end
        local shade = dimmed and 0.4 or 1
        self._icon:SetVertexColor(shade, shade, shade)
    end;

    _ShowBankItem = function(self)
        local tip = MUI_Tooltip
        tip:SetOwner(self.button, "ANCHOR_RIGHT")
        if tip:SetInventoryItem("player", BankButtonIDToInvSlotID(self.slot)) then
            tip:Show()
            if IsModifiedClick("COMPAREITEMS") or GetCVarBool("alwaysCompareItems") then
                tip:ShowCompareItem()
            end
        else
            tip:Hide()
        end
    end;

    SetFocused = function(self, focused)
        self._focus:SetVisible(focused)
    end;
}

-- ---------------------------------------------------------------------
-- BankGrid
-- ---------------------------------------------------------------------
class "BankGrid" : extends "ScrollFrame" {
    __init = function(self, parent)
        ScrollFrame.__init(self, parent, "MUI_BankGrid")
        self:SetSize(VIEW_W, VIEW_H)

        self._canvas = Frame("Frame", self)
        self._canvas:SetSize(VIEW_W, VIEW_H)
        self:SetScrollChild(self._canvas)

        self.containers = { BANK_CONTAINER }
        for i = 1, NUM_BANKBAGSLOTS do
            self.containers[i + 1] = NUM_BAG_SLOTS + i
        end

        self._holders = {}
        self._slots   = {}
        for i, container in ipairs(self.containers) do
            local holder = Frame("Frame", self._canvas, "MUI_BankGridBag" .. (i - 1))
            holder:SetID(container)
            holder:FillParent()
            self._holders[container] = holder
            self._slots[container]   = {}
        end

        self._scroll = 0
        self._range  = 0
        self:EnableMouseWheel(true)
        self:SetScript("OnMouseWheel", function(_, delta)
            self:_ScrollTo(self._scroll - delta * NOTCH)
        end)

        -- Where the view sits in the columns, when not all of them fit.
        self._track = Texture(parent, nil, "ARTWORK")
        self._track:SetColorTexture(0, 0, 0, 0.5)
        self._track:SetSize(VIEW_W, 3)
        self._track:Below(self, 5)
        self._thumb = Texture(parent, nil, "OVERLAY")
        self._thumb:SetColorTexture(1, 0.82, 0, 0.7)
        self._thumb:SetHeight(3)
        self:_ScrollTo(0)
    end;

    Refresh = function(self)
        local index = 0
        for _, container in ipairs(self.containers) do
            local slots = self._slots[container]
            local size  = C_Container.GetContainerNumSlots(container)
            for slot = 1, size do
                local item = slots[slot]
                if not item then
                    item = BankSlot(self._holders[container], container, slot)
                    slots[slot] = item
                end
                if item.index ~= index then
                    item.index = index
                    item.button:ClearAllPoints()
                    item.button:AlignParentTopLeft(
                        (index % ROWS) * (SLOT_H + ROW_GAP), ColumnX(math.floor(index / ROWS)))
                end
                item.button:Show()
                item:Update()
                index = index + 1
            end
            -- A smaller bag, or none, went into the slot.
            for slot = size + 1, #slots do
                slots[slot].button:Hide()
            end
        end

        local columns = math.ceil(index / ROWS)
        local width   = columns > 0 and ColumnX(columns - 1) + SLOT_W or 0
        self._canvas:SetWidth(math.max(width, VIEW_W))
        self._range = math.max(0, width - VIEW_W)
        self:_ScrollTo(self._scroll)
    end;

    Highlight = function(self, container)
        for id, slots in pairs(self._slots) do
            for _, item in ipairs(slots) do
                item:SetFocused(id == container)
            end
        end
    end;

    ResetScroll = function(self)
        self:_ScrollTo(0)
    end;

    _ScrollTo = function(self, offset)
        self._scroll = math.max(0, math.min(offset, self._range))
        self:SetHorizontalScroll(self._scroll)

        local scrolls = self._range > 0
        self._track:SetVisible(scrolls)
        self._thumb:SetVisible(scrolls)
        if scrolls then
            local total = VIEW_W + self._range
            self._thumb:SetWidth(VIEW_W * VIEW_W / total)
            self._thumb:ClearAllPoints()
            self._thumb:AlignLeft(self._track, VIEW_W * self._scroll / total)
        end
    end;
}
