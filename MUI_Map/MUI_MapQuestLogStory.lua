-- MUI_MapQuestLogStory: retail's "zone story" banner for the map quest log.
--
-- Retail (QuestMapFrame's StoryHeader) tops the quest list of the displayed
-- zone with a banner — zone name over "x/y Chapters" on the StoryHeader-BG
-- parchment strip, an ornate divider across its top — and lists the
-- chapters with check marks in a tooltip. Same art (skin\worldmap\
-- storyheader, cut from retail's questmaplogatlas / questlogframe2x /
-- ScenarioIcon-Check) and same geometry here. Classic has no zone story
-- achievements, so the chapters come from MUI_StorylineDB: the zone's
-- quests grouped by hand into storylines and hubs (tools/storylines/).
-- On top of retail's banner + tooltip, the banner expands into the chapter
-- list and each chapter into its quest steps, so a chapter's contents can
-- be read right in the log.
--
--   ══════════════════════════════════════════════
--   │ Redridge Mountains                       │ ← QuestLogStory (banner)
--   │ 2/5 Chapters                             │
--   └──────────────────────────────────────────┘
--     ▸ Solomon's Plea                     3/3   ← QuestLogStoryChapter
--     ▾ Lakeshire                          4/11
--         ✓ Dry Times                            ← QuestLogStoryStep
--         ✓ A Free Lunch
--         - Visit the Herbalist
--
-- A step is one quest; the same-named parts of a chain are numbered ("The
-- Tower of Althalaxx (3)"), so a 9-quest chapter shows 9 lines. Quests
-- that exclude each other share one step ("Escape Through Stealth /
-- Force"), done once either is. Quests the character's race or class can
-- never take are dropped, and so is a chapter left with no steps.

local BANNER_H    = 69     -- retail's StoryHeader: 304 x 69 ...
local BG_DROP     = 5      -- ... with its parchment hanging 5 px below the frame
local DIVIDER_H   = 15
local CHAPTER_H   = 16
local STEP_H      = 14
local STEP_INDENT = 16
local ROW_GAP     = 2
local BODY_PAD    = BG_DROP + 4
local BOTTOM_PAD  = 8      -- under the last chapter row
local CHAPTER_INSET = 16   -- chapter rows in from the block's sides
local CHECK_SIZE  = 12

-- The green check (ScenarioIcon-Check) as a text escape, for the tooltip's
-- chapter list; retail draws it 16 px before each completed chapter.
local _CHECK_ICON = ("|T%s:16:16:0:0:1024:256:612:628:40:56|t")
    :format(MUI.TEX_SKIN .. "worldmap\\storyheader")

local _GREEN = { 0.1, 1, 0.1 }    -- GREEN_FONT_COLOR, retail's completed chapter

-- A quest ruled out for good: one of the quests it excludes (the other
-- Scepter path, the quest a breadcrumb leads to) is already completed.
local function _RuledOut(id)
    if C_QuestLog.IsQuestFlaggedCompleted(id) then return false end
    local q = MUI_QuestDB:Get(id)
    for _, other in ipairs(q and q.exclusiveTo or {}) do
        if C_QuestLog.IsQuestFlaggedCompleted(math.abs(other)) then return true end
    end
    return false
end
local _GOLD  = { 1, 0.82, 0 }
local _GREY  = { 0.6, 0.6, 0.6 }


-- ---------------------------------------------------------------------
-- QuestLogStoryStep: one quest line — check mark or "-" bullet, name.
-- ---------------------------------------------------------------------
class "QuestLogStoryStep" : extends "Frame" {
    __init = function(self, parent)
        Frame.__init(self, "Frame", parent)
        self:SetHeight(STEP_H)
        self:EnableMouse(true)

        self.check = Texture(self, nil, "ARTWORK")
        self.check:SetAtlas(MUI_AtlasRegistry.StoryHeader, "Check", true)
        self.check:SetSize(CHECK_SIZE, CHECK_SIZE)
        self.check:AlignParentLeft(0, 0)

        self.bullet = FontString(self, nil, "ARTWORK")
        self.bullet:SetFont(MUI.FONT, 10.5)
        self.bullet:SetShadowOffset(1, -1)
        self.bullet:SetWidth(CHECK_SIZE)
        self.bullet:SetJustifyH("CENTER")
        self.bullet:AlignParentLeft(0, 0)
        self.bullet:SetText("-")

        self.text = FontString(self, nil, "ARTWORK")
        self.text:SetFont(MUI.FONT, 10.5)
        self.text:SetShadowOffset(1, -1)
        self.text:SetJustifyH("LEFT")
        self.text:SetWordWrap(false)
        self.text:RightOf(self.check, 3, 0)
        self.text:AlignParentRight(0, 0)

        self:SetScript("OnEnter", function() self:_SyncHover(true) end)
        self:SetScript("OnLeave", function() self:_SyncHover(false) end)
        -- A step the player is on opens its description, like a quest row.
        self:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and self.step and self.step.onQuest then
                PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                MUI_ModuleMap:ShowQuestDescription(self.step.onQuest)
            end
        end)
        self:SetTooltip("ANCHOR_NONE", function(tooltip) self:_BuildTooltip(tooltip) end)
    end;

    -- step = { name, level, complete, onQuest, giver, any }
    SetStep = function(self, step)
        self.step = step
        local prefix = ""
        if MUI_DB.settings.questHelper.showQuestLevel and step.level and step.level > 0 then
            prefix = "[" .. step.level .. "] "
        end
        self.text:SetText(prefix .. step.name)
        self.check:SetVisible(step.complete)
        self.bullet:SetVisible(not step.complete)
        self:_SyncHover(false)
    end;

    _SyncHover = function(self, isOver)
        local s = self.step
        if s and s.complete then
            local v = isOver and 0.75 or 0.6
            self.text:SetTextColor(v, v, v, 1)
        elseif s and s.onQuest then
            self.text:SetTextColor(1, isOver and 1 or 0.82, 0, 1)
        else
            local v = isOver and 1 or 0.9
            self.text:SetTextColor(v, v, v, 1)
        end
        self.bullet:SetTextColor(0.9, 0.9, 0.9, 1)
    end;

    _BuildTooltip = function(self, tooltip)
        local s = self.step
        if not s then return end
        tooltip:ClearAllPoints()
        tooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 16, 4)
        tooltip:SetMinimumWidth(200)
        tooltip:AddTitle(s.name, true)
        if s.giver then
            tooltip:AddLine("Starts at: " .. s.giver, 1, 1, 1, true)
        end
        if s.any then
            tooltip:AddLine("Only one of these quests can be taken; either one completes the step.", 0.7, 0.7, 0.7, true)
        end
        tooltip:AddBlank()
        if s.complete then
            tooltip:AddLine("Completed", _GREEN[1], _GREEN[2], _GREEN[3])
        elseif s.onQuest then
            tooltip:AddLine("In your quest log", _GOLD[1], _GOLD[2], _GOLD[3])
        else
            tooltip:AddLine("Not completed", 0.7, 0.7, 0.7)
        end
        if s.onQuest then
            tooltip:AddBlank()
            tooltip:AddLine("<Click for more details>", 0, 1, 0)
        end
    end;
}


-- ---------------------------------------------------------------------
-- QuestLogStoryChapter: collapsible chapter row (toggle, name, quests
-- done/total) over its step lines. `collapsed` is public so the banner can remember it
-- per chapter; `OnToggled` is set by the banner to re-stack.
-- ---------------------------------------------------------------------
class "QuestLogStoryChapter" : extends "Frame" {
    __init = function(self, parent)
        Frame.__init(self, "Frame", parent)

        self.header = Frame("Frame", self)
        self.header:SetHeight(CHAPTER_H)
        self.header:AlignParentTop()
        self.header:FillWidth()
        self.header:EnableMouse(true)

        self.toggle = QuestTrackerCollapseBtn(self.header, nil, "secondary", 12)
        self.toggle:AlignParentLeft(0, 0)
        -- The whole row is the click target; a mouse-enabled child confuses
        -- Era's focus tracking (see QuestLogCategory).
        self.toggle:EnableMouse(false)

        self.progress = FontString(self.header, nil, "ARTWORK")
        self.progress:SetFont(MUI.FONT, 10)
        self.progress:SetShadowOffset(1, -1)
        self.progress:SetJustifyH("RIGHT")
        self.progress:AlignParentRight(0, 0)

        self.check = Texture(self.header, nil, "ARTWORK")
        self.check:SetAtlas(MUI_AtlasRegistry.StoryHeader, "Check", true)
        self.check:SetSize(CHECK_SIZE, CHECK_SIZE)
        self.check:LeftOf(self.progress, 2, 0)

        self.name = FontString(self.header, nil, "ARTWORK")
        self.name:SetFont(MUI.FONT, 10.5)
        self.name:SetShadowOffset(1, -1)
        self.name:SetJustifyH("LEFT")
        self.name:SetWordWrap(false)
        self.name:RightOf(self.toggle, 3, 0)
        self.name:LeftOf(self.check, 4, 0)

        self.body = Frame("Frame", self)
        self.body:Below(self.header, ROW_GAP)
        self.body:AlignLeft(self.header)
        self.body:AlignRight(self.header)

        self.steps     = {}
        self.collapsed = true

        self.header:SetScript("OnEnter", function() self:_SyncHover(true) end)
        self.header:SetScript("OnLeave", function() self:_SyncHover(false) end)
        self.header:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and self.header:IsMouseOver() then
                self:ToggleCollapsed()
            end
        end)
    end;

    -- chapter = { name, steps, done, total, complete }
    SetChapter = function(self, chapter, collapsed)
        self.chapter   = chapter
        self.collapsed = collapsed
        self.name:SetText(chapter.name)
        self.progress:SetText(chapter.done .. "/" .. chapter.total)
        self.check:SetVisible(chapter.complete)
        if not chapter.complete then
            self.check:SetSize(0.1, CHECK_SIZE)
        else
            self.check:SetSize(CHECK_SIZE, CHECK_SIZE)
        end

        for _, row in ipairs(self.steps) do row:Hide() end
        local y = 0
        for i, step in ipairs(chapter.steps) do
            local row = self.steps[i]
            if not row then
                row = QuestLogStoryStep(self.body)
                self.steps[i] = row
            end
            row:ClearAllPoints()
            row:AlignParentTopLeft(y, STEP_INDENT)
            row:AlignParentTopRight(y, 0)
            row:SetStep(step)
            row:Show()
            y = y + STEP_H + ROW_GAP
        end
        self.body:SetHeight(math.max(y - ROW_GAP, 0.1))

        self.toggle:SetExpanded(not collapsed)
        self:_ApplyCollapsed()
        self:_SyncHover(false)
    end;

    ToggleCollapsed = function(self)
        self.collapsed = not self.collapsed
        PlaySound(self.collapsed
            and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
            or  SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self.toggle:SetExpanded(not self.collapsed)
        self:_ApplyCollapsed()
        if self.OnToggled then self:OnToggled() end
    end;

    _ApplyCollapsed = function(self)
        if self.collapsed then
            self.body:Hide()
            self:SetHeight(CHAPTER_H)
        else
            self.body:Show()
            self:SetHeight(CHAPTER_H + ROW_GAP + (self.body:GetHeight() or 0))
        end
    end;

    _SyncHover = function(self, isOver)
        local ch = self.chapter
        if ch and ch.complete then
            local c = _GREEN
            self.name:SetTextColor(c[1], c[2], c[3], isOver and 1 or 0.85)
            self.progress:SetTextColor(c[1], c[2], c[3], isOver and 1 or 0.85)
        else
            self.name:SetTextColor(1, isOver and 1 or 0.82, 0, 1)
            self.progress:SetTextColor(_GREY[1], _GREY[2], _GREY[3], 1)
        end
    end;
}


-- ---------------------------------------------------------------------
-- QuestLogStory: the banner (zone name over "x/y Chapters"; a click folds
-- the chapters) with the chapter rows beneath. SetZone(areaId, zoneName) pours in the
-- zone's chapters and answers whether there is anything to show. The
-- banner's collapsed state is a saved setting; chapter states are kept
-- per zone for the session. `OnLayoutChanged` is set by the host.
-- ---------------------------------------------------------------------
class "QuestLogStory" : extends "Frame" {
    __init = function(self, parent)
        Frame.__init(self, "Frame", parent, "MUI_MapQuestLogStory")

        self.banner = Frame("Frame", self)
        self.banner:SetHeight(BANNER_H)
        self.banner:AlignParentTop()
        self.banner:FillWidth(9)
        self.banner:EnableMouse(true)

        -- Retail's StoryHeader layout: the parchment is the frame's size but
        -- anchored 5 px down, the divider runs 3 px above the top edge from
        -- 3 px inside the left corner to 3 px past the right one, the name is
        -- GameFontHighlightMedium at (18, -20) — set 2 px lower here, which
        -- centres name + count on the parchment — with the small white progress
        -- line 4 px under it, and the hover is the parchment again, additive.
        self.bannerBg = Texture(self.banner, nil, "BACKGROUND")
        self.bannerBg:SetAtlas(MUI_AtlasRegistry.StoryHeader, "Banner", true)
        self.bannerBg:SetHeight(BANNER_H)
        self.bannerBg:AlignParentTop(BG_DROP)
        self.bannerBg:FillWidth()

        self.bannerHL = Texture(self.banner, nil, "ARTWORK")
        self.bannerHL:SetAtlas(MUI_AtlasRegistry.StoryHeader, "Banner", true)
        self.bannerHL:SetAllPoints(self.bannerBg)
        self.bannerHL:SetBlendMode("ADD")
        self.bannerHL:SetAlpha(0.4)
        self.bannerHL:Hide()

        self.divider = Texture(self.banner, nil, "OVERLAY")
        self.divider:SetAtlas(MUI_AtlasRegistry.StoryHeader, "Divider", true)
        self.divider:SetHeight(DIVIDER_H)
        self.divider:AlignParentTopLeft(-3, 3)
        self.divider:AlignParentTopRight(-3, -3)

        self.title = FontString(self.banner, nil, "OVERLAY")
        self.title:SetFont(MUI.FONT, 14)
        self.title:SetShadowOffset(1, -1)
        self.title:SetTextColor(1, 1, 1, 1)
        self.title:SetJustifyH("LEFT")
        self.title:SetWordWrap(false)
        self.title:AlignParentTopLeft(22, 18)
        self.title:AlignParentTopRight(22, 12)

        self.progress = FontString(self.banner, nil, "OVERLAY")
        self.progress:SetFont(MUI.FONT, 10)
        self.progress:SetShadowOffset(1, -1)
        self.progress:SetTextColor(1, 1, 1, 1)
        self.progress:SetJustifyH("LEFT")
        self.progress:AlignLeft(self.title)
        self.progress:Below(self.title, 4)

        self.body = Frame("Frame", self)
        self.body:Below(self.banner, BODY_PAD)
        self.body:FillWidth()

        self.chapters          = {}
        self._collapsedChapter = {}

        self.banner:SetScript("OnEnter", function() self.bannerHL:Show() end)
        self.banner:SetScript("OnLeave", function() self.bannerHL:Hide() end)
        self.banner:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and self.banner:IsMouseOver() then
                self:ToggleCollapsed()
            end
        end)
        self.banner:SetTooltip("ANCHOR_NONE", function(tooltip) self:_BuildTooltip(tooltip) end)
    end;

    SetZone = function(self, areaId, zoneName)
        local data = MUI_StorylineDB:GetChapters(areaId)
        if not data then return false end
        local chapters = self:_Compute(data)
        if #chapters == 0 then return false end

        local done = 0
        for _, ch in ipairs(chapters) do
            if ch.complete then done = done + 1 end
        end
        self._areaId   = areaId
        self._chapters = chapters
        self._done     = done
        self.title:SetText(zoneName or "")
        self.progress:SetText(string.format("%d/%d Chapters", done, #chapters))
        self:_Layout()
        return true
    end;

    -- DB chapters → display chapters for this character: one step per quest
    -- the player can take, with completion from the quest flags and the
    -- quest log. Same-named parts of a chain each get a numbered step;
    -- exclusive variants of one quest stay a single step, done once any of
    -- them is. A quest a completed one has ruled out (the path not taken, a
    -- skipped breadcrumb) is left out rather than counted as undone.
    _Compute = function(self, data)
        local avail = MUI_QuestHelper and MUI_QuestHelper.availability
        if not avail then return {} end
        local out = {}
        for _, ch in ipairs(data) do
            local steps, doneQuests, allDone = {}, 0, true
            for _, ids in ipairs(ch.steps) do
                local mine = {}
                for _, id in ipairs(ids) do
                    if avail:IsForPlayer(id) and not _RuledOut(id) then mine[#mine + 1] = id end
                end
                if ids.any and #mine > 1 then
                    local complete, onQuest = false, nil
                    for _, id in ipairs(mine) do
                        if C_QuestLog.IsQuestFlaggedCompleted(id) then complete = true end
                        if not onQuest and C_QuestLog.IsOnQuest(id) then onQuest = id end
                    end
                    local step = self:_Step(mine[1], self:_JoinNames(mine), complete, onQuest)
                    step.any = true
                    steps[#steps + 1] = step
                else
                    for k, id in ipairs(mine) do
                        local name = MUI_QuestDB:LocalizeQuestName(id) or ""
                        if #mine > 1 then name = string.format("%s (%d)", name, k) end
                        steps[#steps + 1] = self:_Step(id, name,
                            C_QuestLog.IsQuestFlaggedCompleted(id),
                            C_QuestLog.IsOnQuest(id) and id or nil)
                    end
                end
            end
            for _, step in ipairs(steps) do
                if step.complete then doneQuests = doneQuests + 1 else allDone = false end
            end
            if #steps > 0 then
                out[#out + 1] = {
                    name     = ch.name,
                    steps    = steps,
                    done     = doneQuests,
                    total    = #steps,
                    complete = allDone,
                }
            end
        end
        return out
    end;

    -- One display step for quest `id`, shown as `name`.
    _Step = function(self, id, name, complete, onQuest)
        local q = MUI_QuestDB:Get(id)
        return {
            name     = name,
            level    = q and q.questLevel or 0,
            complete = complete,
            onQuest  = onQuest,
            giver    = self:_GiverName(q),
        }
    end;

    -- The names of alternative quests as one label, the words they all
    -- start with said once: "Escape Through Stealth" + "Escape Through
    -- Force" → "Escape Through Stealth / Force".
    _JoinNames = function(self, idList)
        local names = {}
        for _, id in ipairs(idList) do
            local n = MUI_QuestDB:LocalizeQuestName(id) or ""
            if not tContains(names, n) then names[#names + 1] = n end
        end
        if #names == 1 then return names[1] end

        local firstWords = {}
        for w in names[1]:gmatch("%S+") do firstWords[#firstWords + 1] = w end
        local common = #firstWords - 1
        for i = 2, #names do
            local k = 0
            for w in names[i]:gmatch("%S+") do
                if firstWords[k + 1] == w then k = k + 1 else break end
            end
            common = math.min(common, k)
        end

        local out = { names[1] }
        for i = 2, #names do
            local rest, n = {}, 0
            for w in names[i]:gmatch("%S+") do
                n = n + 1
                if n > common then rest[#rest + 1] = w end
            end
            out[#out + 1] = (#rest > 0) and table.concat(rest, " ") or names[i]
        end
        return table.concat(out, " / ")
    end;

    -- Name of whoever hands out the quest: starter NPC, else object, else item.
    _GiverName = function(self, q)
        local sb = q and q.startedBy
        if not sb then return nil end
        local npcs, objects, items = sb[1], sb[2], sb[3]
        if npcs and npcs[1] then
            local n = MUI_NpcDB:Get(npcs[1])
            return n and n.name
        end
        if objects and objects[1] then
            local o = MUI_ObjectDB:Get(objects[1])
            return o and o.name
        end
        if items and items[1] then
            local it = MUI_ItemDB:Get(items[1])
            return it and it.name
        end
    end;

    -- Stack the chapter rows under the banner (or just the banner when the
    -- block is collapsed) and size the block.
    _Layout = function(self)
        for _, row in ipairs(self.chapters) do row:Hide() end
        if MUI_DB.settings.questHelper.zoneStoryCollapsed then
            self.body:Hide()
            self:SetHeight(BANNER_H + BG_DROP)
            return
        end

        self.body:Show()
        local y = 0
        for i, ch in ipairs(self._chapters) do
            local row = self.chapters[i]
            if not row then
                row = QuestLogStoryChapter(self.body)
                row.OnToggled = function(r)
                    self._collapsedChapter[self._areaId .. "/" .. r.chapter.name] = r.collapsed
                    self:_Layout()
                    if self.OnLayoutChanged then self:OnLayoutChanged() end
                end
                self.chapters[i] = row
            end
            local chCollapsed = self._collapsedChapter[self._areaId .. "/" .. ch.name]
            if chCollapsed == nil then chCollapsed = true end
            row:ClearAllPoints()
            row:AlignParentTopLeft(y, CHAPTER_INSET)
            row:AlignParentTopRight(y, CHAPTER_INSET)
            row:SetChapter(ch, chCollapsed)
            row:Show()
            y = y + (row:GetHeight() or CHAPTER_H) + ROW_GAP
        end
        self.body:SetHeight(math.max(y - ROW_GAP, 0.1))
        self:SetHeight(BANNER_H + BODY_PAD + (self.body:GetHeight() or 0) + BOTTOM_PAD)
    end;

    ToggleCollapsed = function(self)
        local s = MUI_DB.settings.questHelper
        s.zoneStoryCollapsed = not s.zoneStoryCollapsed
        PlaySound(s.zoneStoryCollapsed
            and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
            or  SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self:_Layout()
        if self.OnLayoutChanged then self:OnLayoutChanged() end
    end;

    -- Retail's StoryTooltip, 27 px right of the banner: zone name, the gold
    -- "Story Progress" label over the small "x/y Chapters" count, then one
    -- line per chapter — green with the check mark in front once done.
    _BuildTooltip = function(self, tooltip)
        if not self._chapters then return end
        tooltip:ClearAllPoints()
        tooltip:SetPoint("TOPLEFT", self.banner, "TOPRIGHT", 27, 0)
        tooltip:SetMinimumWidth(240)
        tooltip:AddLine(self.title:GetText() or "", 1, 1, 1, true, 14)
        tooltip:AddBlank()
        tooltip:AddLine("Story Progress", _GOLD[1], _GOLD[2], _GOLD[3])
        tooltip:AddLine(string.format("%d/%d Chapters", self._done, #self._chapters), 1, 1, 1, false, 10)
        tooltip:AddBlank()
        for _, ch in ipairs(self._chapters) do
            if ch.complete then
                tooltip:AddLine(_CHECK_ICON .. " " .. ch.name, _GREEN[1], _GREEN[2], _GREEN[3])
            else
                tooltip:AddLine(ch.name, 1, 1, 1)
            end
        end
        tooltip:AddBlank()
        tooltip:AddLine(MUI_DB.settings.questHelper.zoneStoryCollapsed
            and "<Click to show the chapters>" or "<Click to hide the chapters>", 0, 1, 0)
    end;
}
