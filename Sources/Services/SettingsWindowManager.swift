import AppKit
import SwiftUI
import Combine

final class SettingsWindowManager: ObservableObject {
    static let shared = SettingsWindowManager()
    
    private(set) var window: NSWindow?
    private var hostingController: NSHostingController<SettingsView>?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupWindowNotifications()
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
        
        DispatchQueue.main.async {
            window.makeFirstResponder(self.hostingController?.view)
        }
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
        window.title = NSLocalizedString("Settings", comment: "")
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = NSColor(Color.flexokiPaper)
        
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
