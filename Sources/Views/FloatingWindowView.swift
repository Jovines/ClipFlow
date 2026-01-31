import AppKit
import Combine
import SwiftUI

class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}

extension NSTextView {
    open override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}

class FocusRinglessView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func drawFocusRingMask() {
    }

    override var focusRingMaskBounds: NSRect {
        return NSRect.zero
    }
}

class FocusRinglessHostingController<Content: View>: NSHostingController<Content> {
    override func loadView() {
        view = FocusRinglessView()
    }
}

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

        // Find the screen containing the mouse, or use the main screen
        let targetScreen = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first

        guard let screen = targetScreen else { return }

        let screenFrame = screen.visibleFrame
        let menuBarHeight = screen.frame.height - screenFrame.height

        // Calculate preferred position (above mouse, accounting for menu bar)
        var windowOrigin = NSPoint(
            x: mouseLocation.x - windowWidth / 2,
            y: mouseLocation.y - windowHeight - 20
        )

        // Ensure window stays within screen bounds
        // Horizontal bounds
        if windowOrigin.x < screenFrame.minX {
            windowOrigin.x = screenFrame.minX + 10
        }
        if windowOrigin.x + windowWidth > screenFrame.maxX {
            windowOrigin.x = screenFrame.maxX - windowWidth - 10
        }

        // Vertical bounds - prefer above mouse, but don't overlap menu bar
        if windowOrigin.y + windowHeight > screenFrame.maxY {
            // Position below mouse instead
            windowOrigin.y = mouseLocation.y + 20
        }
        if windowOrigin.y < screenFrame.minY {
            windowOrigin.y = screenFrame.minY + 10
        }

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

struct FloatingWindowView: View {
    let onClose: () -> Void
    let onItemSelected: (ClipboardItem) -> Void
    let maxVisibleItems: Int
    @StateObject private var clipboardMonitor: ClipboardMonitor
    @State private var searchText = ""

    init(onClose: @escaping () -> Void, onItemSelected: @escaping (ClipboardItem) -> Void, maxVisibleItems: Int, clipboardMonitor: ClipboardMonitor = .shared) {
        self.onClose = onClose
        self.onItemSelected = onItemSelected
        self.maxVisibleItems = maxVisibleItems
        _clipboardMonitor = StateObject(wrappedValue: clipboardMonitor)
    }
    @State private var isSelectionMode = false
    @State private var selectedItem: ClipboardItem?
    @State private var selectedIndex: Int = -1
    @State private var showImagePreview = false
    @State private var selectedTag: Tag?
    @State private var allTags: [Tag] = []

    @State private var editingItem: ClipboardItem?
    @State private var editContent: String = ""
    @State private var originalContent: String = ""
    @State private var editorPosition: EditorPosition = .right
    @State private var editorWidth: CGFloat = 280
    @State private var expandedGroups: Set<Int> = []
    @State private var detailItem: ClipboardItem?
    @State private var showDetailPanel = false

    private let groupPanelWidth: CGFloat = 300

    enum EditorPosition {
        case left
        case right
    }

    private var groupedItems: [(groupInfo: GroupInfo, items: [ClipboardItem])] {
        let visibleItems = Array(filteredItems.prefix(maxVisibleItems))
        let remainingItems = Array(filteredItems.dropFirst(maxVisibleItems))

        var groups: [(groupInfo: GroupInfo, items: [ClipboardItem])] = []

        if !visibleItems.isEmpty {
            groups.append((GroupInfo(startIndex: 1, endIndex: visibleItems.count, totalCount: filteredItems.count), visibleItems))
        }

        for (index, chunk) in remainingItems.chunked(into: 10).enumerated() {
            let startIndex = maxVisibleItems + index * 10 + 1
            let endIndex = min(startIndex + chunk.count - 1, filteredItems.count)
            groups.append((GroupInfo(startIndex: startIndex, endIndex: endIndex, totalCount: filteredItems.count), Array(chunk)))
        }

        return groups
    }

    struct GroupInfo {
        let startIndex: Int
        let endIndex: Int
        let totalCount: Int
    }

    private var isEditing: Bool {
        editingItem != nil
    }

