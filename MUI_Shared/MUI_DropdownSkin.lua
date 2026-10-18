-- DropdownSkin: retail's dropdown button art (the text holder with the arrow
-- button at its right end, as DropdownSimple draws it) on one of Blizzard's
-- WowStyle1DropdownTemplate buttons.
--
-- Era's template sets its classic art again, by atlas, on every state and
-- size change, so its two textures are made transparent rather than
-- re-textured. Ours are regions of the same button, under its label, and
-- follow the mouse from hooks.

local SHEET = MUI.TEX_BASE .. "dropdown"

-- The text holder on the sheet, its end caps, and the scale it is drawn at.
local HOLDER = { x = 333, y = 11, w = 84, h = 57, cap = 15, scale = 0.45 }
local ARROW_SIZE = 25
local ARROWS = {
    normal  = { 241, 339 },
    hover   = { 241, 451 },
    pressed = { 297, 451 },
}

class "DropdownSkin" : extends "Frame" {

    __init = function(self, native)
        Frame.__init(self, native)
        Texture(native.Background):SetAlpha(0)
        Texture(native.Arrow):SetAlpha(0)

        local cap = HOLDER.cap * HOLDER.scale
        local left = self:_HolderPiece(HOLDER.x, HOLDER.cap)
        left:SetWidth(cap)
        left:AlignParentTopLeft()
        left:AlignParentBottomLeft()
        local right = self:_HolderPiece(HOLDER.x + HOLDER.w - HOLDER.cap, HOLDER.cap)
        right:SetWidth(cap)
        right:AlignParentTopRight()
        right:AlignParentBottomRight()
        local middle = self:_HolderPiece(HOLDER.x + HOLDER.cap, HOLDER.w - 2 * HOLDER.cap)
        middle:FillBetweenH(left, right)

        self._arrow = Texture(self, nil, "ARTWORK")
        self._arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
        self._arrow:AlignParentRight(1)
        self:_SetArrow("normal")

        self:HookScript("OnEnter", function() self:_SetArrow("hover") end)
        self:HookScript("OnLeave", function() self:_SetArrow("normal") end)
        self:HookScript("OnMouseDown", function() self:_SetArrow("pressed") end)
        self:HookScript("OnMouseUp", function()
            self:_SetArrow(self:IsMouseOver() and "hover" or "normal")
        end)
    end;

    -- A full-height column of the text holder, `width` sheet pixels from `x`.
    _HolderPiece = function(self, x, width)
        local piece = Texture(self, nil, "BACKGROUND")
        piece:SetTextureRegion(SHEET, 512, 512, x, HOLDER.y, width, HOLDER.h)
        return piece
    end;

    _SetArrow = function(self, state)
        local at = ARROWS[state]
        self._arrow:SetTextureRegion(SHEET, 512, 512, at[1], at[2], 54, 53)
    end;
}
