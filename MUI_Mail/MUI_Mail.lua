-- Reskin Era's MailFrame + OpenMailFrame (both ButtonFrameTemplate) to retail's
-- modern PortraitFrameTemplate chrome via MUI_PanelChrome (portrait-metal nineslice + tiled rock body + TopTileStreaks + modern X).
-- We keep the native frames and their logic; only the visuals change.

object "ModuleMail" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Mail")
    end;

    OnEnable = function(self)
        -- Era's native MailFrame title path is dead (and our border covers the low
        -- title FontString), so set it explicitly. Inbox / Send Mail follow the
        -- selected tab; OpenMail is static.
        self:_Reskin(MailFrame, function() self:_UpdateMailTitle() end)
        self:_Reskin(OpenMailFrame, function() MUI_PanelChrome:SetTitle(OpenMailFrame, OPENMAIL) end)

        if MailFrame and MailFrameTab_OnClick then
            hooksecurefunc("MailFrameTab_OnClick", function() self:_UpdateMailTitle() end)
        end
    end;

    _UpdateMailTitle = function(self)
        if not MailFrame then return end
        local tab = MailFrame.selectedTab or 1
        MUI_PanelChrome:SetTitle(MailFrame, tab == 1 and INBOX or SENDMAIL)
    end;

    _Reskin = function(self, native, setTitle)
        if not native then return end
        local frame = Frame(native)

        local function apply()
            MUI_PanelChrome:Apply(native)

            -- Era's loose "Mail-Icon" OVERLAY texture (MailFrame.xml:267) — replaced
            -- by the portrait ring icon below; hide it.
            for _, r in ipairs(frame:GetRegions()) do
                if r.GetTexture then
                    local tex = r:GetTexture()
                    if type(tex) == "string" and tex:lower():find("mail%-icon") then
                        r:Hide()
                    end
                end
            end

            -- Mail icon in the portrait ring (retail MailFrame.lua:21).
            frame:SetPortraitToAsset("Interface\\MailFrame\\Mail-Icon")

            if setTitle then setTitle() end
        end

        apply()
        frame:HookScript("OnShow", apply)
    end;
}