    private var characterCount: Int {
        editContent.count
    }

    private var maxCharacterCount: Int {
        10000
    }

    @StateObject private var groupPanelCoordinator = GroupPanelCoordinator()

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                if !searchText.isEmpty {
                    searchIndicatorView
                    Divider()
                }
                TagFilterBar(
                    tags: allTags,
                    selectedTag: $selectedTag,
                    onTagSelected: handleTagSelected
                )
                Divider()
                modeIndicatorView
                Divider()
                if isSelectionMode {
                    selectionModeHint
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                contentView
            }
            .frame(width: 360, height: 420)

            if isEditing {
                editorPanel
                    .frame(width: editorWidth, height: 420)
            }

            if groupPanelCoordinator.isShowingPanel {
                groupPanel
                    .frame(width: groupPanelWidth, height: 420)
            }
        }
        .background(Color.flexokiSurface.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
        .focusable(true)
        .onAppear {
            clipboardMonitor.refresh()
            resetSearch()
            loadAllTags()
            groupPanelCoordinator.startTracking()
        }
        .onDisappear {
            groupPanelCoordinator.stopTracking()
        }
        .onChange(of: filteredItems.count) { newCount in
            if selectedIndex >= newCount && selectedIndex >= 0 {
                selectedIndex = max(0, newCount - 1)
            }
        }
        .onKeyPress(.downArrow) {
            navigateSelection(direction: .down)
            return .handled
        }
        .onKeyPress(.upArrow) {
            navigateSelection(direction: .up)
            return .handled
        }
        .onKeyPress(.tab) {
            if isEditing {
                return .ignored
            }
            toggleMode()
            return .handled
        }
        .onKeyPress(.return) {
            if isEditing {
                saveEdit()
            } else if isSelectionMode {
                if selectedIndex >= 0, let item = getSelectedItem() {
                    handleItemSelection(item)
                }
            } else {
                isSelectionMode = true
                selectedIndex = -1
            }
            return .handled
        }
        .onKeyPress(.delete) {
            if isEditing {
                return .ignored
            }
            if searchText.isEmpty {
                if let item = getSelectedItem() {
                    clipboardMonitor.deleteItem(item)
                }
            } else {
                removeLastSearchCharacter()
            }
            return .handled
        }
        .onKeyPress(.escape) {
            if isEditing {
                cancelEdit()
            } else if isSelectionMode {
                isSelectionMode = false
                selectedIndex = -1
            } else if !searchText.isEmpty {
                searchText = ""
                selectedIndex = -1
            } else if selectedTag != nil {
                selectedTag = nil
                selectedIndex = -1
            } else {
                onClose()
            }
            return .handled
        }
        .onKeyPress(phases: .down) { press in
            if isEditing {
                if press.characters == "r" && press.modifiers.contains(.command) {
                    resetEdit()
                    return .handled
                }
                return .ignored
            }
            return handleKeyPress(press)
        }
        .sheet(isPresented: $showImagePreview) {
            if let item = selectedItem {
                ImagePreviewView(item: item)
            }
        }
    }

    private enum NavigationDirection {
        case up, down
    }

    private func navigateSelection(direction: NavigationDirection) {
        let visibleItems = getVisibleItems()
        let maxIndex = visibleItems.count - 1

        switch direction {
        case .down:
            if selectedIndex < 0 {
                selectedIndex = 0
            } else if selectedIndex < maxIndex {
                withAnimation(.easeOut(duration: 0.1)) {
                    selectedIndex += 1
                }
            }
        case .up:
            if selectedIndex < 0 {
                selectedIndex = maxIndex
            } else if selectedIndex > 0 {
                withAnimation(.easeOut(duration: 0.1)) {
                    selectedIndex -= 1
                }
            }
        }
    }

    private func getVisibleItems() -> [ClipboardItem] {
        var visible: [ClipboardItem] = []
        for (groupIndex, group) in groupedItems.enumerated() {
            if groupIndex == 0 {
                visible.append(contentsOf: group.items)
            } else if expandedGroups.contains(groupIndex) {
                visible.append(contentsOf: group.items)
            }
        }
        return visible
    }

    private func getSelectedItem() -> ClipboardItem? {
        let index = min(selectedIndex, filteredItems.count - 1)
        guard index >= 0 && index < filteredItems.count else { return nil }
        return filteredItems[index]
    }

    @ViewBuilder
    private var contentView: some View {
        if filteredItems.isEmpty {
            emptyStateView
        } else {
            VStack(spacing: 0) {
                if !searchText.isEmpty {
                    searchResultHeader
                }
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(groupedItems.enumerated()), id: \.offset) { groupIndex, group in
                            if groupIndex == 0 {
                                LazyVStack(spacing: 4) {
                                    ForEach(Array(group.items.enumerated()), id: \.element.id) { itemIndex, item in
                                        CompactItemRow(
                                            item: item,
                                            index: itemIndex,
                                            isSelected: selectedIndex == itemIndex,
                                            clipboardMonitor: clipboardMonitor,
                                            onSelect: { handleItemSelection(item) },
                                            onEdit: { startEdit(item) },
                                            onDelete: { clipboardMonitor.deleteItem(item) }
                                        )
                                    }
                                }
                            } else {
                                GroupView(
                                    groupInfo: group.groupInfo,
                                    items: group.items,
                                    groupIndex: groupIndex,
                                    onToggleExpand: { toggleGroup(groupIndex) },
                                    selectedIndex: $selectedIndex,
                                    clipboardMonitor: clipboardMonitor,
                                    onItemSelected: { item in
                                        handleItemSelection(item)
                                    },
                                    onItemEdit: { item in
                                        startEdit(item)
                                    },
                                    onItemDelete: { item in
                                        clipboardMonitor.deleteItem(item)
                                    },
                                    panelCoordinator: groupPanelCoordinator
                                )
                            }
                        }
                    }
                    .padding(8)
                    .onAppear {
                        groupPanelCoordinator.updateGroupedItems(groupedItems)
                    }
                    .onChange(of: filteredItems.count) { _, _ in
                        groupPanelCoordinator.updateGroupedItems(groupedItems)
                    }

                }
            }
        }
    }

    @ViewBuilder
    private var searchResultHeader: some View {
        HStack {
            Text("\(searchResultCount) result\(searchResultCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(Color.flexokiTextSecondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.flexokiSurface.opacity(0.5))
    }

    @ViewBuilder
    private func itemRow(for item: ClipboardItem, index: Int) -> some View {
        FloatingItemRow(
            item: item,
            index: index,
            isSelected: selectedIndex == index,
            isEditing: editingItem?.id == item.id,
            onSelect: {
                handleItemSelection(item)
            },
            onEdit: {
                startEdit(item)
            },
            onDelete: {
                clipboardMonitor.deleteItem(item)
            },
            clipboardMonitor: clipboardMonitor
        )
    }

    private func toggleGroup(_ groupIndex: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedGroups.contains(groupIndex) {
                expandedGroups.remove(groupIndex)
            } else {
                expandedGroups.insert(groupIndex)
            }
        }
    }

    private func handleItemSelection(_ item: ClipboardItem) {
        if item.contentType == .image {
            selectedItem = item
            showImagePreview = true
        } else {
            onItemSelected(item)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 36))
                .foregroundStyle(Color.flexokiTextSecondary)

            Text("No clipboard history")
                .font(.subheadline)
                .foregroundStyle(Color.flexokiTextSecondary)

            Text("Copy something to see it here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editorPanel: some View {
        VStack(spacing: 0) {
            editorHeader
            Divider()
            editorContent
            Divider()
            editorFooter
        }
        .background(Color.flexokiSurface.opacity(0.95))
    }

    private var groupPanel: some View {
        VStack(spacing: 0) {
            groupPanelHeader
            Divider()
            groupPanelContent
            Divider()
            groupPanelFooter
        }
        .background(Color.flexokiSurface.opacity(0.95))
    }

    private var groupPanelHeader: some View {
        HStack {
            if let info = groupPanelCoordinator.panelInfo {
                Text("记录 \(info.startIndex)-\(info.endIndex)")
                    .font(.system(size: 13, weight: .medium))
            }
            Spacer()
            Text("\(groupPanelCoordinator.panelItems.count) 条")
                .font(.caption)
                .foregroundStyle(Color.flexokiTextSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var groupPanelContent: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(Array(groupPanelCoordinator.panelItems.enumerated()), id: \.element.id) { index, item in
                    GroupPanelItemRow(
                        item: item,
                        index: index,
                        clipboardMonitor: clipboardMonitor,
                        onSelect: {
                            onItemSelected(item)
                            groupPanelCoordinator.hidePanel()
                        },
                        onEdit: { startEdit(item) },
                        onDelete: { clipboardMonitor.deleteItem(item) },
                        panelCoordinator: groupPanelCoordinator
                    )
                }
            }
            .padding(8)
        }
    }

    private var groupPanelFooter: some View {
        HStack {
            Spacer()

            Button(action: { groupPanelCoordinator.hidePanel() }) {
                Text("关闭")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var editorHeader: some View {
        HStack {
            Text("编辑记录")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Button(action: { cancelEdit() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.flexokiTextSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            TextEditor(text: $editContent)
                .font(.system(size: 13))
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.clear)

            HStack {
                Text("\(characterCount)/\(maxCharacterCount)")
                    .font(.caption)
                    .foregroundStyle(Color.flexokiTextSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private var editorFooter: some View {
        HStack(spacing: 8) {
            Button(action: { resetEdit() }) {
                Text("重置")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .disabled(editContent == originalContent)

            Spacer()

            Button(action: { cancelEdit() }) {
                Text("取消")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)

            Button(action: { saveEdit() }) {
                Text("保存")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .disabled(editContent.isEmpty || editContent == originalContent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func startEdit(_ item: ClipboardItem) {
        guard item.contentType == .text else { return }
        editingItem = item
        editContent = item.content
        originalContent = item.content
        determineEditorPosition()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let window = FloatingWindowManager.shared.floatingWindow else { return }
            window.makeKey()
            if let hostingView = FloatingWindowManager.shared.floatingWindowHostingController?.view {
                window.makeFirstResponder(hostingView)
            }
        }
    }

    private func saveEdit() {
        guard let item = editingItem else { return }
        clipboardMonitor.updateItemContent(id: item.id, newContent: editContent)
        clipboardMonitor.moveItemToTop(id: item.id)
        editingItem = nil
        editContent = ""
        originalContent = ""
        selectedIndex = -1
    }

    private func cancelEdit() {
        editingItem = nil
        editContent = ""
        originalContent = ""
    }

    private func resetEdit() {
        editContent = originalContent
    }

    private func determineEditorPosition() {
        guard let window = FloatingWindowManager.shared.floatingWindow else {
            editorPosition = .right
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        }?.visibleFrame ?? NSScreen.main?.visibleFrame ?? CGRect.zero

        let windowFrame = window.frame
        let rightSpace = screenFrame.maxX - windowFrame.maxX
        let leftSpace = windowFrame.minX - screenFrame.minX

        if rightSpace >= editorWidth + 10 {
            editorPosition = .right
        } else if leftSpace >= editorWidth + 10 {
            editorPosition = .left
        } else {
            editorPosition = .right
        }
    }

    private var filteredItems: [ClipboardItem] {
        var items = clipboardMonitor.capturedItems
        
        // 标签筛选
        if let selectedTag = selectedTag {
            items = items.filter { item in
                item.tags.contains { $0.id == selectedTag.id }
            }
        }
        
        // 搜索文本筛选
        if !searchText.isEmpty {
            items = items.filter { item in
                item.content.localizedCaseInsensitiveContains(searchText) ||
                item.tags.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        return items
    }

    private var searchResultCount: Int {
        filteredItems.count
    }

    private func loadAllTags() {
        do {
            allTags = try DatabaseManager.shared.fetchAllTags()
        } catch {
            ClipFlowLogger.error("Failed to load tags: \(error)")
            allTags = []
        }
    }

    private func handleTagSelected(_ tag: Tag?) {
        selectedTag = tag
        selectedIndex = -1
        searchText = ""
        isSelectionMode = false
        
        if let tag = tag {
            TagUsageManager.shared.recordUsage(for: tag.id)
        }
    }

    private var searchIndicatorView: some View {
        HStack(spacing: 8) {
            Image(systemName: isSelectionMode ? "number" : "magnifyingglass")
                .foregroundStyle(isSelectionMode ? Color.flexokiAccent : .secondary)
                .font(.system(size: 13))
            
            if isSelectionMode {
                Text("选择模式")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.flexokiAccent)
            } else {
                Text(searchText)
                    .font(.system(size: 13))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("\(filteredItems.count)")
                .font(.caption)
                .foregroundStyle(Color.flexokiTextSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.flexokiSurface)
                .clipShape(Capsule())
            
            Button(action: resetSearch) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.flexokiTextSecondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private var modeIndicatorView: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelectionMode ? .secondary : Color.flexokiAccent)
                
                Text("搜索")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelectionMode ? .secondary : Color.flexokiAccent)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelectionMode ? Color.clear : Color.flexokiAccent.opacity(0.15))
            .clipShape(Capsule())
            
            HStack(spacing: 4) {
                Image(systemName: "number")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelectionMode ? Color.flexokiAccent : .secondary)
                
                Text("选择")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelectionMode ? Color.flexokiAccent : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelectionMode ? Color.flexokiAccent.opacity(0.15) : Color.clear)
            .clipShape(Capsule())
            
            Spacer()
            
            HStack(spacing: 4) {
                if !searchText.isEmpty && !isSelectionMode {
                    Text(searchText)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.flexokiTextSecondary)
                        .lineLimit(1)
                        .padding(.trailing, 4)
                }
                
                HStack(spacing: 2) {
                    Text("Tab")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.flexokiSurface)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.flexokiSurface.opacity(0.8))
    }

    private var selectionModeHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "number")
                .font(.system(size: 10))
                .foregroundStyle(Color.flexokiAccent)

            Text("按数字 1-9 快速选择")
                .font(.system(size: 10))
                .foregroundStyle(Color.flexokiAccent)

            Spacer()

            Text("Enter 确认")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.flexokiSurface)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.flexokiAccent.opacity(0.08))
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let key = press.characters
        
        if isSelectionMode {
            return handleSelectionModeKeyPress(key)
        } else {
            return handleSearchModeKeyPress(key)
        }
    }
    
    private func handleSelectionModeKeyPress(_ key: String) -> KeyPress.Result {
        if key >= "1" && key <= "9" {
            let index = Int(key)! - 1
            if index < filteredItems.count {
                selectedIndex = index
                handleItemSelection(filteredItems[index])
            }
            return .handled
        }
        return .ignored
    }
    
    private func handleSearchModeKeyPress(_ key: String) -> KeyPress.Result {
        if key == "\u{7F}" || key == "\u{08}" {
            if !searchText.isEmpty {
                removeLastSearchCharacter()
            }
            return .handled
        }
        
        if key.count == 1 {
            let char = key.first!
            let isValidChar = char.isLetter || char.isNumber || char == " " || char == "-" || char == "_" || char == "."
            
            if isValidChar {
                searchText += key
                selectedIndex = -1
                return .handled
            }
        }
        
        return .ignored
    }

    private func toggleMode() {
        isSelectionMode.toggle()
        if isSelectionMode {
            selectedIndex = -1
        }
    }

    private func removeLastSearchCharacter() {
        if !searchText.isEmpty {
            searchText.removeLast()
            selectedIndex = -1
        }
    }

    private func resetSearch() {
        searchText = ""
        isSelectionMode = false
        selectedTag = nil
        selectedIndex = -1
    }
}

// MARK: - Group Panel Coordinator

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
            let groupHeaderBounds = detectGroupHeaderAtMouse(mouseLocation, windowFrame: window.frame)
            if let (groupIndex, groupInfo, items) = groupHeaderBounds {
                if currentGroupIndex != groupIndex {
                    startHoverDelay(groupIndex: groupIndex, groupInfo: groupInfo, items: items)
                }
            } else {
                cancelHoverDelay()
                if isShowingPanel {
                    hidePanel()
                }
            }
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

        if rightSpace >= panelWidth + 20 {
            panelPosition = .right
        } else if leftSpace >= panelWidth + 20 {
            panelPosition = .left
        } else {
            panelPosition = .right
        }
    }
}

// MARK: - Floating Item Row

struct FloatingItemRow: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let isEditing: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let clipboardMonitor: ClipboardMonitor
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            if index < 10 {
                Text("\(index)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isSelected || isEditing ? Color.flexokiAccent : .secondary)
                    .frame(width: 16, height: 16)
                    .background((isSelected || isEditing) ? Color.flexokiAccent.opacity(0.2) : Color.flexokiSurface.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            contentPreview

            Spacer()

            if isHovered && !isEditing {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.flexokiAccent)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .keyboardShortcut(KeyEquivalent.delete, modifiers: [])
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isEditing ? Color.flexokiAccent : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(perform: onSelect)
        .accessibilityLabel(accessibilityLabel)
    }

    private var contentPreview: some View {
        HStack(spacing: 8) {
            contentIcon

            VStack(alignment: .leading, spacing: 2) {
                previewText
                    .font(.system(size: 12))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    timeText

                    if !item.tags.isEmpty {
                        HStack(spacing: 2) {
                            ForEach(item.tags.prefix(1)) { tag in
                                Text(tag.name)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.fromHex(tag.color).opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.flexokiTextSecondary)
            }
        }
    }

    private var contentIcon: some View {
        Group {
            switch item.contentType {
            case .text:
                Image(systemName: "doc.text")
                    .foregroundStyle(Color.flexokiTextSecondary)
                    .font(.system(size: 14))
            case .image:
                thumbnailView
            }
        }
        .frame(width: 24, height: 24)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnailPath = item.thumbnailPath,
           let imageData = ImageCacheManager.shared.loadImage(forKey: thumbnailPath),
           let nsImage = NSImage(data: imageData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: "photo")
                .foregroundStyle(Color.flexokiTextSecondary)
                .font(.system(size: 14))
        }
    }

    private var previewText: some View {
        Group {
            switch item.contentType {
            case .text:
                Text(item.content)
            case .image:
                Text("Image")
            }
        }
    }

    private var timeText: some View {
        Text(formatTimeAgo(from: item.createdAt))
    }

    private func formatTimeAgo(from date: Date) -> String {
        let now = Date()
        let elapsed = now.timeIntervalSince(date)

        if elapsed < 60 {
            return "刚刚"
        } else if elapsed < 120 {
            return "1 分钟前"
        } else if elapsed < 180 {
            return "2 分钟前"
        } else if elapsed < 240 {
            return "3 分钟前"
        } else if elapsed < 300 {
            return "4 分钟前"
        } else if elapsed < 600 {
            return "5 分钟前"
        } else if elapsed < 900 {
            return "10 分钟前"
        } else if elapsed < 1200 {
            return "15 分钟前"
        } else if elapsed < 1800 {
            return "20 分钟前"
        } else if elapsed < 3600 {
            return "半小时前"
        } else if elapsed < 7200 {
            return "1 小时前"
        } else if elapsed < 86400 {
            let hours = Int(elapsed / 3600)
            return "\(hours) 小时前"
        } else {
            let days = Int(elapsed / 86400)
            return "\(days) 天前"
        }
    }

    private var backgroundColor: Color {
        if isEditing {
            return Color.flexokiAccent.opacity(0.15)
        }
        if isSelected {
            return Color.flexokiAccent.opacity(0.2)
        }
        return isHovered ? Color.flexokiBase200.opacity(0.5) : .clear
    }

    private var accessibilityLabel: String {
        switch item.contentType {
        case .text:
            return "Text: \(item.content.prefix(50))"
        case .image:
            return "Image"
        }
    }
}

// MARK: - Image Preview View

struct ImagePreviewView: View {
    let item: ClipboardItem
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()

                if let imagePath = item.imagePath,
                   let imageData = ImageCacheManager.shared.loadImage(forKey: imagePath),
                   let nsImage = NSImage(data: imageData) {
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onTapGesture(count: 2) {
                                withAnimation(.spring()) {
                                    scale = scale > 1.0 ? 1.0 : 2.0
                                }
                            }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Unable to load image")
                        .foregroundStyle(.white)
                }
            }
            .navigationTitle("Image Preview")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        Button(action: { withAnimation { scale = max(0.5, scale - 0.25) } }) {
                            Image(systemName: "minus.magnifyingglass")
                        }

                        Button(action: { withAnimation { scale = 1.0 } }) {
                            Image(systemName: "arrow.counterclockwise")
                        }

                        Button(action: { withAnimation { scale = min(3.0, scale + 0.25) } }) {
                            Image(systemName: "plus.magnifyingglass")
                        }
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

// MARK: - Group View

struct GroupView: View {
    let groupInfo: FloatingWindowView.GroupInfo
    let items: [ClipboardItem]
    let groupIndex: Int
    let onToggleExpand: () -> Void
    @Binding var selectedIndex: Int
    let clipboardMonitor: ClipboardMonitor
    let onItemSelected: (ClipboardItem) -> Void
    let onItemEdit: (ClipboardItem) -> Void
    let onItemDelete: (ClipboardItem) -> Void
    @ObservedObject var panelCoordinator: GroupPanelCoordinator

    @State private var isHovered = false

    private let itemsPerGroup = 10

    private var displayIndex: Int {
        if groupIndex == 0 {
            return -1
        }
        let offset = 10 + (groupIndex - 1) * itemsPerGroup
        return offset
    }

    var body: some View {
        VStack(spacing: 0) {
            groupHeader
        }
        .frame(height: 36)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                panelCoordinator.showPanelForGroup(groupIndex: groupIndex, groupInfo: groupInfo, items: items)
            }
        }
    }

    private var groupHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.flexokiTextSecondary)

            Text("▼ \(groupInfo.startIndex)-\(groupInfo.endIndex) (\(items.count)条)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.flexokiTextSecondary)

            Spacer()

            if isHovered {
                Text("悬停查看")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isHovered ? Color.flexokiSurface.opacity(0.5) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }
}

struct CompactItemRow: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let clipboardMonitor: ClipboardMonitor
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            if index < 10 {
                Text("\(index)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isSelected ? Color.flexokiAccent : .secondary)
                    .frame(width: 14, height: 14)
                    .background(isSelected ? Color.flexokiAccent.opacity(0.2) : Color.flexokiSurface.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            contentPreview

            Spacer()

            if isHovered && index < 9 {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.flexokiAccent)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .keyboardShortcut(KeyEquivalent.delete, modifiers: [])
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isSelected ? Color.flexokiAccent.opacity(0.2) : (isHovered ? Color.flexokiBase200.opacity(0.3) : .clear))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(perform: onSelect)
    }

    private var contentPreview: some View {
        HStack(spacing: 6) {
            Group {
                switch item.contentType {
                case .text:
                    Image(systemName: "doc.text")
                case .image:
                    Image(systemName: "photo")
                }
            }
            .foregroundStyle(Color.flexokiTextSecondary)
            .font(.system(size: 11))

            Text(item.content)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundStyle(Color.flexokiText)
        }
    }
}

// MARK: - Group Panel Item Row

struct GroupPanelItemRow: View {
    let item: ClipboardItem
    let index: Int
    let clipboardMonitor: ClipboardMonitor
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @ObservedObject var panelCoordinator: GroupPanelCoordinator
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            contentPreview

            Spacer()

            if isHovered {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.flexokiAccent)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .keyboardShortcut(KeyEquivalent.delete, modifiers: [])
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovered ? Color.flexokiBase200.opacity(0.5) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if !hovering {
                panelCoordinator.hidePanel()
            }
        }
        .onTapGesture(perform: onSelect)
    }

    private var contentPreview: some View {
        HStack(spacing: 6) {
            Group {
                switch item.contentType {
                case .text:
                    Image(systemName: "doc.text")
                case .image:
                    Image(systemName: "photo")
                }
            }
            .foregroundStyle(Color.flexokiTextSecondary)
            .font(.system(size: 11))

            Text(item.content)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundStyle(Color.flexokiText)
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
