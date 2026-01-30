import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBarItem: NSStatusItem?
    private let windowManager = FloatingWindowManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        setupClipboardMonitor()
        registerGlobalShortcut()
        requestPermissions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClipboardMonitor.shared.stop()
        windowManager.cleanup()
    }

    private func setupStatusBarItem() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipFlow")
            button.action = #selector(toggleFloatingWindow)
        }
    }

    private func setupClipboardMonitor() {
        ClipboardMonitor.shared.start()
    }

    private func registerGlobalShortcut() {
        let shortcut = HotKeyManager.shared.loadSavedShortcut()
        _ = HotKeyManager.shared.register(shortcut)

        HotKeyManager.shared.onHotKeyPressed = { [weak self] in
            self?.toggleFloatingWindow()
        }
    }

    private func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        if !trusted {
            ClipFlowLogger.warning("Accessibility permissions not granted. Global shortcuts may not work.")
            ClipFlowLogger.info("Please enable 'ClipFlow' in System Settings > Privacy & Security > Accessibility")
        }
    }

    @objc private func toggleFloatingWindow() {
        windowManager.toggleWindow()
    }
}
