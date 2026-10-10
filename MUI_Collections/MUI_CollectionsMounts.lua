-- MUI_CollectionsMounts: the Collections window's mounts page — retail's
-- mount journal over Era's mounts (MUI_MountDB). The list down the left with
-- the search box and the filter over it, the mount on show to its right, how
-- many the character has above the list, the button that mounts under it.
--
-- Era has no mount journal: a mount is an item in the bags (the paladin's and
-- the warlock's own are spells). So the character has a mount while it has
-- the item, the bank counted, and can ride it while the item is in the bags
-- and it meets what the item asks for.
--
--   CollectionsMounts(canvas)
--     :Refresh()              list, selection, count and button, as things stand
--     :SelectMount(mount)
--     :Reset()                the search emptied, the model back as it stood
--     :StateOf(mount)         whether the character has it, can ride it, rides it
--     :IsForPlayer(mount)     whether its side and class may ever ride it
--     :PickUp(mount)          onto the cursor, for an action bar
--     :Link(mount)            into the chat line being written

local Style = MUI_CollectionsStyle
local Log   = MUI_CollectionsLog

local LEFT_W, GAP = 260, 20
local TOP, BOTTOM = 60, 26         -- the insets' edges, from the canvas's

-- The kind of place a mount comes from: the filter's sources.
local function SourceOf(mount)
    if mount.class then return "class" end
    if mount.vendor then return "vendor" end
    if mount.quest then return "quest" end
    return "drop"
end

-- ---------------------------------------------------------------------
-- CollectionsMountButton: retail's Mount button. Using an item is a protected
-- action, so the gold button only looks the part: a secure button with no art
-- of its own uses the item (or casts the class's spell). That one is not in
-- the window's tree — a protected frame there would make showing and hiding
-- the window protected in combat — but a root frame, brought in on the gold
-- button's place on the screen while the cursor is on it, and put away as
-- the cursor leaves: off the button it is not there to take a click meant
-- for whatever lies over the window. It is bound, placed, shown and hidden
-- out of combat only, and put away as a fight starts: nothing mounts in
-- combat. Getting off is not protected: while the mount on show is being
-- ridden the gold button does that itself, in combat too.
--
--   :SetReady(mount)    a click mounts it. Out of combat only
--   :SetRiding()        a click gets off
--   :SetOff(reason)     nothing to click; `reason` goes in the tooltip
--   :Disarm()           put the secure button away
-- ---------------------------------------------------------------------
class "CollectionsMountButton" : extends "ButtonGold" {
    __init = function(self, parent)
        ButtonGold.__init(self, parent, nil, MOUNT)
        self:SetSize(140, 22)
        self._riding  = false
        self._reason  = nil
        self._ready   = false         -- a click would mount
        self._secure  = nil           -- made when first needed
        self._bound   = nil           -- the mount it is set to
        self._hovered = false         -- the cursor is on this button or on the secure one

        self.OnClick = function()
            if self._riding then Dismount() end
        end
        self:SetTooltip("ANCHOR_RIGHT", function(tip)
            tip:AddLine(self._riding and BINDING_NAME_DISMOUNT or MOUNT, 1, 1, 1, false, 13)
            if self._reason then tip:AddLine(self._reason, 1, 0.125, 0.125, true) end
        end)

        -- The secure button coming in under the cursor takes it from this
        -- one, and gives it back when it goes: neither is the cursor leaving.
        local enter, leave = self:GetScript("OnEnter"), self:GetScript("OnLeave")
        self:SetScript("OnEnter", function()
            enter()
            self._hovered = true
            self:_Cover()
        end)
        self:SetScript("OnLeave", function()
            leave()
            self._hovered = false
            if self._secure and not self._secure:IsMouseOver() then self:Disarm() end
        end)
    end;

    SetReady = function(self, mount)
        self._riding, self._reason = false, nil
        self:SetText(MOUNT)
        self:SetEnabled(true)

        if not self._secure then self:_BuildSecure() end
        if self._bound ~= mount then
            self._bound = mount
            if mount.item then
                self._secure:SetAttribute("type", "item")
                self._secure:SetAttribute("item", "item:" .. mount.item)
            else
                self._secure:SetAttribute("type", "spell")
                self._secure:SetAttribute("spell", mount.spell)
            end
        end
        self._ready = true
        if self._hovered then self:_Cover() end
    end;

    SetRiding = function(self)
        self._riding, self._reason, self._ready = true, nil, false
        self:SetText(BINDING_NAME_DISMOUNT)
        self:SetEnabled(true)
        self:Disarm()
    end;

    SetOff = function(self, reason)
        self._riding, self._reason, self._ready = false, reason, false
        self:SetText(MOUNT)
        self:SetEnabled(false)
        self:Disarm()
    end;

    -- In combat it is hidden already, so this never touches it then.
    Disarm = function(self)
        if self._secure and self._secure:IsShown() then self._secure:Hide() end
    end;

    _BuildSecure = function(self)
        local secure = SecureActionButton(nil, "MUI_CollectionsMountSecure")
        secure:SetFrameStrata("HIGH")
        secure:Hide()
        -- It has no art: this button shows its hover and its press.
        for _, script in ipairs({ "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp" }) do
            secure:SetScript(script, function() self:GetScript(script)() end)
        end
        secure:SetScript("PostClick", function() PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK) end)
        self._secure = secure
    end;

    -- Bring the secure button in under the cursor, on this one's place on
    -- the screen.
    _Cover = function(self)
        local secure = self._secure
        if not self._ready or secure:IsShown() or InCombatLockdown() then return end
        secure:SetScale(self:GetEffectiveScale() / MUI_Root:GetEffectiveScale())
        secure:SetSize(self:GetWidth(), self:GetHeight())
        secure:ClearAllPoints()
        secure:AlignParentBottomLeft(self:GetBottom(), self:GetLeft())
        secure:Show()
    end;
}

-- ---------------------------------------------------------------------
-- CollectionsMounts
-- ---------------------------------------------------------------------
class "CollectionsMounts" : extends "Frame" {
    __init = function(self, canvas)
        Frame.__init(self, "Frame", canvas)
        self:FillParent()
        local _, classFile = UnitClass("player")
        self._playerClass   = classFile
        self._playerFaction = UnitFactionGroup("player")
        self._query    = ""
        self._filters  = { collected = true, uncollected = true, unusable = true,
                           drop = true, quest = true, vendor = true, class = true }
        self._selected = nil
        self._shown    = nil             -- the mount the display is of
        self._buffs    = {}              -- [spell id] = true: the auras on the character
        self._combat   = false           -- between a fight's first event and its last
        self._dirty    = false

        self._left = InnerFrame(self)
        self._left:SetWidth(LEFT_W)
        self._left:AlignParentTopLeft(TOP, 4)
        self._left:AlignParentBottomLeft(BOTTOM, 4)

        self._right = InnerFrame(self)
        self._right:HideBg()
        self._right:FillParentPadding(4 + LEFT_W + GAP, TOP, 6, BOTTOM)

        self._list = CollectionsMountList(self._left, self)
        self._list:AlignParentTopLeft(36, 3)
        self._display = CollectionsMountDisplay(self._right)

        self:_BuildSearch()
        self:_BuildFilter()
        self:_BuildCount()

        self._button = CollectionsMountButton(self)
        self._button:AlignParentBottomLeft(4, 4)

        Log.OnMountsChanged = function()
            if self:IsVisible() then self:Refresh() end
        end

        -- What the character has, can use or rides changed: once a frame at
        -- most, and only while the page shows.
        local function dirty() self._dirty = true end
        for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "SPELLS_CHANGED",
                                 "SKILL_LINES_CHANGED", "PLAYER_LEVEL_UP", "UPDATE_FACTION" }) do
            self:RegisterEventHandler(event, dirty)
        end
        self:RegisterUnitEventHandler("UNIT_AURA", "player", dirty)
        -- A fight's first event comes before the client locks protected
        -- frames: the secure button is put away right in its handler.
        self:RegisterEventHandler("PLAYER_REGEN_DISABLED", function()
            self._combat, self._dirty = true, true
            self._button:Disarm()
            self:_UpdateButton()
        end)
        self:RegisterEventHandler("PLAYER_REGEN_ENABLED", function()
            self._combat, self._dirty = false, true
            self:_UpdateButton()
        end)

        self:SetScript("OnUpdate", function()
            if self._dirty then self:Refresh() end
        end)
        -- Nothing is laid out while hidden: a name's fit is only known on screen.
        self:SetScript("OnShow", function() self:Refresh() end)
        self:SetScript("OnHide", function() self._button:Disarm() end)
    end;

    -- ---- controls ---------------------------------------------------------

    _BuildSearch = function(self)
        self._search = EditBox(self._left, "MUI_CollectionsMountsSearch", "SearchBoxTemplate")
        self._search:SetSize(145, 20)
        self._search:AlignParentTopLeft(9, 15)
        self._search.OnTextChanged = function(_, text)
            local query = strlower(text or "")
            if query == self._query then return end
            self._query = query
            if self:IsVisible() then self:Refresh() end
        end
    end;

    -- Collected or not, the mounts the character may never ride, where a
    -- mount comes from.
    _BuildFilter = function(self)
        local button = DropdownSimple(self._left, "MUI_CollectionsMountsFilter")
        button:SetSize(86, 22)
        button:RightOf(self._search, 5)
        button:SetText(FILTER)

        local menu = DropdownMenu(button, "MUI_CollectionsMountsFilterMenu", button)
        menu:SetMenuWidth(150)
        local function toggle(label, key)
            return { type = "checkbox", label = label, checked = true, OnChanged = function(_, checked)
                self._filters[key] = checked
                self:Refresh()
            end }
        end
        menu:SetItems({
            toggle(COLLECTED, "collected"),
            toggle(NOT_COLLECTED, "uncollected"),
            toggle("Unusable", "unusable"),
            { type = "separator" },
            toggle(BATTLE_PET_SOURCE_1, "drop"),
            toggle(BATTLE_PET_SOURCE_2, "quest"),
            toggle(BATTLE_PET_SOURCE_3, "vendor"),
            toggle(CLASS, "class"),
        })
        button.OnClick = function() menu:Toggle() end
    end;

    -- Retail's MountCount: how many mounts the character has.
    _BuildCount = function(self)
        local box = Frame("Frame", self, nil, "InsetFrameTemplate3")
        box:SetSize(130, 20)
        box:AlignParentTopLeft(35, 70)

        local label = Style:Label(box, 10, 1, 0.82, 0, "ARTWORK")
        label:SetText(TOTAL_MOUNTS)
        label:AlignParentLeft(10)

        self._count = Style:Label(box, 10, 1, 1, 1, "ARTWORK")
        self._count:AlignParentRight(10)
    end;

    -- ---- how the character stands to a mount ------------------------------

    IsForPlayer = function(self, mount)
        return (not mount.faction or mount.faction == self._playerFaction)
           and (not mount.class or mount.class == self._playerClass)
    end;

    _InBags = function(self, mount)
        return (C_Item.GetItemCount(mount.item) or 0) > 0
    end;

    -- Whether the character has the mount, whether it can ride it (a fight
    -- aside), whether it is riding it.
    StateOf = function(self, mount)
        local collected, usable
        if mount.item then
            collected = (C_Item.GetItemCount(mount.item, true) or 0) > 0
            usable = collected and self:_InBags(mount) and C_Item.IsUsableItem(mount.item) or false
        else
            collected = C_SpellBook.IsSpellKnown(mount.spell)
            usable = collected
        end

        local riding = self._buffs[mount.spell] or false
        if mount.auras then
            for _, aura in ipairs(mount.auras) do
                if self._buffs[aura] then riding = true end
            end
        end
        return collected, usable, riding
    end;

    -- The mount being ridden is one of the auras on the character.
    _ReadBuffs = function(self)
        wipe(self._buffs)
        local i = 1
        local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
        while aura do
            self._buffs[aura.spellId] = true
            i = i + 1
            aura = C_UnitAuras.GetBuffDataByIndex("player", i)
        end
    end;

    -- The item out of the bags, or the class's spell. Addon code may not
    -- pick things up in combat.
    PickUp = function(self, mount)
        if InCombatLockdown() then return end
        if mount.item then
            if self:_InBags(mount) then C_Item.PickupItem(mount.item) end
        elseif C_SpellBook.IsSpellKnown(mount.spell) then
            C_Spell.PickupSpell(mount.spell)
        end
    end;

    Link = function(self, mount)
        local link
        if mount.item then
            link = select(2, C_Item.GetItemInfo(mount.item))
        else
            link = C_Spell.GetSpellLink(mount.spell)
        end
        if link then ChatFrameUtil.InsertLink(link) end
    end;

    -- ---- what shows -------------------------------------------------------

    _Passes = function(self, mount, collected)
        local filters = self._filters
        if not (collected and filters.collected or not collected and filters.uncollected) then return false end
        if not filters.unusable and not self:IsForPlayer(mount) then return false end
        if not filters[SourceOf(mount)] then return false end
        if self._query ~= "" and not strfind(strlower(mount.name), self._query, 1, true) then return false end
        return true
    end;

    Refresh = function(self)
        self._dirty = false
        self:_ReadBuffs()

        local starred, held, others = {}, {}, {}
        local owned = 0
        local selected = false
        for _, mount in ipairs(MUI_MountDB:GetMounts()) do
            local collected = self:StateOf(mount)
            if collected then owned = owned + 1 end
            if self:_Passes(mount, collected) then
                local group = Log:IsFavoriteMount(mount.spell) and starred or collected and held or others
                group[#group + 1] = mount
                if mount == self._selected then selected = true end
            end
        end
        -- Starred mounts first, then the ones the character has, each group
        -- by name as the data is.
        for _, group in ipairs({ held, others }) do
            for _, mount in ipairs(group) do
                starred[#starred + 1] = mount
            end
        end
        if not selected then self._selected = starred[1] end

        self._list:SetMounts(starred, self._selected)
        if self._shown ~= self._selected then
            self._shown = self._selected
            self._display:SetMount(self._selected)
            if self._selected then self._list:ScrollTo(self._selected) end
        end
        self._count:SetText(owned)
        self:_UpdateButton()
    end;

    -- What a click on the Mount button would do, and why it would not.
    _UpdateButton = function(self)
        local button, mount = self._button, self._selected
        if not self:IsVisible() then
            button:Disarm()
            return
        end
        if not mount then
            button:SetOff()
            return
        end
        local collected, usable, riding = self:StateOf(mount)
        if riding then
            button:SetRiding()
        elseif not collected then
            button:SetOff(NOT_COLLECTED)
        elseif self._combat or InCombatLockdown() then
            button:SetOff(ERR_NOT_IN_COMBAT)
        elseif not usable then
            button:SetOff(self:_InBags(mount) and ERR_CANT_USE_ITEM or BANK)
        else
            button:SetReady(mount)
        end
    end;

    SelectMount = function(self, mount)
        if mount == self._selected then return end
        self._selected, self._shown = mount, mount
        self._list:Select(mount)
        self._display:SetMount(mount)
        self:_UpdateButton()
    end;

    Reset = function(self)
        self._search:SetText("")
        self._search:ClearFocus()
        self._display:Reset()
    end;
}
