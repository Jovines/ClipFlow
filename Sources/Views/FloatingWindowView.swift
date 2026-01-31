import AppKit
import Combine
import SwiftUI

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
                    .onChange(of: filteredItems.count) { _, _ in
                        groupPanelCoordinator.updateGroupedItems(groupedItems)
                    }

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
                    index: itemIndex,
                    isSelected: selectedIndex == itemIndex,
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
            selectedIndex: $selectedIndex,
            clipboardMonitor: clipboardMonitor,
            onItemSelected: handleItemSelection,
            onItemEdit: startEdit,
            onItemDelete: { clipboardMonitor.deleteItem($0) },
            panelCoordinator: groupPanelCoordinator
        )
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
                        onDelete: { clipboardMonitor.deleteItem(item) }
                    )
                }
            }
            .padding(8)
        }
        .onHover { hovering in
            // 面板隐藏由 handleMouseMoved 统一处理
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

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
