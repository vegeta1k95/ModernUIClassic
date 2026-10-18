-- MUI_CalendarHolidays: Classic Era's world events, which the Era server
-- does not send. C_Calendar exists on Era and serves player and guild
-- events and raid lockouts, but no holiday reaches it, and the client's own
-- Holidays table holds none of these. Their dates are kept here instead:
--
--   * fixed every year: Hallow's End, Winter Veil, Children's Week, Love is
--     in the Air, Midsummer and its fireworks;
--   * moving: Noblegarden on Easter Sunday, the Lunar Festival near Chinese
--     New Year, the Harvest Festival four days before the Mid-Autumn
--     Festival (retail's own Holidays table has 2024-2027 on both rules);
--   * the Darkmoon Faire from the Monday after a month's first Friday to the
--     Sunday after, in Elwynn Forest in odd months and Mulgore in even ones;
--   * the Stranglethorn fishing contest every Sunday, 14:00 to 16:00;
--   * a battleground's Call to Arms weekend every three weeks, the three in
--     turn from Arathi Basin on 2 January 2026.
--
-- Era's lengths differ from retail's where both Questie and ClassicCalendar
-- (two Era addons) recorded them: a three-week Lunar Festival, a five-day
-- Love is in the Air, a one-day Noblegarden, a one-week Midsummer. Times
-- are realm time; where nothing records them, retail's 10:00 start is used.
--
--   MUI_CalendarHolidays:GetDayEvents(year, month, day)
--     the events of that day as C_Calendar.GetDayEvent describes one
--     (calendarType "HOLIDAY", sequenceType, iconTexture, ...), plus
--     .filter (the calendar filter that hides it), .description, .key

local ART = "Interface\\Calendar\\Holidays\\Calendar_"
local DAY = 1440    -- minutes

-- Days since 1 January 1970 (Howard Hinnant's days_from_civil) and back.
local function DayNumber(year, month, day)
    if month <= 2 then year = year - 1 end
    local era = math.floor(year / 400)
    local yoe = year - era * 400
    local doy = math.floor((153 * ((month + 9) % 12) + 2) / 5) + day - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end

local function CivilDate(n)
    n = n + 719468
    local era = math.floor(n / 146097)
    local doe = n - era * 146097
    local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
    local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
    local mp = math.floor((5 * doy + 2) / 153)
    local day = doy - math.floor((153 * mp + 2) / 5) + 1
    local month = mp < 10 and mp + 3 or mp - 9
    local year = yoe + era * 400
    if month <= 2 then year = year + 1 end
    return year, month, day
end

-- 1 = Sunday ... 7 = Saturday, as the calendar API counts.
local function Weekday(n)
    return (n + 4) % 7 + 1
end

-- A minute count as the API's CalendarTime.
local function CalendarTime(minutes)
    local n = math.floor(minutes / DAY)
    local year, month, day = CivilDate(n)
    local rest = minutes - n * DAY
    return { year = year, month = month, monthDay = day, weekday = Weekday(n),
             hour = math.floor(rest / 60), minute = rest % 60 }
end

-- Easter Sunday (the anonymous Gregorian computus).
local function Easter(year)
    local a = year % 19
    local b, c = math.floor(year / 100), year % 100
    local d, e = math.floor(b / 4), b % 4
    local f = math.floor((b + 8) / 25)
    local g = math.floor((b - f + 1) / 3)
    local h = (19 * a + b - d - g + 15) % 30
    local i, k = math.floor(c / 4), c % 4
    local l = (32 + 2 * e + 2 * i - h - k) % 7
    local m = math.floor((a + 11 * h + 22 * l) / 451)
    local x = h + l - 7 * m + 114
    return math.floor(x / 31), x % 31 + 1
end

-- Chinese New Year and the Mid-Autumn Festival, by year.
local NEW_YEAR = {
    [2024] = { 2, 10 }, [2025] = { 1, 29 }, [2026] = { 2, 17 }, [2027] = { 2, 6 },
    [2028] = { 1, 26 }, [2029] = { 2, 13 }, [2030] = { 2, 3 },  [2031] = { 1, 23 },
    [2032] = { 2, 11 }, [2033] = { 1, 31 }, [2034] = { 2, 19 }, [2035] = { 2, 8 },
}
local MID_AUTUMN = {
    [2024] = { 9, 17 }, [2025] = { 10, 6 }, [2026] = { 9, 25 }, [2027] = { 9, 15 },
    [2028] = { 10, 3 }, [2029] = { 9, 22 }, [2030] = { 9, 12 }, [2031] = { 10, 1 },
    [2032] = { 9, 19 }, [2033] = { 9, 8 },  [2034] = { 9, 27 }, [2035] = { 9, 16 },
}
-- The Lunar Festival's first day where retail's table has it; other years
-- start the day before Chinese New Year, as 2025 and 2026 did.
local LUNAR_FESTIVAL = {
    [2024] = { 2, 3 }, [2025] = { 1, 28 }, [2026] = { 2, 16 }, [2027] = { 2, 2 },
}

local function Textures(name)
    return { ART .. name .. "Start", ART .. name .. "Ongoing", ART .. name .. "End" }
end

-- `starts(year)` gives the minute every occurrence beginning in that year
-- starts at; it lasts `length` minutes.
local HOLIDAYS = {
    {
        key = "LunarFestival", name = "Lunar Festival", filter = "holidays", priority = 5,
        textures = Textures("LunarFestival"), length = 20 * DAY,
        description = "Every year the druids of Moonglade hold a celebration of their city's great triumph over an ancient evil. During the Lunar Festival, citizens of Azeroth have the opportunity to honor their elders by celebrating their sage wisdom, sharing in magnificent feasts, and of course... shooting lots of fireworks!",
        starts = function(year)
            local date = LUNAR_FESTIVAL[year]
            if date then return { DayNumber(year, date[1], date[2]) * DAY + 600 } end
            date = NEW_YEAR[year]
            if date then return { (DayNumber(year, date[1], date[2]) - 1) * DAY + 600 } end
        end,
    },
    {
        key = "LoveIsInTheAir", name = "Love is in the Air", filter = "holidays", priority = 5,
        textures = Textures("LoveInTheAir"), length = 5 * DAY,
        description = "Something is in the air in the major cities of Azeroth. Many guards and townsfolk spend their days giving and receiving gifts to other amorous citizens.",
        starts = function(year) return { DayNumber(year, 2, 11) * DAY + 600 } end,
    },
    {
        key = "Noblegarden", name = "Noblegarden", filter = "holidays", priority = 5,
        textures = Textures("Noblegarden"), length = DAY - 1,
        description = "The feast of Noblegarden has arrived.  The proving grounds of each race, the place where young heroes first test their strength, each holds cleverly hidden treasure eggs.  How many can you find?",
        starts = function(year) return { DayNumber(year, Easter(year)) * DAY } end,
    },
    {
        key = "ChildrensWeek", name = "Children's Week", filter = "holidays", priority = 5,
        textures = Textures("ChildrensWeek"), length = 7 * DAY,
        description = "Show an orphan what the hero's life is like!  Visit Orphan Matron Nightingale in Stormwind or Orphan Matron Battlewail in Orgrimmar and make a child's dream come true.",
        starts = function(year) return { DayNumber(year, 5, 1) * DAY + 600 } end,
    },
    {
        key = "Midsummer", name = "Midsummer Fire Festival", filter = "holidays", priority = 5,
        textures = Textures("Midsummer"), length = 7 * DAY,
        description = "A time of merriment and celebration, dedicated to the hottest season of the year.",
        starts = function(year) return { DayNumber(year, 6, 21) * DAY + 600 } end,
    },
    {
        key = "FireworksSpectacular", name = "Fireworks Spectacular", filter = "holidays", priority = 4,
        textures = { ART .. "Fireworks", ART .. "Fireworks", ART .. "Fireworks" }, length = 18 * 60,
        description = "After the sun sets, the end of Midsummer is celebrated, with an hourly firework extravaganza.\n\nTo watch the show, visit any capital city or Booty Bay.",
        starts = function(year) return { DayNumber(year, 6, 27) * DAY + 600 } end,
    },
    {
        key = "HarvestFestival", name = "Harvest Festival", filter = "holidays", priority = 5,
        textures = Textures("HarvestFestival"), length = 7 * DAY,
        description = "The Harvest Festival is a time to commemorate those who have sacrificed their lives to help friends and allies.  Feasts are held outside Orgrimmar and Ironforge in honor of these fallen heroes.",
        starts = function(year)
            local date = MID_AUTUMN[year]
            if date then return { (DayNumber(year, date[1], date[2]) - 4) * DAY + 600 } end
        end,
    },
    {
        key = "HallowsEnd", name = "Hallow's End", filter = "holidays", priority = 5,
        textures = Textures("HallowsEnd"), length = 14 * DAY + 60,
        description = "Hallow's End celebrates the break of the Forsaken from the Scourge.\n\nFun and mischief reign as the Innkeepers of Azeroth give treats, and tricks, to whomever asks.",
        starts = function(year) return { DayNumber(year, 10, 18) * DAY + 600 } end,
    },
    {
        key = "WinterVeil", name = "Feast of Winter Veil", filter = "holidays", priority = 5,
        textures = Textures("WinterVeil"), length = 18 * DAY,
        description = "Greatfather Winter is visiting the cities of Ironforge and Orgrimmar, courtesy of Smokywood Pastures.  And throughout Azeroth, it is the season to be jolly!",
        starts = function(year) return { DayNumber(year, 12, 15) * DAY + 600 } end,
    },
    {
        key = "DarkmoonElwynn", name = "Darkmoon Faire", filter = "darkmoon", priority = 1,
        textures = Textures("DarkmoonFaireElwynn"), length = 7 * DAY - 1,
        description = "The Darkmoon Faire is here, this time in idyllic Elwynn Forest.\n\nMeet Silas Darkmoon and his troupe, play games that test mind and nerve, and behold exotic sights from the four corners of Azeroth... and beyond!",
        months = 1,
    },
    {
        key = "DarkmoonMulgore", name = "Darkmoon Faire", filter = "darkmoon", priority = 1,
        textures = Textures("DarkmoonFaireMulgore"), length = 7 * DAY - 1,
        description = "The Darkmoon Faire is here, this time at the foot of Thunder Bluff.\n\nMeet Silas Darkmoon and his troupe, play games that test mind and nerve, and behold exotic sights from the four corners of Azeroth... and beyond!",
        months = 0,
    },
    {
        key = "FishingExtravaganza", name = "Stranglethorn Fishing Extravaganza", filter = "weekly", priority = 0,
        textures = { ART .. "FishingExtravaganza", ART .. "FishingExtravaganza", ART .. "FishingExtravaganza" },
        length = 120,
        description = "A fishing tournament, competed along the coasts of Stranglethorn Vale.  Catch as many tastyfish as you can!  \n\nWill you be one of the first to catch forty fish and win a prize?  Tastyfish can be caught for two hours after the contest begins, but you'll have to be quick to win!",
        anchor = { 2026, 1, 4 }, period = 7, hour = 14,
    },
    {
        key = "CallToArmsAB", name = "Call to Arms: Arathi Basin", filter = "battlegrounds", priority = 0,
        textures = Textures("WeekendBattlegrounds"), length = 4 * DAY - 1,
        description = "The battle for Arathi Basin grows intense.  Greater honor is given to those who pledge sword to their liege and battle in Arathi.",
        anchor = { 2026, 1, 2 }, period = 21, hour = 0,
    },
    {
        key = "CallToArmsAV", name = "Call to Arms: Alterac Valley", filter = "battlegrounds", priority = 0,
        textures = Textures("WeekendBattlegrounds"), length = 4 * DAY - 1,
        description = "The battle for Alterac Valley grows intense.  Greater honor is given to those who pledge sword to their liege and battle in Alterac.",
        anchor = { 2026, 1, 9 }, period = 21, hour = 0,
    },
    {
        key = "CallToArmsWSG", name = "Call to Arms: Warsong Gulch", filter = "battlegrounds", priority = 0,
        textures = Textures("WeekendBattlegrounds"), length = 4 * DAY - 1,
        description = "The battle for Warsong Gulch grows intense.  Greater honor is given to those who pledge sword to their liege and battle in the Gulch.",
        anchor = { 2026, 1, 16 }, period = 21, hour = 0,
    },
}

object "CalendarHolidays" {
    __init = function(self)
        self._years = {}
    end;

    -- The Darkmoon Faire of `holiday`'s months in `year`: from the Monday
    -- after each first Friday.
    _DarkmoonStarts = function(self, holiday, year)
        local starts = {}
        for month = 1, 12 do
            if month % 2 == holiday.months then
                local first = DayNumber(year, month, 1)
                local friday = first + (6 - Weekday(first)) % 7
                starts[#starts + 1] = (friday + 3) * DAY
            end
        end
        return starts
    end;

    -- A weekly or every-few-weeks event's starts in `year`.
    _CycleStarts = function(self, holiday, year)
        local anchor = DayNumber(holiday.anchor[1], holiday.anchor[2], holiday.anchor[3])
        local first, last = DayNumber(year, 1, 1), DayNumber(year, 12, 31)
        local day = anchor + math.ceil((first - anchor) / holiday.period) * holiday.period
        local starts = {}
        while day <= last do
            starts[#starts + 1] = day * DAY + holiday.hour * 60
            day = day + holiday.period
        end
        return starts
    end;

    -- Every occurrence starting in `year`, as { holiday, start, stop } in
    -- minutes and the days they cover.
    _Occurrences = function(self, year)
        local list = self._years[year]
        if list then return list end
        list = {}
        for _, holiday in ipairs(HOLIDAYS) do
            local starts
            if holiday.months then
                starts = self:_DarkmoonStarts(holiday, year)
            elseif holiday.anchor then
                starts = self:_CycleStarts(holiday, year)
            else
                starts = holiday.starts(year) or {}
            end
            for _, start in ipairs(starts) do
                local stop = start + holiday.length
                list[#list + 1] = {
                    holiday = holiday, start = start, stop = stop,
                    firstDay = math.floor(start / DAY), lastDay = math.floor(stop / DAY),
                }
            end
        end
        self._years[year] = list
        return list
    end;

    -- One occurrence's event on day `n`, in the API's shape.
    _Event = function(self, occurrence, n)
        local holiday = occurrence.holiday
        local numDays = occurrence.lastDay - occurrence.firstDay + 1
        local index = n - occurrence.firstDay + 1
        local sequenceType, texture
        if numDays == 1 then
            sequenceType, texture = "", holiday.textures[1]
        elseif index == 1 then
            sequenceType, texture = "START", holiday.textures[1]
        elseif index == numDays then
            sequenceType, texture = "END", holiday.textures[3]
        else
            sequenceType, texture = "ONGOING", holiday.textures[2]
        end
        return {
            key = holiday.key .. occurrence.firstDay,
            title = holiday.name, isCustomTitle = true,
            description = holiday.description,
            filter = holiday.filter, priority = holiday.priority,
            calendarType = "HOLIDAY", eventType = Enum.CalendarEventType.Other,
            sequenceType = sequenceType, sequenceIndex = index, numSequenceDays = numDays,
            iconTexture = texture, dontDisplayBanner = false, dontDisplayEnd = false,
            startTime = CalendarTime(occurrence.start), endTime = CalendarTime(occurrence.stop),
            modStatus = "", inviteStatus = Enum.CalendarStatus.Invited, invitedBy = "",
            inviteType = Enum.CalendarInviteType.Normal, difficultyName = "",
        }
    end;

    -- The day's events, the most important holiday first.
    GetDayEvents = function(self, year, month, day)
        local n = DayNumber(year, month, day)
        local events = {}
        for y = year - 1, year do
            for _, occurrence in ipairs(self:_Occurrences(y)) do
                if occurrence.firstDay <= n and n <= occurrence.lastDay then
                    events[#events + 1] = self:_Event(occurrence, n)
                end
            end
        end
        table.sort(events, function(a, b)
            if a.priority ~= b.priority then return a.priority > b.priority end
            return a.key < b.key
        end)
        return events
    end;
}
