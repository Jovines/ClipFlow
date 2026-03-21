// swiftlint:disable file_length
import AppKit
import Combine
import SwiftUI

final class FloatingWindowManager: ObservableObject, @unchecked Sendable {
    static let shared = FloatingWindowManager()

    @Published private(set) var isWindowVisible = false
    @Published private(set) var isWindowLoaded = false
    @Published var isProjectMode: Bool = false
    @Published var currentProject: Project? = nil

    private(set) var floatingWindow: FloatingWindow?
    var floatingWindowHostingController: NSHostingController<FloatingWindowView>?
    var projectWindowHostingController: NSHostingController<ProjectModeContainerView>?
    private let clipboardMonitor: ClipboardMonitor
    private var cancellables = Set<AnyCancellable>()
    private var clickOutsideMonitor: Any?
    private var previousActiveApp: NSRunningApplication?
    private var isPasting = false

    private let windowWidth: CGFloat = 360
    private let projectWindowWidth: CGFloat = 680
    private let windowHeight: CGFloat = 480
    private let maxVisibleItems = 15
    private let itemsPerGroup = 15
    private let screenMargin: CGFloat = 2

    private init(clipboardMonitor: ClipboardMonitor = .shared) {
        self.clipboardMonitor = clipboardMonitor
        setupBindings()
        setupProjectBindings()
    }

    private func setupBindings() {
        let window = floatingWindow
        NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)
            .sink { notification in
                if notification.object as? NSWindow == window {
                    Task { @MainActor in
                        self.isWindowVisible = false
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupProjectBindings() {
        // Observe changes to active project
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let projectId = ProjectService.shared.activeProjectId
            let newMode = projectId != nil
            if self.isProjectMode != newMode || (projectId != nil && self.currentProject?.id != projectId) {
                DispatchQueue.main.async {
                    self.isProjectMode = newMode
                    if let pid = projectId {
                        self.currentProject = ProjectService.shared.projects.first { $0.id == pid }
                    } else {
                        self.currentProject = nil
                    }
                }
            }
        }
    }
    
    func enterProjectMode(_ project: Project) {
        Task {
            try? await ProjectService.shared.activateProject(id: project.id)
            await MainActor.run {
                if isWindowVisible {
                    // Recreate window for project mode
                    hideWindow()
                    showProjectWindow(project: project)
                }
            }
        }
    }
    
    func exitProjectMode() {
        Task {
            try? await ProjectService.shared.exitProjectMode()
            await MainActor.run {
                currentProject = nil
                isProjectMode = false
                if isWindowVisible {
                    hideWindow()
                    showWindow(recreate: true)
                }
            }
        }
    }

    func showWindow(recreate: Bool = false) {
        guard !isWindowVisible || recreate else {
            bringWindowToFront()
            return
        }

        if recreate {
            floatingWindowHostingController = nil
        }

        NotificationCenter.default.post(name: NSNotification.Name("FloatingWindowWillShow"), object: nil)

        previousActiveApp = NSWorkspace.shared.frontmostApplication

        if floatingWindow == nil || recreate {
            createWindow()
        }

        positionWindow(width: preferredFloatingWindowWidth())
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
        } else if let project = currentProject, isProjectMode {
            showProjectWindow(project: project)
        } else {
            showWindow()
        }
    }
    
    func showProjectWindow(project: Project) {
        guard !isWindowVisible else {
            bringWindowToFront()
            return
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("FloatingWindowWillShow"), object: nil)
        
        previousActiveApp = NSWorkspace.shared.frontmostApplication
        
        if floatingWindow == nil {
            createProjectWindow(project: project)
        }
        
        positionWindow(width: projectWindowWidth)
        floatingWindow?.orderFront(nil)
        floatingWindow?.makeKeyAndOrderFront(nil)
        
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.floatingWindow?.makeKey()
            self.floatingWindow?.makeFirstResponder(self.projectWindowHostingController?.view)
        }
        
        isWindowVisible = true
        startClickOutsideMonitoring()
    }
    
