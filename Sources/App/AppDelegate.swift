import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBarItem: NSStatusItem?
    private let windowManager = FloatingWindowManager.shared
    private var hasCheckedPermission = false
    private var isFloatingWindowActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        setupClipboardMonitor()
        checkAndRequestAccessibilityPermission()
        setupWindowFocusMonitoring()
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

    private func setupStatusBarItem() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipFlow")
            button.target = self
            button.action = #selector(toggleFloatingWindow)
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
            let options: [String: Bool] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            NSApp.windows.filter { $0 != self.windowManager.floatingWindow }.forEach { window in
                window.close()
            }
        }
    }
}
