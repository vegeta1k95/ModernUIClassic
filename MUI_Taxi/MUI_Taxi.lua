-- MUI_Taxi: the flight master's map — Era's TaxiFrame in the window the other
-- panels have, half as large again, with retail's flight points on it.
--
-- Era's TaxiFrame stays the real panel: the panel manager opens it at a
-- flight master, Escape and walking away close it, and its OnShow fills the
-- map and places the nodes. This window is its child and covers it. Era's
-- map texture (SetTaxiMap paints it on every visit) and the node buttons
-- Era creates are moved onto a stage of ours drawn at one and a half times
-- their size. Era places the nodes on the map texture in the map's own
-- 316x352 units, so on the scaled stage everything still lines up.
--
-- The nodes stay Era's buttons: their click takes the flight and their
-- tooltip is Era's. They wear retail's winged boots (green where you are,
-- grey where you can fly, yellow under the cursor, a stud where you
-- cannot) instead of Era's 16 px dots. The routes are drawn again as lines
-- between the nodes; Era's own, rotated quads of the same art on its route
-- layer, are hidden with that layer.
--
-- The map itself is Era's: retail's versions of the continent maps are the
-- same 512 px and show the world after the Cataclysm.

-- The panel manager puts Era's frame 16 px left of and 12 px above where a
-- window's art begins: its classic art has that much empty margin.
local NATIVE_DX, NATIVE_DY = 16, 12
-- Era's TAXI_MAP_WIDTH / TAXI_MAP_HEIGHT: the units its nodes are placed in.
local MAP_W, MAP_H = 316, 352
local MAP_SCALE = 1.5
-- The map fills the window's body, under the title bar.
local FRAME_W = MAP_W * MAP_SCALE + 6
local FRAME_H = MAP_H * MAP_SCALE + 21

-- Retail's TaxiAssets sheet (128x512): the boots are 74x74 at x = 1.
local SHEET = MUI.TEX_SKIN .. "taxi\\taxi-assets"
local BOOT_GREY, BOOT_GREEN, BOOT_YELLOW = 35, 111, 187

local ROUTE_ART = "Interface\\TaxiFrame\\UI-Taxi-Line"
local ROUTE_THICKNESS = 28

-- How each kind of node (TaxiNodeGetType) is drawn, as retail's flight map
-- does: the boot's row on the sheet (none: the small stud of a node there
-- is no way to, or of one only flown over) and its size on the map, which
-- is retail's 28 / 20 / 14 on a stage half as large again.
local LOOKS = {
    CURRENT     = { boot = BOOT_GREEN, size = 18 },
    REACHABLE   = { boot = BOOT_GREY,  size = 14, hover = BOOT_YELLOW },
    UNREACHABLE = { size = 10 },
    DISTANT     = { size = 8 },
}

-- ---------------------------------------------------------------------
-- TaxiNodeButton: one of Era's TaxiButton<i> buttons, in retail's art.
-- ---------------------------------------------------------------------
class "TaxiNodeButton" : extends "Button" {
    __init = function(self, index, window, layer)
        Button.__init(self, getglobal("TaxiButton" .. index))
        self.index = index
        self.kind = nil           -- TaxiNodeGetType, as of the last Update

        -- Onto the stage. TaxiButtonTemplate names TaxiFrame as the parent,
        -- which leaves a node under this window and at the frame's own
        -- scale: Era's offsets from the map's corner then fall short.
        self:SetParent(layer)
        self:PutInfront(layer, 1)

        self._icon = Texture(self, nil, "ARTWORK")
        self._icon:CenterInParent()
        self._glow = Texture(self, nil, "HIGHLIGHT")
        self._glow:SetBlendMode("ADD")
        self._glow:SetAlpha(0.25)
        self._glow:Fill(self._icon)

