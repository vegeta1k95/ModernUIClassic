-- Recipe list pane (left side of the overlay).
--
-- Owns: search box + filter button + filter dropdown menu, the scroll
-- frame and its content child, the row pool, and all the list-building
-- logic (native walk → entries → painted rows). External state pulled
-- in via SetContext per refresh: { adapter, profKey, unlearnedSpellID }.
--
-- Row clicks are interpreted in-place: learned → adapter:SetSelection
-- (which triggers the SetSelection hook on the overlay), unlearned →
-- OnUnlearnedSelected(spellID), header → toggle local collapse + redraw.

local TEX = MUI.TEX_SKIN .. "professions\\tradeskill\\"

local ROW_HEIGHT  = RecipeListRow.ROW_HEIGHT
local CAT_HEIGHT  = RecipeListRow.CAT_HEIGHT
local DIV_HEIGHT  = RecipeListRow.DIV_HEIGHT
local ROW_GAP     = RecipeListRow.ROW_GAP
local CAT_GAP     = RecipeListRow.CAT_GAP
local DIV_GAP     = RecipeListRow.DIV_GAP
local DIV_TOP_PAD = RecipeListRow.DIV_TOP_PAD

class "ProfessionsRecipeList" : extends "Frame" {

    __init = function(self, parent)
        Frame.__init(self, "Frame", parent)

        self._listFrame = InnerFrame(parent)
        self._listFrame:HideBg()
        self._listFrame:AlignParentTopLeft(70.5, 9)
        self._listFrame:AlignParentBottom(5)
        self._listFrame:SetWidth(273.5)
        self._listFrame:SetScale(0.9)

        self._textEmpty = FontString(self._listFrame)
        self._textEmpty:AlignParentTop(60)
        self._textEmpty:FillWidth(50)
        self._textEmpty:SetTextColor(1, 0.82, 0, 1)
        self._textEmpty:SetText("No results mathcing current filters were found")
        self._textEmpty:Hide()

        local bg = Texture(parent, nil, "BACKGROUND")
        bg:SetTextureRegion(TEX .. "tradeskill", 2048, 1024, 0, 78, 270, 574)
        bg:SetDrawLayer("BACKGROUND", 1)
        bg:Fill(self._listFrame)

        self._searchBox = SearchBox(self._listFrame, nil)
        self._searchBox:AlignParentTopLeft(8, 8)
        self._searchBox:SetSize(152, 20)

        local TEX_BTN = MUI.TEX_BASE .. "dropdown"

        self._btnFilter = Button(self._listFrame, nil, "Filter")
        self._btnFilter:SetNormalTexture(TEX_BTN):SetTextureRegion(TEX_BTN, 512, 512, 0, 185, 196, 48)
        self._btnFilter:SetPushedTexture(TEX_BTN):SetTextureRegion(TEX_BTN, 512, 512, 0, 185, 196, 48)
        self._btnFilter:SetHighlightTexture(TEX_BTN):SetTextureRegion(TEX_BTN, 512, 512, 0, 185, 196, 48)
        self._btnFilter:RightOf(self._searchBox, -2)
        self._btnFilter:AlignParentRight(3)
        self._btnFilter:SetHeight(24)
        self._btnFilter.label:SetTextColor(1, 0.82, 0, 1)

        -- Filter state. _filterSkillLevelup hides recipes whose difficulty
        -- can't grant a skill point (trivial / difficult / nil).
        -- _filterCraftable hides recipes the player doesn't currently have
        -- all reagents for (numAvailable == 0). Both NON-persistent — reset
        -- to false on each reload by design. _searchQuery is the lowercased
        -- search string (empty = no text filter).
        self._filterSkillLevelup = false
        self._filterCraftable    = false
        self._searchQuery        = ""

        self._collapsedCats = {}

