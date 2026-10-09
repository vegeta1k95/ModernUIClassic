-- MUI_AdventureGuideModel: the journal's model page — a boss's creatures in
-- 3D over the instance's backdrop, in the paper frame, a round button for
-- each down the left (retail's model scene and creature buttons).
--
-- Retail frames a creature with a model scene, which fits any size to the
-- view by itself. Here it is a plain model with a camera placed per creature:
-- a distance and an eye height worked out from the size of its model
-- (tools/encounterjournal_export.py) and kept in the journal data. Drag
-- turns the creature, the wheel moves the camera in and out.
--
--   AdventureGuideModel(parent)
--     :SetBackdrop(instance)
--     :SetCreatures(creatures, shown)   { { name, display, dist?, eye? }, ... };
--                                       `shown`: the one to start on (the first)
--     :ShowCreature(creature)           one of the list

local Style = MUI_AdventureGuideStyle

local PANE_W, PANE_H = 390, 423

-- For a creature the data has no camera for: a man-sized one's.
local DEFAULT_DIST, DEFAULT_EYE = 3, 0.5
local ZOOM_MIN, ZOOM_MAX, ZOOM_STEP = 0.5, 2.0, 0.1
local TURN_PER_PIXEL = 0.01

-- ---------------------------------------------------------------------
-- AdventureGuideCreatureButton: a creature's portrait in the journal's ring
-- (EncounterCreatureButtonTemplate); the one on show is drawn larger.
-- ---------------------------------------------------------------------
class "AdventureGuideCreatureButton" : extends "Button" {
    __init = function(self, parent, owner)
        Button.__init(self, parent)
        self:SetClickSound(SOUNDKIT.IG_MAINMENU_OPTION)
        self.creature = nil

        self._face = Texture(self, nil, "BACKGROUND")
        self._face:SetDrawLayer("BACKGROUND", 6)
        self._face:CenterInParent()

        Style:SetPiece(self:SetNormalTexture(Style.ART .. "journal"), "BossModelButton", true)
        local glow = self:SetHighlightTexture(Style.ART .. "journal")
        Style:SetPiece(glow, "BossModelButton", true)
        glow:SetBlendMode("ADD")

        self:SetTooltip("ANCHOR_RIGHT", function(tip)
            tip:AddLine(self.creature.name, 1, 1, 1, false, 13)
        end)
        self.OnClick = function() owner:ShowCreature(self.creature) end
        self:SetSelected(false)
    end;

    SetCreature = function(self, creature)
        self.creature = creature
        self._face:SetPortraitFromCreatureDisplayID(creature.display)
    end;

    SetSelected = function(self, selected)
        if selected then
            self:SetSize(64, 61)
            self._face:SetSize(40, 40)
        else
            self:SetSize(50, 49)
            self._face:SetSize(36, 36)
        end
    end;
}


class "AdventureGuideModel" : extends "Frame" {
    __init = function(self, parent)
        Frame.__init(self, "Frame", parent)
        self:SetSize(PANE_W, PANE_H)
        self._creatures = {}
        self._shown = nil             -- the creature on show
        self._loaded = false          -- its model file is in
        self._zoom = 1
        self._facing = 0
        self._buttons = {}

        self._backdrop = Texture(self, nil, "BACKGROUND")
        self._backdrop:SetSize(394, 425)
        self._backdrop:AlignParentBottomLeft(-2, 0)

        self:_BuildModel()

        -- Over the model: the paper frame, the name on its shadow.
        local front = Frame("Frame", self)
        front:FillParent()
        front:PutInfront(self._model, 1)
        self._front = front

        local paper = Texture(front, nil, "ARTWORK")
        paper:SetTexture(Style.ART .. "model-frame")
        paper:SetTexCoord(0.767578125, 0, 0, 0.828125)
        paper:SetSize(393, 424)
        paper:AlignParentBottomRight(0, -3)

        local shadow = Style:Piece(front, "OVERLAY", "BossNameShadow")
        shadow:AlignParentBottom(-2)

        self._name = Style:Title(front, 18)
        self._name:SetDrawLayer("OVERLAY", 2)
        self._name:SetSize(380, 18)
        self._name:AlignParentBottom(2)

        -- A hidden model comes back empty: it is loaded again each time the
        -- page shows.
        self:SetScript("OnShow", function() self:_Load() end)
    end;

    _BuildModel = function(self)
        local model = PlayerModel(self)
        model:FillParent()
        self._model = model

        -- The camera can only be placed once the model's file is in.
        model:SetScript("OnModelLoaded", function()
            self._loaded = true
            model:MakeCurrentCameraCustom()
            self:_PlaceCamera()
            model:SetFacing(self._facing)
        end)

        model:EnableMouse(true)
        model:SetScript("OnMouseDown", function(_, button)
            if button ~= "LeftButton" then return end
            self._dragFrom = GetCursorPosition()
            self._dragFacing = self._facing
        end)
        model:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then self._dragFrom = nil end
        end)
        model:SetScript("OnHide", function() self._dragFrom = nil end)
        model:SetScript("OnUpdate", function()
            if not self._dragFrom then return end
            self._facing = self._dragFacing + (GetCursorPosition() - self._dragFrom) * TURN_PER_PIXEL
            model:SetFacing(self._facing)
        end)

        model:EnableMouseWheel(true)
        model:SetScript("OnMouseWheel", function(_, delta)
            self._zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, self._zoom - delta * ZOOM_STEP))
            self:_PlaceCamera()
        end)
    end;

    -- Level with the creature at its eye height, `dist` in front of it.
    _PlaceCamera = function(self)
        if not self._loaded or not self._model:HasCustomCamera() then return end
        local creature = self._shown
        local eye = creature.eye or DEFAULT_EYE
        self._model:SetCameraPosition((creature.dist or DEFAULT_DIST) * self._zoom, 0, eye)
        self._model:SetCameraTarget(0, 0, eye)
    end;

    _Load = function(self)
        self._loaded = false
        self._model:ClearModel()
        if self._shown then self._model:SetDisplayInfo(self._shown.display) end
    end;

    SetBackdrop = function(self, instance)
        self._backdrop:SetTexture(Style:InstanceArt("backdrops", instance.bg))
        self._backdrop:SetTexCoord(0.76953125, 0, 0, 0.830078125)
    end;

    SetCreatures = function(self, creatures, shown)
        self._creatures = creatures
        for i, creature in ipairs(creatures) do
            local button = self._buttons[i]
            if not button then
                button = AdventureGuideCreatureButton(self._front, self)
                if i == 1 then
                    button:AlignParentTopLeft(35, 3)
                else
                    button:Below(self._buttons[i - 1], -8)
                end
                self._buttons[i] = button
            end
            button:SetCreature(creature)
            button:Show()
        end
        for i = #creatures + 1, #self._buttons do
            self._buttons[i]:Hide()
        end
        self:ShowCreature(shown or creatures[1])
    end;

    ShowCreature = function(self, creature)
        self._shown = creature
        self._zoom, self._facing = 1, 0
        self._name:SetText(creature.name)
        for i, button in ipairs(self._buttons) do
            button:SetSelected(self._creatures[i] == creature)
        end
        if self:IsVisible() then self:_Load() end
    end;
}
