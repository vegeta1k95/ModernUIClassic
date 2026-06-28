
local function AddTemplate(string, template)
    if template then
        return string .. ", " .. template
    end
    return string
end

class "SecureFrame" : extends "Frame" {

    __init = function(self, parent, name, type, template)
        Frame.__init(self, type or "Frame", parent, name, AddTemplate("SecureHandlerBaseTemplate", template))
        self._references = ""
    end;

    SecureExecute = function(self, body)
        self._native:Execute(self._references .. body)
    end;

    SecureWrapScript = function(self, header, script, preBody, postBody)
        self._native:WrapScript(header._native, script, self._references .. preBody, self._references .. postBody)
    end;

    SecureUnwrapScript = function(self, frame, script)
        self._native:UnwrapScript(frame, script)
    end;

    SetFrameRef = function(self, id, frame)
        if frame then
            self._native:SetFrameRef(id, frame._native)
            self._references = self._references .. string.format([[local %s = self:GetFrameRef("%s")]], id, id);
        end
        
    end;
}

class "SecureButton" : extends {"SecureFrame", "Button"} {

    __init = function(self, parent, name, template)
        SecureFrame.__init(self, parent, name, "Button", AddTemplate("SecureHandlerClickTemplate", template))
        self:EnableMouse(true)
        self:RegisterForClicks("AnyUp")
        self._enabled = true
    end;

    ---@nocombat
    SetOnClick = function(self, body)
        self:SetAttribute("_onclick", self._references .. body)
    end;

}

class "SecureActionButton" : extends {"SecureFrame", "Button"} {

    __init = function(self, parent, name, template)
        SecureFrame.__init(self, parent, name, "Button", AddTemplate("SecureActionButtonTemplate", template))
        self:EnableMouse(true)
        self:RegisterForClicks("AnyUp")
        self:SetEnabled(true)
    end;

    ---@nocombat
    SetMacroText = function(self, text)
        self:SetAttribute("type", "macro")
        self:SetAttribute("macrotext", text)
    end;
}