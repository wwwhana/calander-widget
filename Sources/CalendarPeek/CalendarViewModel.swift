import CalendarCore
import Combine
import EventKit
import Foundation

struct CalendarAccount: Identifiable, Hashable {
    let id: String
    let title: String
    let kind: String
    let calendarCount: Int
    var isVisible: Bool
}

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published private(set) var displayedMonth = Date()
    @Published private(set) var selectedDate = Date()
    @Published private(set) var eventsByDay: [Date: [CalendarEvent]] = [:]
    @Published private(set) var accounts: [CalendarAccount] = []
    @Published private(set) var authorization = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var isLoading = false

    private let store = EKEventStore()
    private var hasLoaded = false
    private let hiddenAccountsKey = "hiddenCalendarAccountIDs"

    private var calendar: Calendar {
        var value = Calendar.autoupdatingCurrent
        let override = UserDefaults.standard.integer(forKey: "firstWeekdayOverride")
        if override > 0 { value.firstWeekday = override }
        return value
    }

    var showEventEndTime: Bool {
        UserDefaults.standard.string(forKey: "eventTimeFormat") == "withEndTime"
    }

    var grid: CalendarGrid {
        CalendarGrid(month: displayedMonth, calendar: calendar)
    }

    var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let start = max(calendar.firstWeekday - 1, 0)
        return (0..<7).map { symbols[(start + $0) % symbols.count] }
    }

    var monthTitle: String {
        displayedMonth.formatted(.dateTime.year().month(.wide))
    }

    func weekNumber(for date: Date) -> Int {
        calendar.component(.weekOfYear, from: date)
    }

    var accessGranted: Bool {
        authorization == .fullAccess
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        refreshAuthorization()
        if accessGranted {
            refreshAccounts()
            refreshEvents()
        }
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            refreshAuthorization()
            if accessGranted || granted {
                refreshAccounts()
                refreshEvents()
            }
        } catch {
            refreshAuthorization()
        }
    }

    func select(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
        if !sameMonth(date, displayedMonth) {
            displayedMonth = date
            refreshEvents()
        }
    }

    func moveMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = next
        selectedDate = calendar.startOfDay(for: next)
        refreshEvents()
    }

    func moveDay(by value: Int) {
        guard let next = calendar.date(byAdding: .day, value: value, to: selectedDate) else { return }
        select(next)
    }

    func moveYear(by value: Int) {
        guard let next = calendar.date(byAdding: .year, value: value, to: displayedMonth) else { return }
        displayedMonth = next
        selectedDate = calendar.startOfDay(for: next)
        refreshEvents()
    }

    func goToToday() {
        let today = Date()
        displayedMonth = today
        selectedDate = calendar.startOfDay(for: today)
        refreshEvents()
    }

    func events(on date: Date) -> [CalendarEvent] {
        eventsByDay[calendar.startOfDay(for: date)] ?? []
    }

    func setFirstWeekday(_ value: Int) {
        UserDefaults.standard.set(value, forKey: "firstWeekdayOverride")
        objectWillChange.send()
        refreshEvents()
    }

    func updateEventListPreferences() {
        objectWillChange.send()
        refreshEvents()
    }

    func setAccountVisible(_ account: CalendarAccount, isVisible: Bool) {
        var hidden = hiddenAccountIDs()
        if isVisible {
            hidden.remove(account.id)
        } else {
            hidden.insert(account.id)
        }
        UserDefaults.standard.set(Array(hidden), forKey: hiddenAccountsKey)
        refreshAccounts()
        refreshEvents()
    }

    func refresh() {
        refreshAuthorization()
        guard accessGranted else {
            accounts = []
            eventsByDay = [:]
            return
        }
        refreshAccounts()
        refreshEvents()
    }

    private func refreshAuthorization() {
        authorization = EKEventStore.authorizationStatus(for: .event)
    }

    private func refreshAccounts() {
        let grouped = Dictionary(grouping: store.calendars(for: .event)) { calendar in
            calendar.source?.sourceIdentifier ?? "local"
        }
        let hiddenIDs = hiddenAccountIDs()
        accounts = grouped.map { id, calendars in
            let source = calendars.first?.source
            return CalendarAccount(
                id: id,
                title: source?.title ?? L10n.text("accounts"),
                kind: sourceKind(source?.sourceType),
                calendarCount: calendars.count,
                isVisible: !hiddenIDs.contains(id)
            )
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func refreshEvents() {
        guard accessGranted,
              let start = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            eventsByDay = [:]
            return
        }

        isLoading = true
        store.refreshSourcesIfNecessary()
        let hiddenIDs = hiddenAccountIDs()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !hiddenIDs.contains($0.calendar.source?.sourceIdentifier ?? "local") }
            .sorted { $0.startDate < $1.startDate }
        var grouped: [Date: [CalendarEvent]] = [:]

        for event in events {
            let item = CalendarEvent(
                id: event.eventIdentifier,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                calendarTitle: event.calendar.title,
                calendarColorHex: colorHex(for: event.calendar)
            )
            add(item, to: &grouped)
        }

        eventsByDay = grouped
        isLoading = false
    }

    private func add(_ event: CalendarEvent, to grouped: inout [Date: [CalendarEvent]]) {
        let firstDay = calendar.startOfDay(for: event.startDate)
        let lastDay = calendar.startOfDay(for: max(event.endDate.addingTimeInterval(-1), event.startDate))
        var day = firstDay
        while day <= lastDay {
            grouped[day, default: []].append(event)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
    }

    private func sameMonth(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.component(.year, from: lhs) == calendar.component(.year, from: rhs) &&
            calendar.component(.month, from: lhs) == calendar.component(.month, from: rhs)
    }

    private func hiddenAccountIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: hiddenAccountsKey) ?? [])
    }

    private func sourceKind(_ type: EKSourceType?) -> String {
        switch type {
        case .calDAV: return L10n.text("calendar.account.kind.caldav")
        case .exchange: return L10n.text("calendar.account.kind.exchange")
        case .subscribed: return L10n.text("calendar.account.kind.subscription")
        case .local: return L10n.text("calendar.account.kind.local")
        case .mobileMe: return L10n.text("calendar.account.kind.icloud")
        default: return L10n.text("calendar.account.kind.other")
        }
    }

    private func colorHex(for calendar: EKCalendar) -> String {
        guard let components = calendar.cgColor?.components, components.count >= 3 else { return "#4F7CFF" }
        let red = Int((components[0] * 255).rounded())
        let green = Int((components[1] * 255).rounded())
        let blue = Int((components[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
