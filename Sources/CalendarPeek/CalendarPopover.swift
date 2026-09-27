import AppKit
import CalendarCore
import SwiftUI

struct CalendarPopover: View {
    @ObservedObject var model: CalendarViewModel
    let openSettings: () -> Void
    let dismiss: () -> Void
    @AppStorage("theme") private var theme = AppTheme.system.rawValue
    @AppStorage("showWeekNumbers") private var showWeekNumbers = false

    private var columns: [GridItem] {
        let dayColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        return showWeekNumbers ? [GridItem(.fixed(24), spacing: 2)] + dayColumns : dayColumns
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.accessGranted {
                header
                calendarGrid
                Divider()
                    .padding(.vertical, 14)
                eventList
            } else {
                accessPrompt
            }
            footer
        }
        .padding(16)
        .frame(width: 430)
        .tint(.red)
        .preferredColorScheme(AppTheme(rawValue: theme)?.colorScheme)
        .task { await model.loadIfNeeded() }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow, .space, .return, .escape, KeyEquivalent(","), KeyEquivalent("q")]) { press in
            handleKeyPress(press)
        }
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let command = press.modifiers.contains(.command)
        switch press.key {
        case .leftArrow:
            command ? model.moveMonth(by: -1) : model.moveDay(by: -1)
        case .rightArrow:
            command ? model.moveMonth(by: 1) : model.moveDay(by: 1)
        case .upArrow:
            command ? model.moveYear(by: -1) : model.moveDay(by: -7)
        case .downArrow:
            command ? model.moveYear(by: 1) : model.moveDay(by: 7)
        case .space:
            model.goToToday()
        case .return:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
        case .escape:
            dismiss()
        default:
            if command && press.key == KeyEquivalent(",") {
                openSettings()
            } else if command && press.key == KeyEquivalent("q") {
                NSApplication.shared.terminate(nil)
            } else {
                return .ignored
            }
        }
        return .handled
    }

    private func openInCalendar(_ event: CalendarEvent) {
        guard let url = event.appleCalendarURL, NSWorkspace.shared.open(url) else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
            return
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 0) {
                Text(model.displayedMonth, format: .dateTime.month(.wide))
                    .font(.system(size: 24, weight: .bold))
                Text(model.displayedMonth, format: .dateTime.year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { model.moveYear(by: -1) } label: {
                Image(systemName: "chevron.left.2")
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("calendar.nav.previousYear"))

            Button { model.moveMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("calendar.nav.previous"))

            Button { model.moveMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("calendar.nav.next"))

            Button { model.moveYear(by: 1) } label: {
                Image(systemName: "chevron.right.2")
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("calendar.nav.nextYear"))
        }
        .padding(.bottom, 14)
    }

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 2) {
                if showWeekNumbers {
                    Color.clear.frame(width: 24, height: 1)
                }
                ForEach(model.weekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(model.grid.days.enumerated()), id: \.offset) { index, day in
                    if showWeekNumbers && index.isMultiple(of: 7) {
                        Text(String(model.weekNumber(for: day.date)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    DayCell(day: day, isSelected: Calendar.current.isDate(day.date, inSameDayAs: model.selectedDate), isToday: Calendar.current.isDateInToday(day.date), events: model.events(on: day.date)) {
                        model.select(day.date)
                    }
                }
            }
        }
    }

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.selectedDate.formatted(.dateTime.weekday(.wide)))
                        .font(.title3.weight(.semibold))
                    Text(model.selectedDate.formatted(.dateTime.year().month(.wide).day()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.isLoading { ProgressView().controlSize(.small) }
            }

            let events = model.events(on: model.selectedDate)
            if events.isEmpty {
                Label(L10n.text("calendar.event.none"), systemImage: "calendar")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(events) { event in
                            Button {
                                openInCalendar(event)
                            } label: {
                                EventRow(event: event, showEndTime: model.showEventEndTime)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(L10n.text("calendar.event.open"))
                            if event.id != events.last?.id {
                                Divider().padding(.leading, 78)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
    }

    private var accessPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 30))
                .foregroundStyle(.tint)
            Text(L10n.text("calendar.access.title")).font(.headline)
            Text(L10n.text("calendar.access.message"))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                Task { await model.requestAccess() }
            } label: {
                Text(L10n.text("calendar.access.allow"))
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var footer: some View {
        HStack {
            Button { model.goToToday() } label: {
                Text(L10n.text("today"))
                    .fontWeight(.semibold)
            }
            .buttonStyle(.plain)

            Spacer()

            Button { model.refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("calendar.menu.refresh"))

            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("calendar.event.open"))
        }
        .font(.callout)
        .padding(.top, 14)
    }
}

private struct DayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let isToday: Bool
    let events: [CalendarEvent]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(day.date, format: .dateTime.day())
                    .font(.system(size: 13, weight: isToday ? .bold : .regular))
                    .frame(width: 30, height: 30)
                    .background(isSelected ? Color.red : .clear)
                    .foregroundStyle(isSelected ? .white : (isToday ? Color.red : (day.isInDisplayedMonth ? .primary : .secondary)))
                    .clipShape(Circle())
                HStack(spacing: 2) {
                    ForEach(Array(events.prefix(3))) { event in
                        Circle()
                            .fill(Color(hex: event.calendarColorHex))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(day.isInDisplayedMonth ? 1 : 0.42)
        .accessibilityLabel(day.date.formatted(.dateTime.year().month().day()))
        .accessibilityValue(events.isEmpty ? L10n.text("calendar.event.none") : "\(events.count)")
    }
}

private struct EventRow: View {
    let event: CalendarEvent
    let showEndTime: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(Color(hex: event.calendarColorHex))
                .frame(width: 4)

            Text(timeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(event.calendarTitle).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private var timeLabel: String {
        guard !event.isAllDay else { return L10n.text("calendar.event.allDay") }
        let start = event.startDate.formatted(.dateTime.hour().minute())
        guard showEndTime else { return start }
        let end = event.endDate.formatted(.dateTime.hour().minute())
        return "\(start)–\(end)"
    }
}

private extension Color {
    init(hex: String) {
        let value = UInt64(hex.dropFirst(), radix: 16) ?? 0x4F7CFF
        self.init(.sRGB, red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}
