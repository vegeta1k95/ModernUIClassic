-- MUI_AdventureGuideStyle: what the Adventure Guide's pages share — the art
-- folder, labels, the pieces of retail's journal sheets.

local ART   = MUI.TEX_SKIN .. "adventureguide\\"
local SHEET = ART .. "journal"          -- 512x1024
local TILE  = ART .. "journal-tile"     -- 64x512, bands that repeat sideways

-- Pieces of the journal sheet, as retail's Blizzard_EncounterJournal.xml and
-- SharedUIPanelTemplates.xml cut them: width, height, left, right, top, bottom.
local PIECES = {
    ["DungeonButton-Up"]              = { 174, 96, 0.00195313, 0.34179688, 0.42871094, 0.52246094 },
    ["DungeonButton-Down"]            = { 174, 96, 0.00195313, 0.34179688, 0.33300781, 0.42675781 },
    ["DungeonButton-Highlight"]       = { 174, 96, 0.34570313, 0.68554688, 0.33300781, 0.42675781 },
    ["DungeonNameBg"]                 = { 256, 64, 0.34570313, 0.84570313, 0.42871094, 0.49121094 },
    ["ShowMapBG"]                     = { 171, 50, 0.00195313, 0.33593750, 0.85253906, 0.90136719 },
    ["LeftPageHeader"]                = { 386, 39, 0.00000000, 0.75585938, 0.95996094, 1.00000000 },
    ["RightPageHeader"]               = { 386, 39, 0.75585938, 0.00000000, 0.95996094, 1.00000000 },
    ["BossModelButton"]               = { 64, 61, 0.50585938, 0.63085938, 0.02246094, 0.08203125 },
    ["CreatureHeaderFrameSm"]         = { 45, 44, 0.72656250, 0.81445313, 0.02246094, 0.06542969 },
    ["BossButton-Up"]                 = { 325, 55, 0.00195313, 0.63671875, 0.21386719, 0.26757813 },
    ["BossButton-Down"]               = { 325, 55, 0.00195313, 0.63671875, 0.10253906, 0.15625000 },
    ["BossButton-Highlight"]          = { 325, 55, 0.00195313, 0.63671875, 0.15820313, 0.21191406 },
    ["BossNameShadow"]                = { 395, 63, 0.00195313, 0.77343750, 0.26953125, 0.33105469 },
    ["Tab-UnSelected"]                = { 63, 57, 0.25585938, 0.37890625, 0.90332031, 0.95898438 },
    ["Tab-Selected"]                  = { 63, 57, 0.12890625, 0.25195313, 0.90332031, 0.95898438 },
    ["Tab-Highlight"]                 = { 63, 57, 0.00195313, 0.12500000, 0.90332031, 0.95898438 },
    ["Tab-BossIcon-Selected"]         = { 48, 43, 0.90234375, 0.99609375, 0.26953125, 0.31152344 },
    ["Tab-BossIcon-UnSelected"]       = { 48, 43, 0.85546875, 0.94921875, 0.52441406, 0.56640625 },
    ["Tab-LootIcon-Selected"]         = { 48, 43, 0.63281250, 0.72656250, 0.61816406, 0.66015625 },
    ["Tab-LootIcon-UnSelected"]       = { 48, 43, 0.73046875, 0.82421875, 0.61816406, 0.66015625 },
    ["Tab-ModelIcon-Selected"]        = { 48, 43, 0.80468750, 0.90039063, 0.66210938, 0.70507813 },
    ["Tab-ModelIcon-UnSelected"]      = { 48, 43, 0.90234375, 1.00000000, 0.66210938, 0.70507813 },
    ["LootFrame"]                     = { 321, 45, 0.00195313, 0.62890625, 0.61816406, 0.66210938 },
    ["DungeonLootFrame"]              = { 369, 64, 0.00195313, 0.72265625, 0.52441406, 0.58691406 },
    ["PaperHeader-UnSelectUp-Left"]   = { 64, 29, 0.84960938, 0.97460938, 0.49023438, 0.51855469 },
    ["PaperHeader-UnSelectUp-Right"]  = { 64, 29, 0.72656250, 0.85156250, 0.52441406, 0.55273438 },
    ["PaperHeader-UnSelectDown-Left"] = { 64, 29, 0.47460938, 0.59960938, 0.49316406, 0.52148438 },
    ["PaperHeader-UnSelectDown-Right"] = { 64, 29, 0.60351563, 0.72851563, 0.49316406, 0.52148438 },
    ["PaperHeader-SelectUp-Left"]     = { 64, 29, 0.81445313, 0.93945313, 0.39453125, 0.42285156 },
    ["PaperHeader-SelectUp-Right"]    = { 64, 29, 0.34570313, 0.47070313, 0.49316406, 0.52148438 },
    ["PaperHeader-SelectDown-Left"]   = { 64, 29, 0.64062500, 0.76562500, 0.21386719, 0.24218750 },
    ["PaperHeader-SelectDown-Right"]  = { 64, 29, 0.76953125, 0.89453125, 0.21386719, 0.24218750 },
    ["PaperHeader-Highlight-Left"]    = { 64, 29, 0.74218750, 0.86718750, 0.15820313, 0.18652344 },
    ["PaperHeader-Highlight-Right"]   = { 64, 29, 0.87109375, 0.99609375, 0.15820313, 0.18652344 },
    ["AbilityTextBG"]                 = { 256, 80, 0.00195313, 0.50195313, 0.02246094, 0.10058594 },
    ["AbilityTextBottomBorder"]       = { 243, 9, 0.04492188, 0.51953125, 0.00097656, 0.00976563 },
}

