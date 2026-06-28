-- ProfessionsTradeSkillFrame
-- Custom overlay for Era's native TradeSkillFrame. We DON'T hide the native;
-- instead we anchor on top of it and push it to BACKGROUND strata. Blizzard's
-- UIPanel system keeps managing the native (open/close/panel-stacking), and
-- we ride along — closing our frame goes through CloseTradeSkill() which
-- triggers TRADE_SKILL_CLOSE and our overlay hides too. No taint.

local TEX = MUI.TEX_SKIN .. "professions\\tradeskill\\"

-- Background texture per profession, keyed by ModuleProfessions def.key
-- (the locale-free canonical key). Looked up via state.def.key in _Refresh.
local BG_BY_KEY = {
    ALCHEMY        = { TEX .. "tradeskill-bg-alchemy",          677, 550 },
    BLACKSMITHING  = { TEX .. "tradeskill-bg-blacksmithing",    677, 550 },
    COOKING        = { TEX .. "tradeskill-bg-cooking",          677, 550 },
    ENCHANTING     = { TEX .. "tradeskill-bg-enchanting",       677, 550 },
    ENGINEERING    = { TEX .. "tradeskill-bg-engineering",      677, 550 },
    FISHING        = { TEX .. "tradeskill-bg-fishing",          677, 550 },
    HERBALISM      = { TEX .. "tradeskill-bg-herbalism",        677, 550 },
    LEATHERWORKING = { TEX .. "tradeskill-bg-leatherworking",   677, 550 },
    MINING         = { TEX .. "tradeskill-bg-mining",           677, 550 },
    SKINNING       = { TEX .. "tradeskill-bg-skinning",         677, 550 },
    TAILORING      = { TEX .. "tradeskill-bg-tailoring",        677, 550 },
    FIRST_AID      = { TEX .. "tradeskill-bg-firstaid",         826, 754 },
    POISONS        = { TEX .. "tradeskill-bg-alchemy",          677, 550 },
}

local BG_DEFAULT = { TEX .. "tradeskill-bg-default", 677, 550 }

local FRAME_WIDTH = 850.5
local FRAME_HEIGHT = 591

-- Enchanting (and a couple of other vanilla skills) uses CraftFrame +
-- CRAFT_* events instead of TradeSkillFrame + TRADE_SKILL_*. Same overlay
-- works for both — the NativeAdapter routes every native API call.

object "ProfessionsTradeSkillFrame" : extends "PanelPortrait" {

    __init = function(self)
        PanelPortrait.__init(self, nil, "MUI_ProfessionsTradeSkillFrame", "")

        self:SetFrameStrata("HIGH")
        self:Hide()

        self:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
        self:AlignParentTopLeft(106, 42.5)

        self._closeButton = CloseButton(self)
        self._closeButton:PutInfront(self._border, 1)
        self._closeButton:SetScale(scale or 0.9)
        self._closeButton.OnClick = function()
            if self.adapter then self.adapter:Close() end
        end

        self:_CreateTopBar()
        self:_CreateListFrame()
        self:_CreateBottomButtons()
        self:_CreateRecipeFrame()
        self:_CreateTabs()
        self:_CreateRankBar()

        MUI_ModuleProfessions:Subscribe(function() self:_Refresh() end)

