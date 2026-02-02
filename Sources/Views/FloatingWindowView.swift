import AppKit
import Combine
import SwiftUI

struct FloatingWindowView: View {
    let onClose: () -> Void
    let onItemSelected: (ClipboardItem) -> Void
    let maxVisibleItems: Int
    @StateObject private var clipboardMonitor: ClipboardMonitor

    init(onClose: @escaping () -> Void, onItemSelected: @escaping (ClipboardItem) -> Void, maxVisibleItems: Int, clipboardMonitor: ClipboardMonitor = .shared) {
        self.onClose = onClose
        self.onItemSelected = onItemSelected
        self.maxVisibleItems = maxVisibleItems
        _clipboardMonitor = StateObject(wrappedValue: clipboardMonitor)
    }
    @State private var showImagePreview = false
    @State private var selectedItem: ClipboardItem?
    @State private var selectedTag: Tag?
    @State private var allTags: [Tag] = []

    @State private var editingItem: ClipboardItem?
    @State private var editContent: String = ""
    @State private var originalContent: String = ""
    @State private var editingItemTags: [Tag] = []
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
        let items = clipboardMonitor.capturedItems
        let visibleItems = Array(items.prefix(maxVisibleItems))
        let remainingItems = Array(items.dropFirst(maxVisibleItems))

        var groups: [(groupInfo: GroupInfo, items: [ClipboardItem])] = []

        if !visibleItems.isEmpty {
            groups.append((GroupInfo(startIndex: 1, endIndex: visibleItems.count, totalCount: items.count), visibleItems))
        }

        for (index, chunk) in remainingItems.chunked(into: 10).enumerated() {
            let startIndex = maxVisibleItems + index * 10 + 1
            let endIndex = min(startIndex + chunk.count - 1, items.count)
            groups.append((GroupInfo(startIndex: startIndex, endIndex: endIndex, totalCount: items.count), Array(chunk)))
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

    @State private var showProjectSelector = false
    @State private var showCreateProjectSheet = false
    @State private var isProjectMode = false
    @State private var currentProject: Project? = nil
    
    var body: some View {
        let content = contentBuilder
        
        return content
            .onChange(of: isProjectMode) { newValue in
                FloatingWindowManager.shared.resizeWindowForProjectMode(
                    isProjectMode: newValue,
                    project: currentProject
                )
            }
    }
    
    private var contentBuilder: some View {
        HStack(spacing: 0) {
            if isProjectMode, let project = currentProject {
                ProjectModeView(
                    project: project,
                    onExit: {
                        FloatingWindowManager.shared.exitProjectMode()
                    }
                )
                .frame(width: 680, height: 480)
            } else {
                VStack(spacing: 0) {
                    HeaderBar(
                        showProjectSelector: $showProjectSelector,
                        currentProject: currentProject,
                        isProjectMode: $isProjectMode,
                        allTags: allTags,
                        selectedTag: $selectedTag,
                        onTagSelected: handleTagSelected
                    )

                    Divider()
                    contentView
                }
                .frame(width: 360, height: 420)
            }

            if isEditing {
                EditorPanelView(
                    editContent: $editContent,
                    editingItem: $editingItem,
                    originalContent: originalContent,
                    onSave: saveEdit,
                    onCancel: cancelEdit,
                    onReset: resetEdit,
                    allTags: $allTags,
                    itemTags: $editingItemTags,
                    onTagsChanged: { tags in
                        if let item = editingItem {
                            clipboardMonitor.updateItemTags(itemId: item.id, tagIds: tags.map { $0.id })
                        }
                    }
                )
                .frame(width: editorWidth, height: 420)
            }

            if groupPanelCoordinator.isShowingPanel {
                GroupPanelView(
                    panelInfo: groupPanelCoordinator.panelInfo.map { info in
                        GroupPanelView.PanelInfo(startIndex: info.startIndex, endIndex: info.endIndex)
                    },
                    panelItems: groupPanelCoordinator.panelItems,
                    clipboardMonitor: clipboardMonitor,
                    onItemSelected: { item in
                        onItemSelected(item)
                    },
                    onItemEdit: startEdit,
                    onItemDelete: { clipboardMonitor.deleteItem($0) },
                    onHide: { groupPanelCoordinator.hidePanel() }
                )
                .frame(width: groupPanelWidth, height: 420)
            }
        }
        .background(Color.flexokiSurface.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
        .onAppear {
            clipboardMonitor.refresh()
            loadAllTags()
            groupPanelCoordinator.startTracking()
        }
        .onDisappear {
            groupPanelCoordinator.stopTracking()
        }
        .onKeyPress(phases: .down) { press in
            if isEditing {
                if press.characters == "r" && press.modifiers.contains(.command) {
                    resetEdit()
                    return .handled
                }
                return .ignored
            }
            return .ignored
        }
        .sheet(isPresented: $showImagePreview) {
            if let item = selectedItem {
                ImagePreviewView(item: item)
            }
        }
        .sheet(isPresented: $showProjectSelector) {
            ProjectSelectorView(
                isPresented: $showProjectSelector,
                onSelectProject: { project in
                    currentProject = project
                    isProjectMode = true
                    // Sync to ProjectService for clipboard monitoring
                    try? ProjectService.shared.activateProject(id: project.id)
                },
                onCreateProject: {
                    showCreateProjectSheet = true
                }
            )
        }
        .sheet(isPresented: $showCreateProjectSheet) {
            CreateProjectSheet(
                isPresented: $showCreateProjectSheet,
                onCreated: { project in
                    currentProject = project
                    isProjectMode = true
                    // Sync to ProjectService for clipboard monitoring
                    try? ProjectService.shared.activateProject(id: project.id)
                }
            )
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

    @ViewBuilder
    private var contentView: some View {
        if items.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(groupedItems.enumerated()), id: \.offset) { groupIndex, group in
                        if groupIndex == 0 {
                            firstGroupView(for: group)
                        } else {
                            expandedGroupView(for: group, groupIndex: groupIndex)
                        }
                    }
                }
                .padding(8)
                .onAppear {
                    groupPanelCoordinator.updateGroupedItems(groupedItems)
                }
                .onChange(of: items.count) { _, _ in
                    groupPanelCoordinator.updateGroupedItems(groupedItems)
                }

            }
        }
    }