-- Bands of the tile sheet: height, top, bottom.
local BANDS = {
    ["PaperHeader-UnSelectUp-Mid"]   = { 29, 0.34375000, 0.40039063 },
    ["PaperHeader-UnSelectDown-Mid"] = { 29, 0.28320313, 0.33984375 },
    ["PaperHeader-SelectUp-Mid"]     = { 29, 0.22265625, 0.27929688 },
    ["PaperHeader-SelectDown-Mid"]   = { 29, 0.40429688, 0.46093750 },
    ["PaperHeader-Highlight-Mid"]    = { 29, 0.46484375, 0.52148438 },
}

-- A section's flags, bit by bit: the icon's place on retail's 512x256 warning
-- icon sheet (the icons_16x16_* atlases, 32 px cells drawn at 20) and the
-- client's name for it.
local FLAGS = {
    { 265, 103, ENCOUNTER_JOURNAL_SECTION_FLAG0 },      -- tank
    { 133, 199, ENCOUNTER_JOURNAL_SECTION_FLAG1 },      -- damage dealer
    { 333, 1,   ENCOUNTER_JOURNAL_SECTION_FLAG2 },      -- healer
    { 367, 1,   ENCOUNTER_JOURNAL_SECTION_FLAG3 },      -- heroic
    { 199, 199, ENCOUNTER_JOURNAL_SECTION_FLAG4 },      -- deadly
    { 401, 1,   ENCOUNTER_JOURNAL_SECTION_FLAG5 },      -- important
    { 435, 1,   ENCOUNTER_JOURNAL_SECTION_FLAG6 },      -- interruptible
    { 469, 1,   ENCOUNTER_JOURNAL_SECTION_FLAG7 },      -- magic
    { 67,  199, ENCOUNTER_JOURNAL_SECTION_FLAG8 },      -- curse
    { 265, 69,  ENCOUNTER_JOURNAL_SECTION_FLAG9 },      -- poison
    { 265, 1,   ENCOUNTER_JOURNAL_SECTION_FLAG10 },     -- disease
    { 299, 1,   ENCOUNTER_JOURNAL_SECTION_FLAG11 },     -- enrage
    { 265, 35,  ENCOUNTER_JOURNAL_SECTION_FLAG12 },     -- mythic
    { 1,   199, "Bleed" },
}

object "AdventureGuideStyle" {

