import Foundation
import AppKit

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func sendAnalysisCompleteNotification(projectName: String) {
        let notification = NSUserNotification()
        notification.title = "AI Analysis Complete".localized(comment: "Notification title")
        notification.informativeText = String(format: "AI analysis for project \"%1$@\" is complete".localized(comment: "Notification message"), projectName)
        notification.soundName = NSUserNotificationDefaultSoundName

        NSUserNotificationCenter.default.deliver(notification)
    }
}
