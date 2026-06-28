-- MinimapTooltip: single coordinator for every minimap hover tooltip.
-- Any widget that wants its content merged into the minimap tooltip
-- registers a source and unregisters when destroyed. Per tick the
-- coordinator walks all sources, picks the highest-priority one per
-- dedup group, and renders one merged tooltip — so simultaneously
-- hovering a quest pin, the focused-quest arrow, a quest area, and a
-- service-NPC pin produces a single deduped tooltip instead of four
-- racing to own GameTooltip.
--
-- Source record:
--   isHovered = function() -> bool      -- called each tick; keep cheap
--   build     = function()               -- appends lines via Tooltip.*
--   dedupKey  = string or function()     -- optional; defaults to the
--                                            registration id. Sources
--                                            sharing a key merge; the
--                                            highest `priority` wins.
--   priority  = number (default 0)
--
-- Blip tooltip integration: when GameTooltip is already owned by
-- Minimap (Classic's native herb/ore/treasure tooltip), the coordinator
-- APPENDS our hovered content after the blip line instead of stealing
-- ownership. Augmentation fires once per blip (keyed on line-1 text).

object "MinimapTooltip" : extends "Frame" {
    __init = function(self)
        Frame.__init(self, "Frame", nil, "MUI_MinimapTooltipDriver")

        self._sources       = {}       -- [id] = source record
        self._tooltipOwner  = Frame("Frame", nil, "MUI_MinimapTooltipOwner")
        self._currentGroups = nil      -- last rendered hover-group map
        self._tooltipShown  = false
        self._lastAugmentedBlip = nil

        self._elapsed = 0
        self:SetScript("OnUpdate", function(_, dt)
            self._elapsed = self._elapsed + dt
            if self._elapsed < 0.05 then return end
            self._elapsed = 0
            self:_Refresh()
        end)
    end;

    -- ---- registration -----------------------------------------------------

    Register = function(self, id, source)
        self._sources[id] = source
    end;

    Unregister = function(self, id)
        self._sources[id] = nil
    end;

    -- ---- internals --------------------------------------------------------

    -- Walk all sources, collect hovered ones into `groups` keyed by
    -- resolved dedupKey. Each group keeps the highest-priority source.
    _CollectHovered = function(self)
        local groups = {}
        for id, src in pairs(self._sources) do
            if src.isHovered and src.isHovered() then
                local key = src.dedupKey
                if type(key) == "function" then key = key() end
                if not key then key = id end
                local prio = src.priority or 0
                local existing = groups[key]
                if not existing or existing.priority < prio then
                    groups[key] = { id = id, source = src, priority = prio }
                end
            end
        end
        return groups
    end;

    -- True if `prev` and `now` describe the same set of winning sources.
    -- Compares both the key set and the chosen source id per key — a pin
    -- overriding an arrow within the same dedup group counts as a change.
    _SameGroups = function(self, prev, now)
        if not prev then return next(now) == nil end
        for k, v in pairs(now) do
            if not prev[k] or prev[k].id ~= v.id then return false end
        end
        for k in pairs(prev) do
            if not now[k] then return false end
        end
        return true
    end;

    -- Iterate groups in stable key order and invoke each winner's build.
    _BuildTooltip = function(self, groups)
        local keys = {}
        for k in pairs(groups) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, key in ipairs(keys) do
            groups[key].source.build()
        end
    end;

    _Refresh = function(self)
        local groups = self:_CollectHovered()
        local shown  = MUI_Tooltip:IsShown()
        local any    = next(groups) ~= nil

        if not any then
            if self._tooltipShown then
                if MUI_Tooltip:IsOwnedBy(self._tooltipOwner) then
                    MUI_Tooltip:Hide()
                end
            end
            self._tooltipShown       = false
            self._currentGroups      = nil
            self._lastAugmentedBlip  = nil
            return
        end

        -- WoW is showing its own minimap blip tooltip (herb / ore / etc.).
        -- Append our content once per distinct blip. SetOwner on a new blip
        -- clears everything (including our previous augmentation), then
        -- AddLine sets a new line-1 text — which is our change token.
        if shown and MUI_Tooltip:IsOwnedBy(MUI_Minimap) then
            local blipName = GameTooltipTextLeft1
                             and GameTooltipTextLeft1:GetText() or ""
            if blipName ~= "" and blipName ~= self._lastAugmentedBlip then
                self:_BuildTooltip(groups)
                MUI_Tooltip:Refresh()
                self._lastAugmentedBlip = blipName
            end
            self._currentGroups = groups
            self._tooltipShown  = false   -- we don't own this render
            return
        end

        -- Any non-Minimap owner path invalidates the blip augmentation
        -- key: next blip show needs to re-augment.
        self._lastAugmentedBlip = nil

        -- Skip rebuild only when the winning source set hasn't changed AND
        -- our tooltip is still onscreen with us as owner.
        local stillOurs = shown and MUI_Tooltip:IsOwnedBy(self._tooltipOwner)
        if stillOurs and self:_SameGroups(self._currentGroups, groups) then
            return
        end

        self._currentGroups = groups
        self._tooltipShown  = true
        MUI_Tooltip:ShowFor(self._tooltipOwner, "ANCHOR_CURSOR", function()
            self:_BuildTooltip(groups)
        end)
    end;
}
