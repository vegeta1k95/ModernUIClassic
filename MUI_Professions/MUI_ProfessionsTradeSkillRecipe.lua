-- Recipe-detail pane on the right side of the overlay.
--
-- Renders the currently-selected recipe — icon + quality border, name +
-- description, produced count, tool/spell-focus requirements, reagent
-- rows, and (for unlearned recipes) the "Recipe is not known" hover line
-- with source attribution.
--
-- State comes through SetContext per refresh: { adapter, profKey,
-- unlearnedSpellID }. Two render paths:
--   * Refresh()       — native-backed (TradeSkill/Craft adapter); fully
--                       populated from the open tradeskill window.
--   * RefreshFromDB() — DB-only fallback used when an "Unlearned" row is
--                       selected and we render the recipe from
--                       MUI_RecipeDB[profKey][spellID].

class "ProfessionsRecipePane" : extends "Frame" {

    -- Quality-tinted border atlas regions, keyed by Enum.ItemQuality value.
    _ICON_BORDER_ATLAS   = MUI.TEX_SKIN .. "auctionhouse\\auctionhouse",
    _ICON_BORDER_REGIONS = {
        [0] = { 146, 720, 122, 122 },  -- Poor (grey)
        [1] = { 146, 720, 122, 122 },  -- Common (white)
        [2] = { 8,   583, 122, 122 },  -- Uncommon (green)
        [3] = { 8,   445, 122, 122 },  -- Rare (blue)
        [4] = { 8,   720, 122, 122 },  -- Epic (purple)
        [5] = { 146, 583, 122, 122 },  -- Legendary (orange)
    },

    __init = function(self, parent, anchorLeft, anchorBottomRight)
        Frame.__init(self, "Frame", parent)

        -- Order matters: build Bg as a child of the parent overlay first so
        -- it sits on the overlay's own BACKGROUND layer (sublevel 1, above
        -- PanelPortrait's frame-background-rock at sublevel 0). InsetFrame's
        -- NineSlice border draws on BORDER -5 — strictly above any
        -- BACKGROUND content, so we don't fight useParentLevel sort order.
        self._recipeFrame = InnerFrame(parent)
        self._recipeFrame:HideBg()
        self._recipeFrame:SetPoint("TOPLEFT", anchorLeft, "TOPRIGHT", 2, 0)
        self._recipeFrame:SetPoint("BOTTOMRIGHT", anchorBottomRight, "TOPRIGHT", 2, 6)
        self._recipeFrame:SetScale(0.9)

        self._bg = Texture(parent, nil, "BACKGROUND")
        self._bg:SetDrawLayer("BACKGROUND", 1)
        self._bg:Fill(self._recipeFrame)

        self._iconFrame = Frame("Frame", self._recipeFrame)
        self._iconFrame:SetSize(61, 61)
        self._iconFrame:AlignParentTopLeft(20, 21)

        self._iconBorder = Texture(self._iconFrame, nil, "ARTWORK")
        self._iconBorder:FillParent()
        self._iconBorder:SetTextureRegion(self._ICON_BORDER_ATLAS, 1024, 1024, 146, 720, 122, 122)

        -- Additive-blend duplicate of the border, shown on hover to glow
        -- the ring. TexCoord is kept in sync with `_iconBorder` from
        -- `_ApplyIconBorder` so the highlight follows the quality colour.
        self._iconBorderHl = Texture(self._iconFrame, nil, "OVERLAY")
        self._iconBorderHl:SetDrawLayer("OVERLAY", 1)
        self._iconBorderHl:FillParent()
        self._iconBorderHl:SetTextureRegion(self._ICON_BORDER_ATLAS, 1024, 1024, 146, 720, 122, 122)
        self._iconBorderHl:SetBlendMode("ADD")
        self._iconBorderHl:SetAlpha(0.4)
        self._iconBorderHl:Hide()

