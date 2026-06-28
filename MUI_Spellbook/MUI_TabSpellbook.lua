
local TEX_BG = MUI.TEX_SKIN .. "spellbook\\spellbook-bg"
local TEX    = MUI.TEX_SKIN .. "spellbook\\spellbook-elements"

-- Retail spellbook page-flip arrows (Interface\Buttons\UI-SpellbookIcon-*).
local PREV_UP   = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up"
local PREV_DOWN = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down"
local PREV_DIS  = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled"
local NEXT_UP   = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
local NEXT_DOWN = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down"
local NEXT_DIS  = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled"
local MOUSE_HL  = "Interface\\Buttons\\UI-Common-MouseHilight"

class "SpellsTab" : extends "SecureFrame" {

    _COLS        = 3;
    _ROWS        = 9;
    _ITEM_W      = 209;
    _ITEM_H      = 63;
    _COL_GAP     = 1;
    _LEFT_MARGIN = 0;
    _TOP_MARGIN  = 3;

    __init = function(self, parent, name)
        SecureFrame.__init(self, parent, name)

        self._leftPage = SecureFrame(self)
        self._leftPage:AlignParentLeft(0)
        self._leftPage:AlignParentTop(0)
        self._leftPage:AlignParentBottom(0)
        self._leftPage:SetWidth(644)

        self._rightPage = SecureFrame(self)
        self._rightPage:AlignParentRight(0)
        self._rightPage:AlignParentTop(0)
        self._rightPage:AlignParentBottom(0)
        self._rightPage:SetWidth(656)

        self._spreads     = {}   -- [spread] = { left = container, right = container }
        self._headers     = {}   -- pool of SpellbookSpecHeaders by index (a title can repeat across pages)
        self._activeItems = {}   -- items shown this layout, hidden on next rebuild


        self._pager = SecureFrame(self, nil, "Frame", "SecureHandlerAttributeTemplate")
        self._pager:SetAttribute("_onattributechanged", [[ -- (self, name, value)
            if name == "current" then
                local n = self:GetAttribute("num") or 0
                for i = 1, n do
                    local l = self:GetFrameRef("L" .. i)
                    local r = self:GetFrameRef("R" .. i)
                    if i == value then
                        if l then l:Show() end
                        if r then r:Show() end
                    else
                        if l then l:Hide() end
                        if r then r:Hide() end
                    end
                end
            end
        ]])

        -- Page navigation, retail spellbook style: "Page X / Y  <  >", bottom
        -- right. Next anchors the corner; prev sits left of it; the label left
        -- of prev.
        self._pageText = FontString(self, nil, "OVERLAY")
        self._pageText:SetFont(MUI.FONT, 13, "")
        self._pageText:SetTextColor(0.141, 0.118, 0.078, 1)
        self._pageText:SetJustifyH("RIGHT")

        self._nextBtn = SecureButton(self)
        self._nextBtn:SetSize(29.5, 28.5)
        self._nextBtn:SetNormalTexture(NEXT_UP)
        self._nextBtn:SetPushedTexture(NEXT_DOWN)
        self._nextBtn:SetDisabledTexture(NEXT_DIS)
        self._nextBtn:SetHighlightTexture(MOUSE_HL):SetBlendMode("ADD")
        self._nextBtn:AlignParentBottomRight(-3, 30)
        self._nextBtn:SetFrameRef("pager", self._pager)
        self._nextBtn:SetOnClick([[
            local p = self:GetFrameRef("pager")
            local c = p:GetAttribute("current")
            local n = p:GetAttribute("num")
            if c < n then p:SetAttribute("current", c + 1) end
        ]])

