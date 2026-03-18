import AppKit
import SwiftUI

@MainActor
final class FocusTodoWindowManager: ObservableObject {
    static let shared = FocusTodoWindowManager()

    private let todoService: FocusTodoService
    private let shortcutManager: FocusTodoShortcutManager
    private var window: FocusTodoWindow?
    private var hostingController: NSHostingController<FocusTodoBarView>?
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var globalMouseMonitor: Any?
    private var globalMouseDragMonitor: Any?
    private var screenChangeObserver: Any?
    private var windowMoveObserver: NSObjectProtocol?
    private var snapDebounceWorkItem: DispatchWorkItem?
    private var suppressMoveSnapUntil = Date.distantPast
    private var isCollapsedDragging = false
    private var hasMovedDuringCollapsedDrag = false
    private var collapsedDragStartMouseLocation = NSPoint.zero
    private var collapsedDragStartWindowOrigin = NSPoint.zero

    private enum SnapPosition: String, CaseIterable {
        case topLeft
        case topCenter
        case topRight
        case middleLeft
        case middleCenter
        case middleRight
        case bottomLeft
        case bottomCenter
        case bottomRight
    }

    private var snapPosition: SnapPosition {
        get {
            guard let value = UserDefaults.standard.string(forKey: FocusTodoPreferences.snapPositionKey),
                  let position = SnapPosition(rawValue: value) else {
                return .topRight
            }
            return position
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: FocusTodoPreferences.snapPositionKey)
        }
    }

    private let collapsedWidth: CGFloat = 280
    private let collapsedMinimalWidth: CGFloat = 178
    private let expandedWidth: CGFloat = 460
    private let topMargin: CGFloat = 6
    private let bottomMargin: CGFloat = 8
    private let rightMargin: CGFloat = 12
    private let leftMargin: CGFloat = 12

    private init(
        todoService: FocusTodoService = .shared,
        shortcutManager: FocusTodoShortcutManager = .shared
    ) {
        self.todoService = todoService
        self.shortcutManager = shortcutManager
    }

    func start() {
        createWindowIfNeeded()
        showWindow()
        setupShortcutMonitors()
        setupMouseMonitor()
        setupScreenObserver()
        setupWindowMoveObserver()
    }

    func cleanup() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        localKeyMonitor = nil

        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
        }
        globalKeyMonitor = nil

        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        globalMouseMonitor = nil

        if let globalMouseDragMonitor {
            NSEvent.removeMonitor(globalMouseDragMonitor)
        }
        globalMouseDragMonitor = nil

        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
        screenChangeObserver = nil

        if let windowMoveObserver {
            NotificationCenter.default.removeObserver(windowMoveObserver)
        }
        windowMoveObserver = nil

        snapDebounceWorkItem?.cancel()
        snapDebounceWorkItem = nil

        window?.orderOut(nil)
        window = nil
        hostingController = nil
    }

    func refreshLayout(animated: Bool = true) {
        guard let window else { return }
        let targetWidth = todoService.isPanelExpanded ? expandedWidth : targetCollapsedWidth
        let targetHeight = todoService.isPanelExpanded
            ? max(220, todoService.measuredExpandedHeight)
            : max(30, todoService.measuredCollapsedHeight)
        let targetFrame = frameForCurrentScreen(width: targetWidth, height: targetHeight, using: screenForWindowFrame(window.frame))
        suppressMoveSnapUntil = Date().addingTimeInterval(animated ? 0.28 : 0.08)

        window.ignoresMouseEvents = !todoService.isPanelExpanded

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                window.animator().setFrame(targetFrame, display: true)
            }
        } else {
            window.setFrame(targetFrame, display: true)
        }
    }

    private func createWindowIfNeeded() {
        guard window == nil else { return }

        let initialHeight = max(30, todoService.measuredCollapsedHeight)
        let frame = frameForCurrentScreen(width: targetCollapsedWidth, height: initialHeight)
        let barView = FocusTodoBarView()
        let hosting = NSHostingController(rootView: barView)
        let panel = FocusTodoWindow(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hosting.view
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = true

        window = panel
        hostingController = hosting
    }

    private func showWindow() {
        guard let window else { return }
        window.orderFrontRegardless()
        window.orderFront(nil)
    }

    private var targetCollapsedWidth: CGFloat {
        todoService.activeItem == nil ? collapsedMinimalWidth : collapsedWidth
    }

    private func setupScreenObserver() {
        guard screenChangeObserver == nil else { return }
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshLayout(animated: false)
            }
        }
    }

    private func setupWindowMoveObserver() {
        guard windowMoveObserver == nil, let window else { return }
        windowMoveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleSnapAfterMoveIfNeeded()
            }
        }
    }

    private func setupShortcutMonitors() {
        guard localKeyMonitor == nil, globalKeyMonitor == nil else { return }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.handleShortcut(from: event) {
                return nil
            }
            return event
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            _ = self.handleShortcut(from: event)
        }
    }

    private func setupMouseMonitor() {
        guard globalMouseMonitor == nil, globalMouseDragMonitor == nil else { return }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let window = self.window else {
                return
            }

            if event.type == .leftMouseDown,
               !self.todoService.isPanelExpanded,
               window.frame.contains(event.locationInWindow) {
                self.isCollapsedDragging = true
                self.hasMovedDuringCollapsedDrag = false
                self.collapsedDragStartMouseLocation = event.locationInWindow
                self.collapsedDragStartWindowOrigin = window.frame.origin
                self.todoService.setCollapsedDragging(true)
                return
            }

            guard self.todoService.isPanelExpanded else { return }

            let clickPoint = event.locationInWindow
            if window.frame.contains(clickPoint) == false {
                Task { @MainActor in
                    self.todoService.setPanelExpanded(false)
                    self.refreshLayout()
                }
            }
        }

        globalMouseDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self,
                  self.isCollapsedDragging,
                  !self.todoService.isPanelExpanded,
                  let window = self.window else {
                return
            }

            if event.type == .leftMouseDragged {
                let current = event.locationInWindow
                let deltaX = current.x - self.collapsedDragStartMouseLocation.x
                let deltaY = current.y - self.collapsedDragStartMouseLocation.y

                if abs(deltaX) > 1 || abs(deltaY) > 1 {
                    self.hasMovedDuringCollapsedDrag = true
                }

                let newOrigin = NSPoint(
                    x: self.collapsedDragStartWindowOrigin.x + deltaX,
                    y: self.collapsedDragStartWindowOrigin.y + deltaY
                )
                window.setFrameOrigin(newOrigin)
            } else {
                self.isCollapsedDragging = false
                self.todoService.setCollapsedDragging(false)
                if self.hasMovedDuringCollapsedDrag {
                    Task { @MainActor in
                        self.snapToNearestPositionAfterDrag()
                    }
                }
                self.hasMovedDuringCollapsedDrag = false
            }
        }
    }

    private func handleShortcut(from event: NSEvent) -> Bool {
        let normalizedFlags = event.modifierFlags.intersection([.command, .shift, .control, .option])
        let toggleShortcut = shortcutManager.shortcut(for: .togglePanel)
        if event.keyCode == toggleShortcut.keyCode && normalizedFlags == toggleShortcut.modifiers {
            todoService.togglePanel()
            refreshLayout()
            if todoService.isPanelExpanded {
                NSApp.activate(ignoringOtherApps: true)
                window?.makeKeyAndOrderFront(nil)
            }
            showWindow()
            return true
        }

        let nextShortcut = shortcutManager.shortcut(for: .nextTask)
        if event.keyCode == nextShortcut.keyCode && normalizedFlags == nextShortcut.modifiers {
            todoService.moveToNext()
            showWindow()
            return true
        }

        let previousShortcut = shortcutManager.shortcut(for: .previousTask)
        if event.keyCode == previousShortcut.keyCode && normalizedFlags == previousShortcut.modifiers {
            todoService.moveToPrevious()
            showWindow()
            return true
        }

        let doneShortcut = shortcutManager.shortcut(for: .markDone)
        if event.keyCode == doneShortcut.keyCode && normalizedFlags == doneShortcut.modifiers {
            todoService.markCurrentDone()
            showWindow()
            return true
        }

        return false
    }

    private func frameForCurrentScreen(width: CGFloat, height: CGFloat) -> NSRect {
        frameForCurrentScreen(width: width, height: height, using: NSScreen.main ?? NSScreen.screens.first)
    }

    private func frameForCurrentScreen(width: CGFloat, height: CGFloat, using screen: NSScreen?) -> NSRect {
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 200, y: 200, width: 1200, height: 800)
        let originX = snapOriginX(for: visibleFrame, width: width)
        let originY = snapOriginY(for: visibleFrame, height: height)
        return NSRect(x: originX, y: originY, width: width, height: height).integral
    }

    private func snapOriginX(for visibleFrame: NSRect, width: CGFloat) -> CGFloat {
        switch snapPosition {
        case .topLeft, .middleLeft, .bottomLeft:
            return visibleFrame.minX + leftMargin
        case .topCenter, .middleCenter, .bottomCenter:
            return visibleFrame.midX - width / 2
        case .topRight, .middleRight, .bottomRight:
            return visibleFrame.maxX - width - rightMargin
        }
    }

    private func snapOriginY(for visibleFrame: NSRect, height: CGFloat) -> CGFloat {
        switch snapPosition {
        case .topLeft, .topCenter, .topRight:
            return visibleFrame.maxY - height - topMargin
        case .middleLeft, .middleCenter, .middleRight:
            return visibleFrame.midY - height / 2
        case .bottomLeft, .bottomCenter, .bottomRight:
            return visibleFrame.minY + bottomMargin
        }
    }

    private func snapToNearestPositionAfterDrag() {
        guard !todoService.isPanelExpanded, let window else { return }
        todoService.notifyCollapsedInteraction()
        let currentFrame = window.frame
        let screen = screenForWindowFrame(currentFrame) ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 200, y: 200, width: 1200, height: 800)

        let nearest = SnapPosition.allCases.min { lhs, rhs in
            let lhsPoint = anchorPoint(for: lhs, in: visibleFrame, width: currentFrame.width, height: currentFrame.height)
            let rhsPoint = anchorPoint(for: rhs, in: visibleFrame, width: currentFrame.width, height: currentFrame.height)
            return distanceSquared(from: currentFrame.origin, to: lhsPoint) < distanceSquared(from: currentFrame.origin, to: rhsPoint)
        } ?? .topRight

        snapPosition = nearest
        refreshLayout()
    }

    private func scheduleSnapAfterMoveIfNeeded() {
        guard !todoService.isPanelExpanded else { return }
        guard Date() >= suppressMoveSnapUntil else { return }

        snapDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.snapToNearestPositionAfterDrag()
            }
        }
        snapDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func anchorPoint(for position: SnapPosition, in visibleFrame: NSRect, width: CGFloat, height: CGFloat) -> NSPoint {
        let x: CGFloat
        let y: CGFloat

        switch position {
        case .topLeft, .middleLeft, .bottomLeft:
            x = visibleFrame.minX + leftMargin
        case .topCenter, .middleCenter, .bottomCenter:
            x = visibleFrame.midX - width / 2
        case .topRight, .middleRight, .bottomRight:
            x = visibleFrame.maxX - width - rightMargin
        }

        switch position {
        case .topLeft, .topCenter, .topRight:
            y = visibleFrame.maxY - height - topMargin
        case .middleLeft, .middleCenter, .middleRight:
            y = visibleFrame.midY - height / 2
        case .bottomLeft, .bottomCenter, .bottomRight:
            y = visibleFrame.minY + bottomMargin
        }

        return NSPoint(x: x, y: y)
    }

    private func distanceSquared(from: NSPoint, to: NSPoint) -> CGFloat {
        let dx = from.x - to.x
        let dy = from.y - to.y
        return dx * dx + dy * dy
    }

    private func screenForWindowFrame(_ frame: NSRect) -> NSScreen? {
        let center = NSPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { NSMouseInRect(center, $0.frame, false) }
    }
}

private final class FocusTodoWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