        self._filterMenu = DropdownMenu(self._listFrame, nil, self._btnFilter)
        self._filterMenu:SetAnchor(function(popup, anchor)
            popup:Below(anchor, -7.5)
            popup:AlignLeft(anchor, -4)
        end)
        self._filterMenu:SetMenuWidth(200)
        self._filterMenu:Close()
        self._filterMenu:RegisterEventHandler("ADDON_LOADED", function ()
            self._filterMenu:SetItems({
                {
                    type    = "checkbox",
                    label   = "Show learned",
                    checked = MUI_DB.settings.professions.showLearned,
                    OnChanged = function(_, checked)
                        MUI_DB.settings.professions.showLearned = checked
                        self:Refresh()
                    end,
                },
                {
                    type    = "checkbox",
                    label   = "Show unlearned",
                    checked = MUI_DB.settings.professions.showUnlearned,
                    OnChanged = function(_, checked)
                        MUI_DB.settings.professions.showUnlearned = checked
                        self:Refresh()
                    end,
                },
                {
                    type    = "checkbox",
                    label   = "Skill levelup",
                    checked = false,
                    OnChanged = function(_, checked)
                        self._filterSkillLevelup = checked
                        self:Refresh()
                    end,
                },
                {
                    type    = "checkbox",
                    label   = "Have reagents",
                    checked = false,
                    OnChanged = function(_, checked)
                        self._filterCraftable = checked
                        self:Refresh()
                    end,
                },
            })
        end)

        self._btnFilter.OnClick = function()
            if self._filterMenu.popup:IsShown() then
                self._filterMenu:Close()
            else
                self._filterMenu:Open()
            end
        end

