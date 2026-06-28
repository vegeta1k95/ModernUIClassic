-- Profession rank bar (retail-style, Era-compatible). Era exposes no
-- MaskTexture API to clip the fill softly, and the StatusBar's internal
-- value-based TexCoord clipping fights with the flipbook's own TexCoord
-- cycling — so both the frame ticking AND the progress crop are done
-- manually here via SetTexCoord + SetWidth on a single plain Texture.
--
-- Layers:
--   * bg     — skillbar-bg slice of professions.tga (fills the frame).
--   * fill   — per-profession flipbook atlas; width = barWidth*ratio,
--              TexCoord = (current frame UVs, cropped right by ratio).
--   * flare  — red placeholder, anchored to fill's right (leading) edge.
--              Hidden at 100%.
--   * border — skillbar-frame slice (OVERLAY).
-- The 60-frame "pulse" restarts on profession switch or skill change.

local TEX = MUI.TEX_SKIN .. "professions\\tradeskill\\"
local PROFESSIONS_ATLAS = MUI.TEX_SKIN .. "professions\\professions"

class "ProfessionsRankBar" : extends "Frame" {

    -- Per-profession atlas info: { texturePath, atlasW, atlasH }.
    -- All atlases pack the same 30-row × 2-col grid; cooking/fishing just
    -- ship a tighter half-height sheet (2048×1024 vs 2048×2048).
    _RANK_FILL_ATLAS = {
        ALCHEMY        = { TEX .. "tradeskill-fill-alchemy",        2048, 2048 },
        BLACKSMITHING  = { TEX .. "tradeskill-fill-blacksmithing",  2048, 2048 },
        COOKING        = { TEX .. "tradeskill-fill-cooking",        2048, 1024 },
        FIRST_AID      = { TEX .. "tradeskill-fill-inscription",    2048, 2048 },
        ENCHANTING     = { TEX .. "tradeskill-fill-enchanting",     2048, 2048 },
        ENGINEERING    = { TEX .. "tradeskill-fill-engineering",    2048, 2048 },
        FISHING        = { TEX .. "tradeskill-fill-fishing",        2048, 1024 },
        HERBALISM      = { TEX .. "tradeskill-fill-herbalism",      2048, 2048 },
        LEATHERWORKING = { TEX .. "tradeskill-fill-leatherworking", 2048, 2048 },
        MINING         = { TEX .. "tradeskill-fill-mining",         2048, 2048 },
        SKINNING       = { TEX .. "tradeskill-fill-skinning",       2048, 2048 },
        TAILORING      = { TEX .. "tradeskill-fill-tailoring",      2048, 2048 },
    },

    -- Atlas frame layout (pixel coords):
    --   Cell (854×33). Origin at (2,2). Padding 1 px between rows,
    --   2 px between columns. 30 rows × 2 cols = 60 frames per atlas.
    --   Iteration is row-major (frame index advances col first, then row).
    _FILL_FRAME_W   = 854,
    _FILL_FRAME_H   = 33,
    _FILL_PAD_X     = 2,
    _FILL_PAD_Y     = 1,
    _FILL_ORIGIN_X  = 2,
    _FILL_ORIGIN_Y  = 2,

    __init = function(self, parent)
        Frame.__init(self, "Frame", parent)
        self:SetSize(400, 22.5)

        -- Background (skillbar-bg slice of professions.tga).
        local bg = Texture(self, nil, "ARTWORK")
        bg:SetDrawLayer("ARTWORK", 1)
        bg:SetColorTexture(1, 0, 0, 1)
        bg:SetTextureRegion(PROFESSIONS_ATLAS, 2048, 1024, 610, 768, 452, 26)
        bg:FillParentPadding(-2, 0, -3, 0)

