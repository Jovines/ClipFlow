import Cocoa
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private let windowManager = FloatingWindowManager.shared
    private var isFloatingWindowActive = false
    private var welcomeWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindowFocusMonitoring()
        setupWindowNotifications()

        if PermissionManager.shared.isFirstLaunch {
            showWelcomeWindow()
        } else {
            setupClipboardMonitor()
            checkAndRequestAccessibilityPermission()
        }
    }

    private func showWelcomeWindow() {
        let welcomeView = WelcomeView(onComplete: { [weak self] in
            self?.setupClipboardMonitor()
            self?.checkAndRequestAccessibilityPermission()
        })

        let hostingController = NSHostingController(rootView: welcomeView)

        welcomeWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        welcomeWindow?.contentViewController = hostingController
        welcomeWindow?.title = "欢迎使用 ClipFlow"
        welcomeWindow?.isReleasedWhenClosed = false
        welcomeWindow?.center()
        welcomeWindow?.orderFrontRegardless()
        welcomeWindow?.makeKey()
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
        if !PermissionManager.shared.isFirstLaunch {
            if PermissionManager.shared.hasAccessibilityPermission {
                let hasShortcut = HotKeyManager.shared.currentShortcut != nil

                if !hasShortcut {
                    registerGlobalShortcut()
                }
            }
        }
    }

    private func setupClipboardMonitor() {
        if PermissionManager.shared.hasClipboardMonitoringConsent {
            ClipboardMonitor.shared.start()
        }
    }

    private func checkAndRequestAccessibilityPermission() {
        PermissionManager.shared.checkAccessibilityPermission()

        if PermissionManager.shared.hasAccessibilityPermission {
            registerGlobalShortcut()
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
