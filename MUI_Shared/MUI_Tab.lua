-- TabBase: Abstract base for tab buttons

class "TabBase" : extends "SecureButton" {
    __init = function(self, parent, name, text, wMin, wMax, padding, direction)
        SecureButton.__init(self, parent, name, "SecureHandlerAttributeTemplate")

        self:SetAttribute("active", false)

        self._widthMin = wMin or 80
        self._widthMax = wMax or 140
        self._padding = padding or 24

        self:SetWidth(self._widthMin)

        self._labelHolder = SecureFrame(self)
        self._labelHolder:CenterInParent(0, 0)

        self._label = FontString(self._labelHolder, nil, "OVERLAY")
        self._label:SetFontSize(10)
        self._label:SetTextColor(1, 0.82, 0, 1)
        self._label:CenterInParent()
        self._label:SetShadowOffset(1, -1)

        self._direction = direction or "bottom"

        if text then
            self:SetText(text)
        end
    end;

    SetText = function(self, text)
        self._label:SetText(text or "")
        local w = self._label:GetStringWidth() + 2 * self._padding
        if w < self._widthMin then w = self._widthMin end
        if w > self._widthMax then w = self._widthMax end
        self:SetWidth(w)
    end;

    SetActive = function(self, active)
        self:SetAttribute("active", active)
    end;

    IsActive = function(self)
        return self:GetAttribute("active")
    end;
}

-- TabOptions: Options-panel style tab with three-part atlas texture

class "TabOptions" : extends "TabBase" {
    __init = function(self, parent, name, text, wMin, wMax, padding, direction)
        TabBase.__init(self, parent, name, text, wMin, wMax, padding, direction)

        local atlas = MUI_AtlasRegistry.TabOptions

        self._texLeft = Texture(self, nil, "BACKGROUND")
        self._texLeft:SetAtlas(atlas, "TabLeft")
        self._texLeft:AlignParentTop()
        self._texLeft:AlignParentBottomLeft()

        self._texRight = Texture(self, nil, "BACKGROUND")
        self._texRight:SetAtlas(atlas, "TabRight")
        self._texRight:AlignParentTop()
        self._texRight:AlignParentBottomRight()

        self._texMiddle = Texture(self, nil, "BACKGROUND")
        self._texMiddle:SetAtlas(atlas, "TabMiddle", true)
        self._texMiddle:RightOf(self._texLeft, 0)
        self._texMiddle:LeftOf(self._texRight, 0)
        self._texMiddle:AlignParentTop()
        self._texMiddle:AlignBottom(self._texLeft)

        self._labelHolder:ClearAllPoints()
        self._labelHolder:CenterInParent(0, -2)

        self:SetAttribute("_onattributechanged", [[ -- (self, name, value)
            if name == "active" then
                if value then
                    self:SetHeight(26)
                else
                    self:SetHeight(23)
                end
            end
        ]]);

        self:HookScript("OnAttributeChanged", function(attrName, attrValue)
            if attrName == "active" then
                if attrValue then
                    self._texLeft:SetAtlas(atlas, "TabLeftActive")
                    self._texRight:SetAtlas(atlas, "TabRightActive")
                    self._texMiddle:SetAtlas(atlas, "TabMiddleActive", true)
                    self._label:SetTextColor(1, 1, 1, 1)
                else
                    self._texLeft:SetAtlas(atlas, "TabLeft")
                    self._texRight:SetAtlas(atlas, "TabRight")
                    self._texMiddle:SetAtlas(atlas, "TabMiddle", true)
                    self._label:SetTextColor(1, 0.82, 0, 1)
                end
            end
        end)

        self:SetActive(false)
    end;
}

class "TabFrame" : extends "TabBase" {
    __init = function(self, parent, name, text, wMin, wMax, padding, direction)
        TabBase.__init(self, parent, name, text, wMin, wMax, padding, direction)

        local atlas = MUI_AtlasRegistry.TabBottom

        self._texLeft = Texture(self, nil, "BACKGROUND")
        self._texLeft:SetAtlas(atlas, "TabLeft")
        self._texLeft:AlignParentTopLeft()
        self._texLeft:AlignParentBottom()

        self._texRight = Texture(self, nil, "BACKGROUND")
        self._texRight:SetAtlas(atlas, "TabRight")
        self._texRight:AlignParentTopRight()
        self._texRight:AlignParentBottom()