    -- The window is retail's 800x496 EncounterJournal at nine tenths, like
    -- the other portrait windows: its pages are laid out in retail's own
    -- numbers on a canvas drawn at this scale.
    S = 0.9,

    ART = ART,

    -- Text on the journal's parchment.
    INK = { 0.25, 0.1484375, 0.02 },

    -- Friz at `size`, coloured; with the usual drop shadow unless `shadow`
    -- is false (text on the parchment has none).
    Label = function(self, parent, size, r, g, b, layer, shadow)
        local fs = FontString(parent, nil, layer or "OVERLAY", MUI.FontBySize(size, shadow))
        fs:SetTextColor(r, g, b, 1)
        return fs
    end;

    -- Parchment text: Friz 12 in ink (GameFontBlack as the journal tints it).
    Ink = function(self, parent, layer)
        local fs = self:Label(parent, 12, self.INK[1], self.INK[2], self.INK[3], layer, false)
        fs:SetJustifyH("LEFT")
        return fs
    end;

    -- Morpheus at `size`, gold on a black shadow (QuestTitleFontBlackShadow).
    Title = function(self, parent, size, layer)
        local fs = FontString(parent, nil, layer or "OVERLAY")
        fs:SetFont(MUI.FONT_CAL, size, "")
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetTextColor(1, 0.82, 0, 1)
        return fs
    end;

    -- Show a piece of the journal sheet on `texture`, at the piece's own
    -- size unless `keepSize`.
    SetPiece = function(self, texture, name, keepSize)
        local p = PIECES[name]
        texture:SetTexture(SHEET)
        texture:SetTexCoord(p[3], p[4], p[5], p[6])
        if not keepSize then texture:SetSize(p[1], p[2]) end
    end;

    -- A new texture showing a piece.
    Piece = function(self, parent, layer, name, sublevel)
        local texture = Texture(parent, nil, layer)
        if sublevel then texture:SetDrawLayer(layer, sublevel) end
        self:SetPiece(texture, name)
        return texture
    end;

    -- Show a band of the tile sheet on `texture`, repeating along its width.
    SetBand = function(self, texture, name)
        local band = BANDS[name]
        texture:SetTexture(TILE, "REPEAT", "CLAMPTOEDGE")
        texture:SetHorizTile(true)
        texture:SetTexCoord(0, 1, band[2], band[3])
        texture:SetHeight(band[1])
    end;

    Band = function(self, parent, layer, name, sublevel)
        local texture = Texture(parent, nil, layer)
        if sublevel then texture:SetDrawLayer(layer, sublevel) end
        self:SetBand(texture, name)
        return texture
    end;

    -- Show the icon of section flag `bit` (0 = tank ...) on `texture`;
    -- returns the flag's name.
    SetFlag = function(self, texture, bit)
        local flag = FLAGS[bit + 1]
        texture:SetTextureRegion(ART .. "flags", 512, 256, flag[1], flag[2], 32, 32)
        return flag[3]
    end;

    -- The bits set in a section's flags, lowest first.
    FlagBits = function(self, flags)
        local bits = {}
        for bit = 0, #FLAGS - 1 do
            if flags % 2 == 1 then bits[#bits + 1] = bit end
            flags = math.floor(flags / 2)
        end
        return bits
    end;

    -- An instance's "buttons" / "lore" / "backdrops" texture.
    InstanceArt = function(self, kind, id)
        return ART .. kind .. "\\" .. id
    end;

    -- A boss's 128x64 plate; the default one when it has none of its own.
    BossArt = function(self, encounter)
        if encounter.portrait then return ART .. "bosses\\" .. encounter.portrait end
        return ART .. "boss-default"
    end;

    -- A dungeon's level range from MUI_DungeonDB, as text; nil for a raid.
    LevelRange = function(self, instance)
        if instance.raid then return nil end
        local dungeon = MUI_DungeonDB:GetDungeonEntrance(instance.area)
        if dungeon.minLevel == dungeon.maxLevel then return tostring(dungeon.minLevel) end
        return dungeon.minLevel .. "-" .. dungeon.maxLevel
    end;
}
