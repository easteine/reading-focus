import AppKit
import ApplicationServices

/// The app and window a session locks to: whatever was in front when the
/// menu bar menu was opened.
struct FocusTarget {
    let app: NSRunningApplication
    /// The app's main window, if Accessibility access allows us to read it.
    let window: AXUIElement?

    var appName: String { app.localizedName ?? "this app" }

    var windowTitle: String? {
        guard let window else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value) == .success,
              let title = value as? String, !title.isEmpty else { return nil }
        return title
    }

    var isFullScreen: Bool {
        get {
            guard let window else { return false }
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value) == .success
            else { return false }
            return (value as? Bool) ?? false
        }
        nonmutating set {
            guard let window else { return }
            AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, newValue as CFBoolean)
        }
    }

    /// Brings the app forward and puts the locked window on top.
    func activate() {
        app.activate(options: [.activateIgnoringOtherApps])
        if let window {
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
    }

    /// The frontmost app other than Reading Focus itself, with its main window.
    static func current() -> FocusTarget? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }

        return FocusTarget(app: app, window: window(of: app))
    }

    /// The app's main (or focused) window via Accessibility; nil if not trusted.
    static func window(of app: NSRunningApplication) -> AXUIElement? {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        for attribute in [kAXMainWindowAttribute, kAXFocusedWindowAttribute] {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(axApp, attribute as CFString, &value) == .success,
               let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
                return (value as! AXUIElement)
            }
        }
        return nil
    }
}
