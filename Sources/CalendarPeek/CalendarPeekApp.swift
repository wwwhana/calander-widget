import AppKit
import SwiftUI

@main
enum CalendarPeekApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = CalendarViewModel()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var settingsWindowController: NSWindowController?
    private var defaultsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configurePopover()
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateStatusItem() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusItem()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: CalendarPopover(
            model: model,
            openSettings: { [weak self] in self?.showSettings(nil) },
            dismiss: { [weak self] in self?.popover.performClose(nil) }
        ))
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let date = Date()
        let style = StatusBarIconStyle(rawValue: UserDefaults.standard.string(forKey: "statusBarIconStyle") ?? "") ?? .calendar

        button.image = nil
        button.title = ""
        switch style {
        case .calendar:
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)
            button.image?.isTemplate = true
            button.title = " \(Calendar.current.component(.day, from: date))"
        case .date:
            button.title = date.formatted(.dateTime.month(.abbreviated).day())
        case .minimal:
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)
            button.image?.isTemplate = true
        }
        button.toolTip = L10n.text("app.name")
    }

    @objc private func statusItemClicked(_ button: NSStatusBarButton) {
        updateStatusItem()
        if NSApp.currentEvent?.type == .rightMouseUp {
            popover.performClose(nil)
            showContextMenu(from: button)
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        let settings = NSMenuItem(title: L10n.text("settings"), action: #selector(showSettings(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: L10n.text("calendar.menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        menu.popUp(positioning: nil, at: .zero, in: button)
    }

    @objc private func showSettings(_ sender: Any?) {
        if settingsWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 650, height: 620),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = L10n.text("settings")
            window.contentViewController = NSHostingController(rootView: SettingsView(model: model))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindowController = NSWindowController(window: window)
        }
        settingsWindowController?.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
