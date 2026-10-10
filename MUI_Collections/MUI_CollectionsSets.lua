-- MUI_CollectionsSets: the Collections window's sets page — retail's wardrobe
-- Sets tab over Era's own item sets (MUI_ItemSetDB). The list down the left
-- with the search box and the filter over it, the set on show to its right,
-- the class the list is for and how many of its sets are whole above them.
--
-- Era has no appearances to collect: a set is whole when the character has
-- held every piece of it at some time (MUI_CollectionsLog).
--
--   CollectionsSets(canvas)
--     :Refresh()              list, selection and progress, as things stand
--     :SelectSet(set)
--     :Reset()                the search emptied, the model back as it stood
--     :IsForPlayer(set), :IsForPlayerClass(set), :IsForPlayerFaction(set)
--     :ClassNames(set)        "Warrior, Paladin"; nil for a set every class wears

local Style = MUI_CollectionsStyle
local Log   = MUI_CollectionsLog

local LEFT_W, GAP = 260, 22

-- Era's classes, by class id.
local CLASSES = { 1, 2, 3, 4, 5, 7, 8, 9, 11 }
local EVERY_CLASS = 0
for _, id in ipairs(CLASSES) do
    EVERY_CLASS = EVERY_CLASS + 2 ^ (id - 1)
end

local function ClassBit(classId)
    return 2 ^ (classId - 1)
end

class "CollectionsSets" : extends "Frame" {
    __init = function(self, canvas)
        Frame.__init(self, "Frame", canvas)
        local _, _, classId = UnitClass("player")
        self._playerClass   = classId
        self._playerFaction = UnitFactionGroup("player")
        self._class    = classId         -- the class listed; nil for all of them
        self._query    = ""
        self._filters  = { collected = true, uncollected = true, pve = true, pvp = true }
        self._selected = nil
        self._shown    = nil             -- the set the details are of
        self._classNames = {}

        self._left = InnerFrame(self)
        self._left:SetWidth(LEFT_W)
        self._left:AlignParentTopLeft()
        self._left:AlignParentBottomLeft()

        self._right = InnerFrame(self)
        self._right:HideBg()
        self._right:FillParentPadding(LEFT_W + GAP, 0, 0, 0)
        Style:Backdrop(self._right)

        self._list = CollectionsSetList(self._left, self)
        self._list:AlignParentTopLeft(36, 3)
        self._details = CollectionsSetDetails(self._right)

        self:_BuildSearch()
        self:_BuildFilter()
        self:_BuildClasses()
        self:_BuildProgress()

        Log.OnChanged = function()
            if self:IsVisible() then self:Refresh() end
        end
        -- Nothing is laid out while hidden: a name's fit is only known on screen.
        self:SetScript("OnShow", function() self:Refresh() end)
    end;

    -- ---- controls ---------------------------------------------------------

    _BuildSearch = function(self)
        self._search = EditBox(self._left, "MUI_CollectionsSetsSearch", "SearchBoxTemplate")
        self._search:SetSize(145, 20)
        self._search:AlignParentTopLeft(9, 15)
        self._search.OnTextChanged = function(_, text)
            local query = strlower(text or "")
            if query == self._query then return end
            self._query = query
            if self:IsVisible() then self:Refresh() end
        end
    end;

    -- Collected or not, earned in the world or from other players.
    _BuildFilter = function(self)
        local button = DropdownSimple(self._left, "MUI_CollectionsSetsFilter")
        button:SetSize(86, 22)
        button:RightOf(self._search, 5)
        button:SetText(FILTER)

