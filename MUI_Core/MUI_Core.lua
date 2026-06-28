-- MUI_Mod: Central module registry
-- Modules extend Module and register themselves, then OnEnable fires on PLAYER_ENTERING_WORLD

MUI_Root = Frame(UIParent)

object "Mod" {

    __init = function(self)
        self._modules = {}

        self._frame = Frame()
        self._frame:RegisterEventHandler("PLAYER_ENTERING_WORLD", function()
            for _, modl in ipairs(self._modules) do
                if not modl._enabled then
                    local ok, err = xpcall(
                        function () modl:OnEnable() end,
                        function(e) return tostring(e) .. "\n" .. debugstack(2, 4, 0) end
                    )
                    if not ok then
                        MUI.Print("|cffff0000ModernUI: Module '" .. modl.name .. "' error: " .. tostring(err) .. "|r")
                    else
                        modl._enabled = true
                    end
                end
            end
        end)
		
		self._frame:RegisterEventHandler("DISPLAY_SIZE_CHANGED", function() self._ApplyScale() end)
		self._frame:RegisterEventHandler("CVAR_UPDATE", function(_, _, cvarName)
			if cvarName == "USE_UISCALE" or 
			   cvarName == "uiScale" or
			   cvarName == "useUiScale" 
			then
				self._ApplyScale()
			end
		end)

    end;
	
	_ApplyScale = function(self)
		if GetCVar("useUiScale") == "1" then
			MUI_Root:SetScale(tonumber(GetCVar("uiScale")) or 1)
		else
			local w, h = GetPhysicalScreenSize()
			if h <= 768 then
				MUI_Root:SetScale(1.0)
			else
				MUI_Root:SetScale(1024 / h)
			end
		end
	end;

    RegisterModule = function(self, module)
        table.insert(self._modules, module)
    end;
	
	RegisterEventHandler = function(self, event, handler)
		self._frame:RegisterEventHandler(event, handler)
	end;
}

class "Module" {
    __init = function(self, name)
        self.name = name or "Unknown"
        MUI_Mod:RegisterModule(self)
    end;

    OnEnable = function(self)
    end;

    OnDisable = function(self)
    end;
}