        self._prevBtn = SecureButton(self)
        self._prevBtn:SetSize(29.5, 28.5)
        self._prevBtn:SetNormalTexture(PREV_UP)
        self._prevBtn:SetPushedTexture(PREV_DOWN)
        self._prevBtn:SetDisabledTexture(PREV_DIS)
        self._prevBtn:SetHighlightTexture(MOUSE_HL):SetBlendMode("ADD")
        self._prevBtn:LeftOf(self._nextBtn, 6)
        self._prevBtn:SetFrameRef("pager", self._pager)
        self._prevBtn:SetOnClick([[
            local p = self:GetFrameRef("pager")
            local c = p:GetAttribute("current")
            if c > 1 then p:SetAttribute("current", c - 1) end
        ]])

        self._pageText:LeftOf(self._prevBtn, 6)

        -- Insecure side: keep the label and arrow art in sync with the page.
        -- The secure snippet does the actual paging; SetText / SetNormalTexture
        -- aren't protected, so this hook is combat-safe.
        self._pager:HookScript("OnAttributeChanged", function(_, name, value)
            if name ~= "current" or not value or value < 1 then return end
            local num = self._numSpreads or 1
            self._pageText:SetText("Page " .. value .. " / " .. num)
            --self._prevBtn:SetNormalTexture(value > 1   and PREV_UP or PREV_DIS)
            self._prevBtn:SetEnabled(value > 1)
            --self._nextBtn:SetNormalTexture(value < num and NEXT_UP or NEXT_DIS)
            self._nextBtn:SetEnabled(value < num)
            -- Retail plays IG_ABILITY_PAGE_TURN on an actual page flip (this
            -- hook doesn't fire at the clamped ends); skip the layout's set.
            if not self._suppressPageSound then
                PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
            end
        end)

        -- Mouse wheel over the pages flips spreads. Driven by a secure snippet
        -- (same clamp as the arrows) so it works in combat; the page label /
        -- arrow art / turn sound all follow via the OnAttributeChanged hook.
        self._wheel = SecureFrame(self, nil, "Frame", "SecureHandlerMouseWheelTemplate")
        self._wheel:FillParent()
        self._wheel:EnableMouseWheel(true)
        self._wheel:SetFrameRef("pager", self._pager)
        self._wheel:SetAttribute("_onmousewheel", [[ -- (self, delta)
            local p = self:GetFrameRef("pager")
            local c = p:GetAttribute("current")
            local n = p:GetAttribute("num")
            if delta < 0 then
                if c < n then p:SetAttribute("current", c + 1) end  -- down = next
            else
                if c > 1 then p:SetAttribute("current", c - 1) end  -- up = prev
            end
        ]])

    end;

    -- sections = ordered list of { title = string, groups = { SpellGroup, ... } }.
    -- Lays every group out across as many left/right spreads as needed, then
    -- shows the first spread. Pagination flips spreads by secure show/hide of
    -- the per-spread containers (see _SetupPager), so it works in combat. The
    -- rebuild itself reparents pooled items, so it must run out of combat.
    SetSections = function(self, sections)
        -- Hide whatever the previous layout placed (groups can disappear).
        for _, item in ipairs(self._activeItems) do item:Hide() end
        for _, h in ipairs(self._headers) do h:Hide() end
        wipe(self._activeItems)

        local rowsPerSpread = self._ROWS * 2

        -- 1) Flatten into rows: a header is a full-width row; items pack _COLS
        --    per row; each section starts on a fresh row.
        local rows = {}
        for _, section in ipairs(sections) do
            -- A header must not be a page's last row (its items would spill to
            -- the next side). Pad with an empty row so it starts the next page.
            if (#rows % rowsPerSpread) % self._ROWS == self._ROWS - 1 then
                table.insert(rows, { items = {} })
            end
            table.insert(rows, { header = section.title, spec = section.spec})

            local line = {}
            local function pushLine()
                -- An item row that starts a new SPREAD repeats the section
                -- header at the top of that spread's left page. A left→right
                -- spill within a spread does NOT repeat.
                if #rows % rowsPerSpread == 0 then
                    table.insert(rows, { header = section.title, spec = section.spec })
                end
                table.insert(rows, { items = line })
                line = {}
            end

            for _, group in ipairs(section.groups) do
                table.insert(line, group)
                if #line == self._COLS then pushLine() end
            end
            if #line > 0 then pushLine() end
        end

        -- 2) Place each row at (spread, page, pageRow). 8 rows per page, two
        --    pages (left then right) per spread.
        local maxSpread = 1
        local headerN = 0
        for rowIndex, row in ipairs(rows) do
            local gi       = rowIndex - 1
            local spread   = math.floor(gi / rowsPerSpread) + 1
            local localRow = gi % rowsPerSpread
            local isLeft   = localRow < self._ROWS
            local pageRow  = localRow % self._ROWS
            maxSpread = math.max(maxSpread, spread)

            local container = self:_GetContainer(spread, isLeft)
            local y = self._TOP_MARGIN + pageRow * self._ITEM_H

            if row.header then
                headerN = headerN + 1
                local header = self:_GetHeader(headerN)
                header:SetParent(container)
                header:ClearAllPoints()
                header:AlignParentTopLeft(y, self._LEFT_MARGIN)
                header:AlignParentTopRight(y, self._LEFT_MARGIN)
                header:SetText(row.header)
                if MUI_DB.settings.spellbook.showHeaderIcons and row.spec then
                    header:SetIcon(MUI_SPEC_ICONS[MUI.GetClassID()][row.spec])
                else
                    header:SetIcon(nil)
                end
                header:Show()
            else
                for col, group in ipairs(row.items) do
                    local c    = col - 1
                    local item = MUI_SpellbookItemPool:Acquire(group:GetName(), container)
                    item:ClearAllPoints()
                    item:AlignParentTopLeft(y, 38 + c * (self._ITEM_W + self._COL_GAP))
                    item:SetSpell(group)
                    item:Show()
                    table.insert(self._activeItems, item)
                end
            end
        end

        self:_SetupPager(maxSpread)
    end;

    _GetContainer = function(self, spread, isLeft)
        self._spreads[spread] = self._spreads[spread] or {}
        local key = isLeft and "left" or "right"
        local c = self._spreads[spread][key]
        if not c then
            c = SecureFrame(isLeft and self._leftPage or self._rightPage)
            c:FillParent()
            self._spreads[spread][key] = c
        end
        return c
    end;

    _GetHeader = function(self, n)
        local h = self._headers[n]
        if not h then
            h = SpellbookSpecHeader(self._leftPage)
            self._headers[n] = h
        end
        return h
    end;

    -- Secure visibility controller: only the current spread's two containers
    -- are shown; prev/next bump the "current" attribute, which the restricted
    -- snippet reads to re-toggle. All combat-safe (own SecureHandler frame).
    _SetupPager = function(self, num)
        for s = 1, num do
            local sp = self._spreads[s]
            if sp then
                if sp.left  then self._pager:SetFrameRef("L" .. s, sp.left)  end
                if sp.right then self._pager:SetFrameRef("R" .. s, sp.right) end
            end
        end

        -- Hide any spreads left over from a larger previous layout.
        for s, sp in pairs(self._spreads) do
            if s > num then
                if sp.left  then sp.left:Hide()  end
                if sp.right then sp.right:Hide() end
            end
        end

        self._numSpreads = num   -- read by the OnAttributeChanged label hook
        self._pager:SetAttribute("num", num)
        -- New containers default shown; force a clean re-evaluation to the
        -- first spread (0 hides all, 1 shows spread 1). Suppress the page-turn
        -- sound during this programmatic reset.
        self._suppressPageSound = true
        self._pager:SetAttribute("current", 0)
        self._pager:SetAttribute("current", 1)
        self._suppressPageSound = false

        if num > 1 then
            self._prevBtn:Show(); self._nextBtn:Show(); self._pageText:Show()
        else
            self._prevBtn:Hide(); self._nextBtn:Hide(); self._pageText:Hide()
        end
    end;
}

