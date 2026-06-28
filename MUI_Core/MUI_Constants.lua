-- MUI_Constants: addon-wide string constants. Loaded right after MUI_Lua so
-- everything that follows can reference MUI.FONT / MUI.TEX_* without redefining
-- the same paths in 13 different files.
--
-- TEX_BASE points at the assets/textures root. TEX_SKIN is the per-module skin
-- subtree — module files concatenate their own subfolder, e.g.:
--   local TEX = MUI.TEX_SKIN .. "unitframes\\"

MUI = MUI or {}

MUI.FONT_CAL  = "Interface\\AddOns\\ModernUI\\assets\\fonts\\morpheus_cyr.ttf"
MUI.FONT      = "Interface\\AddOns\\ModernUI\\assets\\fonts\\frizqt___cyr.ttf"
MUI.TEX_BASE  = "Interface\\AddOns\\ModernUI\\assets\\textures\\"
MUI.TEX_ICON  = "Interface\\AddOns\\ModernUI\\assets\\textures\\icons\\"
MUI.TEX_SKIN  = MUI.TEX_BASE .. "skin\\"

-- Print to the default chat frame. Lazy-wraps DEFAULT_CHAT_FRAME on first
-- use (ChatFrame class is loaded later in the .toc). Use this for all
-- addon-side logging so module files never touch DEFAULT_CHAT_FRAME directly.
local _defaultChat
MUI.Print = function(msg)
    if not _defaultChat then
        _defaultChat = ChatFrame(DEFAULT_CHAT_FRAME)
    end
    _defaultChat:AddMessage(msg)
end

MUI.PrintTable = function(tbl, indentation)
    indentation = indentation or 0
    local pad = string.rep("    ", indentation)
    MUI.Print(pad .. "{")
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            MUI.Print(pad .. "    " .. tostring(k) .. " =")
            MUI.PrintTable(v, indentation + 1)
        else
            MUI.Print(pad .. "    " .. tostring(k) .. " = " .. tostring(v))
        end
    end
    MUI.Print(pad .. "}")
end
