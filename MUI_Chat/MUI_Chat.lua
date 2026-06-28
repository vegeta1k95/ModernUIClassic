-- MUI_Chat: lightweight tweaks to Classic Era's native chat (no rewrite, no reskin).
-- Reposition, resize, replace scroll buttons with a minimal scrollbar + end button,
-- fade scrollbar with chat mouseover, mirror edit-box as a faint ghost.

-- ---- Layout constants -------------------------------------------------------------

local CHAT_WIDTH      = 388
local CHAT_HEIGHT     = 154
local VISIBLE_LINES   = 13
local BG_PAD_LEFT     =  2
local BG_PAD_RIGHT    = 12
local BG_PAD_TOP      =  2
local BG_PAD_BOTTOM   =  6

local CHAT_ANCHOR_X   = 46
local CHAT_ANCHOR_Y   = 32

local ALPHA_REST      = 0.2
local ALPHA_HOVER     = 0.6
local ALPHA_GHOST     = 0.3

-- ---- Helpers ---------------------------------------------------------------------
local function GetChild(cf, suffix)
    local name = ChatFrame(cf):GetName()
    return getglobal(name .. "ButtonFrame" .. suffix) or getglobal(name .. suffix)
end

-- ---- Module ----------------------------------------------------------------------
object "ModuleChat" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Chat")
    end;

    OnEnable = function(self)
        self:OverrideBlizzardDefaults()
        self:SetupPrimaryChat()
        self:RepositionButtonFrameChildren()
        self:RepositionDock()

        for i = 1, (NUM_CHAT_WINDOWS or 10) do
            local cf = getglobal("ChatFrame" .. i)
            if cf then self:SetupChatFrame(cf) end
        end

        self:HookFadeAnimations()
        self:InstallClassColorFilter()
    end;

    -- GetColoredName class-colors sender names when ChatTypeInfo[type].colorNameByClass is true.
    -- Use the public API (fires UPDATE_CHAT_COLOR_NAME_BY_CLASS) so it persists through
    -- Blizzard's chat-config reloads. Channel chats use CHANNEL<N> types (N = channel index).
    InstallClassColorFilter = function(self)
        local types = {
            "SAY", "YELL", "EMOTE",
            "WHISPER", "WHISPER_INFORM",
            "PARTY", "PARTY_LEADER",
            "RAID", "RAID_LEADER", "RAID_WARNING",
            "GUILD", "OFFICER",
        }
        for _, t in ipairs(types) do
            SetChatColorNameByClass(t, true)
        end
        -- Every numbered channel (CHANNEL1..CHANNEL20) gets it too.
        for i = 1, (MAX_WOW_CHAT_CHANNELS or 20) do
            SetChatColorNameByClass("CHANNEL" .. i, true)
        end
    end;

    -- Blizzard resets tab noMouseAlpha from these constants (default 0). Match our rest alpha.
    OverrideBlizzardDefaults = function(self)
        CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA = ALPHA_REST
        CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA   = ALPHA_REST
    end;

    -- ChatFrame1 position + unclamp. FCF's setup may run after our OnEnable on fresh login,
    -- so also hook the function that applies the default anchor to re-override it.
    SetupPrimaryChat = function(self)
        self.chat = ChatFrame(ChatFrame1)
        if self.chat:IsMovable() or self.chat:IsResizable() then
            self.chat:SetUserPlaced(true)
        end
        self.chat:SetClampedToScreen(false)
        self.chat:SetClampRectInsets(0, 0, 0, 0)

        local function apply()
            self.chat:ClearAllPoints()
            self.chat:AlignParentBottomLeft(CHAT_ANCHOR_X, CHAT_ANCHOR_Y)
        end
        apply()

        hooksecurefunc("FCF_DockUpdate", function() apply(); self:RepositionDock() end)
    end;

    -- Pull menu + channel buttons out of the ButtonFrame's LayoutMixin and position manually.
    RepositionButtonFrameChildren = function(self)
        ChatFrameMenuButton.layoutIndex = nil
        ChatFrameMenuButton.ignoreInLayout = true

        self.menuBtn = Button(ChatFrameMenuButton)
        self.menuBtn:SetParent(UIParent)
        self.menuBtn:ClearAllPoints()
        self.menuBtn:LeftOf(self.chat, 3.5, -64)
        self.menuBtn:SetSize(29, 28.5)

        ChatFrameChannelButton.layoutIndex = nil
        ChatFrameChannelButton.ignoreInLayout = true

        self.channelBtn = Button(ChatFrameChannelButton)
        self.channelBtn:SetParent(UIParent)
        self.channelBtn:ClearAllPoints()
        self.channelBtn:LeftOf(self.chat, 5, 70)
        self.channelBtn:SetScale(0.9)
    end;

    -- Tabs ride on GeneralDockManager anchored to ChatFrame1 TOPLEFT +6 by default.
    -- Push up to compensate for top content padding so tabs stay in place.
    RepositionDock = function(self)
        local dockY = BG_PAD_TOP + 3  -- 6 (original) + (TOP_PAD - 2)
        local dock = Frame(GeneralDockManager)
        dock:ClearAllPoints()
        dock:SetPoint("BOTTOMLEFT",  self.chat, "TOPLEFT",  0, dockY)
        dock:SetPoint("BOTTOMRIGHT", self.chat, "TOPRIGHT", 0, dockY)
    end;

    -- Per-frame setup pipeline.
    SetupChatFrame = function(self, cf)
        local chatFrame = ChatFrame(cf)

        self:NormalizeClamp(chatFrame)
        self:HideNativeButtons(cf)
        chatFrame:SetSize(CHAT_WIDTH, CHAT_HEIGHT)
        self:AnchorBackground(cf, chatFrame)
        self:CreateScrollBar(cf, chatFrame)
        self:CreateEndButton(cf, chatFrame)
        self:WireScrollSync(cf, chatFrame)
        self:WireAddMessage(cf, chatFrame)
        self:SetupEditBox(cf, chatFrame)
        self:ApplyRestAlphas(cf, chatFrame)
    end;

    NormalizeClamp = function(self, chatFrame)
        chatFrame:SetClampedToScreen(false)
        chatFrame:SetClampRectInsets(0, 0, 0, 0)
        -- Inactive slots (e.g. ChatFrame4 when never opened) aren't movable/resizable yet
        -- and SetUserPlaced errors on them.
        if chatFrame:IsMovable() or chatFrame:IsResizable() then
            chatFrame:SetUserPlaced(true)
        end
    end;

    HideNativeButtons = function(self, cf)
        for _, suffix in ipairs({ "UpButton", "DownButton", "BottomButton" }) do
            local btn = GetChild(cf, suffix)
            if btn then
                local b = Button(btn)
                b:SetAlpha(0)
                b:EnableMouse(false)
            end
        end
    end;

    -- Keep Background at original visual size; re-anchor on Blizzard's own updates.
    AnchorBackground = function(self, cf, chatFrame)
        local function apply()
            local bgNative = cf.Background or getglobal(chatFrame:GetName() .. "Background")
            if bgNative then
                local bg = Texture(bgNative)
                bg:ClearAllPoints()
                bg:SetPoint("TOPLEFT",     chatFrame, "TOPLEFT",     -BG_PAD_LEFT,   BG_PAD_TOP)
                bg:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT",  BG_PAD_RIGHT, -BG_PAD_BOTTOM)
            end
        end
        apply()
        if FloatingChatFrame_UpdateBackgroundAnchors and not cf._muiBgHooked then
            cf._muiBgHooked = true
            hooksecurefunc("FloatingChatFrame_UpdateBackgroundAnchors", function(frame)
                if frame == cf then apply() end
            end)
        end
    end;

    CreateScrollBar = function(self, cf, chatFrame)
        local sb = MinimalScrollBar(chatFrame)
        sb:SetWidth(6)
        sb:AlignTop(chatFrame, 2)
        sb:AlignRight(chatFrame, -6)
        sb:SetValue(0)
        sb.upBtn:SetScale(0.85)
        sb.downBtn:SetScale(0.85)
		sb:SetAlpha(ALPHA_REST)

        sb.upBtn.OnClick   = function() chatFrame:ScrollUp();   if cf._muiSyncBar then cf._muiSyncBar() end end
        sb.downBtn.OnClick = function() chatFrame:ScrollDown(); if cf._muiSyncBar then cf._muiSyncBar() end end

        -- Slider: higher value = further up. Invert to SetScrollOffset (0=bottom, max=top).
        sb.OnScroll = function(_, value)
            chatFrame:SetScrollOffset(sb:GetMax() - math.floor(value))
        end

        cf._muiScrollBar = sb
    end;

    CreateEndButton = function(self, cf, chatFrame)
        local atlas = MUI_AtlasRegistry.ScrollbarMinimalProportional
        local btn = Button(chatFrame)
        btn:SetSize(17, 17)
        btn:SetScale(0.85)
		btn:SetAlpha(ALPHA_REST)
        btn:SetStateAtlas(atlas, "ArrowEnd", "ArrowEndDown", "ArrowEnd")
        btn:SetHighlightAtlas(atlas, "ArrowEndOver")
        btn:AlignParentBottomRight(6, -12)
        btn.OnClick = function()
            chatFrame:ScrollToBottom()
            if cf._muiSyncBar then cf._muiSyncBar() end
        end
        -- Anchor the scrollbar's bottom to the end button.
        if cf._muiScrollBar then cf._muiScrollBar:Above(btn, 2) end

        cf._muiEndBtn = btn
    end;

    -- syncBar: call after any scroll change to refresh bar range + thumb and toggle visibility.
    WireScrollSync = function(self, cf, chatFrame)
        local sb  = cf._muiScrollBar
        local btn = cf._muiEndBtn

        local function applyRange(mxLines)
            local hasScroll = (chatFrame:GetNumMessages() or 0) > 1
            cf._muiHasScroll = hasScroll

            sb:SetMinMax(0, math.max(mxLines, 1))
            sb:SetContentSize(VISIBLE_LINES, math.max(mxLines, 1) + VISIBLE_LINES)

            if hasScroll then
                -- Only reset alpha to REST on transition from hidden → shown; otherwise
                -- preserve HOVER alpha (fade hook owns it when mouse is over chat).
                if not sb:IsShown() then
                    sb:Show();  sb:SetAlpha(ALPHA_REST)
                    btn:Show(); btn:SetAlpha(ALPHA_REST)
                end
            else
                sb:Hide()
                btn:Hide()
            end
        end

        local function syncBar()
            local mx = chatFrame:GetMaxScrollLines()
            applyRange(mx)
            if cf._muiHasScroll then
                sb:SetValue(mx - chatFrame:GetScrollOffset())
            end
        end

        chatFrame:HookScript("OnMouseWheel", syncBar)
        cf._muiApplyRange = applyRange
        cf._muiSyncBar    = syncBar

        -- Initial application.
        applyRange(chatFrame:GetMaxScrollLines())
    end;

    WireAddMessage = function(self, cf, chatFrame)
        chatFrame:HookAddMessage(function(frame, ...)
            if frame._muiApplyRange then frame._muiApplyRange(chatFrame:GetMaxScrollLines()) end
        end)
    end;

    -- Ghost = always-visible faint clone of the edit-box border textures, behind the real one.
    SetupEditBox = function(self, cf, chatFrame)
        local nativeEB = getglobal(chatFrame:GetName() .. "EditBox")
        if not nativeEB then return end

        local eb = EditBox(nativeEB)
        eb:ClearAllPoints()
        eb:SetPoint("TOPLEFT",  chatFrame, "BOTTOMLEFT",  -6, -2)
        eb:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 14, -4)

        local ghost = Frame("Frame", chatFrame, chatFrame:GetName() .. "_MUI_EditGhost")
        ghost:ClearAllPoints()
        ghost:SetPoint("TOPLEFT",     eb, "TOPLEFT",     0, 0)
        ghost:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 0, 0)
        ghost:SetAlpha(ALPHA_GHOST)

        for _, region in ipairs(eb:GetRegions()) do
            if region.SetTexture and region:GetTexture() then
                local layer = region:GetDrawLayer()
                local tex = Texture(ghost, nil, layer)
                tex:SetTexture(region:GetTexture())
                tex:SetAllPoints(region)
                tex:SetTexCoord(region:GetTexCoord())
                tex:SetVertexColor(region:GetVertexColor())
            end
        end

        cf._muiEditGhost = ghost
    end;

    -- Hook Blizzard's per-texture rest alpha + tab alpha to match our scrollbar rest alpha.
    ApplyRestAlphas = function(self, cf, chatFrame)
        cf.oldAlpha = ALPHA_REST
        local tab = getglobal(chatFrame:GetName() .. "Tab")
        if tab then tab.noMouseAlpha = ALPHA_REST end
    end;

    -- Fade scrollbar + end button along with Blizzard's chat-texture fade.
    HookFadeAnimations = function(self)
        hooksecurefunc("FCF_FadeInChatFrame", function(frame)
            if frame._muiSyncBar then frame._muiSyncBar() end
            if frame._muiHasScroll and frame._muiScrollBar then
                frame._muiScrollBar:Show()
                frame._muiEndBtn:Show()
                frame._muiScrollBar:FadeIn(0.1, frame._muiScrollBar:GetAlpha(), ALPHA_HOVER)
                frame._muiEndBtn:FadeIn(0.1, frame._muiEndBtn:GetAlpha(),    ALPHA_HOVER)
            end
        end)

        hooksecurefunc("FCF_FadeOutChatFrame", function(frame)
            if frame._muiHasScroll and frame._muiScrollBar then
                frame._muiScrollBar:FadeOut(0.9, frame._muiScrollBar:GetAlpha(), 0)
                frame._muiEndBtn:FadeOut(0.9, frame._muiEndBtn:GetAlpha(),    0)
            end
        end)
    end;
}
