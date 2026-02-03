import Foundation
import AppKit

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func sendAnalysisCompleteNotification(projectName: String) {
        let notification = NSUserNotification()
        notification.title = "AI 分析完成"
        notification.informativeText = "项目「\(projectName)」的 AI 分析已完成"
        notification.soundName = NSUserNotificationDefaultSoundName

        NSUserNotificationCenter.default.deliver(notification)
    }
}
