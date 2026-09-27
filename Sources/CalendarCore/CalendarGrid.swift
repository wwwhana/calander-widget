import Foundation

public struct CalendarDay: Identifiable, Hashable, Sendable {
    public let date: Date
    public let isInDisplayedMonth: Bool

    public var id: Date { date }

    public init(date: Date, isInDisplayedMonth: Bool) {
        self.date = date
        self.isInDisplayedMonth = isInDisplayedMonth
    }
}

public struct CalendarGrid: Sendable {
    public let month: Date
    public let days: [CalendarDay]

    public init(month: Date, calendar: Calendar = .current) {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let firstCell = calendar.date(byAdding: .day, value: -leading, to: monthStart) ?? monthStart

        self.month = monthStart
        self.days = (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstCell) else { return nil }
            return CalendarDay(date: date, isInDisplayedMonth: calendar.isDate(date, equalTo: monthStart, toGranularity: .month))
        }
    }
}

public struct CalendarEvent: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let calendarTitle: String
    public let calendarColorHex: String

    public init(id: String, title: String, startDate: Date, endDate: Date, isAllDay: Bool, calendarTitle: String, calendarColorHex: String) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarTitle = calendarTitle
        self.calendarColorHex = calendarColorHex
    }

    public var appleCalendarURL: URL? {
        guard !id.isEmpty else { return nil }
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        guard let identifier = id.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }

        var components = URLComponents()
        components.scheme = "ical"
        components.host = "ekevent"
        components.percentEncodedPath = "/\(identifier)"
        components.queryItems = [
            URLQueryItem(name: "method", value: "show"),
            URLQueryItem(name: "options", value: "more")
        ]
        return components.url
    }
}
