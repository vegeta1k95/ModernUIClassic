-- MUI_AuctionHouseStyle: what the auction house panels share — the scale
-- retail's lengths are drawn at, labels, pieces of the two art sheets,
-- money and quality-coloured text.

local CHROME      = MUI_AtlasRegistry.AuctionHouse
local BACKGROUNDS = MUI_AtlasRegistry.AuctionHouseBackgrounds

-- Auction time left, as the client reports it (1..4).
local TIME_LEFT = { AUCTION_TIME_LEFT1, AUCTION_TIME_LEFT2, AUCTION_TIME_LEFT3, AUCTION_TIME_LEFT4 }

object "AuctionHouseStyle" {

    -- The window is retail's 800x538 AuctionHouseFrame at nine tenths, like
    -- the other portrait windows: every length inside is retail's times S.
    S = 0.9,

    -- Friz at `size`, coloured, with the usual drop shadow.
    Label = function(self, parent, size, r, g, b, layer)
        local fs = FontString(parent, nil, layer or "OVERLAY", MUI.FontBySize(size))
        fs:SetTextColor(r or 1, g or 1, b or 1, 1)
        return fs
    end;

    -- A piece of the chrome sheet, `w` x `h` in retail's units.
    Piece = function(self, parent, layer, region, w, h, sublevel)
        local t = Texture(parent, nil, layer)
        if sublevel then t:SetDrawLayer(layer, sublevel) end
        t:SetAtlas(CHROME, region, true)
        t:SetSize(w * self.S, h * self.S)
        return t
    end;

    -- Re-texture a piece made by Piece, keeping its size.
    SetPiece = function(self, texture, region)
        texture:SetAtlas(CHROME, region, true)
    end;

    -- One of the panel backgrounds.
    Background = function(self, parent, region, layer)
        local t = Texture(parent, nil, layer or "BACKGROUND")
        t:SetAtlas(BACKGROUNDS, region, true)
        return t
    end;

    -- The recessed border retail's panels sit in (InsetFrameTemplate),
    -- unfilled, over `parent` inset by the given retail lengths.
    Inset = function(self, parent, left, top, right, bottom)
        local inset = InnerFrame(parent)
        inset:HideBg()
        inset:FillParentPadding((left or 0) * self.S, (top or 0) * self.S, (right or 0) * self.S, (bottom or 0) * self.S)
        return inset
    end;

    -- Coins as text; `none` (default "") when there is no amount.
    Money = function(self, copper, none)
        if not copper or copper <= 0 then return none or "" end
        return C_CurrencyInfo.GetCoinTextureString(copper, 11)
    end;

    QualityText = function(self, name, quality)
        local c = ITEM_QUALITY_COLORS[quality or 1] or ITEM_QUALITY_COLORS[1]
        return string.format("|cff%02x%02x%02x%s|r",
            math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5), name)
    end;

    TimeLeft = function(self, timeLeft)
        return TIME_LEFT[timeLeft] or ""
    end;

    -- The ring retail frames a big item icon with, by quality.
    QualityRing = function(self, quality)
        if quality == 0 then return "ItemIconBorderGray" end
        if quality == 2 then return "ItemIconBorderGreen" end
        if quality == 3 then return "ItemIconBorderBlue" end
        if quality == 4 then return "ItemIconBorderPurple" end
        if quality == 5 then return "ItemIconBorderOrange" end
        return "ItemIconBorderWhite"
    end;
}
