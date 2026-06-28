object "TooltipItemHook" {

    __init = function(self)

        self._tooltips = {
            MUI_Tooltip,
            MUI_TooltipComparison1,
            MUI_TooltipComparison2,
            MUI_TooltipItemRef,
            MUI_TooltipItemRefComparison1,
            MUI_TooltipItemRefComparison2
        }

        MUI_TooltipItemRef:HookScript("OnShow", function() MUI_TooltipItemRef:Hide() end)

        self._HookCurrentEquipped()
        self._HookChatItemLinks()
        self:_HookSellPrice()
        self:_HookItemLevel()

        for _, t in ipairs(self._tooltips) do
          t:SetScript("OnTooltipAddMoney", nil)
        end

    end;

    _HookChatItemLinks = function(self)
        for i = 1, NUM_CHAT_WINDOWS do
            local cf = _G["ChatFrame" .. i]
            if cf then
                cf:HookScript("OnHyperlinkEnter", function(frame, link)
                    if link and link:sub(1, 5) == "item:" then
                        MUI_Tooltip:ShowFor(MUI_Root, "ANCHOR_CURSOR", function(tooltip)
                            tooltip:SetHyperlink(link)
                        end)
                    end
                end)
                cf:HookScript("OnHyperlinkLeave", function()
                    MUI_Tooltip:Hide()
                end)
            end
        end
    end;

    _HookItemLevel = function(self)
        for i, tooltip in pairs(self._tooltips) do
            tooltip:HookScript("OnTooltipSetItem", function()
                local _, link = tooltip:GetItem()
                if not link then return end
                local _, _, _, ilvl, _, _, _, _, equipLoc, _, _, classID, subclassID = GetItemInfo(link)

                if classID == 7 then
                    tooltip:InsertLine(2, "Crafting Reagent", 0.38, 0.68, 0.95)
                    return
                end

                if not ilvl or ilvl <= 1 then return end
                if not equipLoc
                    or equipLoc == ""
                    or equipLoc == "INVTYPE_NON_EQUIP_IGNORE"
                then return end
                tooltip:InsertLine(2, "Item level: " .. ilvl, 1, 0.82, 0)
                tooltip:Show()
            end)
        end
    end;

    _HookSellPrice = function(self)
        for i, tooltip in pairs(self._tooltips) do
            -- One sell-price line per tooltip session. AH (and a few other
            -- code paths) fire OnTooltipSetItem twice when the rendered
            -- tooltip embeds a child item — e.g. a recipe scroll showing
            -- its produced item below. Without this flag we'd append the
            -- "Selling price:" line for BOTH items.
            tooltip:HookScript("OnTooltipCleared", function()
                tooltip._mui_sellPriceAdded = false
            end)
            tooltip:HookScript("OnTooltipSetItem", function ()
                if tooltip._mui_sellPriceAdded then return end
                local _, link = tooltip:GetItem()
                if not link then return end
                local sellPrice = select(11, GetItemInfo(link))
                if not sellPrice or sellPrice <= 0 then return end
                tooltip:AddLine("Selling price:   " .. GetCoinTextureString(sellPrice), 1, 1, 1)
                tooltip._mui_sellPriceAdded = true
                tooltip:Show()
            end)
        end
    end;

    _HookCurrentEquipped = function(self)

        --tooltip:InsertLine(2, "Pidor suka", 1, 0.82, 0, false)

        local tooltips = {
            MUI_TooltipComparison1,
            MUI_TooltipComparison2,
            MUI_TooltipItemRefComparison1,
            MUI_TooltipItemRefComparison2
        }

        local function remove(tooltip)
            tooltip:RemoveLine(1)
            local L, R = tooltip:GetLine(1)
            if L then
                local _, _, lFlags = L:GetFont()
                L:SetFont(MUI.FONT, 13, lFlags)
            end

            if R then
                local _, _, rFlags = R:GetFont()
                R:SetFont(MUI.FONT, 13, rFlags)
            end
        end

        for i, tooltip in pairs(tooltips) do
            tooltip:HookScript("OnTooltipSetItem", function()
                remove(tooltip)
            end)


            local badge = NineSlice(tooltip)
            badge:Above(tooltip, -1)
            badge:AlignLeft(tooltip)
            badge:SetFromTextureRegion("tooltiplabel", 128, 32, 16, 0, 96, 31, 8, 8, 8, 4, 0.75)

            local text = FontString(badge, nil, "OVERLAY")
            text:SetText("Currently equipped")
            text:SetTextColor(1, 0.82, 0, 1)
            text:SetFontSize(10.5)
            text:CenterInParent(0, -1)
            text:SetJustifyH("CENTER")

            badge:SetSize(text:GetStringWidth() + 20, 20)


        end

        local function topAlign(tt)
            if not tt or not tt:IsShown() then return end
            local n = tt:GetNumPoints()
            if n == 0 then return end
            local pts = {}
            for i = 1, n do
                pts[i] = { tt:GetPoint(i) }   -- { point, relTo, relPoint, x, y }
            end
            tt:ClearAllPoints()
            for _, p in ipairs(pts) do
                local point, relTo, relPoint, x, y = p[1], p[2], p[3], p[4], p[5]
                if point and point:find("^TOP") then y = 0 end   -- strip the -10
                tt:SetPoint(point, relTo, relPoint, x, y)
            end
        end

        hooksecurefunc("GameTooltip_AnchorComparisonTooltips", function(_, _, t1, t2, p1Shown, p2Shown)
            if p1Shown then topAlign(t1) end
            if p2Shown then topAlign(t2) end
        end)

    end;

}