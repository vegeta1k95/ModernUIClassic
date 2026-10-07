-- MUI_BankFrame: the bank window — retail's BankFrame (738x460, drawn at nine
-- tenths like the other portrait windows) on Era's bank.
--
-- Era's BankFrame stays the real panel: the panel manager opens it at a
-- banker, Escape and walking away close it, its OnHide ends the bank session
-- and its events keep the next bag slot's price current. This window is its
-- child and covers it. Era's own slots live in BankSlotsFrame, which
-- BankFrame_ShowPanel shows again on every visit, putting the frame back to
-- its classic size as well; both are undone from a hook on it.
--
--   BankWindow()
--     :Refresh()              the grid, the bag tabs, the money
--     :DepositReagents()      every trade good in the bags, into the bank
--     .grid .tabs

local FRAME_W, FRAME_H = 664, 414
-- The panel manager puts Era's frame 16 px left of and 12 px above where a
-- window's art begins: its classic art has that much empty margin.
local NATIVE_DX, NATIVE_DY = 16, 12
local TAB_OVERHANG = 36           -- the bag tabs, past the right edge
local FOOTER       = 27           -- the money row, under the item area
local GRID_TOP, GRID_LEFT = 57, 25
local TAB_TOP, TAB_GAP    = 22, 15

local TRADE_GOODS = Enum.ItemClass.Tradegoods

local REFRESH_EVENTS = {
    "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED",
    "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "INVENTORY_SEARCH_UPDATE", "PLAYER_MONEY",
}

class "BankWindow" : extends "PanelPortrait" {
    __init = function(self)
        self._blizzard   = Frame(BankFrame)
        self._nativeBody = Frame(BankSlotsFrame)
        PanelPortrait.__init(self, self._blizzard, "MUI_BankFrame", "")
        self:FillParentPadding(NATIVE_DX, NATIVE_DY, 0, 0)

        -- Nothing of Era's frame shows or takes the mouse; this window does.
        self._blizzard:HideAllRegions()
        self._blizzard:EnableMouse(false)
        Frame(BankCloseButton):Hide()

        self._closeButton = CloseButton(self)
        self._closeButton:PutInfront(self._border, 1)
        self._closeButton:SetScale(0.9)
        -- The client ends the session, and Era's frame closes on that.
        self._closeButton.OnClick = function() CloseBankFrame() end

        self:_BuildItemArea()

        self.grid = BankGrid(self)
        self.grid:AlignParentTopLeft(GRID_TOP, GRID_LEFT)

        self.tabs = {}
        for i = 1, NUM_BANKBAGSLOTS do
            local tab = BankBagTab(self, i, self.grid)
            local size = tab:GetWidth()
            tab:AlignParentTopRight(TAB_TOP + (i - 1) * (size + TAB_GAP), -(size + 2))
            self.tabs[i] = tab
        end

        self:_BuildSearch()
        self:_BuildDeposit()
        self:_BuildMoney()

        -- A sort or a deposit sends these in bursts: one refresh a frame.
        for _, event in ipairs(REFRESH_EVENTS) do
            self:RegisterEventHandler(event, function() self._stale = true end)
        end
        self:HookScript("OnUpdate", function()
            if self._stale then self:Refresh() end
        end)
        self:RegisterEventHandler("PLAYER_REGEN_ENABLED", function()
            if self._depositPending then
                self._depositPending = nil
                if self:IsVisible() then self:DepositReagents() end
            end
        end)

        self._blizzard:HookScript("OnShow", function() self:_OnOpen() end)
        hooksecurefunc("BankFrame_ShowPanel", function() self:_FitNative() end)
        self:_FitNative()
    end;

    -- The item area: retail's bank background, the recessed border around it
    -- (open at the top, where it meets the title bar) and the shadow its edges
    -- cast inward. The money row below keeps the window's rock.
    _BuildItemArea = function(self)
        local tile = Texture(self, nil, "BACKGROUND")
        tile:SetDrawLayer("BACKGROUND", 1)
        tile:SetTexture(MUI.TEX_SKIN .. "bank\\bank-frame-background", "REPEAT", "REPEAT")
        tile:SetHorizTile(true)
        tile:SetVertTile(true)
        tile:Fill(self._content, 0, 0, 0, FOOTER - 2)

        local area = Frame("Frame", self)
        area:Fill(self._content, 0, 0, 0, FOOTER - 2)

        local border = InnerBorder(area)
        border:FillParent()

        local corners = MUI_AtlasRegistry.BankShadows
        local sides   = MUI_AtlasRegistry.BankShadowsVertical

        local bottomLeft = Texture(area, nil, "BORDER")
        bottomLeft:SetAtlas(corners, "CornerBottomLeft", true)
        bottomLeft:SetSize(41, 41)
        bottomLeft:AlignParentBottomLeft(2, 2)

        local bottomRight = Texture(area, nil, "BORDER")
        bottomRight:SetAtlas(corners, "CornerBottomRight", true)
        bottomRight:SetSize(41, 41)
        bottomRight:AlignParentBottomRight(2, 3)

        local bottom = Texture(area, nil, "BORDER")
        bottom:SetAtlas(corners, "Bottom", true)
        bottom:SetHeight(15)
        bottom:AlignParentBottomLeft(2, 43)
        bottom:AlignParentBottomRight(2, 44)