    private func createProjectWindow(project: Project) {
        let projectContainerView = ProjectModeContainerView(
            project: project,
            onClose: { [weak self] in
                self?.hideWindow()
            },
            onExitProject: { [weak self] in
                self?.exitProjectMode()
            }
        )
        
        projectWindowHostingController = NSHostingController(rootView: projectContainerView)
        
        let window = FloatingWindow(
            contentRect: NSRect(x: 0, y: 0, width: projectWindowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.contentView = projectWindowHostingController?.view
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = false  // Disable to avoid conflict with internal split view
        window.collectionBehavior = [.canJoinAllSpaces, .managed]
        window.setIsVisible(false)
        
        floatingWindow = window
        isWindowLoaded = true
    }

    func bringWindowToFront() {
        floatingWindow?.orderFrontRegardless()
    }
    
    func resizeWindowForProjectMode(isProjectMode: Bool, project: Project? = nil) {
        guard let window = floatingWindow, isWindowVisible else { return }
        
        let targetWidth: CGFloat = isProjectMode ? projectWindowWidth : preferredFloatingWindowWidth()
        let currentFrame = window.frame
        
        var newFrame = currentFrame
        newFrame.size.width = targetWidth
        newFrame.size.height = windowHeight
        
        let targetScreen = screen(for: window, fallbackPoint: NSEvent.mouseLocation)
        guard let screen = targetScreen else { return }
        newFrame.origin = clampedWindowOrigin(
            for: newFrame.origin,
            windowSize: newFrame.size,
            in: screen.visibleFrame
        )
        
        // Animate the resize
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().setFrame(newFrame, display: true)
        }
        
        ClipFlowLogger.info("Window resized to \(targetWidth)x\(windowHeight) at (\(newFrame.origin.x), \(newFrame.origin.y))")
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
}

extension FloatingWindowManager {

    private func createWindow() {
        let manager = self
        let floatingView = FloatingWindowView(
            onClose: { [weak self] in
                self?.hideWindow()
            },
            onItemSelected: { [weak self] item in
                guard let self = self else { return }
                let shouldAutoPaste = UserDefaults.standard.object(forKey: "pasteAfterSelectionEnabled") as? Bool ?? true
                self.isPasting = shouldAutoPaste
                self.clipboardMonitor.copyToClipboard(item)
                self.hideWindowForPaste()

                if shouldAutoPaste {
                    Task { @MainActor in
                        manager.simulatePaste()
                        Task { @MainActor in
                            manager.isPasting = false
                        }
                    }
                } else {
                    self.isPasting = false
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
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = false  // Disable to avoid conflict with internal split view
        window.collectionBehavior = [.canJoinAllSpaces, .managed]
        window.setIsVisible(false)

        floatingWindow = window
        isWindowLoaded = true
    }

    private func positionWindow(width: CGFloat? = nil) {
        guard let window = floatingWindow else { return }

        let windowWidthToUse = width ?? preferredFloatingWindowWidth()
        let mouseLocation = NSEvent.mouseLocation

        let targetScreen = screen(containingOrNearestTo: mouseLocation)

        guard let screen = targetScreen else { return }

        let screenFrame = screen.visibleFrame

        let windowSize = NSSize(width: windowWidthToUse, height: windowHeight)
        let desiredX = mouseLocation.x - windowWidthToUse / 2
        let spaceBelow = mouseLocation.y - screenFrame.minY - screenMargin
        let spaceAbove = screenFrame.maxY - mouseLocation.y - screenMargin

        let desiredY: CGFloat
        if spaceBelow >= windowHeight && (spaceBelow >= spaceAbove || spaceAbove < windowHeight) {
            desiredY = mouseLocation.y - windowHeight - screenMargin
        } else if spaceAbove >= windowHeight {
            desiredY = mouseLocation.y + screenMargin
        } else if spaceBelow >= spaceAbove {
            desiredY = screenFrame.minY + screenMargin
        } else {
            desiredY = screenFrame.maxY - screenMargin - windowHeight
        }

        let windowOrigin = clampedWindowOrigin(
            for: NSPoint(x: desiredX, y: desiredY),
            windowSize: windowSize,
            in: screenFrame
        )

        window.setFrame(NSRect(origin: windowOrigin, size: windowSize), display: false)
    }

    private func preferredFloatingWindowWidth() -> CGFloat {
        guard let hostingView = floatingWindowHostingController?.view else {
            return windowWidth
        }

        hostingView.layoutSubtreeIfNeeded()
        let fittingWidth = hostingView.fittingSize.width

        guard fittingWidth.isFinite, fittingWidth > 0 else {
            return windowWidth
        }

        return ceil(fittingWidth)
    }

    private func screen(containingOrNearestTo point: NSPoint) -> NSScreen? {
        if let containingScreen = NSScreen.screens.first(where: { $0.frame.contains(point) }) {
            return containingScreen
        }

        return NSScreen.screens.min { lhs, rhs in
            distance(from: point, to: lhs.frame) < distance(from: point, to: rhs.frame)
        }
    }

    private func screen(for window: NSWindow, fallbackPoint: NSPoint) -> NSScreen? {
        if let windowScreen = window.screen {
            return windowScreen
        }

        let windowCenter = NSPoint(x: window.frame.midX, y: window.frame.midY)
        return screen(containingOrNearestTo: windowCenter) ?? screen(containingOrNearestTo: fallbackPoint)
    }

    private func clampedWindowOrigin(
        for origin: NSPoint,
        windowSize: NSSize,
        in screenFrame: CGRect
    ) -> NSPoint {
        let minX = screenFrame.minX + screenMargin
        let maxX = max(minX, screenFrame.maxX - screenMargin - windowSize.width)
        let minY = screenFrame.minY + screenMargin
        let maxY = max(minY, screenFrame.maxY - screenMargin - windowSize.height)

        return NSPoint(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY)
        )
    }

    private func distance(from point: NSPoint, to rect: CGRect) -> CGFloat {
        let dx: CGFloat
        if point.x < rect.minX {
            dx = rect.minX - point.x
        } else if point.x > rect.maxX {
            dx = point.x - rect.maxX
        } else {
            dx = 0
        }

        let dy: CGFloat
        if point.y < rect.minY {
            dy = rect.minY - point.y
        } else if point.y > rect.maxY {
            dy = point.y - rect.maxY
        } else {
            dy = 0
        }

        return hypot(dx, dy)
    }
}

extension FloatingWindowManager {

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
