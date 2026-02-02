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
        print("[INFO] 应用启动，当前窗口: \(NSApp.windows.map { "\($0.title):\($0.isVisible)" })")
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
            print("[INFO] 窗口关闭: \(window.title), 剩余窗口: \(NSApp.windows.map { "\($0.title):\($0.isVisible)" })")
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
            ClipFlowLogger.info("DidBecomeActive - trusted: \(trusted), hasShortcut: \(hasShortcut)")
            
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
        ClipFlowLogger.info("Initial permission check - trusted: \(trusted)")
        
        if trusted {
            registerGlobalShortcut()
        } else {
            let promptKey = "AXTrustedCheckOptionPrompt"
            let options: [String: Bool] = [promptKey: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
            ClipFlowLogger.info("System permission prompt shown")
        }
    }

    private func registerGlobalShortcut() {
        let shortcut = HotKeyManager.shared.loadSavedShortcut()
        ClipFlowLogger.info("Attempting to register shortcut: \(shortcut.displayString)")
        
        let success = HotKeyManager.shared.register(shortcut)
        
        if success {
            HotKeyManager.shared.onHotKeyPressed = { [weak self] in
                ClipFlowLogger.info("Hotkey pressed!")
                self?.toggleFloatingWindow()
            }
            ClipFlowLogger.info("Global shortcut registered successfully: \(shortcut.displayString)")
        } else {
            ClipFlowLogger.error("Failed to register global shortcut: \(shortcut.displayString)")
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
