-- MUI_CollectionsMountDisplay: the mount on show, right of the list — the
-- creature against retail's journal backdrop, and over its top left corner
-- the mount's icon and name, where it comes from and retail's line about it
-- (retail's MountJournal.MountDisplay).
--
-- Retail frames a mount with a model scene. Here it is a plain model with a
-- camera placed per mount: a distance and an eye height worked out from the
-- size of its model (tools/mounts_export.py) and kept with the mount. The
-- camera puts the mount in the middle of the model's frame, so the frame is
-- the pane under the lines about the mount, not all of it as retail's. Drag
-- turns the mount, the wheel moves the camera in and out.
--
--   CollectionsMountDisplay(parent)     fills an inset frame
--     :SetMount(mount)                  nil: nothing to show
--     :Reset()                          the model back as it first stood

local Style = MUI_CollectionsStyle

local FACING = -0.6                -- three quarters on, its head to the left
local ZOOM_MIN, ZOOM_MAX, ZOOM_STEP = 0.5, 2.0, 0.1
local TURN_PER_PIXEL = 0.01
local TEXT_W = 345
local MODEL_TOP = 100              -- the model's frame, from the pane's top

-- ---------------------------------------------------------------------
-- CollectionsMountModel: a mount's creature, turned by a drag.
-- ---------------------------------------------------------------------
class "CollectionsMountModel" : extends "PlayerModel" {
    __init = function(self, parent)
        PlayerModel.__init(self, parent)
        self._mount  = nil
        self._loaded = false           -- the model's file is in
        self._zoom, self._facing = 1, FACING

        -- The camera can only be placed once the model's file is in.
        self:SetScript("OnModelLoaded", function()
            self._loaded = true
            self:MakeCurrentCameraCustom()
            self:_PlaceCamera()
            self:SetFacing(self._facing)
        end)

        self:EnableMouse(true)
        self:EnableMouseWheel(true)
        self:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" then self._turnFrom = GetCursorPosition() end
        end)
        self:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then self._turnFrom = nil end
        end)
        self:SetScript("OnMouseWheel", function(_, delta)
            self._zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, self._zoom - delta * ZOOM_STEP))
            self:_PlaceCamera()
        end)
        self:SetScript("OnUpdate", function()
            if not self._turnFrom then return end
            local x = GetCursorPosition()
            self._facing = self._facing + (x - self._turnFrom) * TURN_PER_PIXEL
            self._turnFrom = x
            self:SetFacing(self._facing)
        end)
        -- A hidden model comes back empty: it is loaded again each time it shows.
        self:SetScript("OnShow", function() self:_Load() end)
        self:SetScript("OnHide", function() self._turnFrom = nil end)
    end;

    SetMount = function(self, mount)
        self._mount = mount
        self._zoom, self._facing = 1, FACING
        if self:IsVisible() then self:_Load() end
    end;

    Reset = function(self)
        self._zoom, self._facing = 1, FACING
        if self._loaded then
            self:_PlaceCamera()
            self:SetFacing(self._facing)
        end
    end;

    _Load = function(self)
        self._loaded = false
        self:ClearModel()
        if self._mount then self:SetDisplayInfo(self._mount.display) end
    end;

    -- Level with the mount at its eye height, `dist` in front of it.
    _PlaceCamera = function(self)
        if not self._loaded or not self:HasCustomCamera() then return end
        local mount = self._mount
        self:SetCameraPosition(mount.dist * self._zoom, 0, mount.eye)
        self:SetCameraTarget(0, 0, mount.eye)
    end;
}

-- ---------------------------------------------------------------------
-- CollectionsMountDisplay
-- ---------------------------------------------------------------------
class "CollectionsMountDisplay" : extends "Frame" {
    __init = function(self, parent)
        Frame.__init(self, "Frame", parent)
        self:FillParent(3)

        local wall = Texture(self, nil, "BACKGROUND")
        wall:SetTexture(Style.ART .. "mounts-bg")
        wall:SetTexCoord(0, 0.78515625, 0, 1)
        wall:FillParent()

        self._model = CollectionsMountModel(self)
        self._model:FillParentPadding(0, MODEL_TOP, 0, 0)

        -- Over the model: the shadow round the pane's edges, then what the
        -- mount is.
        local shadow = Frame("Frame", self, "MUI_CollectionsMountShadow", "ShadowOverlayTemplate")
        shadow:FillParent()
        shadow:PutInfront(self._model, 1)

        local over = Frame("Frame", self)
        over:FillParent()
        over:PutInfront(self._model, 2)
        self._over = over

        self._icon = Texture(over, nil, "BORDER")
        self._icon:SetSize(38, 38)
        self._icon:AlignParentTopLeft(30, 26)

        self._name = Style:Label(over, 16, 1, 1, 1)
        self._name:SetJustifyH("LEFT")
        self._name:SetJustifyV("MIDDLE")
        self._name:SetSize(270, 35)
        self._name:SetMaxLines(2)
        self._name:RightOf(self._icon, 10)

        self._source = Style:Label(over, 12, 1, 1, 1)
        self._source:SetJustifyH("LEFT")
        self._source:SetWidth(TEXT_W)
        self._source:AlignParentTopLeft(74, 26)

        self._lore = Style:Label(over, 12, 1, 0.82, 0)
        self._lore:SetJustifyH("LEFT")
        self._lore:SetWidth(TEXT_W)
        self._lore:Below(self._source, 12)
    end;

    SetMount = function(self, mount)
        self._over:SetVisible(mount ~= nil)
        self._model:SetMount(mount)
        if not mount then return end
        self._icon:SetTexture(MUI_MountDB:GetIcon(mount))
        self._name:SetText(mount.name)
        self._source:SetText(self:_Source(mount))
        self._lore:SetText(mount.lore)
    end;

    Reset = function(self)
        self._model:Reset()
    end;

    -- Where a mount comes from, a label and what it names to the line as
    -- retail writes them. The labels are the client's own.
    _Source = function(self, mount)
        local lines = {}
        local function line(label, value)
            lines[#lines + 1] = "|cffffd200" .. label .. "|r " .. value
        end
        if mount.class then
            line(CLASS .. ":", LOCALIZED_CLASS_NAMES_MALE[mount.class])
        elseif mount.vendor then
            line(BATTLE_PET_SOURCE_3 .. ":", mount.vendor)
        elseif mount.drop then
            line(BATTLE_PET_SOURCE_1 .. ":", mount.drop)
        else
            line(SOURCE, mount.quest and BATTLE_PET_SOURCE_2 or BATTLE_PET_SOURCE_1)
        end
        local area = mount.area and C_Map.GetAreaInfo(mount.area)
        if area then line(ZONE_COLON, area) end
        if mount.cost then line(COSTS_LABEL, C_CurrencyInfo.GetCoinTextureString(mount.cost)) end
        return table.concat(lines, "\n")
    end;
}