        self._texMiddle = Texture(self, nil, "BACKGROUND")
        self._texMiddle:SetAtlas(atlas, "TabMiddle", true)
        self._texMiddle:RightOf(self._texLeft, 0)
        self._texMiddle:LeftOf(self._texRight, 0)
        self._texMiddle:AlignTop(self._texLeft)
        self._texMiddle:AlignParentBottom()

        self._hlLeft = Texture(self, nil, "HIGHLIGHT")
        self._hlLeft:SetAtlas(atlas, "TabLeft")
        self._hlLeft:Fill(self._texLeft)
        self._hlLeft:SetBlendMode("ADD")
        self._hlLeft:SetAlpha(0.4)

        self._hlRight = Texture(self, nil, "HIGHLIGHT")
        self._hlRight:SetAtlas(atlas, "TabRight")
        self._hlRight:Fill(self._texRight)
        self._hlRight:SetBlendMode("ADD")
        self._hlRight:SetAlpha(0.4)

        self._hlMiddle = Texture(self, nil, "HIGHLIGHT")
        self._hlMiddle:SetAtlas(atlas, "TabMiddle", true)
        self._hlMiddle:Fill(self._texMiddle)
        self._hlMiddle:SetBlendMode("ADD")
        self._hlMiddle:SetAlpha(0.4)

        self._label:SetFontSize(9)
        self._labelHolder:ClearAllPoints()
        self._labelHolder:CenterInParent(-2, 4)

        self:SetScript("OnEnter", function()
            self._label:SetTextColor(1, 1, 1, 1)
        end)

        self:SetScript("OnLeave", function()
            if self:IsActive() then
                self._label:SetTextColor(1, 1, 1, 1)
            else
                self._label:SetTextColor(1, 0.82, 0, 1)
            end
        end)

        local yU = self._direction == "bottom" and 2 or -5
        local yD = self._direction == "bottom" and 4 or -5

        self:SetFrameRef("label", self._labelHolder)
        self:SetAttribute("_onattributechanged", string.format([[ -- (self, name, value)
            if name == "active" then
                local label = self:GetFrameRef("label")
                label:ClearAllPoints()
                if value then
                    self:SetHeight(36)
                    label:SetPoint("CENTER", self, "CENTER", -2, %d)
                else
                    self:SetHeight(31)
                    label:SetPoint("CENTER", self, "CENTER", -2, %d)
                end
            end
        ]], yU, yD));

        self:HookScript("OnAttributeChanged", function(_, attrName, attrValue)
            if attrName == "active" then
                if attrValue then
                    self._texLeft:SetAtlas(atlas, "TabLeftActive")
                    self._texRight:SetAtlas(atlas, "TabRightActive")
                    self._texMiddle:SetAtlas(atlas, "TabMiddleActive", true)
                    self._hlLeft:SetAtlas(atlas, "TabLeftActive")
                    self._hlRight:SetAtlas(atlas, "TabRightActive")
                    self._hlMiddle:SetAtlas(atlas, "TabMiddleActive", true)
                    self._label:SetTextColor(1, 1, 1, 1)
                else
                    self._texLeft:SetAtlas(atlas, "TabLeft")
                    self._texRight:SetAtlas(atlas, "TabRight")
                    self._texMiddle:SetAtlas(atlas, "TabMiddle", true)
                    self._hlLeft:SetAtlas(atlas, "TabLeft")
                    self._hlRight:SetAtlas(atlas, "TabRight")
                    self._hlMiddle:SetAtlas(atlas, "TabMiddle", true)
                    self._label:SetTextColor(1, 0.82, 0, 1)
                end
                self:_ApplyDirection()
            end
        end)

        self:SetActive(false)

    end;

    _ApplyDirection = function(self)
        local function apply(tex)
            local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = tex:GetTexCoord()
            if self._direction == "top" then
                tex:SetTexCoord(LLx, LLy, ULx, ULy, LRx, LRy, URx, URy)
            elseif self._direction == "right" then
                tex:SetTexCoord(LLx, LLy, LRx, LRy, ULx, ULy, URx, URy)
            elseif self._direction == "left" then
                tex:SetTexCoord(URx, URy, ULx, ULy, LRx, LRy, LLx, LLy)
            end
        end
        apply(self._texLeft)
        apply(self._texMiddle)
        apply(self._texRight)
        apply(self._hlLeft)
        apply(self._hlMiddle)
        apply(self._hlRight)
    end;
}
