-- MUI_AdventureGuideSearch: the journal's search — retail's SearchBoxTemplate
-- at the window's top right, its preview list (five matches and "Show all"
-- inside a UI-Frame border) and the full results window on the rock
-- background. Dungeons, bosses, their abilities and creatures, and loot are
-- searched by name; three characters start it. The search runs over the
-- journal data, at once.
--
--   AdventureGuideSearch(canvas, window)
--     .box            the edit box (the window places it)
--     :Reset()        empty and closed

local Style = MUI_AdventureGuideStyle

local PREVIEWS      = 5
local PREVIEW_ROW_H = 27
local RESULT_ROW_W, RESULT_ROW_H = 575, 49
local RESULTS_W, RESULTS_H = 600, 400
local RESULTS_VIEW_H = 360          -- between the title bar and the bottom border
local SEARCH_MIN    = 3
local SEARCH_TEXT   = { 0.96875, 0.8984375, 0.578125 }
local SEARCH_DIM    = { 0.66796875, 0.51171875, 0.3359375 }
local QUESTION_MARK = 134400

-- What a result is; they list in this order.
local INSTANCE, BOSS, ABILITY, ADD, ITEM = 1, 2, 3, 4, 5
local KIND_TEXT = {
    ENCOUNTER_JOURNAL_INSTANCE, ENCOUNTER_JOURNAL_ENCOUNTER, ENCOUNTER_JOURNAL_ABILITY,
    ENCOUNTER_JOURNAL_ENCOUNTER_ADD, ENCOUNTER_JOURNAL_ITEM,
}

-- One of retail's UI-Frame border atlases on `parent`, tiling along its run.
local function FramePiece(parent, atlasName, sublevel)
    local t = Texture(parent, nil, "BORDER")
    if sublevel then t:SetDrawLayer("BORDER", sublevel) end
    t:SetBlizzardAtlas(atlasName, true)
    if atlasName:find("^_") then t:SetHorizTile(true) end
    if atlasName:find("^!") then t:SetVertTile(true) end
    return t
end

local function QualityText(name, quality)
    local c = ITEM_QUALITY_COLORS[quality]
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5), name)
end

class "AdventureGuideSearch" : extends "Frame" {
    __init = function(self, canvas, window)
        Frame.__init(self, "Frame", canvas)
        self:SetSize(1, 1)
        self:AlignParentTopLeft()
        self.window = window
        self._canvas = canvas
        self.selected = 1
        self.found = {}

        self.box = EditBox(canvas, "MUI_AdventureGuideSearchBox", "SearchBoxTemplate")
        self.box:SetSize(210, 20)

        self:_BuildPreview()
        self:_BuildResults()

        self.box.OnFocusGained = function()
            self.results:Hide()
            self:_UpdatePreview()
        end
        self.box.OnFocusLost = function()
            -- a click on a preview row takes the focus first; let it land
            C_Timer.After(0.15, function()
                if not self.box:HasFocus() then self.preview:Hide() end
            end)
        end
        self.box.OnTextChanged = function() self:_UpdatePreview() end
        self.box.OnEnterPressed = function() self:_Choose() end
        self.box:SetScript("OnKeyDown", function(_, key)
            if key == "UP" then
                self:_Select(self.selected - 1)
            elseif key == "DOWN" then
                self:_Select(self.selected + 1)
            end
        end)
    end;

    Reset = function(self)
        self.box:SetText("")
        self.box:ClearFocus()
        self.preview:Hide()
        self.results:Hide()
    end;

    -- ---- the index ------------------------------------------------------

    -- Every name the journal has, by kind: { name, lower, instance,
    -- encounter, ... }.
    _Index = function(self)
        if self._index then return self._index end
        local index = { {}, {}, {}, {}, {} }
        local items = {}
        local function add(kind, entry)
            entry.kind = kind
            entry.lower = string.lower(entry.name)
            table.insert(index[kind], entry)
        end
        for _, raids in ipairs({ false, true }) do
            for _, instance in ipairs(MUI_EncounterJournalDB:GetInstances(raids)) do
                add(INSTANCE, { name = instance.name, instance = instance })
                for _, encounter in ipairs(instance.encounters) do
                    add(BOSS, { name = encounter.name, instance = instance, encounter = encounter,
                                display = encounter.creatures[1].display })
                    self:_IndexSections(add, instance, encounter, encounter.sections or {}, {})
                    local loot = encounter.loot or {}
                    for i = 1, #loot, 2 do
                        if not items[loot[i]] then
                            items[loot[i]] = true
                            local name, quality = MUI_EncounterJournalDB:GetItem(loot[i])
                            add(ITEM, { name = name, instance = instance, encounter = encounter,
                                        item = loot[i], quality = quality })
                        end
                    end
                end
            end
        end
        self._index = index
        return index
    end;