        -- After Era's own handlers, which draw its routes and the tooltip.
        self:HookScript("OnEnter", function()
            self:Update(true)
            window:OnNodeEnter(self)
        end)
        self:HookScript("OnLeave", function()
            self:Update(false)
            window:OnNodeLeave(self)
        end)
    end;

    -- Era sets its dot and its highlight again whenever the map opens or
    -- the cursor crosses the node; they are kept transparent.
    Update = function(self, hovered)
        local dot = self:GetNormalTexture()
        if dot then dot:SetAlpha(0) end
        self:GetHighlightTexture():SetAlpha(0)

        self.kind = TaxiNodeGetType(self.index)
        local look = LOOKS[self.kind]
        if not look then return end

        if look.boot then
            local row = hovered and look.hover or look.boot
            self._icon:SetTextureRegion(SHEET, 128, 512, 1, row, 74, 74)
            self._glow:SetTextureRegion(SHEET, 128, 512, 1, row, 74, 74)
        else
            self._icon:SetTextureRegion(SHEET, 128, 512, 77, 35, 16, 16)
            self._glow:SetTextureRegion(SHEET, 128, 512, 77, 35, 16, 16)
        end
        self._icon:SetSize(look.size, look.size)
        -- A node there is no way to from here turns red under the cursor,
        -- as Era's dot does.
        if hovered and self.kind == "UNREACHABLE" then
            self._icon:SetVertexColor(1, 0.25, 0.25)
        else
            self._icon:SetVertexColor(1, 1, 1)
        end
    end;
}

-- ---------------------------------------------------------------------
-- TaxiWindow
-- ---------------------------------------------------------------------
class "TaxiWindow" : extends "PanelPortrait" {
    __init = function(self)
        self._blizzard = Frame(TaxiFrame)
        PanelPortrait.__init(self, self._blizzard, "MUI_TaxiFrame", "Flight Map")
        self:FillParentPadding(NATIVE_DX, NATIVE_DY, 0, 0)
        self._nodes = {}          -- by Era's node index
        self._routes = {}         -- the lines, reused

        self:_BuildStage()

        -- Nothing else of Era's frame shows or takes the mouse; this window does.
        self._blizzard:HideAllRegions()
        self._blizzard:EnableMouse(false)
        self:_SkinCloseButton()

        self._blizzard:SetSize(NATIVE_DX + FRAME_W, NATIVE_DY + FRAME_H)
        self._blizzard:HookScript("OnShow", function() self:_OnOpen() end)
    end;

