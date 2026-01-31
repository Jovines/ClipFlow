import SwiftUI

class GroupPanelCoordinator: ObservableObject {
    @Published var isShowingPanel = false
    @Published var panelItems: [ClipboardItem] = []
    @Published var panelInfo: FloatingWindowView.GroupInfo?
    @Published var panelPosition: FloatingWindowView.EditorPosition = .right

    private var mouseMoveMonitor: Any?
    private var hoverTask: Task<Void, Never>?
    private let hoverDelay: UInt64 = 100_000_000
    private let panelWidth: CGFloat = 300
    private var currentGroupIndex: Int?
    private var groupedItems: [(groupInfo: FloatingWindowView.GroupInfo, items: [ClipboardItem])] = []

    func updateGroupedItems(_ items: [(groupInfo: FloatingWindowView.GroupInfo, items: [ClipboardItem])]) {
        groupedItems = items
    }

    func startTracking() {
        stopTracking()
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.handleMouseMoved()
            }
        }
    }

    func stopTracking() {
        if let monitor = mouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMoveMonitor = nil
        }
        hoverTask?.cancel()
        hoverTask = nil
    }

    private func handleMouseMoved() {
        guard let window = FloatingWindowManager.shared.floatingWindow else {
            hidePanel()
            return
        }

        let mouseLocation = NSEvent.mouseLocation

        if NSMouseInRect(mouseLocation, window.frame, false) {
        } else {
            cancelHoverDelay()
            if isShowingPanel {
                hidePanel()
            }
        }
    }

    private func detectGroupHeaderAtMouse(_ mouseLocation: NSPoint, windowFrame: NSRect) -> (Int, FloatingWindowView.GroupInfo, [ClipboardItem])? {
        guard !groupedItems.isEmpty else { return nil }

        let lastGroupIndex = groupedItems.count - 1
        guard lastGroupIndex > 0 else { return nil }

        let headerHeight: CGFloat = 30
        let topAreaHeight: CGFloat = 76

        let headerTopInWindow = windowFrame.height - topAreaHeight - CGFloat(lastGroupIndex) * headerHeight
        let headerBottomInWindow = headerTopInWindow - headerHeight

        let mouseYInWindow = windowFrame.maxY - mouseLocation.y
        let mouseXInWindow = mouseLocation.x - windowFrame.minX

        if mouseXInWindow >= 0 && mouseXInWindow <= windowFrame.width &&
           mouseYInWindow >= headerBottomInWindow && mouseYInWindow <= headerTopInWindow {
            let group = groupedItems[lastGroupIndex]
            return (lastGroupIndex, group.groupInfo, group.items)
        }
        return nil
    }

    private func startHoverDelay(groupIndex: Int, groupInfo: FloatingWindowView.GroupInfo, items: [ClipboardItem]) {
        cancelHoverDelay()
        currentGroupIndex = groupIndex
        panelInfo = groupInfo
        panelItems = items

        hoverTask = Task {
            try? await Task.sleep(nanoseconds: hoverDelay)
            if !Task.isCancelled {
                await MainActor.run {
                    showPanel()
                }
            }
        }
    }

    private func cancelHoverDelay() {
        hoverTask?.cancel()
        hoverTask = nil
    }

    private func showPanel() {
        adjustWindowPositionForExpansion(panelWidth: panelWidth)
        determinePanelPosition()
        withAnimation(.easeInOut(duration: 0.15)) {
            isShowingPanel = true
        }
    }

    func showPanelForGroup(groupIndex: Int, groupInfo: FloatingWindowView.GroupInfo, items: [ClipboardItem]) {
        cancelHoverDelay()
        currentGroupIndex = groupIndex
        panelInfo = groupInfo
        panelItems = items
        showPanel()
    }

    func isCurrentGroup(_ groupIndex: Int) -> Bool {
        currentGroupIndex == groupIndex
    }

    func hidePanel() {
        withAnimation(.easeInOut(duration: 0.1)) {
            isShowingPanel = false
        }
        currentGroupIndex = nil
        panelItems = []
        panelInfo = nil
        cancelHoverDelay()
    }

    private func determinePanelPosition() {
        guard let window = FloatingWindowManager.shared.floatingWindow else {
            panelPosition = .right
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        }?.visibleFrame ?? NSScreen.main?.visibleFrame ?? CGRect.zero

        let windowFrame = window.frame
        let rightSpace = screenFrame.maxX - windowFrame.maxX
        let leftSpace = windowFrame.minX - screenFrame.minX

        let totalWidth = windowFrame.width + panelWidth

        let canExpandRight = windowFrame.minX + totalWidth <= screenFrame.maxX
        let canExpandLeft = windowFrame.maxX - totalWidth >= screenFrame.minX

        if rightSpace >= panelWidth + 20 && canExpandRight {
            panelPosition = .right
        } else if leftSpace >= panelWidth + 20 && canExpandLeft {
            panelPosition = .left
        } else if canExpandLeft {
            panelPosition = .left
        } else if canExpandRight {
            panelPosition = .right
        } else {
            panelPosition = .right
        }
    }

    private func adjustWindowPositionForExpansion(panelWidth: CGFloat) {
        guard let window = FloatingWindowManager.shared.floatingWindow else { return }

        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        }?.visibleFrame ?? NSScreen.main?.visibleFrame ?? CGRect.zero

        var windowFrame = window.frame
        let totalWidth = windowFrame.width + panelWidth

        if windowFrame.minX + totalWidth > screenFrame.maxX {
            windowFrame.origin.x = screenFrame.maxX - totalWidth
        }

        if windowFrame.minX < screenFrame.minX {
            windowFrame.origin.x = screenFrame.minX
        }

        if windowFrame != window.frame {
            window.setFrame(windowFrame, display: true, animate: true)
        }
    }
}