    -- `above`: the headers a section sits under, outermost first.
    _IndexSections = function(self, add, instance, encounter, sections, above)
        for _, section in ipairs(sections) do
            local chain = {}
            for i, node in ipairs(above) do chain[i] = node end
            chain[#chain + 1] = section
            add(section.display and ADD or ABILITY, {
                name = section.title, instance = instance, encounter = encounter,
                chain = chain, icon = section.icon, display = section.display,
            })
            if section.sub then
                self:_IndexSections(add, instance, encounter, section.sub, chain)
            end
        end
    end;

    _Search = function(self, text)
        local needle = string.lower(text)
        local found = {}
        for _, entries in ipairs(self:_Index()) do
            for _, entry in ipairs(entries) do
                if string.find(entry.lower, needle, 1, true) then found[#found + 1] = entry end
            end
        end
        return found
    end;

    -- ---- how a result reads ---------------------------------------------

    _SetIcon = function(self, texture, entry)
        texture:SetTexCoord(0, 1, 0, 1)
        if entry.display then
            texture:SetPortraitFromCreatureDisplayID(entry.display)
        elseif entry.kind == INSTANCE then
            texture:SetTexture(Style:InstanceArt("buttons", entry.instance.button))
            texture:SetTexCoord(0.15625, 0.52734375, 0, 0.7421875)
        elseif entry.kind == ITEM then
            texture:SetTexture(C_Item.GetItemIconByID(entry.item))
        else
            texture:SetTexture(entry.icon or QUESTION_MARK)
        end
    end;

    _Name = function(self, entry)
        if entry.kind == ITEM then return QualityText(entry.name, entry.quality) end
        return entry.name
    end;

    _Path = function(self, entry)
        if entry.kind == INSTANCE then return "" end
        if entry.kind == BOSS then return entry.instance.name end
        return entry.instance.name .. " > " .. entry.encounter.name
    end;

    -- ---- building --------------------------------------------------------

    -- The dropdown under the box: the rows that show, wrapped by retail's
    -- UI-Frame border whose bottom corner follows the last of them.
    _BuildPreview = function(self)
        local atlas = MUI_AtlasRegistry.Search
        local pc = Frame("Frame", self._canvas)
        pc:SetSize(210, PREVIEW_ROW_H)
        pc:Below(self.box)
        pc:SetFrameStrata("DIALOG")
        pc:Hide()
        self.preview = pc

        pc.anchor = FramePiece(pc, "UI-Frame-BotCornerLeft")
        pc.anchor:SetDrawLayer("OVERLAY")
        pc.anchor:AlignParentLeft(-7)
        local cornerR = FramePiece(pc, "UI-Frame-BotCornerRight")
        cornerR:SetDrawLayer("OVERLAY")
        cornerR:SetPoint("BOTTOM", pc.anchor, "BOTTOM", 0, 0)
        cornerR:AlignParentRight(-4)
        local bottom = FramePiece(pc, "_UI-Frame-Bot")
        bottom:SetDrawLayer("OVERLAY")
        bottom:SetPoint("BOTTOMLEFT", pc.anchor, "BOTTOMRIGHT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", cornerR, "BOTTOMLEFT", 0, 0)
        local left = FramePiece(pc, "!UI-Frame-LeftTile")
        left:SetDrawLayer("OVERLAY")
        left:AlignParentTop(-1)
        left:SetPoint("BOTTOMLEFT", pc.anchor, "TOPLEFT", 0, 0)
        local right = FramePiece(pc, "!UI-Frame-RightTile")
        right:SetDrawLayer("OVERLAY")
        right:AlignParentTop(-1)
        right:SetPoint("BOTTOMRIGHT", cornerR, "TOPRIGHT", 1, 0)
        local top = FramePiece(pc, "_UI-Frame-Bot")
        top:SetDrawLayer("OVERLAY")
        top:AlignParentTopLeft(-3, -2)
        top:SetPoint("BOTTOMRIGHT", pc, "TOPRIGHT", 2, -3)

        pc.rows = {}
        for i = 1, PREVIEWS do
            local b = Frame("Frame", pc)
            b:SetSize(210, PREVIEW_ROW_H)
            b:EnableMouse(true)
            if i == 1 then b:AlignParentTopLeft() else b:Below(pc.rows[i - 1]) end
            local rowBg = Texture(b, nil, "BACKGROUND")
            rowBg:SetAtlas(atlas, "RowBg", true)
            rowBg:FillParent()
            b.selected = Texture(b, nil, "OVERLAY")
            b.selected:SetDrawLayer("OVERLAY", 3)
            b.selected:SetAtlas(atlas, "Highlight", true)
            b.selected:FillParent()
            b.selected:Hide()
            local iconFrame = Texture(b, nil, "OVERLAY")
            iconFrame:SetDrawLayer("OVERLAY", 2)
            iconFrame:SetAtlas(atlas, "IconFrameLarge", true)
            iconFrame:SetSize(21, 21)
            iconFrame:AlignParentLeft(5, 1)
            b.icon = Texture(b, nil, "OVERLAY")
            b.icon:Fill(iconFrame, 1, 2, 1, 1)
            b.name = Style:Label(b, 10, SEARCH_TEXT[1], SEARCH_TEXT[2], SEARCH_TEXT[3])
            b.name:SetJustifyH("LEFT")
            b.name:SetWordWrap(false)
            b.name:RightOf(b.icon, 5)
            b.name:AlignParentRight(5)
            -- on the press: the release may come after the box lost focus
            b:SetScript("OnMouseDown", function(_, button)
                if button == "LeftButton" and b.entry then self:_Pick(b.entry) end
            end)
            pc.rows[i] = b
        end

        local all = Frame("Frame", pc)
        all:SetSize(210, 24)
        all:EnableMouse(true)
        all:Below(pc.rows[PREVIEWS])
        local allBg = Texture(all, nil, "BACKGROUND")
        allBg:SetAtlas(atlas, "RowBg", true)
        allBg:FillParent()
        all.selected = Texture(all, nil, "OVERLAY")
        all.selected:SetDrawLayer("OVERLAY", 2)
        all.selected:SetAtlas(atlas, "Highlight", true)
        all.selected:FillParent()
        all.selected:Hide()
        all.text = Style:Label(all, 12, 1, 0.82, 0)
        all.text:CenterInParent()
        all:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" then self:_ShowAll() end
        end)
        pc.showAll = all
    end;

    -- The full results window: the rock background in retail's UI-Frame
    -- border, a title bar, the close button, the scrolling rows.
    _BuildResults = function(self)
        local res = Frame("Frame", self._canvas)
        res:SetSize(RESULTS_W, RESULTS_H)
        res:AlignParentBottom(7)
        res:SetFrameStrata("DIALOG")
        res:EnableMouse(true)
        res:Hide()
        self.results = res

        local rock = Texture(res, nil, "BACKGROUND")
        rock:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
        rock:SetHorizTile(true)
        rock:SetVertTile(true)
        rock:SetVertexColor(0.9, 0.8, 0.7)
        rock:AlignParentTopLeft()
        rock:AlignParentBottomRight(8, 0)

        local tl = FramePiece(res, "UI-Frame-TopCornerLeft")
        tl:AlignParentTopLeft(-4, -7)
        local tr = FramePiece(res, "UI-Frame-TopCornerRightSimple")
        tr:AlignParentTopRight(-4, -4)
        local topBorder = FramePiece(res, "_UI-Frame-Top")
        topBorder:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
        topBorder:SetPoint("TOPRIGHT", tr, "TOPLEFT", 0, 0)
        local bl = FramePiece(res, "UI-Frame-BotCornerLeft")
        bl:AlignParentBottomLeft(4, -7)
        local br = FramePiece(res, "UI-Frame-BotCornerRight")
        br:AlignParentBottomRight(4, -4)
        local bottomBorder = FramePiece(res, "_UI-Frame-Bot")
        bottomBorder:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, 0)
        bottomBorder:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
        local leftBorder = FramePiece(res, "!UI-Frame-LeftTile")
        leftBorder:SetPoint("BOTTOMLEFT", bl, "TOPLEFT", 0, 0)
        leftBorder:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
        local rightBorder = FramePiece(res, "!UI-Frame-RightTile")
        rightBorder:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
        rightBorder:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 1, 0)
        local streaks = FramePiece(res, "_UI-Frame-TopTileStreaks", -1)
        streaks:AlignParentTopLeft()
        streaks:AlignParentTopRight()
        -- the second top row is the title bar's lower edge
        local tl2 = FramePiece(res, "UI-Frame-TopCornerLeft", 1)
        tl2:AlignParentTopLeft(20, -7)
        local tr2 = FramePiece(res, "UI-Frame-TopCornerRightSimple", 1)
        tr2:AlignParentTopRight(20, -4)
        local topBorder2 = FramePiece(res, "_UI-Frame-Top", 1)
        topBorder2:SetPoint("TOPLEFT", tl2, "TOPRIGHT", 0, 0)
        topBorder2:SetPoint("TOPRIGHT", tr2, "TOPLEFT", 0, 0)

        res.title = Style:Label(res, 12, 1, 0.82, 0, "BORDER")
        res.title:AlignParentTop(7)
        res.title:AlignParentLeft(60)
        res.title:AlignParentRight(60)
        res.close = CloseButton(res)
        res.close:ClearAllPoints()
        res.close:SetPoint("TOPRIGHT", tr, "TOPRIGHT", 1, -4)

        -- Only the rows in view exist: a short query can match hundreds.
        res.scroll = AdventureGuideScroll(res, RESULT_ROW_W, RESULTS_VIEW_H, RESULT_ROW_H)
        res.scroll:AlignParentBottomLeft(12, 1)
        res.scroll:PlaceBar(8, 5, 5)
        res.scroll.OnScroll = function() self:_ShowResults() end
        res.rows = {}
        for i = 1, math.ceil(RESULTS_VIEW_H / RESULT_ROW_H) + 1 do
            res.rows[i] = self:_ResultRow(res.scroll.content)
        end
    end;

    -- A result (EncounterSearchLGTemplate): the icon on its frame, the name,
    -- where it is found, what it is.
    _ResultRow = function(self, parent)
        local atlas = MUI_AtlasRegistry.Search
        local b = Frame("Frame", parent)
        b:SetSize(RESULT_ROW_W, RESULT_ROW_H)
        b:EnableMouse(true)
        b:Hide()
        local bg = Texture(b, nil, "BACKGROUND")
        if bg:SetBlizzardAtlas("_SearchBarLg") then bg:SetHorizTile(true) end
        bg:FillParent()
        local hl = Texture(b, nil, "HIGHLIGHT")
        hl:SetAtlas(atlas, "HighlightLarge", true)
        hl:FillParent()
        local iconFrame = Texture(b, nil, "OVERLAY")
        iconFrame:SetDrawLayer("OVERLAY", 2)
        iconFrame:SetAtlas(atlas, "IconFrameLarge")
        iconFrame:AlignParentLeft(10)
        b.icon = Texture(b, nil, "OVERLAY")
        b.icon:Fill(iconFrame, 1, 2, 1, 1)
        b.name = Style:Label(b, 16, SEARCH_TEXT[1], SEARCH_TEXT[2], SEARCH_TEXT[3])
        b.name:SetJustifyH("LEFT")
        b.name:SetWordWrap(false)
        b.name:SetSize(400, 12)
        b.name:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 10, 0)
        b.path = Style:Label(b, 12, SEARCH_DIM[1], SEARCH_DIM[2], SEARCH_DIM[3])
        b.path:SetJustifyH("LEFT")
        b.path:SetWordWrap(false)
        b.path:SetWidth(400)
        b.path:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -7)
        b.kind = Style:Label(b, 12, SEARCH_DIM[1], SEARCH_DIM[2], SEARCH_DIM[3])
        b.kind:SetJustifyH("RIGHT")
        b.kind:SetWidth(140)
        b.kind:AlignParentRight(14)
        b:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and b.entry and b:IsMouseOver() then
                PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
                self:_Pick(b.entry)
            end
        end)
        return b
    end;

    -- ---- the preview -----------------------------------------------------

    _UpdatePreview = function(self)
        local pc = self.preview
        local text = self.box:GetText() or ""
        if not self.box:HasFocus() or #text < SEARCH_MIN then
            pc:Hide()
            return
        end
        self.found = self:_Search(text)
        local n = #self.found
        if n == 0 then
            pc:Hide()
            return
        end
        local last
        for i = 1, PREVIEWS do
            local row, entry = pc.rows[i], self.found[i]
            if entry then
                row.entry = entry
                row.name:SetText(self:_Name(entry))
                self:_SetIcon(row.icon, entry)
                row:Show()
                last = row
            else
                row.entry = nil
                row:Hide()
            end
        end
        if n > PREVIEWS then
            pc.showAll.text:SetText(string.format(ENCOUNTER_JOURNAL_SHOW_SEARCH_RESULTS, n))
            pc.showAll:Show()
            last = pc.showAll
        else
            pc.showAll:Hide()
        end
        -- the border's bottom corner rides 5 under the last entry
        pc.anchor:ClearAllPoints()
        pc.anchor:AlignParentLeft(-7)
        pc.anchor:SetPoint("BOTTOM", last, "BOTTOM", 0, -5)
        self:_Select(1)
        pc:Show()
    end;

    -- Highlight entry `idx` (the rows, then Show all), wrapping around.
    _Select = function(self, idx)
        local pc = self.preview
        local shown = 0
        for i = 1, PREVIEWS do
            pc.rows[i].selected:Hide()
            if pc.rows[i]:IsShown() then shown = shown + 1 end
        end
        pc.showAll.selected:Hide()
        local count = shown + (pc.showAll:IsShown() and 1 or 0)
        if count == 0 then
            self.selected = 1
            return
        end
        self.selected = (idx - 1) % count + 1
        if self.selected > shown then
            pc.showAll.selected:Show()
        else
            pc.rows[self.selected].selected:Show()
        end
    end;

    -- Enter: the highlighted entry.
    _Choose = function(self)
        local pc = self.preview
        if not pc:IsShown() then return end
        local shown = 0
        for i = 1, PREVIEWS do
            if pc.rows[i]:IsShown() then shown = shown + 1 end
        end
        if self.selected > shown then
            self:_ShowAll()
        elseif pc.rows[self.selected].entry then
            self:_Pick(pc.rows[self.selected].entry)
        end
    end;

    -- ---- the results -----------------------------------------------------

    _ShowAll = function(self)
        local res = self.results
        self.preview:Hide()
        self.box:ClearFocus()
        res.title:SetText(string.format(ENCOUNTER_JOURNAL_SEARCH_RESULTS, self.box:GetText() or "", #self.found))
        res:Show()
        res.scroll:SetContentHeight(#self.found * RESULT_ROW_H)
        res.scroll:ScrollTo(0)
        self:_ShowResults()
    end;

    _ShowResults = function(self)
        local res = self.results
        local first = math.floor(res.scroll:GetScroll() / RESULT_ROW_H)
        for i, row in ipairs(res.rows) do
            local entry = self.found[first + i]
            row.entry = entry
            if entry then
                row.name:SetText(self:_Name(entry))
                row.path:SetText(self:_Path(entry))
                row.kind:SetText(KIND_TEXT[entry.kind])
                self:_SetIcon(row.icon, entry)
                row:ClearAllPoints()
                row:AlignParentTopLeft((first + i - 1) * RESULT_ROW_H, 0)
            end
            row:SetVisible(entry ~= nil)
        end
    end;

    -- Open the journal on a result.
    _Pick = function(self, entry)
        self.preview:Hide()
        self.results:Hide()
        self.box:ClearFocus()
        local window = self.window
        if entry.kind == INSTANCE then
            window:ShowInstance(entry.instance)
        elseif entry.kind == ADD then
            window:ShowEncounter(entry.instance, entry.encounter, entry.display)
        else
            window:ShowEncounter(entry.instance, entry.encounter)
            if entry.kind == ABILITY then
                window.page:ShowSection(entry.chain)
            elseif entry.kind == ITEM then
                window.page:ShowLoot()
            end
        end
    end;
}
