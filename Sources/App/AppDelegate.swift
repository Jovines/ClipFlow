import Cocoa
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private let windowManager = FloatingWindowManager.shared
    private let focusTodoWindowManager = FocusTodoWindowManager.shared
    private var userDefaultsObserver: NSObjectProtocol?
    private var hasCheckedPermission = false
    private var isFloatingWindowActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupClipboardMonitor()
        checkAndRequestAccessibilityPermission()
        setupWindowFocusMonitoring()
        setupWindowNotifications()
        setupFocusTodoFeatureObserver()
        syncFocusTodoFeatureState()
    }

    private func setupWindowNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidClose),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    @objc private func windowDidClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClipboardMonitor.shared.stop()
        windowManager.cleanup()
        focusTodoWindowManager.cleanup()
        Task {
            await PersistentShellSession.shared.terminateSession()
        }
        if let userDefaultsObserver {
            NotificationCenter.default.removeObserver(userDefaultsObserver)
        }
        userDefaultsObserver = nil
    }

    private func setupFocusTodoFeatureObserver() {
        guard userDefaultsObserver == nil else { return }
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncFocusTodoFeatureState()
            }
        }
    }

    private func syncFocusTodoFeatureState() {
        let isEnabled = UserDefaults.standard.object(forKey: FocusTodoPreferences.isEnabledKey) as? Bool ?? FocusTodoPreferences.defaultIsEnabled
        if isEnabled {
            focusTodoWindowManager.start()
        } else {
            focusTodoWindowManager.cleanup()
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        if hasCheckedPermission {
            let trusted = AXIsProcessTrustedWithOptions(nil)
            let hasShortcut = HotKeyManager.shared.currentShortcut != nil

            if trusted && !hasShortcut {
                registerGlobalShortcut()
            }
        }
    }

    private func setupClipboardMonitor() {
        ClipboardMonitor.shared.start()
    }
    
    private func checkAndRequestAccessibilityPermission() {
        hasCheckedPermission = true
        
        let trusted = AXIsProcessTrustedWithOptions(nil)

        if trusted {
            registerGlobalShortcut()
        }
    }

    func requestAccessibilityPermissionPrompt() {
        let options: [String: Bool] = ["AXTrustedCheckOptionPrompt": true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func openAccessibilitySettings() {
        guard let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(settingsURL)
    }

    private func registerGlobalShortcut() {
        let shortcut = HotKeyManager.shared.loadSavedShortcut()
        
        let success = HotKeyManager.shared.register(shortcut)
        
        if success {
            HotKeyManager.shared.onHotKeyPressed = { [weak self] in
                self?.toggleFloatingWindow()
            }
        }
    }

    @objc private func toggleFloatingWindow() {
        windowManager.toggleWindow()
    }

    private func setupWindowFocusMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(floatingWindowWillShow),
            name: NSNotification.Name("FloatingWindowWillShow"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(floatingWindowDidHide),
            name: NSNotification.Name("FloatingWindowDidHide"),
            object: nil
        )
    }

    @objc private func applicationDidResignActive() {
        ClipFlowLogger.info("applicationDidResignActive - isFloatingWindowActive: \(isFloatingWindowActive), windows: \(NSApp.windows.map { "\($0.title):\($0.isVisible)" })")
        if !isFloatingWindowActive {
            closeMainWindow()
        }
    }

    @objc private func floatingWindowWillShow() {
        isFloatingWindowActive = true
    }

    @objc private func floatingWindowDidHide() {
        isFloatingWindowActive = false
    }

    private func closeMainWindow() {
        Task { @MainActor in
            let settingsWindow = SettingsWindowManager.shared.window
            NSApp.windows
                .filter { window in
                    window.isVisible &&
                    window.level == .normal &&
                    window !== settingsWindow &&
                    !(window is FloatingWindow)
                }
                .forEach { window in
                    window.close()
                }
        }
    }
}
