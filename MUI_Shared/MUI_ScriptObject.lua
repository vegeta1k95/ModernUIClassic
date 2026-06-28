-- ScriptObject: shared SetScript/HookScript wrappers. Mixed into Frame
-- (Widget already has SetScript/GetScript; HookScript/HasScript come from
-- here). Raw ._native: calls are intentional — this IS the wrapper layer.

class "ScriptObject" {
    __init = function(self)
    end;

    SetScript = function(self, name, func)
        self._native:SetScript(name, func)
    end;

    GetScript = function(self, name)
        return self._native:GetScript(name)
    end;

    HookScript = function(self, name, func)
        self._native:HookScript(name, func)
    end;

    HasScript = function(self, name)
        return self._native:HasScript(name)
    end;
}
