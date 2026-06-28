-- MUI_DebugLog: copyable debug log pane.
--
-- Use during development when you need to inspect runtime state but the
-- chat frame is too noisy / can't be selected for copy. Floating frame
-- with a multi-line EditBox; calls to MUI_Dbg(msg) append to it. To
-- copy: click into the box, Ctrl+A, Ctrl+C. Drag the title bar area to
-- reposition; close button at top-right; Clear button at bottom.
--
-- Usage:
--   MUI_Dbg("foo: " .. tostring(x))
--   MUI_Dbg(("rect=%dx%d eff=%.3f"):format(w, h, scale))
--
-- Re-show after closing:  /run MUI_DebugLogFrame:Show()

local _LOG, _FRAME = "", nil

local function _ensureFrame()
    if _FRAME then return _FRAME end
    local f = CreateFrame("Frame", "MUI_DebugLogFrame", UIParent, "BackdropTemplate")
    f:SetSize(720, 360)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 24,
        insets   = { left = 6, right = 6, top = 6, bottom = 6 },
    })

    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     12, -12)
    sf:SetPoint("BOTTOMRIGHT", -32,  36)

    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(680)
    eb:SetAutoFocus(false)
    sf:SetScrollChild(eb)
    f._eb = eb

    local clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clear:SetSize(60, 18)
    clear:SetPoint("BOTTOMRIGHT", -30, 14)
    clear:SetText("Clear")
    clear:SetScript("OnClick", function() _LOG = ""; eb:SetText("") end)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() f:Hide() end)

    _FRAME = f
    return f
end

function MUI_Dbg(msg)
    _LOG = _LOG .. tostring(msg) .. "\n"
    local f = _ensureFrame()
    f._eb:SetText(_LOG)
end
