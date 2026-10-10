-- MUI_CollectionsStyle: what the Collections window's pages share — the
-- scale, labels, the pieces of retail's art.

local ART = MUI.TEX_SKIN .. "collections\\"

-- Pieces of the art, as retail's atlases cut them: sheet, the sheet's width
-- and height, the piece's left, top, width, height.
local PIECES = {
    ["Corner"]       = { "collections", 512, 512, 1,   7,   90,  67 },
    ["Favorite"]     = { "collections", 512, 512, 93,  7,   31,  33 },
    ["ShadowSmall"]  = { "collections", 512, 512, 93,  42,  13,  13 },
    ["ShadowLarge"]  = { "collections", 512, 512, 93,  213, 145, 147 },
    ["ModelFade"]    = { "sets",        512, 256, 1,   1,   403, 178 },
    ["IconRow"]      = { "sets",        512, 256, 1,   181, 418, 64 },
    ["Row"]          = { "list",        512, 512, 1,   193, 209, 46 },
    ["RowHighlight"] = { "list",        512, 512, 212, 193, 209, 46 },
    ["RowSelected"]  = { "list",        512, 512, 1,   241, 209, 46 },
    -- An item's border by its quality; the plain one is for a piece not held.
    ["Border"]       = { "set-borders", 256, 128, 87,  44,  41,  41 },
    ["Border2"]      = { "set-borders", 256, 128, 44,  1,   41,  41 },
    ["Border3"]      = { "set-borders", 256, 128, 1,   44,  41,  41 },
    ["Border4"]      = { "set-borders", 256, 128, 87,  1,   41,  41 },
    ["Border5"]      = { "set-borders", 256, 128, 44,  44,  41,  41 },
}

object "CollectionsStyle" {

    -- The window is retail's 703x606 CollectionsJournal at nine tenths, like
    -- the other portrait windows: its pages are laid out in retail's own
    -- numbers on a canvas drawn at this scale.
    S = 0.9,

    ART = ART,

    -- Friz at `size`, coloured, with the usual drop shadow.
    Label = function(self, parent, size, r, g, b, layer)
        local fs = FontString(parent, nil, layer or "OVERLAY", MUI.FontBySize(size))
        fs:SetTextColor(r, g, b, 1)
        return fs
    end;

    -- Morpheus at `size`, gold on a black shadow (retail's Fancy fonts).
    Title = function(self, parent, size, layer)
        local fs = FontString(parent, nil, layer or "OVERLAY")
        fs:SetFont(MUI.FONT_CAL, size, "")
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetTextColor(1, 0.82, 0, 1)
        return fs
    end;

    -- Show a piece on `texture`, at the piece's own size unless `keepSize`;
    -- mirrored sideways (`flipH`) or upside down (`flipV`).
    SetPiece = function(self, texture, name, keepSize, flipH, flipV)
        local p = PIECES[name]
        texture:SetTextureRegion(ART .. p[1], p[2], p[3], p[4], p[5], p[6], p[7], flipH, flipV)
        if not keepSize then texture:SetSize(p[6], p[7]) end
    end;

    -- A new texture showing a piece.
    Piece = function(self, parent, layer, name, sublevel)
        local texture = Texture(parent, nil, layer)
        if sublevel then texture:SetDrawLayer(layer, sublevel) end
        self:SetPiece(texture, name)
        return texture
    end;

    -- A shadow piece in each corner of `frame`, `inset` in from its edges,
    -- and its last column and row stretched along the edges between them.
    _Shadow = function(self, frame, name, layer, sublevel, inset)
        local p = PIECES[name]
        local sheet = ART .. p[1]
        local corners = {}
        for i, flip in ipairs({ { false, false }, { true, false }, { false, true }, { true, true } }) do
            local corner = Texture(frame, nil, layer)
            corner:SetDrawLayer(layer, sublevel)
            self:SetPiece(corner, name, false, flip[1], flip[2])
            corners[i] = corner
        end
        corners[1]:AlignParentTopLeft(inset, inset)
        corners[2]:AlignParentTopRight(inset, inset)
        corners[3]:AlignParentBottomLeft(inset, inset)
        corners[4]:AlignParentBottomRight(inset, inset)

        -- The middle of the last texel, so nothing beside the piece bleeds in.
        local column, row = p[4] + p[6] - 0.6, p[5] + p[7] - 0.6
        local function edge(first, second, x, y, w, h, flipH, flipV, across)
            local texture = Texture(frame, nil, layer)
            texture:SetDrawLayer(layer, sublevel)
            texture:SetTextureRegion(sheet, p[2], p[3], x, y, w, h, flipH, flipV)
            if across then
                texture:FillBetweenH(first, second)
            else
                texture:FillBetweenV(first, second)
            end
        end
        edge(corners[1], corners[2], column, p[5], 0.2, p[7], false, false, true)
        edge(corners[3], corners[4], column, p[5], 0.2, p[7], false, true, true)
        edge(corners[1], corners[3], p[4], row, p[6], 0.2, false, false, false)
        edge(corners[2], corners[4], p[4], row, p[6], 0.2, true, false, false)
    end;

    -- Retail's CollectionsBackgroundTemplate on an inset frame: the tiled
    -- wall, shadow coming in from its edges, the ornaments in the bottom
    -- corners (retail's sets page hides the top pair).
    Backdrop = function(self, frame)
        local wall = Texture(frame, nil, "BACKGROUND")
        wall:SetTexture(ART .. "collections-tile", "REPEAT", "REPEAT")
        wall:SetHorizTile(true)
        wall:SetVertTile(true)
        wall:FillParentPadding(4, 4, 4, 4)

        self:_Shadow(frame, "ShadowLarge", "BORDER", 2, 4)
        self:_Shadow(frame, "ShadowSmall", "OVERLAY", 0, 4)

        local left = Texture(frame, nil, "ARTWORK")
        left:SetDrawLayer("ARTWORK", 2)
        self:SetPiece(left, "Corner", false, false, true)
        left:AlignParentBottomLeft(4, 4)
        local right = Texture(frame, nil, "ARTWORK")
        right:SetDrawLayer("ARTWORK", 2)
        self:SetPiece(right, "Corner", false, true, true)
        right:AlignParentBottomRight(4, 4)
    end;
}
