-- Retail-style micro menu bar

local ATLAS = MUI_AtlasRegistry.MicroMenu
local BUTTON_SPACING = -5

class "MicroButtonBase" : extends "Button" {

    __init = function(self, atlasPrefix)

        self:SetSize(32, 41)

        self._bg = Texture(self, nil, "BACKGROUND")
        self._bg:SetAtlas(ATLAS, "ButtonBGUp")
        self._bg:FillParent()

        self:SetScript("OnMouseDown", function()
            self._bg:SetAtlas(ATLAS, "ButtonBGDown")
        end)
        self:SetScript("OnMouseUp", function()
            self._bg:SetAtlas(ATLAS, "ButtonBGUp")
        end)

        self._atlasPrefix = atlasPrefix
        self:SetEnabled(true)
    end;

    HookFrameVisibility = function(self, frame)
        frame:HookScript("OnShow", function()
            self:SetButtonState("PUSHED", 1)
            self._bg:SetAtlas(ATLAS, "ButtonBGDown")
        end)
        frame:HookScript("OnHide", function()
            self:SetButtonState("NORMAL")
            self._bg:SetAtlas(ATLAS, "ButtonBGUp")
        end)
    end;

    SetEnabled = function(self, enabled)
        Button.SetEnabled(self, enabled)
        self:SetAlpha(enabled and 1.0 or 0.7)

        if not self._atlasPrefix then return end

        if enabled then
            self:SetStateAtlas(ATLAS,
                self._atlasPrefix .. "Up",
                self._atlasPrefix .. "Down",
                self._atlasPrefix .. "Disabled"
            )
            self:SetHighlightAtlas(ATLAS, self._atlasPrefix .. "Mouseover", true)

        else
            self:SetStateAtlas(ATLAS,
                self._atlasPrefix .. "Disabled",
                self._atlasPrefix .. "Disabled",
                self._atlasPrefix .. "Disabled"
            )
            self:SetHighlightAtlas(ATLAS, self._atlasPrefix .. "Disabled", true)
        end

    end;

}

class "MicroButtonMacro" : extends {"MicroButtonBase", "SecureActionButton"} {

    __init = function(self, parent, name, atlasPrefix)
        SecureActionButton.__init(self, parent, "MUI_MicroBtn_" .. name)
        MicroButtonBase.__init(self, atlasPrefix)
    end;
}

class "MicroButtonToggle" : extends {"MicroButtonBase", "SecureButton"} {

    __init = function(self, parent, name, atlasPrefix)
        SecureButton.__init(self, parent, "MUI_MicroBtn_" .. name)
        MicroButtonBase.__init(self, atlasPrefix)
    end
}

class "MicroMenuFrame" : extends {"Frame", "Editable"} {

    __init = function(self)
        Frame.__init(self, "Frame", MUI_Root, "MUI_MicroMenuBar")
        Editable.__init(self)
        self:EditModeSetLabel("Micro Menu")
        self:EditModeSetupSettings(function(content) end)
    end
}


object "ModuleMicroMenu" : extends "Module" {
    __init = function(self)
        Module.__init(self, "MicroMenu")
    end;

    OnEnable = function(self)
        self:HideVanillaButtons()
        self:CreateButtons()
        self:HookGameMenu()
    end;

    HideVanillaButtons = function(self)
        local hideList = {
            "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton",
            "QuestLogMicroButton", "SocialsMicroButton", "FriendsMicroButton",
            "GuildMicroButton", "WorldMapMicroButton", "MainMenuMicroButton",
            "HelpMicroButton", "LFDMicroButton", "PVPMicroButton",
            "AchievementMicroButton", "CollectionsMicroButton", "EJMicroButton",
            "StoreMicroButton", "ProfessionMicroButton",
        }

        local PARK_AT_SLOT = {
            Character = "CharacterMicroButton",
            Talents   = "TalentMicroButton",
            QuestLog  = "WorldMapMicroButton",   -- routed through WorldMap, see BUTTONS
            Spellbook = "SpellbookMicroButton",
            Guild     = "SocialsMicroButton",
            GameMenu  = "MainMenuMicroButton",
        }

        -- Don't Hide/override .Show on these frames (taints secure UpdateMicroButtons).
        -- SetAlpha(0) makes the native invisible while keeping its frame shown so the
        -- secure /click forwarder can call its OnClick. EnableMouse(true) is required
        -- on natives we forward to so the IsMouseOver gate inside their OnMouseUp
        -- (Character/MainMenu) sees the cursor when our button is clicked.
        local forwarded = {}
        for _, native in pairs(PARK_AT_SLOT) do forwarded[native] = true end