        -- Chain into SearchBox's OnTextChanged (it already runs the
        -- clear-button update inside __init); preserve that and add our
        -- own filter trigger.
        local prevOnTextChanged = self._searchBox.OnTextChanged
        self._searchBox.OnTextChanged = function(box, text)
            if prevOnTextChanged then prevOnTextChanged(box, text) end
            self._searchQuery = (text or ""):lower()
            self:Refresh()
        end

        self._listScroll = MinimalScrollBar(self._listFrame, 8, 8)
        self._listScroll:AlignParentBottomRight(5, 12)
        self._listScroll:Below(self._btnFilter, 4)
        self._listScroll:SetScrollSpeed(20)
        self._listScroll:SetValue(0)
        self._listScroll:SetMinMax(0, 0)
        self._listScroll.OnScroll = function(_, v)
            self._listScrollFrame:SetVerticalScroll(v)
        end

        self._listScrollFrame = ScrollFrame(self._listFrame)
        self._listScrollFrame:Below(self._searchBox, 6)
        self._listScrollFrame:SetPoint("TOPRIGHT",  self._listScroll, "TOPLEFT",  -5, 0)
        self._listScrollFrame:SetPoint("BOTTOMLEFT",  self._listFrame, "BOTTOMLEFT",  8 , 6)
        self._listScrollFrame:AlignParentBottom(8)
        self._listScrollFrame:EnableMouseWheel(true)

        -- Scroll child holds every row stacked top-to-bottom. Its height
        -- is recomputed in _PaintRecipeRows from the sum of row heights.
        self._listContent = Frame("Frame", self._listScrollFrame)
        self._listContent:SetSize(1, 1)

        self._listScrollFrame:SetScrollChild(self._listContent)
        self._listScrollFrame:SetScript("OnMouseWheel", function(_, delta)
            local v = self._listScroll:GetValue()
            self._listScroll:SetValue(delta > 0 and (v - 30) or (v + 30))
        end)

        self._listRowPool = {}
    end;

    -- Expose the InnerFrame so the singleton can anchor its recipe pane
    -- against it (BOTTOMLEFT/TOPRIGHT, etc.).
    GetListFrame = function(self) return self._listFrame end;

    -- Per-refresh context — set by the singleton before Refresh runs so
    -- the list knows which adapter to walk and which unlearned spell (if
    -- any) is currently being previewed.
    SetContext = function(self, adapter, profKey, unlearnedSpellID)
        self.adapter            = adapter
        self._activeProfKey     = profKey
        self._unlearnedSpellID  = unlearnedSpellID
    end;

    ResetScroll = function(self)
        if self._listScroll then self._listScroll:SetValue(0) end
        if self._listScrollFrame then self._listScrollFrame:SetVerticalScroll(0) end
    end;

    -- Fresh client-side collapse state. Called on every native switch.
    ResetCollapsed = function(self) self._collapsedCats = {} end;

    Refresh = function(self)
        if not self._listRowPool then return end
        self._listEntries = self:_GetRecipeEntries()
        self:_PaintRecipeRows()
    end;

    _AcquireRow = function(self, idx)
        local row = self._listRowPool[idx]
        if not row then
            row = RecipeListRow(self._listContent)
            self._listRowPool[idx] = row
        end
        return row
    end;

    -- Snapshot the currently-active native into a flat array of entries.
    -- We never call Expand/CollapseTradeSkillSubClass — those trigger
    -- Blizzard's own click sound on top of ours (DFUI works around this
    -- the same way, see ProfessionFrame.mixin.lua:2596-2600). Instead we
    -- keep Blizzard's state all-expanded (forced at _OnShow) and track
    -- collapse client-side via self._collapsedCats[headerName].
    --
    -- Applies the filter dropdown ("Skill levelup": only easy/medium/optimal)
    -- and the search query (case-insensitive substring on the recipe name).
    -- Headers with zero recipes passing the filter are skipped entirely so
    -- the UI never shows empty categories.
    _GetRecipeEntries = function(self)
        local collapsed  = self._collapsedCats or {}
        local levelup    = self._filterSkillLevelup
        local craftable  = self._filterCraftable
        local query      = self._searchQuery or ""
        local filtering  = levelup or craftable or query ~= ""

        local function passes(skillType, name, available)
            if levelup and not (skillType == "easy"
                             or skillType == "medium"
                             or skillType == "optimal") then return false end
            if craftable and (not available or available <= 0) then return false end
            if query ~= "" and not (name and string.find(name:lower(), query, 1, true)) then
                return false
            end
            return true
        end

        local list = {}
        local currentHeader = nil
        local recipesUnderCurrent = {}

        local function flush()
            if currentHeader then
                local hasContent = #recipesUnderCurrent > 0
                local emitHeader = hasContent or not filtering
                if emitHeader then
                    table.insert(list, currentHeader)
                    if currentHeader.isExpanded then
                        for _, r in ipairs(recipesUnderCurrent) do
                            table.insert(list, r)
                        end
                    end
                end
            else
                for _, r in ipairs(recipesUnderCurrent) do
                    table.insert(list, r)
                end
            end
            currentHeader = nil
            recipesUnderCurrent = {}
        end

        local function startHeader(i, name, skillType)
            flush()
            currentHeader = {
                index      = i,
                isHeader   = true,
                isExpanded = not (collapsed[name] == true),
                name       = name,
                skillType  = skillType,
            }
            recipesUnderCurrent = {}
        end

        local recipeMeta = MUI_RecipeDB
                       and self._activeProfKey
                       and MUI_RecipeDB:Get(self._activeProfKey)
        local useCategories = false
        if recipeMeta then
            for _, info in pairs(recipeMeta) do
                if info.category then useCategories = true; break end
            end
        end

        if useCategories then
            local bucketed = MUI_DB.settings.professions.showLearned
                          and self:_BucketByCategory(recipeMeta, passes, collapsed)
                          or  {}
            self:_AppendUnlearnedEntries(bucketed, recipeMeta, collapsed)
            return bucketed
        end

        if MUI_DB.settings.professions.showLearned and self.adapter then
            local adapter   = self.adapter
            local activeIdx = adapter:GetSelectionIndex()
            for i = 1, adapter:GetNumRecipes() do
                local name, skillType, available, _, _, numSkillUps = adapter:GetRecipeInfo(i)
                if skillType == "header" then
                    startHeader(i, name, skillType)
                elseif passes(skillType, name, available) then
                    table.insert(recipesUnderCurrent, {
                        index     = i,
                        isHeader  = false,
                        name      = name,
                        skillType = skillType,
                        available = available,
                        skillUps  = numSkillUps,
                        selected  = (i == activeIdx) and not self._unlearnedSpellID,
                    })
                end
            end
            flush()
        end
        self:_AppendUnlearnedEntries(list, recipeMeta, collapsed)
        return list
    end;

    _AppendUnlearnedEntries = function(self, list, recipeMeta, collapsed)
        if not recipeMeta then return end
        if not MUI_DB.settings.professions.showUnlearned then return end
        if self._filterCraftable then return end

        local adapter = self.adapter
        local learned = {}
        if adapter then
            for i = 1, adapter:GetNumRecipes() do
                local name, skillType = adapter:GetRecipeInfo(i)
                if skillType ~= "header" and name then learned[name] = true end
            end
        end

        local rank = 0
        if adapter then
            local _, r = adapter:GetLine()
            rank = r or 0
        end

        local query   = self._searchQuery or ""
        local levelup = self._filterSkillLevelup

        local unlearned = {}
        for spellID, entry in pairs(recipeMeta) do
            if entry.reagents and entry.skillrange then
                local name = GetSpellInfo(spellID)
                if name and not learned[name] then
                    local sr = entry.skillrange
                    local skillType = "trivial"

                    if     rank < sr[1] then skillType = "optimal"
                    elseif rank < sr[2] then skillType = "optimal"
                    elseif rank < sr[3] then skillType = "medium"
                    elseif rank < sr[4] then skillType = "easy"
                    else                     skillType = "trivial" end

                    local nameOk = query == ""
                                or string.find(name:lower(), query, 1, true) ~= nil
                    local levelOk = not levelup
                                 or skillType == "easy"
                                 or skillType == "medium"
                                 or skillType == "optimal"

                    if nameOk and levelOk then
                        unlearned[#unlearned + 1] = {
                            index       = -1,
                            isHeader    = false,
                            isUnlearned = true,
                            spellID     = spellID,
                            name        = name,
                            skillType   = skillType,
                            dimmed      = true,
                            selected    = (self._unlearnedSpellID == spellID),
                            skillrange  = entry.skillrange,
                            category    = entry.category,
                        }
                    end
                end
            end
        end
        if #unlearned == 0 then return end

        local useCategories = false
        for _, info in pairs(recipeMeta) do
            if info.category then useCategories = true; break end
        end

        table.insert(list, { isDivider = true, name = "Unlearned", index = -1 })

        if useCategories then
            local buckets = {}
            for _, e in ipairs(unlearned) do
                local cat = e.category or "Other"
                buckets[cat] = buckets[cat] or {}
                table.insert(buckets[cat], e)
            end
            for _, recipes in pairs(buckets) do
                table.sort(recipes, function(a, b)
                    return (a.skillrange[1] or 0) > (b.skillrange[1] or 0)
                end)
            end
            local cats = {}
            for cat in pairs(buckets) do cats[#cats + 1] = cat end
            table.sort(cats)
            for _, cat in ipairs(cats) do
                local collapseKey = "unlearned:" .. cat
                local isCollapsed = collapsed[collapseKey] == true
                table.insert(list, {
                    index       = -1,
                    isHeader    = true,
                    isExpanded  = not isCollapsed,
                    name        = cat,
                    skillType   = "header",
                    collapseKey = collapseKey,
                })
                if not isCollapsed then
                    for _, e in ipairs(buckets[cat]) do
                        table.insert(list, e)
                    end
                end
            end
        else
            table.sort(unlearned, function(a, b)
                return (a.skillrange[1] or 0) > (b.skillrange[1] or 0)
            end)
            for _, e in ipairs(unlearned) do table.insert(list, e) end
        end
    end;

    _BucketByCategory = function(self, recipeMeta, passes, collapsed)
        if not self._recipeNameToCategory then self._recipeNameToCategory = {} end
        local cache = self._recipeNameToCategory[self._activeProfKey]
        if not cache then
            cache = {}
            for spellID, info in pairs(recipeMeta) do
                local n = GetSpellInfo(spellID)
                if n then cache[n] = info.category end
            end
            self._recipeNameToCategory[self._activeProfKey] = cache
        end

        local buckets   = {}
        local adapter   = self.adapter
        if adapter then
            local activeIdx = adapter:GetSelectionIndex()
            for i = 1, adapter:GetNumRecipes() do
                local name, skillType, available, _, _, numSkillUps = adapter:GetRecipeInfo(i)
                if skillType ~= "header" and passes(skillType, name, available) then
                    local cat = cache[name] or "Other"
                    buckets[cat] = buckets[cat] or {}
                    table.insert(buckets[cat], {
                        index     = i,
                        isHeader  = false,
                        name      = name,
                        skillType = skillType,
                        available = available,
                        skillUps  = numSkillUps,
                        selected  = (i == activeIdx) and not self._unlearnedSpellID,
                    })
                end
            end
        end

        local out = {}
        local function emitCategory(cat, recipes)
            local isCollapsed = collapsed[cat] == true
            table.insert(out, {
                isHeader   = true,
                isExpanded = not isCollapsed,
                name       = cat,
                skillType  = "header",
                index      = -1,
            })
            if not isCollapsed then
                for _, r in ipairs(recipes) do table.insert(out, r) end
            end
        end

        local cats = {}
        for cat in pairs(buckets) do cats[#cats + 1] = cat end
        table.sort(cats)
        for _, cat in ipairs(cats) do
            local recipes = buckets[cat]
            if #recipes > 0 then
                emitCategory(cat, recipes)
            end
        end

        return out
    end;

    _PaintRecipeRows = function(self)
        local entries = self._listEntries or {}

        if #entries == 0 then
            self._textEmpty:Show()
            self._listScrollFrame:Hide()
            self._listScroll:Hide()
            return
        else
            self._textEmpty:Hide()
            self._listScrollFrame:Show()
            self._listScroll:Show()
        end

        local contentW = self._listScrollFrame:GetWidth()
        if contentW and contentW > 0 then
            self._listContent:SetWidth(contentW)
        end

        local y = 4
        for i, e in ipairs(entries) do
            if e.isDivider and i > 1 then
                y = y + DIV_TOP_PAD
            end
            local row = self:_AcquireRow(i)
            if e.isDivider then
                row:SetDivider(e.name)
            elseif e.isHeader then
                row:SetData(true, e.isExpanded, e.name)
            else
                row:SetData(false, e.skillType, e.name, e.available, e.skillUps, e.selected, e.dimmed)
            end
            row._entryIndex       = e.index
            row._entryIsHeader    = e.isHeader
            row._entryIsDivider   = e.isDivider
            row._entryIsExpanded  = e.isExpanded
            row._entryIsUnlearned = e.isUnlearned
            row._entrySpellID     = e.spellID
            row._entryName        = e.name
            row._entryCollapseKey = e.collapseKey
            if e.isDivider then
                row.OnClick = nil
            else
                row.OnClick = function() self:_OnRowClick(row) end
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT",  self._listContent, "TOPLEFT",  0, -y)
            row:SetPoint("RIGHT",    self._listContent, "RIGHT",    0,  0)
            row:Show()

            local rowH, rowGap
            if e.isDivider then
                rowH, rowGap = DIV_HEIGHT, DIV_GAP
            elseif e.isHeader then
                rowH, rowGap = CAT_HEIGHT, CAT_GAP
            else
                rowH, rowGap = ROW_HEIGHT, ROW_GAP
            end
            y = y + rowH + rowGap
        end

        for i = #entries + 1, #self._listRowPool do
            self._listRowPool[i]:Hide()
        end

        local contentH = math.max(1, y)
        self._listContent:SetHeight(contentH)
        self._listScrollFrame:UpdateScrollChildRect()

        local viewportH = self._listScrollFrame:GetHeight() or 0
        local maxScroll = math.max(0, contentH - viewportH)
        self._listScroll:SetMinMax(0, maxScroll)
        self._listScroll:SetContentSize(math.max(1, viewportH), contentH)
    end;

    _OnRowClick = function(self, row)
        local idx = row._entryIndex
        if not idx then return end
        if row._entryIsHeader then
            -- DFUI does NOT call Expand/CollapseTradeSkillSubClass here
            -- (mixin:2596-2600 — commented out). Those Blizzard funcs fire
            -- a second click sound on top of ours. We track collapse state
            -- on our side by header name and filter recipes in _GetRecipeEntries.
            local key = row._entryCollapseKey or row._entryName
            if key then
                self._collapsedCats[key] = not self._collapsedCats[key] or nil
                self:Refresh()
            end
        elseif row._entryIsUnlearned then
            -- DB-only recipe (player hasn't learned it). Notify owner so it
            -- can stash the spellID + route the recipe pane through the DB
            -- path instead of touching the native selection.
            self._unlearnedSpellID = row._entrySpellID
            if self.OnUnlearnedSelected then
                self:OnUnlearnedSelected(row._entrySpellID)
            end
            self:Refresh()
        else
            -- Clear any pending unlearned selection so the SetSelection
            -- hook's refresh resumes the native path cleanly.
            self._unlearnedSpellID = nil
            if self.OnLearnedSelected then self:OnLearnedSelected(idx) end
            if self.adapter then self.adapter:SetSelection(idx) end
            self:Refresh()
        end
    end;
}
