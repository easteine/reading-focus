import Foundation
import AppKit

class ReadingModeManager: NSObject {
    static let shared = ReadingModeManager()

    private(set) var isActive = false
    private var endTime: Date?
    private var countdownTimer: Timer?
    private var appSwitchObserver: Any?
    private var appQuitObserver: Any?

    private var target: FocusTarget?
    // Only exit fullscreen at the end if we were the ones who entered it.
    private var enteredFullScreen = false

    // Callbacks for the status bar UI
    var onTimerTick: ((String) -> Void)?
    var onSessionEnd: (() -> Void)?

    // MARK: - Public API

    func startSession(duration: TimeInterval, target: FocusTarget) {
        guard !isActive else { return }
        isActive = true
        self.target = target
        endTime = Date().addingTimeInterval(duration)

        GestureBlocker.shared.block()
        focusAndFullscreenTarget()
        enableDoNotDisturb()
        startAppSwitchGuard()
        startCountdown()
    }

    func stopSession() {
        guard isActive else { return }
        isActive = false

        countdownTimer?.invalidate()
        countdownTimer = nil
        endTime = nil

        stopAppSwitchGuard()
        disableDoNotDisturb()
        exitTargetFullscreen()
        GestureBlocker.shared.restore()
        target = nil

        onSessionEnd?()
    }

    var formattedTimeRemaining: String {
        guard let end = endTime else { return "" }
        let remaining = max(0, end.timeIntervalSinceNow)
        let h = Int(remaining) / 3600
        let m = Int(remaining) % 3600 / 60
        let s = Int(remaining) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }

    // MARK: - Target app control

    private func focusAndFullscreenTarget() {
        guard let target else { return }
        target.activate()

        enteredFullScreen = false
        guard !target.isFullScreen else { return }
        // Give the app a moment to come forward before the fullscreen animation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.isActive, let target = self.target else { return }
            target.isFullScreen = true
            self.enteredFullScreen = true
        }
    }

    private func exitTargetFullscreen() {
        guard enteredFullScreen, let target else { return }
        target.isFullScreen = false
        enteredFullScreen = false
    }

    // MARK: - Do Not Disturb

    // Requires user to create two Shortcuts in the macOS Shortcuts app:
    //   "Reading Mode On"  — sets Do Not Disturb focus ON
    //   "Reading Mode Off" — turns Do Not Disturb OFF
    // See README for setup instructions.
    private func enableDoNotDisturb() {
        runShortcut(named: "Reading Mode On")
    }

    private func disableDoNotDisturb() {
        runShortcut(named: "Reading Mode Off")
    }

    private func runShortcut(named name: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", name]
        // Fire-and-forget; failure is silent (DND is optional convenience)
        try? task.run()
    }

    // MARK: - App switch guard

    private func startAppSwitchGuard() {
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, self.isActive else { return }

            guard let activated = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication else { return }

            guard activated.processIdentifier != self.target?.app.processIdentifier else { return }

            let bid = activated.bundleIdentifier ?? ""

            // Allow: our own app (for the Stop menu) and system UI
            let allowed = [
                Bundle.main.bundleIdentifier ?? "",
                "com.apple.dock",
                "com.apple.systemuiserver",
                "com.apple.controlcenter",
            ]
            guard !allowed.contains(bid) else { return }

            // Give the other app 0.15 s to draw before we push the target back
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self, self.isActive else { return }
                self.target?.activate()
            }
        }

        // If the locked app quits there is nothing left to guard; end the
        // session so gestures are restored instead of staying blocked.
        appQuitObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, self.isActive,
                  let quit = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                  quit.processIdentifier == self.target?.app.processIdentifier else { return }
            self.stopSession()
        }
    }

    private func stopAppSwitchGuard() {
        if let obs = appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            appSwitchObserver = nil
        }
        if let obs = appQuitObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            appQuitObserver = nil
        }
    }

    // MARK: - Countdown

    private func startCountdown() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard let end = self.endTime else { return }

            if end.timeIntervalSinceNow <= 0 {
                self.stopSession()
            } else {
                self.onTimerTick?(self.formattedTimeRemaining)
            }
        }
    }
}
