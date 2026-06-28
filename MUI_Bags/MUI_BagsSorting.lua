-- Bag / bank sorting for Classic Era.
--
-- Era has no C_Container.SortBags(), so we implement it in Lua. One click runs
-- the whole thing to completion: the target order is computed ONCE (after
-- stacking), then we drive the bags toward that frozen target across
-- BAG_UPDATE_DELAYED ticks until the live layout matches it.
--
-- Why not a single sweep: each PickupContainerItem move makes the server lock
-- the slots it touches until it confirms, and a chained pickup onto a locked
-- slot is dropped. So we only ever fire DISJOINT moves within one frame (each
-- physical slot used at most once), then wait for the locks to clear and do
-- the next batch. Exposes the singleton MUI_BagSorter:SortBags() / :SortBank().

local NUM_BAGS     = NUM_BAG_SLOTS or 4
local NUM_BANKBAGS = NUM_BANKBAGSLOTS or 7
local BANK         = BANK_CONTAINER or -1
local MAX_PASSES   = 60     -- hard stop against a stuck loop
local MAX_STALLS   = 12     -- give up if no batch lands across this many retries
local WATCHDOG     = 5      -- seconds; force-finish so a stuck run can't block re-clicks

-- Container id lists (filtered to ones that actually exist at sort time).
local BAG_CONTAINERS = { 0 }
for i = 1, NUM_BAGS do BAG_CONTAINERS[#BAG_CONTAINERS + 1] = i end

local BANK_CONTAINERS = { BANK }
for i = NUM_BAGS + 1, NUM_BAGS + NUM_BANKBAGS do BANK_CONTAINERS[#BANK_CONTAINERS + 1] = i end

-- Sort key: group by item class -> subclass -> quality (high first) -> name ->
-- itemID -> stack size. Uncached items (GetItemInfo nil) sort to the end.
local function ComputeKey(item)
    local name, _, _, _, _, _, _, maxStack, _, _, _, classID, subclassID = GetItemInfo(item.link or item.itemID)
    item.name       = name or ""
    item.maxStack   = maxStack or 1
    item.classID    = classID or 99
    item.subclassID = subclassID or 99
end

local function ItemBefore(a, b)
    if a.classID    ~= b.classID    then return a.classID    < b.classID    end
    if a.subclassID ~= b.subclassID then return a.subclassID < b.subclassID end
    if a.quality    ~= b.quality    then return a.quality    > b.quality    end
    if a.name       ~= b.name       then return a.name       < b.name       end
    if a.itemID     ~= b.itemID     then return a.itemID     < b.itemID     end
    return a.count > b.count
end

object "BagSorter" {

    SortBags = function(self) self:Start(BAG_CONTAINERS) end;
    SortBank = function(self) self:Start(BANK_CONTAINERS) end;

    Start = function(self, containerIDs)
        if self._running then return end
        if InCombatLockdown() then return end

        local containers = {}
        for _, id in ipairs(containerIDs) do
            local n = C_Container.GetContainerNumSlots(id)
            if n and n > 0 then containers[#containers + 1] = { id = id, size = n } end
        end
        if #containers == 0 then return end

        self._containers = containers
        self._running = true
        self._phase   = "stack"   -- "stack" -> consolidate partials, then "order"
        self._order   = nil       -- frozen target itemID-per-slot once ordering begins
        self._passes  = 0
        self._stalls  = 0

        if not self._events then
            self._events = Frame("Frame")
            self._events:RegisterEventHandler("BAG_UPDATE_DELAYED", function()
                if self._running then self:Step() end
            end)
        end

        -- Watchdog: never let a stuck run keep _running set (which would block
        -- the next click). A fresh Start bumps the token so old timers no-op.
        self._token = (self._token or 0) + 1
        local token = self._token
        C_Timer.After(WATCHDOG, function()
            if self._running and self._token == token then self:Finish() end
        end)

        ClearCursor()
        self:Step()
    end;

    Finish = function(self)
        self._running = false
        self._containers = nil
        self._order = nil
    end;

    -- Read every slot in the target containers plus the subset holding an item
    -- (with sort key + maxStack precomputed). pos.index is the flat slot index.
    Snapshot = function(self)
        local slots, items = {}, {}
        local k = 0
        for _, c in ipairs(self._containers) do
            for slot = 1, c.size do
                k = k + 1
                local pos = { bag = c.id, slot = slot, index = k }
                local info = C_Container.GetContainerItemInfo(c.id, slot)
                if info then
                    pos.itemID  = info.itemID
                    pos.count   = info.stackCount or 1
                    pos.quality = info.quality or 1
                    pos.link    = info.hyperlink
                    pos.locked  = info.isLocked
                    ComputeKey(pos)
                    items[#items + 1] = pos
                end
                slots[k] = pos
            end
        end
        return slots, items
    end;

    -- One batch of work, re-triggered by BAG_UPDATE_DELAYED until done.
    Step = function(self)
        self._passes = self._passes + 1
        if self._passes > MAX_PASSES then self:Finish(); return end

        local slots, items = self:Snapshot()

        local moved
        if self._phase == "stack" then
            moved = self:StackPass(items)
            if not moved then
                -- Stacking settled: freeze the sorted target, start ordering.
                self._phase = "order"
                self._order = self:ComputeOrder(items)
                moved = self:OrderPass(slots, self._order)
            end
        else
            moved = self:OrderPass(slots, self._order)
        end

        if moved then
            self._stalls = 0
            return  -- BAG_UPDATE_DELAYED will run the next batch
        end

        if self._phase == "order" and self:IsSorted(slots, self._order) then
            self:Finish()
            return
        end

        -- Nothing moved but not done: the slots we need are still locked from a
        -- previous batch. Retry shortly; bail if it never settles.
        self._stalls = self._stalls + 1
        if self._stalls > MAX_STALLS then
            self:Finish()
        else
            C_Timer.After(0.1, function() if self._running then self:Step() end end)
        end
    end;

    -- Merge a batch of same-item partial stacks. Only disjoint, unlocked pairs
    -- this frame; 3-pickup (src, dst, src) merges with overflow back to src.
    StackPass = function(self, items)
        local partials = {}
        for _, it in ipairs(items) do
            if it.maxStack > 1 and it.count < it.maxStack and not it.locked then
                local list = partials[it.itemID]
                if not list then list = {}; partials[it.itemID] = list end
                list[#list + 1] = it
            end
        end

        local touched, moved = {}, false
        for _, list in pairs(partials) do
            local p = 1
            while p + 1 <= #list do
                local dst, src = list[p], list[p + 1]
                if not touched[dst.index] and not touched[src.index] then
                    C_Container.PickupContainerItem(src.bag, src.slot)
                    C_Container.PickupContainerItem(dst.bag, dst.slot)
                    C_Container.PickupContainerItem(src.bag, src.slot)
                    ClearCursor()
                    touched[dst.index] = true
                    touched[src.index] = true
                    moved = true
                end
                p = p + 2
            end
        end
        return moved
    end;

    -- The frozen target: sorted itemID per flat slot index (nil past the last
    -- stack). Computed once, after stacking, so the goal never shifts mid-sort.
    ComputeOrder = function(self, items)
        local sorted = {}
        for i = 1, #items do sorted[i] = items[i] end
        table.sort(sorted, ItemBefore)
        local order = {}
        for i = 1, #sorted do order[i] = sorted[i].itemID end
        return order
    end;

    -- Move a batch toward the frozen order: each wrong slot pulls its desired
    -- item in from a later slot. Disjoint, unlocked pairs only this frame.
    -- Matching by itemID means we never drop an item onto the same item, so
    -- these are always clean swaps (no accidental merges), preserving stacks.
    OrderPass = function(self, slots, order)
        local touched, moved = {}, false
        for k = 1, #slots do
            local cur  = slots[k]
            local want = order[k]
            if want and cur.itemID ~= want and not cur.locked and not touched[cur.index] then
                local from
                for j = k + 1, #slots do
                    local s = slots[j]
                    if s.itemID == want and not s.locked and not touched[s.index] then
                        from = s
                        break
                    end
                end
                if from then
                    C_Container.PickupContainerItem(from.bag, from.slot)
                    C_Container.PickupContainerItem(cur.bag, cur.slot)
                    C_Container.PickupContainerItem(from.bag, from.slot)
                    ClearCursor()
                    touched[cur.index]  = true
                    touched[from.index] = true
                    moved = true
                end
            end
        end
        return moved
    end;

    IsSorted = function(self, slots, order)
        for k = 1, #slots do
            if slots[k].itemID ~= order[k] then return false end
        end
        return true
    end;
}
