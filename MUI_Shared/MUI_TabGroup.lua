-- TabGroup: Manages a group of tabs with radio-button selection

class "TabGroup" : extends "SecureFrame" {
    __init = function(self, parent, name, tabClass, direction, tabPadding)
        SecureFrame.__init(self, parent, name, "Frame", "SecureHandlerAttributeTemplate")
        self._direction = direction or "bottom"
        self._tabClass = tabClass or TabOptions
        self._tabPadding = tabPadding or 100
        self._silent = true
        self._tabs = {}
        
        self:HookScript("OnAttributeChanged", function(_, attrName, attrValue)
            if attrName == "index" then

                if not self._silent then
                    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
                end

                if self.OnTabSelected then
                    self:OnTabSelected(attrValue)
                end
            end
        end)

    end;

    GetNumTabs = function(self)
        return #self._tabs
    end;

    GetTab = function(self, index)
        return self._tabs[index]
    end;

    SetSilent = function(self, silent)
        self._silent = silent
    end;

    SetActiveIndex = function(self, index)
        self:SetAttribute("index", index)
    end;

    GetActiveIndex = function(self)
        return self:GetAttribute("index")
    end;

    -- _direction governs which edge of the parent the row/column hugs and
    -- which tab edge is shared (so the active tab grows away from that edge):
    --   "top"    — row along parent's BOTTOM, tab bottoms aligned, active grows UP
    --   "bottom" — row along parent's TOP,    tab tops aligned,    active grows DOWN
    --   "left"   — column along parent's RIGHT, tab rights aligned, active grows LEFT
    --   "right"  — column along parent's LEFT,  tab lefts aligned,  active grows RIGHT
    _AnchorFirst = function(self, tab)
        local dir = self._direction
        if     dir == "bottom" then tab:AlignParentTopLeft()
        elseif dir == "left"   then tab:AlignParentTopRight()
        elseif dir == "right"  then tab:AlignParentTopLeft()
        else                        tab:AlignParentBottomLeft()  -- "top" default
        end
    end;

    _AnchorAfter = function(self, tab, prev)
        local dir = self._direction
        local padding = self._tabPadding
        if dir == "bottom" then
            tab:AlignTop(prev)
            tab:RightOf(prev, padding)
        elseif dir == "left" then
            tab:AlignRight(prev)
            tab:Below(prev, padding)
        elseif dir == "right" then
            tab:AlignLeft(prev)
            tab:Below(prev, padding)
        else  -- "top" default
            tab:AlignBottom(prev)
            tab:RightOf(prev, padding)
        end
    end;

    AddTab = function(self, name, text, page, wMin, wMax, padding)

        if page then
            page:Hide()
        end

        local index = #self._tabs + 1
        local tab = self._tabClass(self, name, text, wMin, wMax, padding, self._direction)

        tab:SetFrameRef("group", self)
        tab:SetOnClick(string.format([[ -- (self)
            local newIndex = %d
            local oldIndex = group:GetAttribute("index")

            if oldIndex ~= newIndex then
                group:SetAttribute("index", newIndex)
            end
        ]], index))

        self._tabs[index] = tab

        self:SetFrameRef("tab" .. index, tab)
        self:SetFrameRef("page" .. index, page)
        self:SetAttribute("_onattributechanged", string.format([[ -- (self, name, value)
            if name == "index" then
                for i=1, %d do 
                    self:GetFrameRef("tab" .. i):SetAttribute("active", i == value)
                    local page = self:GetFrameRef("page" .. i)
                    if page then
                        if i == value then
                            page:Show()
                        else
                            page:Hide()
                        end
                    end
                end
            end
        ]], index))

        if index == 1 then
            self:_AnchorFirst(tab)
            self:SelectTab(1)
        else
            self:_AnchorAfter(tab, self._tabs[index - 1])
        end

        return tab
    end;

    -- Hide every tab and park it in _pool by text. Reset selection state.
    -- Next AddTab(text, …) with a pooled text reuses the same native frame
    -- (since WoW has no frame-destroy API). Call before rebuilding the tab
    -- set on data changes (e.g., player learned a new profession).
    ClearTabs = function(self)
        for _, tab in ipairs(self._tabs) do
            tab:Hide()
            tab:ClearAllPoints()
            tab:SetAttribute("_onclick", "")
        end
        self._tabs = {}
        self:SetAttribute("_onattributechanged", "")
        self:SetActiveIndex(nil)
    end;

    SelectTab = function(self, index)

        local oldIndex = self:GetActiveIndex()
        local newIndex = index

        if oldIndex == newIndex then
            return
        end

        self:SetActiveIndex(newIndex)
    end;

}
