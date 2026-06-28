-- Modern minimap reskin

local TEX = MUI.TEX_SKIN .. "minimap\\"

-- Addon "minimap button" bin. Collects the addon settings buttons scattered
-- around the minimap into one collapsible grid: the draggable LibDBIcon ones
-- (from the library's registry) plus any frame whose name looks like a minimap
-- button. Map pins (Questie marks, gather nodes, …) and Blizzard frames are
-- deliberately left alone. The name heuristic mirrors MinimapButtonButton.
local BIN_PAD     = 2    -- gap between grid cells
local BIN_MARGIN  = 20   -- inner padding (insets buttons inside the diamond border)
local BIN_PER_ROW = 6    -- buttons per row before wrapping to the next row

local BIN_BUTTON_PATTERNS = {
    "^LibDBIcon10_", "MinimapButton", "MinimapFrame", "MinimapIcon",
    "[-_]Minimap[-_]", "Minimap$",
}
local BIN_PIN_PATTERNS = {
    "^HandyNotes", "^TomTom", "^HereBeDragons", "^Questie", "^GatherMate",
    "^pin", "^Pin",
}

local function binNameMatches (name, patterns)
    for _, pattern in ipairs(patterns) do
        if name:match(pattern) then return true end
    end
    return false
end

-- A collectible settings button: a non-Blizzard, non-ours frame whose name looks
-- button-ish (and not pin-ish, and not a numbered pin frame). LibDBIcon buttons
-- come from the registry instead, so this is only the name-scan fallback.
local function isBinButtonName (name)
    if not name then return false end
    if name:match("^MUI") then return false end            -- our own frames
    if issecurevariable(_G, name) then return false end    -- Blizzard frame
    if name:match("^TomCats%-") then return true end        -- TomCats (name ends in a year)
    if name:match("%d$") then return false end              -- numbered map pin
    return binNameMatches(name, BIN_BUTTON_PATTERNS)
       and not binNameMatches(name, BIN_PIN_PATTERNS)
end

MUI_Minimap = MinimapFrame(Minimap)

object "ModuleMinimap" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Minimap")
    end;

    OnEnable = function(self)

        self.zoomIn  = Button(MinimapZoomIn)
        self.zoomOut = Button(MinimapZoomOut)

        -- Scroll-wheel zoom
        MUI_Minimap:EnableMouseWheel(true)
        MUI_Minimap:SetScript("OnMouseWheel", function(frame, delta)
            if delta > 0 then
                self.zoomIn:Click()
            elseif delta < 0 then
                self.zoomOut:Click()
            end
        end)

        self:HideBlizzardFrame()
        self:AddBorder()
        self:AddTopPanel()
		self:SkinPlayerArrow()
		self:SkinZoomButtons()
		self:SkinDurability()
        self:SkinTracker()
		self:SkinMail()
        self.blipSwapper = MinimapBlipAtlasSwapper(MUI_Minimap)
        self:AddButtonBin()
    end;

    HideBlizzardFrame = function(self)
        MUI_Minimap:ClearAllPoints()
        MUI_Minimap:AlignParentTopRight(33, 10)
        MUI_Minimap:SetFrameStrata("MEDIUM")
        MUI_Minimap:SetScale(1.25)

        -- "Restore default position" must reproduce OUR anchor, not the Blizzard
        -- points the snapshot captured at construction (before this ran).
        MUI_Minimap:EditModeSetDefaultPosition(function(mm)
            mm:ClearAllPoints()
            mm:AlignParentTopRight(33, 10)
        end)
        -- 1.25 is the minimap's default scale, not a user customization.
        MUI_Minimap:EditModeSetDefaultScale(1.25)

        local cluster = Frame(MinimapCluster)
        cluster:EnableMouse(false)

        -- Blizzard minimap chrome we want to kill
        local kills = {
            "MinimapBorder", "MinimapBorderTop", "MinimapToggleButton",
            "GameTimeFrame", "TimeManagerClockButton", "TimeManagerFrame",
            "MiniMapLFGFrame", "LFGMinimapFrame", "QueueStatusButton",
            "QueueStatusMinimapButton", "QueueStatusFrame",
            "MinimapShopFrame",
            "MinimapNorthTag", "MinimapCompassTexture",
            "MinimapZoneTextButton"
        }
		
        for _, name in ipairs(kills) do
            local f = getglobal(name)
            if f then Frame(f):Kill() end
        end
    end;

    AddBorder = function(self)
        self.border = Texture(MUI_Minimap, nil, "OVERLAY")
        self.border:SetTexture(TEX .. "minimap-border.tga")
        self.border:FillParent(-10)

        self.shadow = Texture(MUI_Minimap, nil, "BORDER")
        self.shadow:SetTexture(TEX .. "minimap-shadow.tga")
        self.shadow:FillParent(-10)
        self.shadow:SetAlpha(0.0)
    end;

    SkinPlayerArrow = function(self)

        MUI_Minimap:SetPOIArrowTexture(TEX .. "arrow-guide.tga")
        MUI_Minimap:SetCorpsePOIArrowTexture(TEX .. "arrow-corpse.tga")
        MUI_Minimap:SetStaticPOIArrowTexture(TEX .. "arrow-poi.tga")

        -- Hide default Blizzard player arrow by replacing with blank texture.
        MUI_Minimap:SetPlayerTexture("")

        -- Custom overlay arrow, rotated by GetPlayerFacing(). HIGH keeps it above
        -- the minimap pins/blips (MEDIUM) while staying below the edit-mode overlay
        -- (FULLSCREEN), so it doesn't poke through it in edit mode.
        self.arrowFrame = Frame("Frame", MUI_Minimap, "MUI_MinimapArrow")
        self.arrowFrame:SetSize(20, 20)
        self.arrowFrame:CenterInParent()
        self.arrowFrame:SetFrameStrata("HIGH")

        self.arrowTex = Texture(self.arrowFrame, nil, "OVERLAY")
        self.arrowTex:SetTexture(TEX .. "player-arrow.tga")
        self.arrowTex:FillParent()

        self.arrowFrame:SetScript("OnUpdate", function()
            local facing = GetPlayerFacing and GetPlayerFacing()
            if facing then
                local cos = math.cos(facing)
                local sin = math.sin(facing)
                local ULx, ULy = 0.5 + (sin - cos) * 0.5,  0.5 - (sin + cos) * 0.5
                local LLx, LLy = 0.5 - (sin + cos) * 0.5,  0.5 - (sin - cos) * 0.5
                local URx, URy = 0.5 + (sin + cos) * 0.5,  0.5 + (sin - cos) * 0.5
                local LRx, LRy = 0.5 - (sin - cos) * 0.5,  0.5 + (sin + cos) * 0.5
                self.arrowTex:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
            end
        end)
    end;

    SkinZoomButtons = function(self)
        local zoomIn = self.zoomIn
        zoomIn:SetParent(MUI_Minimap)
        zoomIn:ClearAllPoints()
        zoomIn:AlignParentBottomRight(42, 2)
        zoomIn:SetScale(0.37)
        zoomIn:SetNormalTexture(TEX .. "zoom-in")
        zoomIn:SetDisabledTexture(TEX .. "zoom-in-disabled")
        zoomIn:SetHighlightTexture(TEX .. "zoom-in-hover")
        zoomIn:SetPushedTexture(TEX .. "zoom-in-pressed")

        local zoomOut = self.zoomOut
        zoomOut:SetParent(MUI_Minimap)
        zoomOut:ClearAllPoints()
        zoomOut:Below(zoomIn, 0, -32)
        zoomOut:SetScale(0.37)
        zoomOut:SetNormalTexture(TEX .. "zoom-out")
        zoomOut:SetDisabledTexture(TEX .. "zoom-out-disabled")
        zoomOut:SetHighlightTexture(TEX .. "zoom-out-hover")
        zoomOut:SetPushedTexture(TEX .. "zoom-out-pressed")

        zoomIn:Hide()
        zoomOut:Hide()

        MUI_Minimap:SetScript("OnEnter", function()
            zoomIn:Show()
            zoomOut:Show()
        end)
        MUI_Minimap:SetScript("OnLeave", function()
            if not zoomIn:IsMouseOver() and not zoomOut:IsMouseOver() then
                zoomIn:Hide()
                zoomOut:Hide()
            end
        end)

        zoomIn:SetScript("OnLeave", function()
            if not MUI_Minimap:IsMouseOver() and not zoomOut:IsMouseOver() then
                zoomIn:Hide()
                zoomOut:Hide()
            end
        end)
        zoomOut:SetScript("OnLeave", function()
            if not MUI_Minimap:IsMouseOver() and not zoomIn:IsMouseOver() then
                zoomIn:Hide()
                zoomOut:Hide()
            end
        end)
    end;

    AddTopPanel = function(self)
        self.topPanel = Frame("Frame", MUI_Minimap, "MUI_MinimapTopPanel")
        self.topPanel:SetSize(130, 20)
        self.topPanel:Above(MUI_Minimap, 14, 4)

        self.topPanelBg = Texture(self.topPanel, nil, "BACKGROUND")
        self.topPanelBg:SetTexture(TEX .. "minimap-toppanel.tga")
        self.topPanelBg:AlignParentTopLeft()
        self.topPanelBg:AlignParentBottomRight()

        -- Time display
        self.timeFrame = Frame("Frame", self.topPanel, "MUI_MinimapTime")
        self.timeFrame:SetSize(40, 20)
        self.timeFrame:AlignParentTopRight(-0.5, -2)
        self.timeFrame:EnableMouse(true)

        self.timeText = FontString(self.timeFrame, nil, "OVERLAY")
        self.timeText:SetFont(MUI.FONT, 7, "")
        self.timeText:SetTextColor(1, 1, 1, 1)
        self.timeText:CenterInParent()

        -- Time update ticker
        local ticker = Frame("Frame", nil)
        ticker._tick = 0
        ticker:SetScript("OnUpdate", function()
            local now = GetTime()
            if ticker._tick > now then return end
            ticker._tick = now + 5
            self.timeText:SetText(date("%H:%M"))
        end)

        self.timeFrame:SetTooltip("ANCHOR_BOTTOMLEFT", function(tooltip)
            local hour, minute = GetGameTime()
            tooltip:AddLine("Time information", 1,1,1, false, 13)
            tooltip:AddDoubleLine("Local time:", date("%H:%M"),
                1, 0.82, 0,
                1, 1, 1,
                10.5
            )
            tooltip:AddDoubleLine("Server time:", string.format("%02d:%02d", hour, minute),
                1, 0.82, 0,
                1, 1, 1,
                10.5
            )
        end)

        local zoneText = FontString(MinimapZoneText)
        zoneText:SetParent(self.topPanel)
        zoneText:ClearAllPoints()
        zoneText:AlignLeft(self.topPanel, 8)
        zoneText:LeftOf(self.timeFrame)
        zoneText:SetJustifyH("LEFT")
        zoneText:SetFont(MUI.FONT, 8.5, "")

        --zoneText:SetTextColor(1, 0.82, 0, 1)
        --MinimapZoneText.SetTextColor = function() end

        local zoneBtn = SecureActionButton(self.topPanel, "MUI_MinimapZoneClick")
        zoneBtn:SetMacroText("/click WorldMapMicroButton")
        zoneBtn:AlignLeft(self.topPanel, 5)
        zoneBtn:LeftOf(self.timeFrame)
        zoneBtn:SetHeight(18)
        zoneBtn:SetTooltip("ANCHOR_BOTTOMLEFT", function(tooltip)

            tooltip:AddLine(GetZoneText() or "", 1, 1, 1, false, 13)

            local r, g, b = zoneText:GetTextColor()
            tooltip:AddLine(zoneText:GetText(), r, g, b, true, 10.5)

            local pvpType, _, factionName = C_PvP.GetZonePVPInfo()
            local territory
            
            if pvpType == "contested" then
                territory = "Contested"
            elseif (pvpType == "friendly" or pvpType == "hostile") and factionName and factionName ~= "" then
                territory = factionName
            end

            if territory then
                tooltip:AddLine("(" .. territory .. " Territory)", r, g, b, true, 10.5)
            end

            tooltip:AddLine("World map (M)", 1, 0.82, 0, true, 10.5)
        end)

    end;

    SkinMail = function(self)
        local mailFrame = Frame(MiniMapMailFrame)
        if not mailFrame then return end
        mailFrame:ClearAllPoints()
        mailFrame:Below(self.finder, -11, -1)
        mailFrame:SetFrameLevel(self.finder:GetFrameLevel() - 1)

        local mailIcon = Texture(MiniMapMailIcon)
        mailIcon:SetTexture(TEX .. "mail.tga")
        mailIcon:SetSize(22, 22)

        Frame(MiniMapMailBorder):HideFrame()
    end;

    SkinTracker = function(self)
        Frame(MiniMapTracking):Kill()
		
		self.finder = Frame("Frame", nil, "MUI_MinimapFinder")
        self.finder:LeftOf(self.topPanel, 0, 0.5)
        self.finder:SetSize(14, 16)

        self.finderBg = Texture(self.finder, nil, "BACKGROUND")
        self.finderBg:SetTexture(TEX .. "finder-bg.tga")
        self.finderBg:FillParent(0)

        self.finderTex = Texture(self.finder, nil, "OVERLAY")
        self.finderTex:SetTexture(TEX .. "finder-idle.tga")
        self.finderTex:FillParent(1)

        self.finder:EnableMouse(true)
        self.finder:SetScript("OnEnter", function()
            self.finderTex:SetTexture(TEX .. "finder-hover.tga")
        end)
        self.finder:SetScript("OnLeave", function()
            self.finderTex:SetTexture(TEX .. "finder-idle.tga")
        end)
        self.finder:SetScript("OnMouseUp", function() self.trackerMenu:Toggle() end)
		
        self.trackerMenu = MinimapTrackerMenu(nil, "MUI_MinimapTracker", self.finder)
    end;

    SkinDurability = function(self)
        if not DurabilityFrame then return end
        self.durability = EditableFrame(DurabilityFrame, "Durability")
        self.durability:ClearAllPoints()
        self.durability:Below(MUI_Minimap, 4)
        self.durability:AlignLeft(MUI_Minimap)
        self.durability:SetScale(0.7)
        self.durability:EditModeSetDefaultScale(0.7)   -- 0.7 is the default, not a user scale
        self.durability:EditModeSetDefaultPosition(function(d)
            d:ClearAllPoints()
            d:Below(MUI_Minimap, 4)
            d:AlignLeft(MUI_Minimap)
        end)

        -- Blizzard's UIParent_ManageFramePositions re-anchors DurabilityFrame to
        -- the minimap cluster on zone changes / panel toggles, overriding ours.
        -- Reclaim our (default or user-moved) layout after it runs.
        hooksecurefunc("UIParent_ManageFramePositions", function()
            MUI_EditMode:ReassertLayout(self.durability)
        end)
    end;

    -- Collapsible bin for third-party minimap buttons. A toggle on the left of
    -- the minimap expands a grid (to its right) of every addon button we've
    -- swept off the minimap edge.
    AddButtonBin = function(self)
        local ARROW = MUI.TEX_SKIN .. "bags\\expand"

        self._binButtons = {}   -- collected button wrappers, in insertion order
        self._binSeen    = {}   -- dedup by frame name

        self.binToggle = Button(MUI_Root, "MUI_MinimapBinToggle")
        self.binToggle:SetSize(16, 16)
        self.binToggle:SetFrameStrata("HIGH")
        self.binToggle:LeftOf(MUI_Minimap, 6, 0)
        self.binToggle:SetNormalTexture(ARROW)
        self.binToggle:SetHighlightTexture(ARROW)
        self.binToggle:SetPushedTexture(ARROW)
        self:SetBinToggleArrow(false)
        self.binToggle:Hide()
        self.binToggle.OnClick = function() self:ToggleBin() end
        self.binToggle:SetTooltip("ANCHOR_LEFT", function(tooltip)
            tooltip:AddLine("Addon Buttons", 1, 1, 1, false, 13)
            tooltip:AddLine("Collected minimap buttons.", 1, 0.82, 0, true, 10.5)
        end)

        -- Bin grows to the LEFT of the toggle, into the empty space beside the
        -- minimap (its right edge is pinned to the toggle). A DiamondBorder panel
        -- (own border + dark centre) at MEDIUM strata — the SAME strata the addons
        -- pin the collected buttons to — so the buttons, reparented in at a higher
        -- frame level, render above the panel via normal child ordering, while the
        -- panel (frame level 6) sits above lower MEDIUM neighbours like the debuff
        -- bar. Mouse-enabled so gaps don't click through.
        self.bin = DiamondBorder(MUI_Root, "MUI_MinimapBin")
        self.bin:SetFrameStrata("MEDIUM")
        self.bin:SetFrameLevel(6)
        self.bin:EnableMouse(true)
        self.bin:LeftOf(self.binToggle, 4)
        self.bin:SetSize(24 + BIN_MARGIN * 2, 24 + BIN_MARGIN * 2)
        self.bin:Hide()

        self.binContent = Frame("Frame", self.bin, "MUI_MinimapBinContent")
        self.binContent:FillParent()

        -- Live capture of LibDBIcon buttons created later (no polling).
        local LDB = LibStub and LibStub("LibDBIcon-1.0", true)
        if LDB and LDB.RegisterCallback then
            LDB.RegisterCallback(self, "LibDBIcon_IconCreated", function(_, button)
                self:AddBinButton(Frame(button))
                self:LayoutBin()
            end)
        end

        -- Gather what exists now, plus two one-shot follow-ups for addons that
        -- build their button during / just after login (Questie, etc.). This is
        -- NOT a poll — afterwards it's event-driven (above) and on-open (ToggleBin).
        local function sweep ()
            self:CollectBinButtons()
            self:LayoutBin()
        end
        sweep()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, sweep)
            C_Timer.After(1, sweep)
        end
    end;

    -- Pull from LibDBIcon's registry (authoritative for the rotatable settings
    -- buttons) plus a name-heuristic scan of the minimap's own children, for
    -- buttons that don't use the library.
    CollectBinButtons = function(self)
        local LDB = LibStub and LibStub("LibDBIcon-1.0", true)
        if LDB and LDB.GetButtonList then
            for _, name in ipairs(LDB:GetButtonList()) do
                self:AddBinButton(Frame(LDB:GetMinimapButton(name)))
            end
        end

        local sources = { MUI_Minimap }
        if MinimapBackdrop then table.insert(sources, Frame(MinimapBackdrop)) end
        for _, src in ipairs(sources) do
            for _, w in ipairs(src:GetChildren()) do
                if isBinButtonName(w:GetName()) then
                    self:AddBinButton(w)
                end
            end
        end
    end;

    AddBinButton = function(self, w)
        if not w then return end
        local name = w:GetName()
        if name then
            if self._binSeen[name] then return end
            self._binSeen[name] = true
        end
        w:SetParent(self.binContent)
        w:SetScale(1)
        w:NeutralizeLayout()   -- block the addon's own setters; we drive it raw
        table.insert(self._binButtons, w)
    end;

    LayoutBin = function(self)
        -- Only currently-shown buttons take a slot; the grid re-flows each open.
        local shown = {}
        for _, w in ipairs(self._binButtons) do
            if w:IsShown() then table.insert(shown, w) end
        end

        local n = #shown
        if n > 0 then self.binToggle:Show() else self.binToggle:Hide() end
        if n == 0 then return end

        -- Cell = the largest collected button, so differently-sized buttons share
        -- a uniform grid without overlapping.
        local cell = 0
        for _, w in ipairs(shown) do
            cell = math.max(cell, w:GetWidth() or 0, w:GetHeight() or 0)
        end
        if cell <= 0 then cell = 24 end

        -- Restrata each button to the bin's strata (MEDIUM — what the addon pins
        -- them to anyway, so no fight) at a level above the panel's border/bg, then
        -- position it. All via the raw C methods, which bypass the buttons' own
        -- locked setters.
        local btnLevel = self.bin:GetFrameLevel() + 5
        for i, w in ipairs(shown) do
            local idx = i - 1
            local col = idx % BIN_PER_ROW
            local row = math.floor(idx / BIN_PER_ROW)
            local x = BIN_MARGIN + col * (cell + BIN_PAD) + cell / 2
            local y = BIN_MARGIN + row * (cell + BIN_PAD) + cell / 2
            w:RawSetDrawOrder("MEDIUM", btnLevel)
            -- Top-right origin → button 1 next to the toggle, grid fills leftward.
            w:RawSetPoint("CENTER", self.binContent, "TOPRIGHT", -x, -y)
        end

        local cols = math.min(n, BIN_PER_ROW)
        local rows = math.ceil(n / BIN_PER_ROW)
        self.bin:SetSize(
            BIN_MARGIN * 2 + cols * cell + (cols - 1) * BIN_PAD,
            BIN_MARGIN * 2 + rows * cell + (rows - 1) * BIN_PAD)
    end;

    ToggleBin = function(self)
        if self.bin:IsShown() then
            self.bin:Hide()
            self:SetBinToggleArrow(false)
        else
            self:CollectBinButtons()
            self:LayoutBin()
            self.bin:Show()
            self:SetBinToggleArrow(true)
        end
    end;

    -- Mirror the expand arrow horizontally. Matches the bags toggle convention
    -- for a left-fanning bin: identity when open, flipped when closed.
    SetBinToggleArrow = function(self, open)
        local l, r = (open and 0 or 1), (open and 1 or 0)
        local n = self.binToggle:GetNormalTexture()
        local h = self.binToggle:GetHighlightTexture()
        local p = self.binToggle:GetPushedTexture()
        if n then n:SetTexCoord(l, r, 0, 1) end
        if h then h:SetTexCoord(l, r, 0, 1) end
        if p then p:SetTexCoord(l, r, 0, 1) end
    end;
}
