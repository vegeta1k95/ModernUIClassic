-- Chat command system

class "ChatCommand" {
    __init = function(self, name, handler)
        self.name = name
        self.handler = handler

        SlashCmdList[strupper(name)] = function(msg)
            self:handler(msg)
        end
        setglobal("SLASH_" .. strupper(name) .. "1", "/" .. name)
    end;

    AddAlias = function(self, alias)
        local key = "SLASH_" .. strupper(self.name)
        local i = 2
        while getglobal(key .. i) do
            i = i + 1
        end
        setglobal(key .. i, "/" .. alias)
    end;
}

-- /reload command
ChatCommand("reload", function(self, msg)
    ReloadUI()
end)
