-- MUI_InspectGuild: the inspect window's Guild tab — retail's
-- InspectGuildFrame, which Era doesn't have: the guild's banner in its
-- tabard's colours over the guild sheet, its name, realm, faction and size.
--
-- The name is Era's guild line for the player; the inspect data
-- (C_PaperDollInfo.GetInspectGuildInfo) has it too, with the realm and
-- the member count, when the server sends them, and the count shows only
-- then. Retail's line of guild achievement points is left out: Era has no
-- achievements. The sheet (Interface\GuildFrame\GuildInspect-Parts),
-- which Era's UI never draws, ships as assets/textures/skin/inspect.

local SHEET = MUI.TEX_SKIN .. "inspect\\guild-inspect"
-- Retail's INSPECT_GUILD_REALM, which Era lacks.
local REALM_FORMAT = "Realm: %s"

-- A tabard with no design, as Blizzard's SetGuildTabardTextures draws it.
local PLAIN_BANNER = { 0.2245, 0.2088, 0.1794 }
local PLAIN_BORDER = { 0.2, 0.2, 0.2 }

class "InspectGuild" : extends "CharacterPane" {

    -- Retail's frame width for the tab, and where its inset ends above the
    -- frame's bottom: retail shows its button bar under this one.
    frameWidth  = 338,
    insetBottom = 26,

    __init = function(self, window)
        CharacterPane.__init(self, window)

        local sheet = Texture(self, nil, "BACKGROUND")
        sheet:SetTextureRegion(SHEET, 512, 512, 1, 1, 321, 334)
        sheet:SetSize(321, 334)
        sheet:AlignParentTopLeft(4, 4)
        self:_BuildBanner()

        self._name    = self:_Line(20)
        self._realm   = self:_Line(16)
        self._faction = self:_Line(16)
        self._members = self:_Line(16)
        -- Retail hangs the name from the frame's centre.
        self._name:AlignTop(window.canvas, 424 / 2 + 18)
        self._realm:Below(self._name, 10)
        self._faction:Below(self._realm, 4)
        self._members:Below(self._faction, 26)

        self:HookScript("OnShow", function() self:Refresh() end)
        self:RegisterEventHandler("INSPECT_READY", function(_, _, guid)
            local unit = InspectFrame.unit
            if unit and UnitGUID(unit) == guid and self:IsVisible() then self:Refresh() end
        end)
    end;

    -- The banner and its border, coloured as the guild's tabard, and its
    -- emblem twice, the left one mirrored.
    _BuildBanner = function(self)
        self._banner = Texture(self, nil, "BACKGROUND")
        self._banner:SetDrawLayer("BACKGROUND", 1)
        self._banner:SetTextureRegion(SHEET, 512, 512, 121, 359, 118, 144)
        self._banner:SetSize(118, 144)
        self._banner:AlignParentTopLeft(4, 104)

        self._bannerBorder = Texture(self, nil, "BACKGROUND")
        self._bannerBorder:SetDrawLayer("BACKGROUND", 2)
        self._bannerBorder:SetTextureRegion(SHEET, 512, 512, 1, 359, 118, 144)
        self._bannerBorder:Fill(self._banner)

        self._emblemLeft = Texture(self, nil, "ARTWORK")
        self._emblemLeft:SetSize(50, 125)
        self._emblemLeft:AlignParentTopLeft(5, 114)
        self._emblemRight = Texture(self, nil, "ARTWORK")
        self._emblemRight:SetSize(50, 125)
        self._emblemRight:RightOf(self._emblemLeft, -1)
    end;

    _Line = function(self, size)
        local line = FontString(self, nil, "OVERLAY")
        line:SetFontSize(size)
        line:SetTextColor(1, 0.82, 0, 1)
        line:SetWidth(300)
        return line
    end;

    -- A unit's guild: its name (nil for none), realm and member count (0
    -- when the server didn't send it).
    ReadGuild = function(self, unit)
        local name, _, _, realm = GetGuildInfo(unit)
        local _, members, inspectName, inspectRealm = C_PaperDollInfo.GetInspectGuildInfo(unit)
        if inspectName and inspectName ~= "" then name = inspectName end
        if inspectRealm and inspectRealm ~= "" then realm = inspectRealm end
        return name, realm or GetRealmName(), members or 0
    end;

    Refresh = function(self)
        local unit = InspectFrame.unit
        if not unit then return end
        local name, realm, members = self:ReadGuild(unit)
        local _, faction = UnitFactionGroup(unit)
        self._name:SetText(name or "")
        self._realm:SetText(REALM_FORMAT:format(realm))
        self._faction:SetText(faction and INSPECT_GUILD_FACTION:format(faction) or "")
        self._members:SetText(members > 0 and INSPECT_GUILD_NUM_MEMBERS:format(members) or "")
        self:_UpdateTabard(unit)
    end;

    -- Blizzard's SetDoubleGuildTabardTextures, on our textures.
    _UpdateTabard = function(self, unit)
        local tabard = C_GuildInfo.GetGuildTabardInfo(unit)
        local emblems = { self._emblemLeft, self._emblemRight }
        if not (tabard and tabard.emblemFileID) then
            self._banner:SetVertexColor(unpack(PLAIN_BANNER))
            self._bannerBorder:SetVertexColor(unpack(PLAIN_BORDER))
            for _, emblem in ipairs(emblems) do emblem:Hide() end
            return
        end
        self._banner:SetVertexColor(tabard.backgroundColor:GetRGB())
        self._bannerBorder:SetVertexColor(tabard.borderColor:GetRGB())
        for _, emblem in ipairs(emblems) do
            emblem:SetTexture(tabard.emblemFileID)
            emblem:SetVertexColor(tabard.emblemColor:GetRGB())
            emblem:Show()
        end
        self._emblemLeft:SetTexCoord(1, 0, 0, 1)
    end;
}