        local menu = DropdownMenu(button, "MUI_CollectionsSetsFilterMenu", button)
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
            { type = "separator" },
            toggle("PvE", "pve"),
            toggle(PVP, "pvp"),
        })
        button.OnClick = function() menu:Toggle() end
    end;

    -- The class the list is for, over the page's top right corner.
    _BuildClasses = function(self)
        self._classButton = DropdownSimple(self, "MUI_CollectionsSetsClass")
        self._classButton:SetSize(150, 24)
        self._classButton:AlignParentTopRight(-28, 9)

        local menu = DropdownMenu(self._classButton, "MUI_CollectionsSetsClassMenu", self._classButton)
        menu:SetMenuWidth(150 * Style.S)
        local items = { { label = ALL_CLASSES, OnClick = function() self:_SetClass(nil) end } }
        for _, id in ipairs(CLASSES) do
            local info = C_CreatureInfo.GetClassInfo(id)
            local color = MUI.ClassColor(info.classFile)
            local name = string.format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, info.className)
            self._classNames[id] = { plain = info.className, colored = name }
            items[#items + 1] = { label = name, OnClick = function() self:_SetClass(id) end }
        end
        menu:SetItems(items)
        self._classButton.OnClick = function() menu:Toggle() end
        self:_NameClass()
    end;

    -- Retail's CollectionsProgressBarTemplate: how many of the class's sets
    -- are whole.
    _BuildProgress = function(self)
        local bar = StatusBar(self, "MUI_CollectionsSetsProgress")
        bar:SetSize(196, 13)
        bar:AlignParentTopLeft(-21, 249)
        bar:SetBackgroundColor(0, 0, 0, 1)
        bar:SetBarTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
        bar:SetBarColor(0.03125, 0.85, 0)
        self._progress = bar

        local border = Texture(bar, nil, "OVERLAY")
        border:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")
        border:SetSize(205, 29)
        border:AlignParentLeft(-5)

        self._progressText = Style:Label(bar, 10, 1, 1, 1)
        self._progressText:SetDrawLayer("OVERLAY", 1)
        self._progressText:CenterInParent(0, 1)
    end;

    _NameClass = function(self)
        if self._class then
            self._classButton:SetText(self._classNames[self._class].colored)
        else
            self._classButton:SetText(ALL_CLASSES)
        end
    end;

    _SetClass = function(self, classId)
        self._class = classId
        self:_NameClass()
        self:Refresh()
    end;

    -- ---- whose a set is ---------------------------------------------------

    IsForPlayerClass = function(self, set)
        return bit.band(set.classes, ClassBit(self._playerClass)) ~= 0
    end;

    IsForPlayerFaction = function(self, set)
        return not set.faction or set.faction == self._playerFaction
    end;

    IsForPlayer = function(self, set)
        return self:IsForPlayerClass(set) and self:IsForPlayerFaction(set)
    end;

    ClassNames = function(self, set)
        if set.classes == EVERY_CLASS then return nil end
        local names = {}
        for _, id in ipairs(CLASSES) do
            if bit.band(set.classes, ClassBit(id)) ~= 0 then
                names[#names + 1] = self._classNames[id].plain
            end
        end
        return table.concat(names, LIST_DELIMITER)
    end;

    -- ---- what shows -------------------------------------------------------

    _Passes = function(self, set, whole)
        local filters = self._filters
        if not (whole and filters.collected or not whole and filters.uncollected) then return false end
        -- The sets one faction earns are the ones won from other players.
        if not (set.faction and filters.pvp or not set.faction and filters.pve) then return false end
        if self._query ~= "" then
            local name   = strlower(MUI_ItemSetDB:GetName(set))
            local source = strlower(MUI_ItemSetDB:GetSource(set))
            if not strfind(name, self._query, 1, true) and not strfind(source, self._query, 1, true) then
                return false
            end
        end
        return true
    end;

    Refresh = function(self)
        local starred, others = {}, {}
        local whole, all = 0, 0
        local selected = false
        for _, set in ipairs(MUI_ItemSetDB:GetSets()) do
            if not self._class or bit.band(set.classes, ClassBit(self._class)) ~= 0 then
                local held, total = Log:Count(set)
                all = all + 1
                if held == total then whole = whole + 1 end
                if self:_Passes(set, held == total) then
                    local group = Log:IsFavorite(set.id) and starred or others
                    group[#group + 1] = set
                    if set == self._selected then selected = true end
                end
            end
        end
        -- Starred sets first, each group in the data's order.
        for _, set in ipairs(others) do
            starred[#starred + 1] = set
        end
        if not selected then self._selected = starred[1] end

        self._list:SetSets(starred, self._selected)
        if self._shown ~= self._selected then
            self._shown = self._selected
            self._details:SetSet(self._selected)
            if self._selected then self._list:ScrollTo(self._selected) end
        else
            self._details:Refresh()
        end

        self._progress:SetMinMaxValues(0, math.max(all, 1))
        self._progress:SetValue(whole)
        self._progressText:SetText(HEIRLOOMS_PROGRESS_FORMAT:format(whole, all))
    end;

    SelectSet = function(self, set)
        if set == self._selected then return end
        self._selected, self._shown = set, set
        self._list:Select(set)
        self._details:SetSet(set)
    end;

    Reset = function(self)
        self._search:SetText("")
        self._search:ClearFocus()
        self._details:Reset()
    end;
}
