import AppKit
import SwiftUI
import Combine

@MainActor
final class SettingsWindowManager: ObservableObject, @unchecked Sendable {
    static let shared = SettingsWindowManager()
    
    @Published private(set) var window: NSWindow?
    private var hostingController: NSHostingController<SettingsView>?
    private var cancellables = Set<AnyCancellable>()
    private var themeObservation: NSKeyValueObservation?
    
    private init() {
        setupWindowNotifications()
        setupThemeObserver()
        setupColorSchemeObserver()
    }

    private func setupThemeObserver() {
        themeObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            self?.updateWindowBackgroundColor()
        }
    }

    private func setupColorSchemeObserver() {
        NotificationCenter.default.publisher(for: ThemeManager.colorSchemeDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateWindowBackgroundColor()
            }
            .store(in: &cancellables)
    }

    private func updateWindowBackgroundColor() {
        window?.backgroundColor = NSColor(ThemeManager.shared.background)
    }
    
    private func setupWindowNotifications() {
        NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)
            .sink { [weak self] notification in
                if notification.object as? NSWindow == self?.window {
                    self?.window?.orderOut(nil)
                }
            }
            .store(in: &cancellables)
    }
    
    func show() {
        if window == nil {
            createWindow()
        }
        
        guard let window = window else { return }
        
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        window.makeFirstResponder(hostingController?.view)
    }
    
    private func createWindow() {
        let settingsView = SettingsView()
        hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.contentView = hostingController?.view
        window.title = "Settings".localized
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = NSColor(ThemeManager.shared.background)
        
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        self.window = window
    }
    
    func close() {
        window?.orderOut(nil)
    }
    
    func toggle() {
        if let window = window, window.isVisible {
            close()
        } else {
            show()
        }
    }
}
