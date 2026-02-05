import Foundation
import AppKit

final class PermissionManager: ObservableObject, @unchecked Sendable {
    static let shared = PermissionManager()

    @Published var hasAccessibilityPermission = false
    @Published var hasClipboardMonitoringConsent = false
    @Published var hasShownWelcome = false

    private let userDefaults = UserDefaults.standard
    private let lock = NSLock()

    private enum Keys {
        static let hasShownWelcome = "hasShownWelcome"
        static let hasClipboardMonitoringConsent = "hasClipboardMonitoringConsent"
    }

    private init() {
        loadPermissionStatus()
    }

    var isFirstLaunch: Bool {
        !userDefaults.bool(forKey: Keys.hasShownWelcome)
    }

    var needsClipboardConsent: Bool {
        !hasClipboardMonitoringConsent
    }

    func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrustedWithOptions(nil)
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = trusted
        }
    }

    func requestAccessibilityPermission(completion: (@Sendable (Bool) -> Void)? = nil) {
        let promptKey = "AXTrustedCheckOptionPrompt"
        let options: [String: Bool] = [promptKey: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        let granted = trusted
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.hasAccessibilityPermission = granted
            completion?(granted)
        }
    }

    @MainActor
    func requestClipboardMonitoringConsent() {
        let alert = NSAlert()
        alert.messageText = "允许 ClipFlow 监控剪贴板？"
        alert.informativeText = "ClipFlow 需要访问您的剪贴板来保存历史记录。\n\n所有数据仅存储在本地，不会上传到任何服务器。\n\n您可以在设置中随时关闭此功能。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "允许")
        alert.addButton(withTitle: "不允许")

        let response = alert.runModal()
        let granted = response == .alertFirstButtonReturn

        self.hasClipboardMonitoringConsent = granted
        self.userDefaults.set(granted, forKey: Keys.hasClipboardMonitoringConsent)

        if granted {
            ClipboardMonitor.shared.start()
        }
    }

    func markWelcomeShown() {
        userDefaults.set(true, forKey: Keys.hasShownWelcome)
        DispatchQueue.main.async {
            self.hasShownWelcome = true
        }
    }

    private func loadPermissionStatus() {
        hasShownWelcome = userDefaults.bool(forKey: Keys.hasShownWelcome)
        hasClipboardMonitoringConsent = userDefaults.bool(forKey: Keys.hasClipboardMonitoringConsent)
        checkAccessibilityPermission()
    }

    func openAccessibilityPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.securityAccessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