        for _, name in ipairs(hideList) do
            local f = getglobal(name)
            if f then
                local w = Frame(f)
                w:SetAlpha(0)
                if not forwarded[name] then
                    w:EnableMouse(false)
                else
                    -- Forwarded natives stay mouse-enabled so /click reaches their
                    -- IsMouseOver gate, but several sit in front of our overlay
                    -- buttons (MainMenu/Character) and would pop the native micro
                    -- tooltip on hover. Suppress it; click is driven by OnClick.
                    w:SetScript("OnEnter", nil)
                    w:SetScript("OnLeave", nil)
                end
            end
        end

        -- MicroButtonPortrait is a Texture/PlayerModel hosted on CharacterMicroButton; Hide it.
        if MicroButtonPortrait then
            local mp = Frame(MicroButtonPortrait)
            mp:Hide()
            mp:SetAlpha(0)
        end
    end;

    CreateButtons = function(self)

        self._container = MicroMenuFrame()
        self._container:AlignParentBottomRight(5, 6)
        self._container:SetScale(0.9)
        self._container:SetClampedToScreen(true)
        self._container:SetHeight(41)

        MUI_MicroMenu = self._container

        -- Game Menu (clickthrough)
        self._btnGameMenu = MicroButtonMacro(self._container, "GameMenu", "GameMenu")
        self._btnGameMenu:AlignParentTopRight()
        local nativeMenu = Button(MainMenuMicroButton)
        nativeMenu:ClearAllPoints()
        nativeMenu:CenterAt(self._btnGameMenu)
        nativeMenu:PutInfront(self._btnGameMenu)
        
        -- Shop
        self._btnShop = MicroButtonMacro(self._container, "Shop", "Shop")
        self._btnShop:LeftOf(self._btnGameMenu, BUTTON_SPACING)
        self._btnShop:SetMacroText("/click StoreMicroButton")
        local function setShopShown(shown)
            if shown then
                self._btnShop:SetButtonState("PUSHED", 1)
                self._btnShop._bg:SetAtlas(ATLAS, "ButtonBGDown")
            else
                self._btnShop:SetButtonState("NORMAL")
                self._btnShop._bg:SetAtlas(ATLAS, "ButtonBGUp")
            end
        end
        hooksecurefunc("StoreFrame_SetShown", setShopShown)
        hooksecurefunc(CatalogShopInboundInterface, "SetShown", setShopShown)

        -- Adventure Guide: enabled once MUI_AdventureGuide hands over its window (WireAdventureGuide)
        self._btnAdventureGuide = MicroButtonToggle(self._container, "AdventureGuide", "AdventureGuide")
        self._btnAdventureGuide:LeftOf(self._btnShop, BUTTON_SPACING)
        self._btnAdventureGuide:SetEnabled(false)

        -- Collections
        self._btnCollections = MicroButtonToggle(self._container, "Collections", "Collections")
        self._btnCollections:LeftOf(self._btnAdventureGuide, BUTTON_SPACING)
        self._btnCollections:SetEnabled(false)

        -- Group Finder → Era's "Looking For Group" panel. It is a UIPanel, which addon
        -- code can't show or hide in combat, so the click goes to the native minimap LFG
        -- eye (kept alive, unseen, by the minimap) and Blizzard's own toggle runs securely.
        self._btnGroupFinder = MicroButtonMacro(self._container, "GroupFinder", "GroupFinder")
        self._btnGroupFinder:LeftOf(self._btnCollections, BUTTON_SPACING)
        self._btnGroupFinder:SetMacroText("/click LFGMinimapFrame")
        -- The eye's handler calls into a load-on-demand addon
        self._btnGroupFinder:SetScript("PreClick", function()
            if not ToggleLFGParentFrame then
                C_AddOns.LoadAddOn("Blizzard_GroupFinder_VanillaStyle")
            end
        end)
        if LFGParentFrame then
            self._btnGroupFinder:HookFrameVisibility(LFGParentFrame)
        else
            self._container:RegisterEventHandler("ADDON_LOADED", function(_, _, addon)
                if addon == "Blizzard_GroupFinder_VanillaStyle" then
                    self._btnGroupFinder:HookFrameVisibility(LFGParentFrame)
                end
            end)
        end

        -- Guild
        self._btnGuild = MicroButtonMacro(self._container, "Guild", "Guild")
        self._btnGuild:LeftOf(self._btnGroupFinder, BUTTON_SPACING)
        self._btnGuild:SetMacroText("/click SocialsMicroButton")
        self._btnGuild:HookFrameVisibility(FriendsFrame)
        local nativeSocial = Button(SocialsMicroButton)
        nativeSocial:ClearAllPoints()
        nativeSocial:CenterAt(self._btnGuild)
        self._btnGuild:PutInfront(nativeSocial)

