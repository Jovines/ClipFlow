import AppKit
import Combine
import SwiftUI

final class FloatingWindowManager: ObservableObject {
    static let shared = FloatingWindowManager()

    @Published private(set) var isWindowVisible = false
    @Published private(set) var isWindowLoaded = false

    private(set) var floatingWindow: FloatingWindow?
    var floatingWindowHostingController: NSHostingController<FloatingWindowView>?
    private let clipboardMonitor: ClipboardMonitor
    private var cancellables = Set<AnyCancellable>()
    private var clickOutsideMonitor: Any?
    private var previousActiveApp: NSRunningApplication?
    private var isPasting = false

    private let windowWidth: CGFloat = 360
    private let windowHeight: CGFloat = 480
    private let maxVisibleItems = 10
    private let itemsPerGroup = 10

    private init(clipboardMonitor: ClipboardMonitor = .shared) {
        self.clipboardMonitor = clipboardMonitor
        setupBindings()
    }

    private func setupBindings() {
        NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)
            .sink { [weak self] notification in
                if notification.object as? NSWindow == self?.floatingWindow {
                    DispatchQueue.main.async {
                        self?.isWindowVisible = false
                    }
                }
            }
            .store(in: &cancellables)
    }

    func showWindow() {
        guard !isWindowVisible else {
            bringWindowToFront()
            return
        }

        NotificationCenter.default.post(name: NSNotification.Name("FloatingWindowWillShow"), object: nil)

        previousActiveApp = NSWorkspace.shared.frontmostApplication

        if floatingWindow == nil {
            createWindow()
        }

        positionWindow()
        floatingWindow?.orderFront(nil)
        floatingWindow?.makeKeyAndOrderFront(nil)

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.floatingWindow?.makeKey()
            self.floatingWindow?.makeFirstResponder(self.floatingWindowHostingController?.view)
        }

        isWindowVisible = true
        startClickOutsideMonitoring()
    }

    func hideWindow() {
        stopClickOutsideMonitoring()
        floatingWindow?.orderOut(nil)
        isWindowVisible = false
        NotificationCenter.default.post(name: NSNotification.Name("FloatingWindowDidHide"), object: nil)
    }

    func hideWindowForPaste() {
        stopClickOutsideMonitoring()
        floatingWindow?.orderOut(nil)
        isWindowVisible = false

        if let previousApp = previousActiveApp {
            previousApp.activate(options: .activateIgnoringOtherApps)
        }

        NotificationCenter.default.post(name: NSNotification.Name("FloatingWindowDidHide"), object: nil)
    }

    func toggleWindow() {
        if isWindowVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    func bringWindowToFront() {
        floatingWindow?.orderFrontRegardless()
    }

    func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        ClipFlowLogger.info("Paste command simulated (Cmd+V)")
    }

    private func createWindow() {
        let floatingView = FloatingWindowView(
            onClose: { [weak self] in
                self?.hideWindow()
            },
            onItemSelected: { [weak self] item in
                self?.isPasting = true
                self?.clipboardMonitor.copyToClipboard(item)
                self?.hideWindowForPaste()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.simulatePaste()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self?.isPasting = false
                    }
                }
            },
            maxVisibleItems: maxVisibleItems,
            clipboardMonitor: clipboardMonitor
        )

        floatingWindowHostingController = FocusRinglessHostingController(rootView: floatingView)

        let window = FloatingWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentView = floatingWindowHostingController?.view
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .managed]
        window.setIsVisible(false)

        floatingWindow = window
        isWindowLoaded = true
    }

    private func positionWindow() {
        guard let window = floatingWindow else { return }

        let mouseLocation = NSEvent.mouseLocation

        let targetScreen = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first

        guard let screen = targetScreen else { return }

        let screenFrame = screen.visibleFrame
        let screenFrameFull = screen.frame

        ClipFlowLogger.debug("=== Position Debug ===")
        ClipFlowLogger.debug("Mouse location: (\(mouseLocation.x), \(mouseLocation.y))")
        ClipFlowLogger.debug("Screen full frame: minX=\(screenFrameFull.minX), maxX=\(screenFrameFull.maxX), minY=\(screenFrameFull.minY), maxY=\(screenFrameFull.maxY)")
        ClipFlowLogger.debug("Screen visible frame: minX=\(screenFrame.minX), maxX=\(screenFrame.maxX), minY=\(screenFrame.minY), maxY=\(screenFrame.maxY)")
        ClipFlowLogger.debug("Window size: (\(windowWidth), \(windowHeight))")

        let margin: CGFloat = 2

        var windowOrigin = NSPoint(x: 0, y: 0)

        let minX = screenFrame.minX + margin
        let maxX = screenFrame.maxX - margin - windowWidth
        let minY = screenFrame.minY + margin
        let maxY = screenFrame.maxY - margin

        windowOrigin.x = mouseLocation.x - windowWidth / 2
        if windowOrigin.x < minX {
            windowOrigin.x = minX
        } else if windowOrigin.x > maxX {
            windowOrigin.x = maxX
        }

        let spaceBelow = mouseLocation.y - minY
        let spaceAbove = maxY - mouseLocation.y
        
        let screenHeight = maxY - minY
        let mouseRelativeY = mouseLocation.y - minY
        let isMouseInLowerHalf = mouseRelativeY > screenHeight * 0.6
        
        ClipFlowLogger.debug("spaceBelow: \(spaceBelow), spaceAbove: \(spaceAbove), windowHeight: \(windowHeight)")
        ClipFlowLogger.debug("minY: \(minY), maxY: \(maxY)")
        ClipFlowLogger.debug("mouseRelativeY: \(mouseRelativeY), screenHeight: \(screenHeight), isMouseInLowerHalf: \(isMouseInLowerHalf)")

        if spaceBelow >= windowHeight && (!isMouseInLowerHalf || spaceAbove < windowHeight) {
            windowOrigin.y = mouseLocation.y - windowHeight - margin
            ClipFlowLogger.debug("Placing window BELOW mouse")
        } else if spaceAbove >= windowHeight {
            windowOrigin.y = mouseLocation.y + margin
            ClipFlowLogger.debug("Placing window ABOVE mouse")
        } else {
            windowOrigin.y = spaceBelow > spaceAbove ? minY : maxY - windowHeight
            ClipFlowLogger.debug("Placing window at EDGE: \(spaceBelow > spaceAbove ? "BOTTOM" : "TOP")")
        }

        ClipFlowLogger.debug("Final window origin: (\(windowOrigin.x), \(windowOrigin.y))")
        ClipFlowLogger.debug("Window will appear at: x=\(Int(windowOrigin.x)), y=\(Int(windowOrigin.y))")
        
        let minValidY = minY
        let maxValidY = maxY - windowHeight
        if windowOrigin.y < minValidY {
            ClipFlowLogger.debug("WARNING: Window y (\(windowOrigin.y)) < minValidY (\(minValidY)), clamping")
            windowOrigin.y = minValidY
        } else if windowOrigin.y > maxValidY {
            ClipFlowLogger.debug("WARNING: Window y (\(windowOrigin.y)) > maxValidY (\(maxValidY)), clamping")
            windowOrigin.y = maxValidY
        }
        
        ClipFlowLogger.debug("Window frame: (\(windowOrigin.x), \(windowOrigin.y)) [\(windowWidth)×\(windowHeight)]")
        ClipFlowLogger.debug("Mouse to window bottom distance: \(abs(mouseLocation.y - windowOrigin.y))")
        ClipFlowLogger.debug("Mouse to window top distance: \(abs(mouseLocation.y - (windowOrigin.y + windowHeight)))")
        ClipFlowLogger.debug("Window placement: \(windowOrigin.y < mouseLocation.y ? "BELOW mouse" : "ABOVE mouse")")

        window.setFrameOrigin(windowOrigin)
    }

    func cleanup() {
        hideWindow()
        stopClickOutsideMonitoring()
        floatingWindowHostingController = nil
        floatingWindow = nil
        isWindowLoaded = false
    }

    private func startClickOutsideMonitoring() {
        stopClickOutsideMonitoring()

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isWindowVisible, let window = self.floatingWindow else { return }

            let mouseLocation = NSEvent.mouseLocation
            if !NSMouseInRect(mouseLocation, window.frame, false) {
                DispatchQueue.main.async {
                    self.hideWindow()
                }
            }
        }
    }

    private func stopClickOutsideMonitoring() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }
}