    @ViewBuilder
    private func firstGroupView(for group: (groupInfo: GroupInfo, items: [ClipboardItem])) -> some View {
        LazyVStack(spacing: 4) {
            ForEach(Array(group.items.enumerated()), id: \.element.id) { itemIndex, item in
                CompactItemRow(
                    item: item,
                    clipboardMonitor: clipboardMonitor,
                    onSelect: { handleItemSelection(item) },
                    onEdit: { startEdit(item) },
                    onDelete: { clipboardMonitor.deleteItem(item) },
                    panelCoordinator: groupPanelCoordinator
                )
            }
        }
    }

    @ViewBuilder
    private func expandedGroupView(for group: (groupInfo: GroupInfo, items: [ClipboardItem]), groupIndex: Int) -> some View {
        GroupView(
            groupInfo: group.groupInfo,
            items: group.items,
            groupIndex: groupIndex,
            onToggleExpand: { toggleGroup(groupIndex) },
            clipboardMonitor: clipboardMonitor,
            onItemSelected: handleItemSelection,
            onItemEdit: startEdit,
            onItemDelete: { clipboardMonitor.deleteItem($0) },
            panelCoordinator: groupPanelCoordinator
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

    private func startEdit(_ item: ClipboardItem) {
        guard item.contentType == .text else { return }
        editingItem = item
        editContent = item.content
        originalContent = item.content
        editingItemTags = item.tags
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
        editingItemTags = []
    }

    private func cancelEdit() {
        editingItem = nil
        editContent = ""
        originalContent = ""
        editingItemTags = []
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

    private var items: [ClipboardItem] {
        clipboardMonitor.capturedItems
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
        
        if let tag = tag {
            TagUsageManager.shared.recordUsage(for: tag.id)
        }
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        return .ignored
    }
    
    private func handleSelectionModeKeyPress(_ key: String) -> KeyPress.Result {
        return .ignored
    }
    
    private func handleSearchModeKeyPress(_ key: String) -> KeyPress.Result {
        return .ignored
    }

    private func toggleMode() {
    }

    private func removeLastSearchCharacter() {
    }

    private func resetSearch() {
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
