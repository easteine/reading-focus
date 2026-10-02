import Foundation

// Turns off the trackpad gestures that leave the current space, for the length
// of a session.
//
// On macOS 26 (Tahoe) space-switching swipes are handled before a CGEventTap can
// see them, so the only reliable block is the system preference itself — the
// same thing System Settings → Trackpad → More Gestures changes. The setting is
// stored in three places and all of them must agree. The change takes effect
// live; no Dock restart is needed.
//
// The original values are saved to UserDefaults before anything is changed, so
// a crash mid-session is repaired on the next launch via restoreIfNeeded().
class GestureBlocker {
    static let shared = GestureBlocker()

    private struct Pref {
        let domain: String
        let key: String
        let currentHost: Bool

        // Stable identifier used in the saved-values dictionary.
        var id: String { "\(currentHost ? "host" : "user")|\(domain)|\(key)" }

        var host: CFString { currentHost ? kCFPreferencesCurrentHost : kCFPreferencesAnyHost }
    }

    private static let trackpadKeys = [
        "TrackpadThreeFingerHorizSwipeGesture",  // swipe between full-screen apps
        "TrackpadFourFingerHorizSwipeGesture",
        "TrackpadThreeFingerVertSwipeGesture",   // Mission Control / App Exposé
        "TrackpadFourFingerVertSwipeGesture",
    ]

    private static let globalKeys = [
        "com.apple.trackpad.threeFingerHorizSwipeGesture",
        "com.apple.trackpad.fourFingerHorizSwipeGesture",
        "com.apple.trackpad.threeFingerVertSwipeGesture",
        "com.apple.trackpad.fourFingerVertSwipeGesture",
    ]

    private static let prefs: [Pref] =
        trackpadKeys.map { Pref(domain: "com.apple.AppleMultitouchTrackpad", key: $0, currentHost: false) } +
        trackpadKeys.map { Pref(domain: "com.apple.driver.AppleBluetoothMultitouch.trackpad", key: $0, currentHost: false) } +
        globalKeys.map { Pref(domain: kCFPreferencesAnyApplication as String, key: $0, currentHost: true) }

    private let savedKey = "savedGesturePrefs"
    // Marker for "key was not set" so restore can delete it rather than write 0.
    private let absent = "absent"

    // MARK: - Public API

    func block() {
        // If values are already saved, a previous session never restored them —
        // keep those originals instead of overwriting them with our own zeros.
        if UserDefaults.standard.dictionary(forKey: savedKey) == nil {
            var saved: [String: Any] = [:]
            for pref in Self.prefs {
                saved[pref.id] = read(pref) ?? absent
            }
            UserDefaults.standard.set(saved, forKey: savedKey)
        }

        for pref in Self.prefs {
            write(pref, value: 0)
        }
        apply()
        NSLog("ReadingFocus: space-switching gestures disabled")
    }

    func restore() {
        guard let saved = UserDefaults.standard.dictionary(forKey: savedKey) else { return }
        for pref in Self.prefs {
            write(pref, value: saved[pref.id] as? Int)
        }
        apply()
        UserDefaults.standard.removeObject(forKey: savedKey)
        NSLog("ReadingFocus: space-switching gestures restored")
    }

    /// Call at launch: undoes a block left behind by a crash or force-quit.
    func restoreIfNeeded() {
        if UserDefaults.standard.dictionary(forKey: savedKey) != nil {
            restore()
        }
    }

    // MARK: - Preferences

    private func read(_ pref: Pref) -> Int? {
        CFPreferencesCopyValue(pref.key as CFString, pref.domain as CFString,
                               kCFPreferencesCurrentUser, pref.host) as? Int
    }

    private func write(_ pref: Pref, value: Int?) {
        CFPreferencesSetValue(pref.key as CFString, value.map { $0 as CFNumber },
                              pref.domain as CFString, kCFPreferencesCurrentUser, pref.host)
    }

    private func apply() {
        for pref in Self.prefs {
            CFPreferencesSynchronize(pref.domain as CFString, kCFPreferencesCurrentUser, pref.host)
        }

        // Same mechanism System Settings uses to push input prefs to the driver.
        let activateSettings = "/System/Library/PrivateFrameworks/" +
            "SystemAdministration.framework/Resources/activateSettings"
        if FileManager.default.fileExists(atPath: activateSettings) {
            runProcess(activateSettings, args: ["-u"])
        }
    }

    private func runProcess(_ path: String, args: [String]) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()
    }
}