        -- Blizzard's *Frame_Update re-Shows the recipe-row buttons (Craft1..8,
        -- TradeSkillSkill1..8) on every refresh — so HideAllChildren in
        -- _OnShow isn't enough; the rows reappear behind our overlay.
        -- Hook both update functions to re-hide afterwards.
        --
        -- BOTH Blizzard_TradeSkillUI and Blizzard_CraftUI are LoadOnDemand —
        -- their *_Update functions don't exist at our __init. We install via
        -- ADDON_LOADED, and also handle the case where they're already loaded
        -- by the time we get here.
        self._hookedTradeSkill = false
        self._hookedCraft = false
        local function tryHook()
            if not self._hookedTradeSkill and TradeSkillFrame_Update then
                hooksecurefunc("TradeSkillFrame_Update", function()
                    if self._activeNative == TradeSkillFrame then self:_HideNative() end
                end)
                -- TradeSkillFrame_SetSelection calls TradeSkillHighlightFrame:Show()
                -- directly (Blizzard_TradeSkillUI.lua:252) — bypasses Update,
                -- so we need a dedicated hook to re-hide that selection bar.
                if TradeSkillFrame_SetSelection then
                    hooksecurefunc("TradeSkillFrame_SetSelection", function()
                        if self._activeNative == TradeSkillFrame then
                            -- DON'T clear self._unlearnedSpellID here — the
                            -- native fires SetSelection on many internal
                            -- events (TRADE_SKILL_UPDATE, category collapse,
                            -- recipe completion, …), and that would yank
                            -- the user off the unlearned-recipe preview.
                            -- `_OnRowClick` handles clearing when the user
                            -- actually clicks a learned row.
                            self:_HideNative()
                            self:_RefreshRecipeFrame()
                        end
                    end)
                end
                self._hookedTradeSkill = true
            end
            if not self._hookedCraft and CraftFrame_Update then
                hooksecurefunc("CraftFrame_Update", function()
                    if self._activeNative == CraftFrame then self:_HideNative() end
                end)
                -- Same fix for CraftHighlightFrame, shown by CraftFrame_SetSelection.
                if CraftFrame_SetSelection then
                    hooksecurefunc("CraftFrame_SetSelection", function()
                        if self._activeNative == CraftFrame then
                            -- Same reasoning as the TradeSkill hook above.
                            self:_HideNative()
                            self:_RefreshRecipeFrame()
                        end
                    end)
                end
                self._hookedCraft = true
            end
        end
        tryHook()
        self:RegisterEventHandler("ADDON_LOADED", function(_, _, name)
            if name == "Blizzard_TradeSkillUI" or name == "Blizzard_CraftUI" then
                tryHook()
            end
        end)

        -- TradeSkillFrame and CraftFrame are independent in vanilla — both can
        -- be open simultaneously. DFUI makes them mutually exclusive (tab-like)
        -- by closing one before showing the other. We do the same, but the
        -- CLOSE event from the cross-close arrives AFTER our SHOW handler has
        -- already activated the new native — so _OnClose must ignore it if
        -- the active native isn't the one whose CLOSE event came in. Without
        -- the guard, opening Alchemy (TRADE_SKILL_SHOW → CloseCraft) would
        -- immediately hide our overlay via the stray CRAFT_CLOSE.
        self:RegisterEventHandler("TRADE_SKILL_SHOW", function()
            if CloseCraft then CloseCraft() end
            self:_OnShow(TradeSkillFrame)
        end)
        self:RegisterEventHandler("TRADE_SKILL_CLOSE", function()
            if self._activeNative == TradeSkillFrame then self:_OnClose() end
        end)
        self:RegisterEventHandler("TRADE_SKILL_UPDATE", function()
            if self._activeNative == TradeSkillFrame then self:_Refresh() end
        end)

        self:RegisterEventHandler("CRAFT_SHOW", function()
            if CloseTradeSkill then CloseTradeSkill() end
            self:_OnShow(CraftFrame)
        end)
        self:RegisterEventHandler("CRAFT_CLOSE", function()
            if self._activeNative == CraftFrame then self:_OnClose() end
        end)
        self:RegisterEventHandler("CRAFT_UPDATE", function()
            if self._activeNative == CraftFrame then self:_Refresh() end
        end)

        -- If the user opened a profession via an action-bar spell mid-combat,
        -- _OnShow couldn't run its protected UIPanel setup. Catch up now.
        self:RegisterEventHandler("PLAYER_REGEN_ENABLED", function()
            if self._activeNative and self._setupPending then
                self:_ApplyNativeSetup()
            end
        end)

        -- Reset the quantity editbox to 1 when the player's current craft
        -- is interrupted or fails to begin — the remaining queue is dropped
        -- by the client, so the displayed pending-count is stale.
        local function onCastEnd(_, _, unit)
            if unit ~= "player" or not self._actionBar then return end
            self._actionBar:ResetQuantity()
        end
        self:RegisterEventHandler("UNIT_SPELLCAST_INTERRUPTED", onCastEnd)
        self:RegisterEventHandler("UNIT_SPELLCAST_FAILED",      onCastEnd)

        -- GetItemInfo returns nil on first call for uncached items and fires
        -- a server fetch; the data arrives via GET_ITEM_INFO_RECEIVED. When
        -- it's for an item the currently-selected unlearned recipe depends
        -- on (output or any reagent), re-run _RefreshFromDB so the icon,
        -- quality border and reagent rows pick up the fresh data.
        self:RegisterEventHandler("GET_ITEM_INFO_RECEIVED", function(_, _, itemID)
            if not self._unlearnedSpellID then return end
            if not self:_RecipeNeedsItem(self._unlearnedSpellID, itemID) then return end
            self:_RefreshFromDB(self._unlearnedSpellID)
        end)
    end;

    _CreateTopBar = function(self)

        local barW  = self:GetWidth()
        local tiles = math.max(1, math.ceil(barW / 256))
        local tileW = barW / tiles

        for i = 1, tiles do
            local bg = Texture(self, nil, "BACKGROUND")
            bg:SetDrawLayer("BACKGROUND", 1)
            bg:SetTextureRegion(MUI.TEX_BASE .. "frame-inner-horizontal", 256, 128, 0, 0, 256, 40)
            bg:SetSize(tileW, 40)
            bg:SetPoint("TOPLEFT", self, "TOPLEFT", (i - 1) * tileW, -16)
        end
    end;

    _CreateRankBar = function(self)
        self._rankBar = ProfessionsRankBar(self)
        self._rankBar:AlignParentTop(34)
        self._rankBar:AlignLeft(self._recipeFrame, 2.5)
    end;

    _UpdateRankBar = function(self, activeState)
        if not self._rankBar then return end
        local profName = self.adapter and self.adapter:GetProfName() or ""
        self._rankBar:Update(activeState, profName)
    end;

    _CreateListFrame = function(self)
        self._listPane = ProfessionsRecipeList(self)
        self._listFrame = self._listPane:GetListFrame()
        self._listPane.OnUnlearnedSelected = function(_, spellID)
            self._unlearnedSpellID = spellID
            self:_RefreshRecipeFrame()
        end
        self._listPane.OnLearnedSelected = function()
            self._unlearnedSpellID = nil
        end
    end;

    _RefreshRecipeList = function(self)
        if not self._listPane then return end
        self._listPane:SetContext(self.adapter, self._activeProfKey, self._unlearnedSpellID)
        self._listPane:Refresh()
    end;

    _CreateRecipeFrame = function(self)
        self._recipePane = ProfessionsRecipePane(self, self._listFrame, self._actionBar:GetCreateButton())
        self._recipeFrame = self._recipePane:GetRecipeFrame()
        self._bg = self._recipePane:GetBackground()
    end;

    _RecipeNeedsItem = function(self, spellID, itemID)
        return self._recipePane and self._recipePane:RecipeNeedsItem(spellID, itemID) or false
    end;

    _RefreshRecipeFrame = function(self)
        if not self._recipePane then return end
        self._recipePane:SetContext(self.adapter, self._activeProfKey, self._unlearnedSpellID)
        self._recipePane:Refresh()
        self:_UpdateActionButtons()
    end;

    _RefreshFromDB = function(self, spellID)
        if not self._recipePane then return end
        self._recipePane:SetContext(self.adapter, self._activeProfKey, self._unlearnedSpellID)
        self._recipePane:RefreshFromDB(spellID)
    end;

    _UpdateActionButtons = function(self)
        if not self._actionBar then return end
        self._actionBar:Refresh(self.adapter, self._unlearnedSpellID ~= nil)
    end;

    _CreateBottomButtons = function(self)
        self._actionBar = ProfessionsActionBar(self)
    end;

    _CreateTabs = function(self)
        self._tabGroup = ProfessionsTabs(self)
        self._tabGroup:Below(self, -1)
        self._tabGroup:AlignLeft(self, 23)
        self._tabGroup.OnSelect = function()
            if self._recipePane then self._recipePane:HideReagentsHeader() end
        end
    end;

    _OnShow = function(self, nativeFrame)
        if not nativeFrame then return end

        self._activeNative = nativeFrame
        -- All read paths into the native (recipe info, reagents, line rank,
        -- selection index, name, close, …) flow through this adapter — no
        -- more `if _activeNative == TradeSkillFrame then GetTradeSkillInfo …`
        -- chains scattered across the file.
        self.adapter = MUI_ProfessionsNativeAdapter:For(nativeFrame)

        self._frame = Frame(nativeFrame)
        -- The native UIPanel setup (SetSize / UIPanelLayout-width / strata)
        -- is protected — defer until out of combat if needed. SetSize and
        -- the attribute are idempotent and only need to be applied once per
        -- native; the strata flip is cosmetic on a frame we then hide.
        if not InCombatLockdown() then
            self:_ApplyNativeSetup()
        else
            self._setupPending = true
        end
        self:_HideNative()

        -- Fresh client-side collapse state for this open session; snap the
        -- list scroll back to top so a profession switch shows the first row.
        if self._listPane then
            self._listPane:ResetCollapsed()
            self._listPane:ResetScroll()
        end

        -- Force Blizzard's side fully expanded so GetTradeSkillInfo / GetCraftInfo
        -- enumerate every recipe regardless of saved collapse state. We never
        -- toggle Blizzard's collapse again after this — header rows mutate
        -- the list pane's local collapse map and filter recipes from there.
        if self.adapter then self.adapter:ExpandAll() end

        UpdateUIPanelPositions(nativeFrame)

        if nativeFrame == CraftFrame then
            self:_InstallCraftButton()
        else
            self:_RemoveCraftButton()
        end

        self:Show()
        self:_Refresh()
        -- Cold-open race: after a /reload, TRADE_SKILL_SHOW often fires
        -- before the server has streamed recipe data, so GetTradeSkillInfo
        -- returns empty names on this first paint. TRADE_SKILL_UPDATE
        -- _should_ fire moments later and re-paint via our handler, but
        -- in practice we sometimes don't see it on the first open. Schedule
        -- a defensive re-paint on the next tick so blank labels resolve
        -- without the user having to click a row.
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, function()
                if self._activeNative then self:_Refresh() end
            end)
        end
    end;

    -- Hide every Blizzard-side widget and region under the currently-active
    -- native (TradeSkillFrame or CraftFrame). Recursive so we catch widgets
    -- nested inside scroll frames / containers, not just direct children.
    -- Called every _Refresh and from the post-update hooks because vanilla's
    -- *Frame_Update re-Shows the recipe rows on each refresh.
    _HideNative = function(self)
        if not self._frame then return end
        self._frame:HideAllRegions()
        self._frame:HideAllDescendants()
    end;

    _InstallCraftButton = function(self) self._actionBar:InstallCraftButton() end;
    _RemoveCraftButton  = function(self) self._actionBar:RemoveCraftButton() end;

    -- One-time setup per native: size, UIPanelLayout-width, and BACKGROUND
    -- strata. All protected on a UIPanel, but all idempotent — the native
    -- is _HideNative'd anyway so the strata is invisible. Apply once and
    -- never touch it again.
    _ApplyNativeSetup = function(self)
        local native = self._activeNative
        if not native or not self._frame then return end
        self._setupApplied = self._setupApplied or {}
        if self._setupApplied[native] then return end
        self._frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
        self._frame:SetAttribute("UIPanelLayout-width", FRAME_WIDTH + 43)
        self._frame:SetFrameStrata("BACKGROUND")
        self._setupApplied[native] = true
        self._setupPending = nil
    end;

    _OnClose = function(self)
        if self._actionBar then self._actionBar:HideCraftButton() end
        self:Hide()
        self._activeNative     = nil
        self.adapter           = nil
        self._unlearnedSpellID = nil
        self._setupPending     = nil
    end;

    _Refresh = function(self)
        self:_HideNative()

        local profName = self.adapter and self.adapter:GetProfName()
        local activeState = MUI_ModuleProfessions:GetByLocalizedName(profName)
        -- Stash the canonical key (e.g. "ENCHANTING") so _GetRecipeEntries
        -- can decide whether to use MUI_RecipeDB-based category grouping or
        -- fall back to Blizzard's native header walk.
        self._activeProfKey = activeState and activeState.def.key or nil

        if profName and profName ~= "UNKNOWN" then
            self:SetTitle(profName)
            if activeState then
                local tex = BG_BY_KEY[activeState.def.key] or BG_DEFAULT
                self._bg:SetTextureRegion(tex[1], 1024, 1024, 0, 0, tex[2], tex[3])
                self:SetPortrait(activeState.def.icon)
            else
                self._bg:SetTextureRegion(BG_DEFAULT, 1024, 1024, 0, 0, 677, 550)
            end
        else
            self._bg:SetTextureRegion(BG_DEFAULT, 1024, 1024, 0, 0, 677, 550)
        end
        self:_RefreshTabs(activeState)
        self:_RefreshRecipeList()
        self:_UpdateRankBar(activeState)
        self:_RefreshRecipeFrame()
    end;

    _RefreshTabs = function(self, activeState)
        self._tabGroup:Refresh(activeState)
    end;
}
