import Cocoa
import UserNotifications

class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let manager = ReadingModeManager.shared
    // Captured when the menu opens, before our own alerts can take focus.
    private var pendingTarget: FocusTarget?
    private weak var targetItem: NSMenuItem?

    override init() {
        super.init()
        configureButton()
        rebuildMenu()
        wireManagerCallbacks()
    }

    // MARK: - Setup

    private func configureButton() {
        guard let btn = statusItem.button else { return }
        btn.image = bookIcon(active: false)
        btn.imagePosition = .imageLeft
    }

    private func wireManagerCallbacks() {
        manager.onTimerTick = { [weak self] remaining in
            DispatchQueue.main.async {
                self?.statusItem.button?.title = " \(remaining)"
                // Keep menu items current without rebuilding every second
            }
        }

        manager.onSessionEnd = { [weak self] in
            DispatchQueue.main.async {
                self?.statusItem.button?.title = ""
                self?.statusItem.button?.image = self?.bookIcon(active: false)
                self?.rebuildMenu()
                self?.fireSessionEndNotification()
            }
        }
    }

    // MARK: - Menu

    private func rebuildMenu() {
        let menu = NSMenu()

        if manager.isActive {
            let header = NSMenuItem(title: "Reading — \(manager.formattedTimeRemaining) left", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            menu.addItem(.separator())

            let stop = NSMenuItem(title: "Stop Session", action: #selector(stopSession), keyEquivalent: "s")
            stop.target = self
            menu.addItem(stop)
        } else {
            let header = NSMenuItem(title: "Start Reading Session", action: nil, keyEquivalent: "")
            header.isEnabled = false
            header.attributedTitle = NSAttributedString(
                string: "Start Reading Session",
                attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
            )
            menu.addItem(header)

            let target = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            target.isEnabled = false
            menu.addItem(target)
            targetItem = target
            menu.addItem(.separator())

            for (label, minutes) in presets {
                let item = NSMenuItem(title: label, action: #selector(startPreset(_:)), keyEquivalent: "")
                item.representedObject = minutes
                item.target = self
                menu.addItem(item)
            }

            menu.addItem(.separator())
            let custom = NSMenuItem(title: "Custom duration…", action: #selector(promptCustomDuration), keyEquivalent: "")
            custom.target = self
            menu.addItem(custom)
        }

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Reading Focus", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        menu.delegate = self
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard !manager.isActive else { return }
        // Opening a status bar menu doesn't activate us, so the frontmost app
        // is still whatever the user was looking at.
        pendingTarget = FocusTarget.current()
        targetItem?.title = targetDescription(pendingTarget)
    }

    private func targetDescription(_ target: FocusTarget?) -> String {
        guard let target else { return "Locks to: no app in front" }
        if let title = target.windowTitle {
            let short = title.count > 40 ? String(title.prefix(40)) + "…" : title
            return "Locks to: \(target.appName) — \(short)"
        }
        return "Locks to: \(target.appName)"
    }

    private let presets: [(String, Int)] = [
        ("15 minutes", 15),
        ("30 minutes", 30),
        ("45 minutes", 45),
        ("1 hour", 60),
        ("90 minutes", 90),
        ("2 hours", 120),
    ]

    // MARK: - Actions

    @objc private func startPreset(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        launch(minutes: minutes)
    }

    @objc private func promptCustomDuration() {
        let alert = NSAlert()
        alert.messageText = "Custom Reading Duration"
        alert.informativeText = "How many minutes would you like to focus?"
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 180, height: 24))
        field.placeholderString = "e.g. 25"
        field.bezelStyle = .roundedBezel
        alert.accessoryView = field

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        guard response == .alertFirstButtonReturn else { return }
        let raw = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard let minutes = Int(raw), minutes > 0 else {
            showError("Please enter a positive number of minutes.")
            return
        }
        launch(minutes: minutes)
    }

    @objc private func stopSession() {
        manager.stopSession()
        rebuildMenu()
    }

    // MARK: - Launch

    private func launch(minutes: Int) {
        // AXIsProcessTrustedWithOptions with prompt:true triggers the macOS system dialog
        // on first run. It returns false until the user grants AND relaunches the app.
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            showAccessibilityDialog()
            return
        }
        // Re-read the window now that Accessibility is confirmed trusted.
        guard let captured = pendingTarget else {
            showError("Click the app you want to focus on so it is in front, then start the session.")
            return
        }
        let target = FocusTarget(app: captured.app,
                                 window: captured.window ?? FocusTarget.window(of: captured.app))
        statusItem.button?.image = bookIcon(active: true)
        statusItem.button?.title = " Starting…"
        manager.startSession(duration: TimeInterval(minutes * 60), target: target)
        rebuildMenu()
    }

    // MARK: - Permissions

    private func showAccessibilityDialog() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
            Reading Focus needs Accessibility access to fullscreen your app and keep it in front.

            1. Open System Settings → Privacy & Security → Accessibility
            2. Enable the toggle next to Reading Focus
               (If not listed, click + and add it from /Applications)
            3. Quit and relaunch Reading Focus
            """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    // MARK: - Notification

    private func fireSessionEndNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Reading Session Complete"
        content.body = "Great job! Your reading session has ended."
        content.sound = .default

        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    // MARK: - Helpers

    private func bookIcon(active: Bool) -> NSImage? {
        let name = active ? "book.closed.fill" : "book.fill"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        img?.isTemplate = true
        return img
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Can't Start Session"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