        -- Spellbook
        self._btnSpellbook = MicroButtonMacro(self._container, "Spellbook", "Spellbook")
        self._btnSpellbook:LeftOf(self._btnGuild, BUTTON_SPACING)
        self._btnSpellbook:SetMacroText("/click MUI_ClassbookTabBtnSpellbook Macro")
        self._btnSpellbook:HookFrameVisibility(MUI_TabSpellbookFrame)
        local nativeSpellbook = Button(SpellbookMicroButton)
        nativeSpellbook:ClearAllPoints()
        nativeSpellbook:CenterAt(self._btnSpellbook)
        self._btnSpellbook:PutInfront(nativeSpellbook)

        -- Quest Log
        self._btnQuestLog = MicroButtonMacro(self._container, "QuestLog", "QuestLog")
        self._btnQuestLog:LeftOf(self._btnSpellbook, BUTTON_SPACING)
        self._btnQuestLog:SetMacroText("/click WorldMapMicroButton")
        self._btnQuestLog:HookFrameVisibility(WorldMapFrame)
        local nativeMap = Button(WorldMapMicroButton)
        nativeMap:ClearAllPoints()
        nativeMap:CenterAt(self._btnQuestLog)
        self._btnQuestLog:PutInfront(nativeMap)

        -- Achievements: enabled once MUI_Achievements hands over its panel (WireAchievements)
        self._btnAchievements = MicroButtonToggle(self._container, "Achievements", "Achievements")
        self._btnAchievements:LeftOf(self._btnQuestLog, BUTTON_SPACING)
        self._btnAchievements:SetEnabled(false)

        -- Talents
        self._btnTalents = MicroButtonMacro(self._container, "Talents", "Talents")
        self._btnTalents:LeftOf(self._btnAchievements, BUTTON_SPACING)
        self._btnTalents:SetMacroText("/click MUI_ClassbookTabBtnTalents Macro")
        self._btnTalents:HookFrameVisibility(MUI_TabTalentsFrame)
        local nativeTalents = Button()
        nativeTalents:ClearAllPoints()
        nativeTalents:CenterAt(self._btnTalents)
        self._btnTalents:PutInfront(nativeTalents)

        -- Professions
        self._btnProfessions = MicroButtonToggle(self._container, "Professions", "Professions")
        self._btnProfessions:LeftOf(self._btnTalents, BUTTON_SPACING)
        self._btnProfessions:HookFrameVisibility(MUI_ProfessionsOverviewFrame)
        self._btnProfessions:SetFrameRef("profFrame", MUI_ProfessionsOverviewFrame)
        self._btnProfessions:SetOnClick([[
            local t = self:GetFrameRef("profFrame")
            if t:IsShown() then
                t:Hide()
            else
                t:Show()
            end
        ]])

        -- Character (clickthrough)
        self._btnCharacter = MicroButtonMacro(self._container, "Character", nil)
        self._btnCharacter:LeftOf(self._btnProfessions, BUTTON_SPACING)
        self._btnCharacter:HookFrameVisibility(CharacterFrame)
        local nativeChar = Button(CharacterMicroButton)
        nativeChar:ClearAllPoints()
        nativeChar:CenterAt(self._btnCharacter)
        nativeChar:PutInfront(self._btnCharacter)

        self._portrait = Texture(self._btnCharacter, "MUI_MicroPortrait", "OVERLAY")
        self._portrait:SetSize(20, 26)
        self._portrait:CenterInParent(1, 0)
        self._portrait:SetTexCoord(0.15, 0.85, 0.0, 1.0)
        self._portrait:SetPortraitFromUnit("player")

        nativeChar:HookScript("OnShow", function()
            self._portrait:SetAlpha(0.5)
        end)
        nativeChar:HookScript("OnHide", function()
            self._portrait:SetAlpha(1.0)
        end)

        -- Blizzard's MicroMenu is a grid layout that pulls its buttons back on every Layout
        local seats = {
            { nativeMenu,      self._btnGameMenu  },
            { nativeSocial,    self._btnGuild     },
            { nativeSpellbook, self._btnSpellbook },
            { nativeMap,       self._btnQuestLog  },
            { nativeChar,      self._btnCharacter },
        }
        hooksecurefunc(MicroMenu, "Layout", function()
            for _, seat in ipairs(seats) do
                seat[1]:ClearAllPoints()
                seat[1]:CenterAt(seat[2])
            end
        end)

        self._container:RegisterEventHandler("UNIT_PORTRAIT_UPDATE", function(_, _, unit)
            if unit ~= "player" then return end
            self._portrait:SetPortraitFromUnit("player")
        end)
        self._container:RegisterEventHandler("PLAYER_ENTERING_WORLD", function()
            self._portrait:SetPortraitFromUnit("player")
        end)

