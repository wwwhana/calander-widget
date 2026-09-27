import CalendarCore
import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
calendar.firstWeekday = 1
let date = calendar.date(from: DateComponents(year: 2024, month: 12, day: 15))!
let grid = CalendarGrid(month: date, calendar: calendar)

assert(grid.days.count == 42)
assert(grid.days.filter(\.isInDisplayedMonth).count == 31)
assert(calendar.component(.year, from: grid.days.first!.date) == 2024)

let event = CalendarEvent(
    id: "event/id with spaces",
    title: "Event",
    startDate: date,
    endDate: date,
    isAllDay: false,
    calendarTitle: "Calendar",
    calendarColorHex: "#FF0000"
)
assert(event.appleCalendarURL?.absoluteString == "ical://ekevent/event%2Fid%20with%20spaces?method=show&options=more")
print("CalendarCoreChecks passed")