        self._iconFrame:SetScript("OnEnter", function() self._iconBorderHl:Show() end)
        self._iconFrame:SetScript("OnLeave", function() self._iconBorderHl:Hide() end)
        -- DFUI uses SetTradeSkillItem(idx) for TradeSkill rows and
        -- SetCraftSpell(idx) for Craft (Enchanting) rows. For unlearned
        -- rows where we don't have a native index, fall back to the cached
        -- item link derived from the DB output, if any.
        self._iconFrame:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            if self._unlearnedSpellID then
                -- Fallback chain for the unlearned-recipe icon tooltip:
                --   1. _recipeLink     — output item link (TradeSkill recipes
                --                        whose DB entry has `output` filled).
                --   2. SetSpellByID    — last resort. Enchant cast-spells
                --                        usually show just the name in Era,
                --                        but it's better than nothing.
                if self._recipeLink then
                    tooltip:SetHyperlink(self._recipeLink)
                    return
                end
                tooltip:SetSpellByID(self._unlearnedSpellID)
                return
            end
            if self.adapter then
                local idx = self.adapter:GetSelectionIndex()
                if idx > 0 then self.adapter:SetRecipeTooltip(tooltip, idx) end
            end
        end)

        self._icon = Texture(self._iconFrame, nil, "BACKGROUND")
        self._icon:FillParent(12)
        self._icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)

        self._recipeCount = FontString(self._iconFrame)
        self._recipeCount:SetFont(MUI.FONT, 15, "OUTLINE")
        self._recipeCount:SetText(2)
        self._recipeCount:SetPoint("CENTER", self._icon, "BOTTOMRIGHT", -3, 6)
        self._recipeCount:Hide()

        self._recipeName = FontString(self._recipeFrame)
        self._recipeName:SetFontSize(14)
        self._recipeName:SetPoint("TOPLEFT", self._iconFrame, "TOPRIGHT", 6, -7)
        self._recipeName:SetText("Recipe name")

        self._recipeRequires = FontString(self._recipeFrame)
        self._recipeRequires:SetFontSize(11)
        self._recipeRequires:AlignLeft(self._recipeName)
        self._recipeRequires:Below(self._recipeName, 4)
        self._recipeRequires:SetText("Requires:")

        self._recipeDescription = FontString(self._recipeFrame)
        self._recipeDescription:SetFontSize(10.5)
        self._recipeDescription:AlignLeft(self._iconFrame, 6)
        self._recipeDescription:Below(self._iconFrame, 5)
        self._recipeDescription:SetText("This is the description of the item/recipe.")

        self._recipeUnknown = Frame("Frame", self._recipeFrame)
        self._recipeUnknown:AlignLeft(self._recipeDescription)
        self._recipeUnknown:Below(self._recipeDescription, 14)
        self._recipeUnknown:SetSize(100, 20)

        local unknownIcon = Texture(self._recipeUnknown, nil, "ARTWORK")
        unknownIcon:SetTextureRegion(MUI.TEX_BASE .. "icon-help", 64, 64, 13, 13, 38, 38)
        unknownIcon:SetSize(18, 18)
        unknownIcon:AlignParentLeft()

        local unknownText = FontString(self._recipeUnknown)
        unknownText:SetText("Recipe is not known")
        unknownText:SetFontSize(12)
        unknownText:SetTextColor(1, 0.82, 0, 1)
        unknownText:RightOf(unknownIcon, 4)

        -- Hover-tooltip: renders the `source` field from the current
        -- recipe's MUI_RecipeDB entry. No header — each acquisition path
        -- is one (or two) tooltip lines, gold-prefixed up through the
        -- colon (BuildSourceLines lives in MUI_ProfessionsSourceResolver).
        self._recipeUnknown:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            local src = self._recipeSource
            if not src then
                tooltip:AddLine("Unknown — no source on file.", 0.7, 0.7, 0.7, true)
                return
            end
            local ctx = {
                profName = self.adapter and self.adapter:GetProfName() or "?",
                orange   = self._recipeOrange,
            }
            local entries = src.kind and { src } or src
            for _, entry in ipairs(entries) do
                MUI_ProfessionsSourceResolver:BuildSourceLines(tooltip, entry, ctx)
            end
        end)

        self._reagentsHeader = FontString(self._recipeFrame)
        self._reagentsHeader:AlignLeft(self._recipeDescription)
        self._reagentsHeader:Below(self._recipeUnknown, 10)
        self._reagentsHeader:SetFont(MUI.FONT, 10,  "")
        self._reagentsHeader:SetShadowOffset(1, -1)
        self._reagentsHeader:SetTextColor(1, 0.82, 0, 1)
        self._reagentsHeader:SetText("Reagents:")
        self._reagentsHeader:Hide()

        self._reagentRows = {}
    end;

    -- Per-refresh context — set by the singleton before Refresh runs.
    SetContext = function(self, adapter, profKey, unlearnedSpellID)
        self.adapter           = adapter
        self._activeProfKey    = profKey
        self._unlearnedSpellID = unlearnedSpellID
    end;

    HideReagentsHeader = function(self) self._reagentsHeader:Hide() end;

    -- True if the unlearned recipe identified by spellID has `itemID` in
    -- its output or any of its reagents — used to gate GET_ITEM_INFO_RECEIVED
    -- re-renders so we don't refresh on every unrelated item the client
    -- happens to fetch.
    RecipeNeedsItem = function(self, spellID, itemID)
        local recipeMeta = MUI_RecipeDB and self._activeProfKey
                       and MUI_RecipeDB:Get(self._activeProfKey)
        local entry = recipeMeta and recipeMeta[spellID]
        if not entry then return false end
        if entry.output and entry.output[1] == itemID then return true end
        for _, r in ipairs(entry.reagents or {}) do
            if r[1] == itemID then return true end
        end
        return false
    end;

    _ApplyIconBorder = function(self, border, quality)
        local r = self._ICON_BORDER_REGIONS[quality or 1] or self._ICON_BORDER_REGIONS[1]
        border:SetTextureRegion(self._ICON_BORDER_ATLAS, 1024, 1024, r[1], r[2], r[3], r[4])
    end;

    -- Pull the currently-selected recipe out of the native (TradeSkill or
    -- Craft) and project it into our recipe-description panel:
    --   icon, quality border, name, description, x-y produced count, and
    --   the reagent rows below. Empty / no-selection state hides the lot.
    -- Returns true if the unlearned path handled the render.
    Refresh = function(self)
        if not self._iconFrame then return end

        if self._unlearnedSpellID then
            self:RefreshFromDB(self._unlearnedSpellID)
            return true
        end

        local adapter = self.adapter
        local idx = adapter and adapter:GetSelectionIndex() or 0

        if idx <= 0 then
            self._iconFrame:Hide()
            self._recipeName:SetText("")
            self._recipeDescription:SetText("")
            self._recipeRequires:Hide()
            self._recipeCount:Hide()
            self._recipeUnknown:Hide()
            self._reagentsHeader:Hide()
            self._recipeSource = nil
            self._recipeOrange = nil
            self:_ClearReagentRows()
            return
        end
        self._iconFrame:Show()

        local name        = adapter:GetRecipeInfo(idx)
        local icon        = adapter:GetRecipeIcon(idx)
        local desc        = adapter:GetRecipeDescription(idx)
        local outputLink  = adapter:GetRecipeItemLink(idx)
        local numReagents = adapter:GetNumReagents(idx)
        local minMade, maxMade = adapter:GetNumMade(idx)

        local quality = 1
        if outputLink then
            local _, _, q = GetItemInfo(outputLink)
            if q then quality = q end
        end

        self._icon:SetPortrait(icon or "")
        self:_ApplyIconBorder(self._iconBorder, quality)
        self:_ApplyIconBorder(self._iconBorderHl, quality)
        self._recipeLink = outputLink
        self._recipeName:SetText(name or "")
        self._recipeDescription:SetText(desc or "")

        if minMade and maxMade and minMade > 1 then
            if minMade == maxMade then
                self._recipeCount:SetText(tostring(minMade))
            else
                self._recipeCount:SetText(minMade .. "-" .. maxMade)
            end
            self._recipeCount:Show()
        else
            self._recipeCount:Hide()
        end

        -- Requirements (tools / spell focus). BuildColoredListString takes
        -- pairs of (name, hasIt?) and returns a comma-separated string with
        -- missing entries wrapped in RED_FONT_COLOR_CODE. Available entries
        -- inherit the FontString's default colour (white), so the rendered
        -- line shows white for satisfied requirements, red for unsatisfied.
        local reqStr = BuildColoredListString(adapter:GetTools(idx))
        if reqStr then
            self._recipeRequires:SetText("|cffffd200Requires: |r" .. reqStr)
            self._recipeRequires:Show()
        else
            self._recipeRequires:Hide()
        end

        -- Source + orange-skill threshold — both hand-authored on the
        -- recipe's MUI_RecipeDB entry; walk profession meta for the entry
        -- whose spell ID resolves to the currently-selected recipe's name.
        local source, orange
        local recipeMeta = MUI_RecipeDB and self._activeProfKey
                       and MUI_RecipeDB:Get(self._activeProfKey)
        if recipeMeta and name then
            for sid, entry in pairs(recipeMeta) do
                if GetSpellInfo(sid) == name then
                    source = entry.source
                    orange = entry.skillrange and entry.skillrange[1]
                    break
                end
            end
        end
        self._recipeSource = source
        self._recipeOrange = orange

        self._recipeUnknown:Hide()

        self:_BuildReagentRows(idx, numReagents)
    end;

    -- DB-only render path used when an "Unlearned" row is selected. Pulls
    -- icon + name from GetSpellInfo, reagents + source from MUI_RecipeDB.
    -- The native tradeskill doesn't have this recipe yet, so descriptions
    -- / numMade / tools aren't available; those fields stay hidden.
    RefreshFromDB = function(self, spellID)
        local recipeMeta = MUI_RecipeDB and self._activeProfKey
                       and MUI_RecipeDB:Get(self._activeProfKey)
        local entry = recipeMeta and recipeMeta[spellID]
        if not entry then
            self._iconFrame:Hide()
            self._recipeName:SetText("")
            self._recipeDescription:SetText("")
            self._recipeRequires:Hide()
            self._recipeCount:Hide()
            self._recipeUnknown:Hide()
            self._recipeSource = nil
            self._recipeOrange = nil
            self:_ClearReagentRows()
            return
        end

        self._iconFrame:Show()
        local name = GetSpellInfo(spellID)
        self._recipeName:SetText(name or ("Spell #" .. tostring(spellID)))

        -- Era's GetSpellTexture / GetSpellInfo return the same generic
        -- crafting placeholder (file 136192) for every tradeskill spell —
        -- the only reliable icon comes from the produced item via
        -- GetItemInfo on `entry.output[1]`. Same for the hover-tooltip
        -- hyperlink and the quality border.
        local quality, icon, link
        if entry.output and entry.output[1] then
            local _, itemLink, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(entry.output[1])
            icon    = itemTexture
            link    = itemLink
            quality = itemQuality
        end
        if not icon then
            icon = (GetSpellTexture and GetSpellTexture(spellID))
                or (select(3, GetSpellInfo(spellID)))
        end
        self._icon:SetTexture(icon)
        self._icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        self:_ApplyIconBorder(self._iconBorder,   quality or 1)
        self:_ApplyIconBorder(self._iconBorderHl, quality or 1)
        self._recipeLink = link

        self._recipeDescription:SetText("")

        local count = entry.output and entry.output[2] or 1
        if count > 1 then
            self._recipeCount:SetText(tostring(count))
            self._recipeCount:Show()
        else
            self._recipeCount:Hide()
        end

        self._recipeRequires:Hide()
        self._recipeUnknown:Show()
        self._recipeSource = entry.source
        self._recipeOrange = entry.skillrange and entry.skillrange[1]

        self:_BuildReagentRowsFromDB(entry.reagents or {})
    end;

    -- Reagent rows built from a DB entry's `reagents` list ({itemId, count}).
    -- Quality, name, and texture come from GetItemInfo; owned count from
    -- GetItemCount. Items not yet in the local cache fall back to a
    -- placeholder name + zero quality.
    _BuildReagentRowsFromDB = function(self, reagents)
        for i, r in ipairs(reagents) do
            local row = self:_AcquireReagentRow(i)
            local itemId, req = r[1], r[2]
            local itemName, itemLink, quality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemId)
            local owned = (GetItemCount and GetItemCount(itemId)) or 0
            row:SetData(itemTexture, quality or 1, owned, req,
                        itemName or ("Item #" .. tostring(itemId)), itemLink)
            row:Show()
        end
        for i = #reagents + 1, #self._reagentRows do
            self._reagentRows[i]:Hide()
        end
    end;

    _BuildReagentRows = function(self, idx, numReagents)
        local adapter = self.adapter
        for i = 1, numReagents do
            local row = self:_AcquireReagentRow(i)
            local rName, rTex, rCount, pCount = adapter:GetReagentInfo(idx, i)
            local rLink                       = adapter:GetReagentItemLink(idx, i)
            local q = 1
            if rLink then
                local _, _, lq = GetItemInfo(rLink)
                if lq then q = lq end
            end
            row:SetData(rTex, q, pCount, rCount, rName, rLink)
            row:Show()
        end
        for i = numReagents + 1, #self._reagentRows do
            self._reagentRows[i]:Hide()
        end

        if #self._reagentRows > 0 then
            self._reagentsHeader:Show()
        else
            self._reagentsHeader:Hide()
        end
    end;

    _AcquireReagentRow = function(self, idx)
        local row = self._reagentRows[idx]
        if row then return row end
        row = ReagentRow(self._recipeFrame)
        if idx == 1 then
            row:SetPoint("TOPLEFT", self._reagentsHeader, "BOTTOMLEFT", 3, -12)
        else
            row:SetPoint("TOPLEFT", self._reagentRows[idx - 1], "BOTTOMLEFT", 0, -10)
        end
        self._reagentRows[idx] = row
        return row
    end;

    _ClearReagentRows = function(self)
        if not self._reagentRows then return end
        for _, row in ipairs(self._reagentRows) do row:Hide() end
    end;

    -- Expose the inner frame for outside anchors (rank bar attaches to its
    -- left edge in the singleton's _CreateRankBar).
    GetRecipeFrame = function(self) return self._recipeFrame end;

    -- Expose the profession-background texture so the singleton can swap
    -- regions per profession in _Refresh.
    GetBackground = function(self) return self._bg end;
}