        self._buttons = {}
        table.insert(self._buttons, self._btnGameMenu)
        table.insert(self._buttons, self._btnShop)
        table.insert(self._buttons, self._btnAdventureGuide)
        table.insert(self._buttons, self._btnCollections)
        table.insert(self._buttons, self._btnGroupFinder)
        table.insert(self._buttons, self._btnGuild)
        table.insert(self._buttons, self._btnSpellbook)
        table.insert(self._buttons, self._btnQuestLog)
        table.insert(self._buttons, self._btnAchievements)
        table.insert(self._buttons, self._btnTalents)
        table.insert(self._buttons, self._btnProfessions)
        table.insert(self._buttons, self._btnCharacter)

        self._container:SetWidth(#self._buttons * 32 + (#self._buttons - 1)*BUTTON_SPACING)

        self:ApplyTooltips()
    end;

    -- "Name (keybind)" tooltips. The key is resolved live each hover via
    -- MicroButtonTooltipText → GetBindingKey, so it tracks rebinds and omits the
    -- parenthesis when nothing is bound. GameMenu and Character keep their native
    -- micro button layered in front (its IsMouseOver click-gate needs the cursor),
    -- so that native — not our overlay — receives the hover; their tooltip goes on
    -- the native (re-enabling the OnEnter we cleared in HideVanillaButtons).
    ApplyTooltips = function(self)
        local function tip(frame, name, action)
            if not frame then return end
            frame:SetTooltip("ANCHOR_TOP", function(tooltip)
                local label = name
                if action and MicroButtonTooltipText then
                    label = MicroButtonTooltipText(name, action)
                end
                tooltip:AddLine(label, 1, 1, 1, false, 13)
            end)
        end

        tip(Frame(MainMenuMicroButton),  "Game Menu",             "TOGGLEGAMEMENU")
        tip(Frame(CharacterMicroButton), "Character Info",        "TOGGLECHARACTER0")
        tip(self._btnShop,           "Shop")
        tip(self._btnAdventureGuide, "Adventure Guide",       "MUI_TOGGLE_ADVENTUREGUIDE")
        --tip(self._btnCollections,    "Collections",           "TOGGLECOLLECTIONS")
        tip(self._btnGroupFinder,    "Group Finder",          "TOGGLEGROUPFINDER")
        tip(self._btnGuild,          "Guild",                 "TOGGLEGUILDTAB")
        tip(self._btnSpellbook,      "Spellbook & Abilities", "TOGGLESPELLBOOK")
        tip(self._btnQuestLog,       "Quest Log",             "TOGGLEQUESTLOG")
        tip(self._btnAchievements,   "Achievements")
        tip(self._btnTalents,        "Talents",               "TOGGLETALENTS")
        tip(self._btnProfessions,    "Professions")
    end;

    -- Our achievements panel (Era has none of its own): the button toggles it.
    -- From plain Lua, not a secure snippet: the panel is not a protected
    -- frame, and a snippet may not touch one in combat.
    WireAchievements = function(self, frame)
        self._btnAchievements:HookFrameVisibility(frame)
        self._btnAchievements:HookScript("OnClick", function() frame:Toggle() end)
        self._btnAchievements:SetEnabled(true)
    end;

    -- Our Adventure Guide (Era has no journal of its own): the same way.
    WireAdventureGuide = function(self, frame)
        self._btnAdventureGuide:HookFrameVisibility(frame)
        self._btnAdventureGuide:HookScript("OnClick", function() frame:Toggle() end)
        self._btnAdventureGuide:SetEnabled(true)
    end;

    HookGameMenu = function(self)

        local function _SetButtonsEnabled(enabled)
            if InCombatLockdown() then return end

            self._btnShop:SetEnabled(enabled)
            self._btnGroupFinder:SetEnabled(enabled)
            self._btnGuild:SetEnabled(enabled)
            self._btnSpellbook:SetEnabled(enabled)
            self._btnQuestLog:SetEnabled(enabled)
            self._btnTalents:SetEnabled(enabled)
            self._btnProfessions:SetEnabled(enabled)

            if self._portrait then
                self._portrait:SetAlpha(enabled and 1.0 or 0.7)
                self._portrait:SetDesaturated(not enabled)
            end
        end

        local gmf = Frame(GameMenuFrame)
        gmf:HookScript("OnShow", function()
            _SetButtonsEnabled(false)
        end)
        gmf:HookScript("OnHide", function()
            _SetButtonsEnabled(true)
        end)
        -- If combat lockdown caused SetButtonsEnabled to no-op (above), the
        -- visual state is stuck at whatever it was when combat started. On
        -- PLAYER_REGEN_ENABLED, re-sync based on current GameMenuFrame
        -- visibility — pulls the buttons back into the right enabled state
        -- regardless of what happened during combat.
        self._container:RegisterEventHandler("PLAYER_REGEN_ENABLED", function()
            _SetButtonsEnabled(not GameMenuFrame:IsShown())
        end)
    end;
}