        -- Fill — plain Texture; width and TexCoord are both driven
        -- manually so one flipbook frame shows at a time and the right
        -- edge tracks `progress` without any soft mask (Era can't do it).
        self._rankFill = Texture(self, nil, "ARTWORK")
        self._rankFill:SetDrawLayer("ARTWORK", 2)
        self._rankFill:AlignParentLeft(3)
        self._rankFill:AlignParentTop(4)
        self._rankFill:AlignParentBottom(3)
        self._rankFill:SetWidth(0)

        -- Flare — red placeholder; anchored to the fill's right edge so
        -- it sits at the leading edge of the progress.
        self._rankFlare = Texture(self, nil, "ARTWORK")
        self._rankFlare:SetDrawLayer("ARTWORK", 3)
        self._rankFlare:SetSize(54, 14)
        self._rankFlare:AlignRight(self._rankFill)
        self._rankFlare:SetBlendMode("ADD")

        -- Border (skillbar-frame slice of professions.tga, sits on top).
        local border = Texture(self, nil, "OVERLAY")
        border:SetDrawLayer("OVERLAY", 1)
        border:SetTextureRegion(PROFESSIONS_ATLAS, 2048, 1024, 1362, 132, 445, 26)
        border:FillParent()
        border:SetSubpixelRendering(true)

        -- Rank text (centred).
        self._rankText = FontString(self, nil, "OVERLAY")
        self._rankText:SetFont(MUI.FONT, 10, "")
        self._rankText:SetShadowOffset(1, -1)
        self._rankText:SetDrawLayer("OVERLAY", 7)
        self._rankText:CenterInParent()
        self._rankText:SetText("")

        -- Manual flipbook state. 30 rows × 2 cols = 60 frames, 854×33 cells
        -- at origin (2,2) with 1 px padding (see _ApplyRankFill). One-shot
        -- pulse: OnUpdate advances _animFrame at perFrame intervals until
        -- the last frame, then holds. Restarted on profession switch or
        -- skill change.
        self._animActive  = false
        self._animFrame   = 0
        self._animElapsed = 0
        self._fillCols    = 2
        self._fillRows    = 30
        self._fillTotal   = 60
        self._fillDur     = 1.5

        self:SetScript("OnUpdate", function(_, elapsed)
            if not self._animActive then return end
            self._animElapsed = self._animElapsed + elapsed
            local perFrame = self._fillDur / self._fillTotal
            local advanced = false
            while self._animElapsed >= perFrame do
                self._animElapsed = self._animElapsed - perFrame
                self._animFrame = self._animFrame + 1
                advanced = true
                if self._animFrame >= self._fillTotal then
                    self._animFrame = self._fillTotal - 1   -- hold last frame
                    self._animActive = false
                    break
                end
            end
            if advanced then self:_ApplyRankFill() end
        end)

        self:Hide()

        self._lastProfKey = nil
        self._lastRatio   = nil
    end;

    -- Apply current animation frame + progress ratio to the fill:
    -- compute pixel rect for the cell, convert to UVs against the active
    -- atlas's pixel dimensions, crop u1 by ratio, set texture width to
    -- barWidth*ratio so visible content matches cropped UVs without
    -- stretching.
    _ApplyRankFill = function(self)
        local fr      = self._animFrame
        local cols    = self._fillCols
        local rows    = self._fillRows
        local atlasW  = self._fillAtlasW or 2048
        local atlasH  = self._fillAtlasH or 2048
        local ratio   = self._lastRatio or 0

        local col = fr % cols
        local row = math.floor(fr / cols)

        local strideX = self._FILL_FRAME_W + self._FILL_PAD_X
        local strideY = self._FILL_FRAME_H + self._FILL_PAD_Y
        local x0 = self._FILL_ORIGIN_X + col * strideX
        local y0 = self._FILL_ORIGIN_Y + row * strideY
        local x1 = x0 + self._FILL_FRAME_W
        local y1 = y0 + self._FILL_FRAME_H

        local u0 = x0 / atlasW
        local u1 = x1 / atlasW
        local v0 = y0 / atlasH
        local v1 = y1 / atlasH

        local u1Crop = u0 + (u1 - u0) * ratio
        local w = self:GetWidth() * ratio - 6

        self._rankFill:SetTexCoord(u0, u1Crop, v0, v1)
        self._rankFill:SetWidth(w)

        self._rankFlare:SetWidth(math.min(54, w))
    end;

    Update = function(self, activeState, profName)
        local skill    = activeState and activeState.rank or 0
        local maxSkill = activeState and activeState.maxRank or 0
        local profKey  = activeState and activeState.def.key or nil

        if not profKey or maxSkill <= 0 then
            self:Hide()
            self._lastProfKey = nil
            self._lastRatio   = nil
            self._animActive  = false
            return
        end
        self:Show()

        local title = activeState and activeState.title or ""
        if title ~= "" then
            self._rankText:SetText(title .. " " .. (profName or "") .. " " .. skill .. "/" .. maxSkill)
        else
            self._rankText:SetText(skill .. "/" .. maxSkill)
        end

        local profChanged = self._lastProfKey ~= profKey
        if profChanged then
            local info = self._RANK_FILL_ATLAS[profKey]
            if info then
                self._rankFlare:SetTextureRegion(info[1], info[2], info[3], 1713, 0, 54, 35)
                self._rankFill:SetTexture(info[1])
                self._fillAtlasW = info[2]
                self._fillAtlasH = info[3]
            end
            self._lastProfKey = profKey
        end

        local ratio = math.min(skill / maxSkill, 1)
        local ratioChanged = self._lastRatio ~= ratio
        self._lastRatio = ratio

        -- One-shot pulse: restart on profession switch or skill change.
        if profChanged or ratioChanged then
            self._animFrame   = 0
            self._animElapsed = 0
            self._animActive  = true
        end

        self:_ApplyRankFill()
        self._rankFlare:SetAlpha(ratio >= 1 and 0 or 1)
    end;
}
