-- MUI_Calendar: retail's calendar for Classic Era, which ships its UI
-- without one:
--
--   MUI_CalendarHolidays      Era's world events, which its server does not send
--   MUI_CalendarStyle         the art, how events are named and coloured, the
--                             dialog the side panels are
--   MUI_CalendarDay           a day of the month and its event lines
--   MUI_CalendarLists         scrolling text, lists, the invite list
--   MUI_CalendarPanels        a holiday, a raid lockout, an event one is
--                             invited to; the event and dungeon pickers
--   MUI_CalendarCreateEvent   making and editing an event, Mass Invite
--   MUI_CalendarFrame         the window
--
-- The calendar button beside the minimap opens it (MinimapCalendarButton);
-- so do the "Toggle Calendar" key binding and /muicalendar.

local L = MUI.L

BINDING_NAME_MUI_TOGGLE_CALENDAR = L.CAL_TOGGLE

object "ModuleCalendar" : extends "Module" {
    __init = function(self)
        Module.__init(self, "Calendar")
    end;

    OnEnable = function(self)
        self.window = CalendarWindow()
        ChatCommand("muicalendar", function() self:Toggle() end)
    end;

    Toggle = function(self)
        self.window:Toggle()
    end;
}