class "TabSpellbook" : extends "SecureFrame" {

    __init = function(self, parent)
        SecureFrame.__init(self, parent, "MUI_TabSpellbookFrame")
        self:FillParent()

        self:_CreateBackground()
        self:_CreateSettings()
        self:_CreateTabs()
    end;

    _CreateBackground = function(self)

        self._bgHeader = Texture(self, nil, "BACKGROUND")
        self._bgHeader:SetTextureRegion(TEX_BG, 2048, 1024, 0, 0, 1616, 58)
        self._bgHeader:AlignParentTop()
        self._bgHeader:FillWidth()
        self._bgHeader:SetHeight(48)

        local bgLeft = Texture(self, nil, "BACKGROUND")
        bgLeft:SetTextureRegion(TEX_BG, 2048, 1024, 916, 60, 804.9, 807)
        bgLeft:AlignParentLeft(0)
        bgLeft:AlignParentBottom()
        bgLeft:Below(self._bgHeader, -3)
        bgLeft:SetWidth(724)

        local bgRight = Texture(self, nil, "BACKGROUND")
        bgRight:SetTextureRegion(TEX_BG, 2048, 1024, 0, 60, 809, 807)
        bgRight:AlignParentRight()
        bgRight:AlignParentBottom()
        bgRight:Below(self._bgHeader, -3)
        bgRight:RightOf(bgLeft, -0.1)