    -- Era's close button, where and how the other windows have theirs. Its
    -- own click closes the panel through the panel manager, which ends the
    -- visit.
    _SkinCloseButton = function(self)
        local close = Button(TaxiCloseButton)
        local atlas = MUI_AtlasRegistry.ButtonRedControl
        close:SetStateAtlas(atlas, "ExitNormal", "ExitPressed", "ExitDisabled")
        close:SetHighlightAtlas(atlas, "Highlight", true)
        close:SetSize(23, 24.5)
        close:SetScale(0.9)
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0.5, 2)
        close:PutInfront(self._border, 1)
    end;

    -- The stage: Era's map texture, our routes over it, Era's node buttons
    -- over those, all at MAP_SCALE; and the recessed border around the lot.
    _BuildStage = function(self)
        local stage = Frame("Frame", self)
        stage:SetScale(MAP_SCALE)
        stage:SetSize(MAP_W, MAP_H)
        stage:AnchorToTopOf(self._content)
        stage:PutInfront(self._content, 1)

        local map = Texture(TaxiMap)
        map:SetParent(stage)
        map:ClearAllPoints()
        map:FillParent()

        self._routeFrame = Frame("Frame", stage)
        self._routeFrame:FillParent()

        self._nodeLayer = Frame("Frame", stage)
        self._nodeLayer:FillParent()
        self._nodeLayer:PutInfront(self._routeFrame, 1)

        -- Era's route layer: its routes are drawn by ours.
        Frame(TaxiRouteMap):Hide()

        local edge = Frame("Frame", self)
        edge:Fill(self._content)
        edge:PutInfront(self._nodeLayer, 3)
        InnerBorder(edge):FillParent()
    end;

    -- A visit starts: Era's OnShow has just painted the map and placed the
    -- nodes.
    _OnOpen = function(self)
        self:SetPortraitFromUnit("npc")
        for index = 1, NumTaxiNodes() do
            local node = self._nodes[index]
            if not node then
                node = TaxiNodeButton(index, self, self._nodeLayer)
                self._nodes[index] = node
            end
            node:Update(false)
        end
        self:_ShowDirectRoutes()
        self:_FitPanel()
    end;

    -- Era's panel entry carries the classic frame's width and height, which
    -- the manager places panels by. They are replaced once the manager has
    -- set the frame up, and the panels laid out again.
    _FitPanel = function(self)
        if self._fitted or not self._blizzard:GetAttribute("UIPanelLayout-defined") then return end
        self._fitted = true
        self._blizzard:SetAttribute("UIPanelLayout-width", NATIVE_DX + FRAME_W)
        self._blizzard:SetAttribute("UIPanelLayout-height", NATIVE_DY + FRAME_H)
        if not InCombatLockdown() then
            UpdateUIPanelPositions(TaxiFrame)
        end
    end;

    -- ---- routes --------------------------------------------------------

    -- Line number `used` of the map, from one node to another.
    _Connect = function(self, used, from, to)
        local line = self._routes[used]
        if not line then
            line = Line(self._routeFrame, nil, "ARTWORK")
            line:SetTexture(ROUTE_ART, "REPEAT")
            line:SetThickness(ROUTE_THICKNESS)
            self._routes[used] = line
        end
        line:SetStartPoint("CENTER", self._nodes[from])
        line:SetEndPoint("CENTER", self._nodes[to])
        line:Show()
    end;

    -- Keep the first `used` lines.
    _TrimRoutes = function(self, used)
        for i = used + 1, #self._routes do
            self._routes[i]:Hide()
        end
    end;

    -- Every flight that is one hop from here, as Era's DrawOneHopLines
    -- shows them; the nodes only flown over go back out of sight.
    _ShowDirectRoutes = function(self)
        local used = 0
        for index = 1, NumTaxiNodes() do
            local kind = TaxiNodeGetType(index)
            if kind == "REACHABLE" and TaxiIsDirectFlight(index) then
                used = used + 1
                self:_Connect(used, TaxiGetNodeSlot(index, 1, true), TaxiGetNodeSlot(index, 1, false))
            elseif kind == "DISTANT" then
                self._nodes[index]:Hide()
            end
        end
        self:_TrimRoutes(used)
    end;

    -- The way to a node, hop by hop.
    _ShowRouteTo = function(self, index)
        local hops = GetNumRoutes(index)
        for hop = 1, hops do
            self:_Connect(hop, TaxiGetNodeSlot(index, hop, true), TaxiGetNodeSlot(index, hop, false))
        end
        self:_TrimRoutes(hops)
    end;

    -- The cursor came onto a node: the way there, if there is one.
    OnNodeEnter = function(self, node)
        if node.kind == "REACHABLE" then
            self:_ShowRouteTo(node.index)
        elseif node.kind == "CURRENT" then
            self:_ShowDirectRoutes()
        elseif node.kind == "UNREACHABLE" then
            self:_TrimRoutes(0)
        end
    end;

    -- The cursor left a node, which also happens when taking the flight
    -- closes the map under it.
    OnNodeLeave = function(self, node)
        if node.kind ~= "DISTANT" and self:IsVisible() then
            self:_ShowDirectRoutes()
        end
    end;
}

object "ModuleTaxi" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Taxi")
    end;

    OnEnable = function(self)
        self.window = TaxiWindow()
    end;
}
