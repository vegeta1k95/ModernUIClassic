-- SocialRaidTab: the Raid tab at retail's width. Its own pieces hang off the
-- window's corners and follow it; what does not is the "not in a raid" text
-- and the grid of raid groups, which Era lays out from the left edge at its
-- own narrower width.

-- Retail's two columns of groups: centred, 16 apart.
local GROUP_Y, GROUP_GAP = -58, 16
local GROUP_COUNT = 8
-- The description, inset 20 from each side of retail's 385.
local DESCRIPTION_W = 345
-- The Raid Information popup: beside the window, below its title bar as
-- retail's is, and clear of the metal frame's overhang.
local INFO_X, INFO_Y = 4, -28

class "SocialRaidTab" {

    __init = function(self)
        FontString(RaidFrameRaidDescription):SetWidth(DESCRIPTION_W)
        self:_SkinRaidInfo()

        -- The groups come with Blizzard_RaidUI, loaded the first time the
        -- player is in a raid or looks at this tab.
        self._events = Frame()
        if C_AddOns.IsAddOnLoaded("Blizzard_RaidUI") then
            self:_LayoutGroups()
        else
            self._events:RegisterEventHandler("ADDON_LOADED", function(events, _, name)
                if name == "Blizzard_RaidUI" then
                    events:UnregisterEventHandler("ADDON_LOADED")
                    self:_LayoutGroups()
                end
            end)
        end
    end;

    -- The saved instances popup ("Raid Information"): Era's is a classic
    -- dialog box with its title in the corner; retail's has the diamond metal
    -- border, a header plate and the minimal scroll bar. The list inside and
    -- its rows are left as Era has them.
    _SkinRaidInfo = function(self)
        local info = Frame(RaidInfoFrame)
        info:ClearAllPoints()
        info:SetPoint("TOPLEFT", RaidFrame, "TOPRIGHT", INFO_X, INFO_Y)

        -- The backdrop's pieces, the header art and the close button's corner.
        for _, region in ipairs(info:GetRegions()) do
            if region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
            end
        end
        -- The border sits at the popup's own level, under its list and
        -- buttons; the popup's own strings go on a frame above it. The title
        -- they hang from is hidden, the header plate having it now.
        local border = DiamondBorder(info)
        border:FillParent()
        border:SetFrameLevel(info:GetFrameLevel())
        local labels = Frame("Frame", info)
        labels:FillParent()
        FontString(RaidInfoHeader):Hide()
        FontString(RaidInfoSubheader):SetParent(labels)
        FontString(RaidInfoInstanceLabel):SetParent(labels)
        FontString(RaidInfoIDLabel):SetParent(labels)
        local header = DiamondHeader(info, nil, RAID_INFORMATION)
        header:AlignTop(border, -26)

        local atlas = MUI_AtlasRegistry.ButtonRedControl
        local close = Button(RaidInfoCloseButton)
        close:SetStateAtlas(atlas, "ExitNormal", "ExitPressed", "ExitDisabled")
        close:SetHighlightAtlas(atlas, "Highlight", true)
        close:SetSize(23, 24.5)
        close:ClearAllPoints()
        close:AlignParentTopRight(-2, -0.5)

        self._infoBar = ScrollBoxBar(RaidInfoFrame.ScrollBar)
    end;

    -- Era chains every right-hand group to the one on its left, 3 apart. The
    -- groups hold Blizzard's secure raid buttons, so they move out of combat.
    _LayoutGroups = function(self)
        if InCombatLockdown() then
            self._events:RegisterEventHandler("PLAYER_REGEN_ENABLED", function(events)
                events:UnregisterEventHandler("PLAYER_REGEN_ENABLED")
                self:_LayoutGroups()
            end)
            return
        end
        local first = Frame(RaidGroup1)
        first:ClearAllPoints()
        first:SetPoint("TOPRIGHT", RaidFrame, "TOP", -GROUP_GAP / 2, GROUP_Y)
        for i = 2, GROUP_COUNT, 2 do
            local group = Frame(_G["RaidGroup" .. i])
            group:ClearAllPoints()
            group:RightOf(_G["RaidGroup" .. (i - 1)], GROUP_GAP)
        end
    end;
}