        local left = Texture(area, nil, "BORDER")
        left:SetAtlas(sides, "Left", true)
        left:SetWidth(15)
        left:AlignParentTopLeft(0, 2)
        left:AlignParentBottomLeft(43, 2)

        local right = Texture(area, nil, "BORDER")
        right:SetAtlas(sides, "Right", true)
        right:SetWidth(15)
        right:AlignParentTopRight(0, 3)
        right:AlignParentBottomRight(43, 3)
    end;

    -- Era's bag search box, which filters every container, and the sort
    -- button beside it, as in the backpack.
    _BuildSearch = function(self)
        self._search = Frame("EditBox", self, "MUI_BankSearchBox", "BagSearchBoxTemplate")
        self._search:SetScale(0.9)
        self._search:SetSize(110, 20)
        self._search:AlignParentTopRight(33, 56)

        self._sort = ButtonSimple(self._search)
        self._sort:SetTexture(MUI.TEX_SKIN .. "bags\\bags", 512, 256, 97, 50, 54, 54)
        self._sort:SetSize(23, 23)
        self._sort:AlignParentRight(-31, -1)
        self._sort:SetTooltip("ANCHOR_LEFT", function(tooltip)
            tooltip:AddLine("Clean Up Bank", 1, 1, 1, true, 13)
        end)
        self._sort.OnClick = function() MUI_BagSorter:SortBank() end
    end;

    _BuildDeposit = function(self)
        self._deposit = ButtonGold(self, nil, "Deposit All Reagents")
        self._deposit:SetSize(160, 22)
        self._deposit:AlignParentBottom(FOOTER + 10)
        self._deposit:SetTooltip("ANCHOR_RIGHT", function(tooltip)
            tooltip:AddLine("Move every trade good in your bags into the bank.", 1, 0.82, 0, true)
        end)
        self._deposit.OnClick = function() self:DepositReagents() end
    end;

    -- The player's money, bottom right, in retail's thin gold band.
    _BuildMoney = function(self)
        local band = Frame("Frame", self, nil, "ThinGoldEdgeTemplate")
        band:SetSize(144, 17)
        band:AlignParentBottomRight(6, 6)
        self._money = FontString(band, nil, "OVERLAY", MUI.FontBySize(10.5))
        self._money:SetTextColor(1, 1, 1, 1)
        self._money:SetJustifyH("RIGHT")
        self._money:AlignParentRight(6)
    end;

    -- ---- the native frame ----------------------------------------------

    -- Era's frame takes this window's size, plus the margin the panel manager
    -- gives it, and tells the manager how much room it needs, bag tabs
    -- included, so a second panel opens beside it. The manager is asked to
    -- lay its panels out again only out of combat, where it may move them all.
    _FitNative = function(self)
        self._nativeBody:Hide()
        self._blizzard:SetSize(NATIVE_DX + FRAME_W, NATIVE_DY + FRAME_H)
        self._blizzard:SetAttribute("UIPanelLayout-width", NATIVE_DX + FRAME_W + TAB_OVERHANG)
        if self._blizzard:IsShown() and not InCombatLockdown() then
            UpdateUIPanelPositions(BankFrame)
        end
    end;

    -- A visit starts: Era's frame has just opened at a banker.
    _OnOpen = function(self)
        self:SetTitle(UnitName("npc") or "Bank")
        self:SetPortraitFromUnit("npc")
        self.grid:ResetScroll()
        self:Refresh()
    end;

    Refresh = function(self)
        self._stale = false
        self.grid:Refresh()
        for _, tab in ipairs(self.tabs) do tab:Update() end
        self._money:SetText(C_CurrencyInfo.GetCoinTextureString(GetMoney(), 11))
    end;

    -- ---- deposit -------------------------------------------------------

    -- The empty slots a deposit may fill: the bank's own and those of
    -- ordinary bags. A bag made for one kind of item is left out; it would
    -- turn most of them away.
    _FreeSlots = function(self)
        local free = {}
        for _, container in ipairs(self.grid.containers) do
            local _, family = C_Container.GetContainerNumFreeSlots(container)
            if container == BANK_CONTAINER or family == 0 then
                for slot = 1, C_Container.GetContainerNumSlots(container) do
                    if not C_Container.GetContainerItemInfo(container, slot) then
                        free[#free + 1] = { container, slot }
                    end
                end
            end
        end
        return free
    end;

    -- Plain item moves, each to a free slot of its own: nothing is used by
    -- mistake, and no two moves touch the same slot. Out of combat, like the
    -- sort; a click in combat is carried out when it ends.
    DepositReagents = function(self)
        if InCombatLockdown() then
            self._depositPending = true
            return
        end
        local free, taken = self:_FreeSlots(), 0
        ClearCursor()
        for bag = 0, NUM_BAG_SLOTS do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and not info.isLocked
                   and select(6, C_Item.GetItemInfoInstant(info.itemID)) == TRADE_GOODS then
                    taken = taken + 1
                    local target = free[taken]
                    if not target then return end
                    C_Container.PickupContainerItem(bag, slot)
                    C_Container.PickupContainerItem(target[1], target[2])
                    -- Whatever the slot refused goes back where it was.
                    ClearCursor()
                end
            end
        end
    end;
}