        local bgBookmark = Texture(self, nil, "ARTWORK")
        bgBookmark:SetTextureRegion(TEX_BG, 2048, 1024, 810, 60, 102, 807)
        bgBookmark:SetWidth(92)
        bgBookmark:Below(self._bgHeader, -3, 8)
        bgBookmark:AlignParentBottom()

    end;

    _CreateTabs = function(self)

        self._tabClass = SpellsTab(self)
        self._tabClass:FillParentPadding(40, 90, 40, 40)

        self._tabGeneral = SpellsTab(self)
        self._tabGeneral:FillParentPadding(40, 90, 40, 40)

        self._tabPet = SpellsTab(self)
        self._tabPet:FillParentPadding(40, 90, 40, 40)

        self._tabs = TabGroup(self, "MUI_SpellBookTabs", TabFrame, "top", -7)
        self._tabs:SetSilent(true)
        self._tabs:SetSize(1, 1)
        self._tabs:AlignParentTop(44)
        self._tabs:AlignParentLeft(60)
        self._tabs.OnTabSelected = function(_, tab)
            PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN, "SFX", false)
        end

        self._classTabBtn   = self._tabs:AddTab("MUI_SpellbookTabBtnClass",   "Class",   self._tabClass,   98, 200, 4)
        self._generalTabBtn = self._tabs:AddTab("MUI_SpellbookTabBtnGeneral", "General", self._tabGeneral, 98, 200, 4)
        self._petTabBtn     = self._tabs:AddTab("MUI_SpellbookTabBtnPet",     "Pet",     self._tabPet,     98, 200, 4)
        self._petTabBtn:Hide()

        -- A rebuild reparents pooled items (SetParent on secure frames),
        -- which is illegal in combat — defer to PLAYER_REGEN_ENABLED. Spread
        -- pagination and Class/General/Pet switches stay combat-safe because
        -- they're pure secure show/hide, never a reparent.
        EventRegistry:RegisterCallback("MUI_SPELLS_UPDATED", function()
            self:_RequestRebuild()
        end, self)

        self:RegisterEventHandler("PLAYER_REGEN_ENABLED", function()
            if self._rebuildPending then
                self._rebuildPending = false
                self:_RebuildAll()
            elseif self._petPending then
                self._petPending = false
                self:_UpdatePetTab()
            end
        end)

        -- Pet spells aren't in MUI_DB, so MUI_SPELLS_UPDATED doesn't cover
        -- them — refresh just the Pet tab on pet/spell changes.
        self:RegisterEventHandler("UNIT_PET", function(_, _, unit)
            if unit == "player" then self:_RequestPetUpdate() end
        end)
        self:RegisterEventHandler("SPELLS_CHANGED", function() self:_RequestPetUpdate() end)

    end;

    _CreateSettings = function(self)
        
        self._settingsBtn = ButtonSimple(self)
        self._settingsBtn:SetTexture(MUI.TEX_SKIN .. "worldmap\\questlog", 1024, 1024, 825, 123, 29, 31)
        self._settingsBtn:SetSize(13, 14)
        self._settingsBtn:AlignRight(self._bgHeader, 20)
        self._settingsBtn:HookScript("OnMouseDown", function()
            self._settingsMenu:Toggle()
        end)

        self._settingsMenu = DropdownMenu(self._settingsBtn, "MUI_SpellbookSettings", self._settingsBtn, 0.45)
        self._settingsMenu:SetMenuWidth(220)
        self._settingsMenu:SetAnchor(function(popup, a)
            popup:Below(a, -4)
            popup:AlignRight(a, -10)
        end)

        self:RegisterEventHandler("PLAYER_ENTERING_WORLD", function()

            self._settingsMenu:SetItems({
                {
                    type    = "checkbox",
                    label   = "Show passive abilities",
                    checked = MUI_DB.settings.spellbook.showPassive,
                    OnChanged = function(_, checked)
                        MUI_DB.settings.spellbook.showPassive = checked
                        self:_RequestRebuild()
                    end,
                },
                {
                    type    = "checkbox",
                    label   = "Show header icons",
                    checked = MUI_DB.settings.spellbook.showHeaderIcons,
                    OnChanged = function(_, checked)
                        MUI_DB.settings.spellbook.showHeaderIcons = checked
                        self:_RequestRebuild()
                    end,
                },
                --[[
                {
                    type    = "checkbox",
                    label   = "Show quest level",
                    checked = MUI_DB.settings.questHelper.showQuestLevel,
                    OnChanged = function(_, checked)
                        MUI_DB.settings.questHelper.showQuestLevel = checked
                        self:Refresh()
                        MUI_QuestHelper.tracker:Rebuild()
                    end,
                },
                {
                    type    = "checkbox",
                    label   = "Color quests by level",
                    checked = MUI_DB.settings.questHelper.showQuestDifficultyColor,
                    OnChanged = function(_, checked)
                        MUI_DB.settings.questHelper.showQuestDifficultyColor = checked
                        self:Refresh()
                        MUI_QuestHelper.tracker:Rebuild()
                    end,
                },
                {
                    type    = "checkbox",
                    label   = "Auto-collapse categories",
                    checked = MUI_DB.settings.questHelper.autoCollapseQuestCategories,
                    OnChanged = function(_, checked)
                        MUI_DB.settings.questHelper.autoCollapseQuestCategories = checked
                        -- Turning the toggle off should immediately expand
                        -- every category (collapse pass would otherwise
                        -- only run on the next map / focus change).
                        if not checked then
                            for _, cat in ipairs(self._categories) do
                                if cat:IsShown() then cat:SetCollapsed(false) end
                            end
                            self:_RecalcHeight()
                        else
                            self:_ApplyMapAwareCollapse()
                        end
                    end,
                },
                --]]
            })

        end)

    end;

    _RequestRebuild = function(self)
        if InCombatLockdown() then
            self._rebuildPending = true
            return
        end
        self:_RebuildAll()
    end;

    -- Pet-tab-only refresh (raw pet-spellbook scan). Reparents pet items, so
    -- combat-deferred like the full rebuild.
    _RequestPetUpdate = function(self)
        if InCombatLockdown() then
            self._petPending = true
            return
        end
        self:_UpdatePetTab()
    end;

    _RebuildAll = function(self)
        self._classTabBtn:SetText(UnitClass("player"))
        self:_UpdateClassTab()
        self:_UpdateGeneralTab()
        self:_UpdatePetTab()
    end;

    _UpdateClassTab = function(self)
        local sections = {}
        for spec = 1, 3 do
            local groups = self:_GroupsFromDB(MUI_DB.data.spells.class[spec])
            if #groups > 0 then
                local _, specName = C_SpecializationInfo.GetSpecializationInfo(spec)
                table.insert(sections, {
                    title  = specName or ("Spec " .. spec),
                    groups = groups,
                    spec   = spec,
                })
            end
        end
        self._tabClass:SetSections(sections)
    end;

    _UpdateGeneralTab = function(self)
        local groups = self:_GroupsFromDB(MUI_DB.data.spells.general)
        local sections = {}
        if #groups > 0 then
            table.insert(sections, { title = "General", groups = groups })
        end
        self._tabGeneral:SetSections(sections)
    end;

    _UpdatePetTab = function(self)
        -- Pet spells aren't in MUI_DB — scan the pet spellbook raw. Group by
        -- name (ranks share one item, like the class tab); SpellbookItem
        -- derives the icon from the spellID. Show the Pet tab only when a pet
        -- with spells is out.
        local sections = {}
        local numPetSpells = HasPetSpells()

        if numPetSpells and numPetSpells > 0 then
            local byName, order = {}, {}
            for slot = 1, numPetSpells do
                local name, rank, spellID = GetSpellBookItemName(slot, "pet")
                local slotType = GetSpellBookItemInfo(slot, "pet")
                if name then
                    if not byName[name] then
                        byName[name] = {}
                        table.insert(order, name)
                    end
                    table.insert(byName[name], {
                        spellID   = spellID,
                        name      = name,
                        rank      = rank or "",
                        levelReq  = 0,
                        isKnown   = slotType ~= "FUTURESPELL",
                        isPassive = IsPassiveSpell(slot, "pet"),
                        source    = "pet",
                    })
                end
            end

            local groups = {}
            for _, name in ipairs(order) do
                table.insert(groups, SpellGroup(name, byName[name]))
            end
            if #groups > 0 then
                table.insert(sections, { title = UnitName("pet") or "Pet", groups = groups })
            end
        end

        self._tabPet:SetSections(sections)
        if #sections > 0 then self._petTabBtn:Show() else self._petTabBtn:Hide() end
    end;

    -- Wrap a name->spells DB table into SpellGroups, dropping passive spells
    -- the player hasn't learned, then sort known > unknown, active > passive;
    -- known alphabetically, unknown by level requirement. Keys precomputed
    -- (display spell = the one SpellbookItem shows) so the comparator stays a
    -- cheap field compare.
    _GroupsFromDB = function(self, db)
        local groups, key = {}, {}
        if db then
            for name, spells in pairs(db) do
                local g       = SpellGroup(name, spells)
                local known   = g:IsKnown()
                local display = known and g:GetLastKnown() or g:GetDisplayRank()
                local passive = (display and display.isPassive) or false
                local showPassives = MUI_DB.settings.spellbook.showPassive
                -- Unlearned passives are skipped;
                -- Learned passives are skipped depending on the setting;
                if (not passive) or (known and showPassives) then
                    table.insert(groups, g)
                    key[g] = {
                        known   = known,
                        passive = passive,
                        name    = g:GetName() or "",
                        level   = (display and display.levelReq) or 0,
                    }
                end
            end

            table.sort(groups, function(a, b)
                local ka, kb = key[a], key[b]
                if ka.known   ~= kb.known   then return ka.known       end  -- known first
                if ka.passive ~= kb.passive then return not ka.passive end  -- active first
                if ka.known then
                    return ka.name < kb.name                                -- known: alphabetical
                end
                if ka.level ~= kb.level then return ka.level < kb.level end -- unknown: by level
                return ka.name < kb.name
            end)
        end
        return groups
    end;

}