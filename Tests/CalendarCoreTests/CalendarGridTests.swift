import Foundation
import Testing
@testable import CalendarCore

@Test("month grid always contains six weeks")
func monthGridHasSixWeeks() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 1
    let date = calendar.date(from: DateComponents(year: 2024, month: 5, day: 15))!

    let grid = CalendarGrid(month: date, calendar: calendar)

    #expect(grid.days.count == 42)
    #expect(calendar.component(.day, from: grid.days.first!.date) == 28)
    #expect(calendar.component(.day, from: grid.days.last!.date) == 8)
    #expect(grid.days.filter(\.isInDisplayedMonth).count == 31)
}

@Test("month grid respects Monday as first weekday")
func monthGridRespectsFirstWeekday() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 2
    let date = calendar.date(from: DateComponents(year: 2024, month: 4, day: 1))!

    let grid = CalendarGrid(month: date, calendar: calendar)

    #expect(calendar.component(.day, from: grid.days.first!.date) == 1)
}

@Test("month membership includes the year")
func monthMembershipIncludesYear() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 1
    let date = calendar.date(from: DateComponents(year: 2024, month: 12, day: 15))!

    let grid = CalendarGrid(month: date, calendar: calendar)

    #expect(grid.days.filter(\.isInDisplayedMonth).count == 31)
    #expect(calendar.component(.year, from: grid.days.first!.date) == 2024)
}

@Test("Calendar link targets the exact EventKit event")
func calendarLinkUsesEventIdentifier() {
    let event = CalendarEvent(
        id: "event/id with spaces",
        title: "Event",
        startDate: .now,
        endDate: .now,
        isAllDay: false,
        calendarTitle: "Calendar",
        calendarColorHex: "#FF0000"
    )

    #expect(event.appleCalendarURL?.absoluteString == "ical://ekevent/event%2Fid%20with%20spaces?method=show&options=more")
}
