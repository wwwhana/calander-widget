import AppKit
import EventKit
import ServiceManagement
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var title: String {
        L10n.text("appearance." + rawValue)
    }
}

enum StatusBarIconStyle: String, CaseIterable, Identifiable {
    case calendar
    case date
    case minimal

    var id: String { rawValue }

    var title: String {
        L10n.text("general.statusBarIcon." + rawValue)
    }
}

enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Running from a Swift package is not a registered login item yet.
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: CalendarViewModel
    @AppStorage("theme") private var theme = AppTheme.system.rawValue

    var body: some View {
        TabView {
            GeneralSettings(model: model)
                .tabItem { Label(L10n.text("general"), systemImage: "calendar") }
            AccountsSettings(model: model)
                .tabItem { Label(L10n.text("accounts"), systemImage: "person.2") }
            AppearanceSettings()
                .tabItem { Label(L10n.text("appearance"), systemImage: "paintbrush") }
            KeyboardSettings()
                .tabItem { Label(L10n.text("keyboard"), systemImage: "command") }
        }
        .padding(20)
        .frame(width: 650, height: 620)
        .preferredColorScheme(AppTheme(rawValue: theme)?.colorScheme)
    }
}

private struct GeneralSettings: View {
    @ObservedObject var model: CalendarViewModel
    @AppStorage("statusBarIconStyle") private var iconStyle = StatusBarIconStyle.calendar.rawValue
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("firstWeekdayOverride") private var firstWeekday = 0
    @AppStorage("eventTimeFormat") private var eventTimeFormat = "oneLine"

    var body: some View {
        Form {
            Section(L10n.text("general.launching")) {
                Picker(L10n.text("general.statusBarIcon"), selection: $iconStyle) {
                    ForEach(StatusBarIconStyle.allCases) { style in
                        Text(style.title).tag(style.rawValue)
                    }
                }
                Toggle(L10n.text("general.launchAtLogin"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, value in
                        LoginItemManager.setEnabled(value)
                    }
            }
            Section(L10n.text("general.calendar")) {
                Picker(L10n.text("general.firstDay"), selection: $firstWeekday) {
                    Text(L10n.text("general.systemSettings")).tag(0)
                    Text(L10n.text("general.sunday")).tag(1)
                    Text(L10n.text("general.monday")).tag(2)
                }
                .onChange(of: firstWeekday) { _, value in
                    model.setFirstWeekday(value)
                }
            }
            Section(L10n.text("general.events")) {
                Picker(L10n.text("general.eventTimeFormat"), selection: $eventTimeFormat) {
                    Text(L10n.text("general.oneLineTime")).tag("oneLine")
                    Text(L10n.text("general.startEndTime")).tag("withEndTime")
                }
                .onChange(of: eventTimeFormat) { _, _ in
                    model.updateEventListPreferences()
                }
            }
            Section(L10n.text("calendar.access.title")) {
                Label {
                    Text(model.accessGranted ? L10n.text("calendar.access.granted") : L10n.text("calendar.access.denied"))
                } icon: {
                    Image(systemName: model.accessGranted ? "checkmark.shield" : "exclamationmark.shield")
                        .foregroundStyle(model.accessGranted ? .green : .orange)
                }
                if !model.accessGranted {
                    Button(L10n.text("calendar.access.allow")) {
                        Task { await model.requestAccess() }
                    }
                }
                if model.authorization == .denied || model.authorization == .restricted {
                    Button(L10n.text("calendar.access.openSettings")) {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task { await model.loadIfNeeded() }
    }
}

private struct AccountsSettings: View {
    @ObservedObject var model: CalendarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.accessGranted {
                ContentUnavailableView(L10n.text("calendar.access.title"), systemImage: "person.2.slash", description: Text(L10n.text("calendar.access.denied")))
            } else if model.accounts.isEmpty {
                ContentUnavailableView(L10n.text("calendar.account.empty"), systemImage: "person.2")
            } else {
                List {
                    ForEach(model.accounts) { account in
                        Toggle(isOn: Binding(
                            get: { account.isVisible },
                            set: { model.setAccountVisible(account, isVisible: $0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.title)
                                Text(String(format: L10n.text("calendar.account.count"), account.kind, account.calendarCount))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }

            HStack {
                Spacer()
                Button {
                    model.refresh()
                } label: {
                    Label(L10n.text("calendar.account.refresh"), systemImage: "arrow.clockwise")
                }
            }
        }
        .task { await model.loadIfNeeded() }
    }
}

private struct AppearanceSettings: View {
    @AppStorage("theme") private var theme = AppTheme.system.rawValue
    @AppStorage("showWeekNumbers") private var showWeekNumbers = false

    var body: some View {
        Form {
            Picker(L10n.text("appearance.theme"), selection: $theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.title).tag(theme.rawValue)
                }
            }
            Toggle(L10n.text("appearance.showWeekNumbers"), isOn: $showWeekNumbers)
        }
        .formStyle(.grouped)
    }
}

private struct KeyboardSettings: View {
    @AppStorage("openShortcut") private var openShortcut = "⇧⌘K"

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(L10n.text("keyboard.openShortcut"))
                    Spacer()
                    TextField("⇧⌘K", text: $openShortcut)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                }
            }
            Section(L10n.text("keyboard.controlCalendar")) {
                ShortcutRow(keys: "↑ ↓ ← →", title: L10n.text("keyboard.navigateDays"))
                ShortcutRow(keys: "⌘ ← →", title: L10n.text("keyboard.navigateMonths"))
                ShortcutRow(keys: "⌘ ↑ ↓", title: L10n.text("keyboard.navigateYears"))
                ShortcutRow(keys: "1 – 9", title: L10n.text("keyboard.cycleCalendars"))
                ShortcutRow(keys: "Space", title: L10n.text("keyboard.today"))
                ShortcutRow(keys: "Return", title: L10n.text("keyboard.openSelected"))
                ShortcutRow(keys: "Esc", title: L10n.text("keyboard.hide"))
                ShortcutRow(keys: "⌘ ,", title: L10n.text("keyboard.preferences"))
                ShortcutRow(keys: "⌘ Q", title: L10n.text("keyboard.quit"))
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutRow: View {
    let keys: String
    let title: String

    var body: some View {
        HStack {
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .frame(width: 105, alignment: .leading)
            Text(title)
                .font(.body.weight(.semibold))
        }
    }
}
