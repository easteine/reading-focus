import Cocoa
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permission for session-end alert
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Undo a gesture block left behind if the app crashed mid-session
        GestureBlocker.shared.restoreIfNeeded()

        statusBarController = StatusBarController()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Clean up any active session before quitting
        if ReadingModeManager.shared.isActive {
            ReadingModeManager.shared.stopSession()
        }
        return .terminateNow
    }
}
