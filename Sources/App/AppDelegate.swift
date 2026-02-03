import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    private let windowManager = FloatingWindowManager.shared
    private var hasCheckedPermission = false
    private var isFloatingWindowActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupClipboardMonitor()
        checkAndRequestAccessibilityPermission()
        setupWindowFocusMonitoring()
        setupWindowNotifications()
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
        } else {
            let promptKey = "AXTrustedCheckOptionPrompt"
            let options: [String: Bool] = [promptKey: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
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
            NSApp.windows.filter { window in
                window.title == "ClipFlow"
            }.forEach { window in
                print("[INFO] 关闭主窗口: \(window.title)")
                window.close()
            }
        }
    }
}
