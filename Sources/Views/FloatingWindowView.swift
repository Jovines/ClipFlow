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
        let filteredItems = filterItemsByTags(clipboardMonitor.capturedItems)
        let visibleItems = Array(filteredItems.prefix(maxVisibleItems))
        let remainingItems = Array(filteredItems.dropFirst(maxVisibleItems))

        var groups: [(groupInfo: GroupInfo, items: [ClipboardItem])] = []

        if !visibleItems.isEmpty {
            groups.append((GroupInfo(startIndex: 1, endIndex: visibleItems.count, totalCount: filteredItems.count), visibleItems))
        }

        for (index, chunk) in remainingItems.chunked(into: 15).enumerated() {
            let startIndex = maxVisibleItems + index * 15 + 1
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

    @State private var showProjectSelector = false
    @State private var showCreateProjectSheet = false
    @State private var showAddToProjectSelector = false
    @State private var isProjectMode = false
    @State private var currentProject: Project? = nil
    @State private var itemForAddToProject: ClipboardItem?

    @StateObject private var tagService = TagService.shared
    @State private var selectedTagIds: [UUID] = []
    @State private var showTagManagement = false
    @State private var showCreateTagSheet = false
    @State private var newTagName: String = ""
    @State private var newTagColorName: String = "blue"

    @State private var showRecommendationHistory = false
    @State private var recommendationHistoryItems: [ClipboardItem] = []
    @State private var recommendedItems: [ClipboardItem] = []

    private let recommendationService = RecommendationService.shared

    private var themeManager: ThemeManager { ThemeManager.shared }

    var body: some View {
        let content = contentBuilder

        return content
            .themeAware()
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
                TagSidebarView(
                    tagService: tagService,
                    selectedTagIds: $selectedTagIds,
                    onCreateTag: createNewTag,
                    onManageTags: openTagManagement,
                    showRecommendationHistory: $showRecommendationHistory
                )
                .frame(height: 420)

                VStack(spacing: 0) {
                    HeaderBar(
                        showProjectSelector: $showProjectSelector,
                        currentProject: currentProject,
                        isProjectMode: $isProjectMode
                    )

                    Divider()
                    contentView
                }
                .frame(width: tagService.allTags.isEmpty ? 360 : 280, height: 460)
            }

            if isEditing {
                EditorPanelView(
                    editContent: $editContent,
                    editingItem: $editingItem,
                    originalContent: originalContent,
                    onSave: saveEdit,
                    onCancel: cancelEdit,
                    onReset: resetEdit
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
                    onAddToProject: { showAddToProject(for: $0) },
                    onHide: { groupPanelCoordinator.hidePanel() }
                )
                .frame(width: groupPanelWidth, height: 420)
            }
        }
        .background(ThemeManager.shared.surface.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
        .onAppear {
            clipboardMonitor.refresh()
            groupPanelCoordinator.startTracking()
            tagService.refreshTags()
            loadRecommendations()
            loadRecommendationHistory()
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
                    try? ProjectService.shared.activateProject(id: project.id)
                }
            )
        }
        .sheet(isPresented: $showAddToProjectSelector) {
            if let item = itemForAddToProject {
                AddToProjectSelectorView(
                    isPresented: $showAddToProjectSelector,
                    clipboardItem: item,
                    onAdded: {
                        ClipFlowLogger.info("✅ Item added to project: \(item.id)")
                    }
                )
            }
        }
        .sheet(item: $editingItem) { item in
            TagPickerView(item: item, tagService: tagService)
        }
        .sheet(isPresented: $showTagManagement) {
            TagManagementView(tagService: tagService)
        }
        .sheet(isPresented: $showCreateTagSheet) {
            createTagSheet
        }
    }

    private func loadRecommendations() {
        Task {
            do {
                recommendedItems = try recommendationService.fetchRecommendedItems()
            } catch {
                ClipFlowLogger.error("Failed to load recommendations: \(error)")
            }
        }
    }

    private func loadRecommendationHistory() {
        Task {
            do {
                recommendationHistoryItems = try recommendationService.fetchRecommendationHistory()
                tagService.refreshRecommendationHistoryCount()
            } catch {
                ClipFlowLogger.error("Failed to load recommendation history: \(error)")
            }
        }
    }

    private func filterItemsByTags(_ items: [ClipboardItem]) -> [ClipboardItem] {
        guard !selectedTagIds.isEmpty else {
            return items
        }
        do {
            let filteredItems = try items.filter { item in
                let itemTags = try tagService.getTagsForItem(itemId: item.id)
                let itemTagIds = itemTags.map { $0.id }
                let hasMatch = !selectedTagIds.isEmpty && !itemTagIds.isEmpty && !Set(selectedTagIds).isDisjoint(with: itemTagIds)
                return hasMatch
            }
            return filteredItems
        } catch {
            return items
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
        let displayItems = showRecommendationHistory ? recommendationHistoryItems : filterItemsByTags(clipboardMonitor.capturedItems)

        if displayItems.isEmpty && recommendedItems.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    if !showRecommendationHistory && !recommendedItems.isEmpty {
                        recommendationSection
                    }

                    if showRecommendationHistory {
                        recommendationHistorySection
                    } else {
                        ForEach(Array(groupedItems.enumerated()), id: \.offset) { groupIndex, group in
                            if groupIndex == 0 {
                                firstGroupView(for: group)
                            } else {
                                expandedGroupView(for: group, groupIndex: groupIndex)
                            }
                        }
                    }
                }
                .padding(8)
                .onAppear {
                    groupPanelCoordinator.updateGroupedItems(groupedItems)
                }
                .onChange(of: displayItems.count) { _, _ in
                    groupPanelCoordinator.updateGroupedItems(groupedItems)
                }
            }
        }
    }

    @ViewBuilder
    private var recommendationSection: some View {
        VStack(spacing: 4) {
            LazyVStack(spacing: 4) {
                ForEach(Array(recommendedItems.enumerated()), id: \.element.id) { index, item in
                    CompactItemRow(
                        item: item,
                        clipboardMonitor: clipboardMonitor,
                        onSelect: { handleItemSelection(item) },
                        onEdit: { startEdit(item) },
                        onDelete: { clipboardMonitor.deleteItem(item) },
                        onAddToProject: { showAddToProject(for: item) },
                        onManageTags: { showTagPicker(for: item) },
                        isRecommended: true,
                        panelCoordinator: groupPanelCoordinator
                    )
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .padding(4)
        .background(themeManager.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var recommendationHistorySection: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(themeManager.textSecondary)
                Text("推荐历史")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(themeManager.textSecondary)
                Spacer()
                if !recommendationHistoryItems.isEmpty {
                    Text("\(recommendationHistoryItems.count) 条")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(themeManager.colorScheme == .dark ? Color.flexokiBase700.opacity(0.5) : Color.flexokiBase200.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if recommendationHistoryItems.isEmpty {
                Text("暂无推荐历史")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(Array(recommendationHistoryItems.enumerated()), id: \.element.id) { index, item in
                        CompactItemRow(
                            item: item,
                            clipboardMonitor: clipboardMonitor,
                            onSelect: { handleItemSelection(item) },
                            onEdit: { startEdit(item) },
                            onDelete: { clipboardMonitor.deleteItem(item) },
                            onAddToProject: { showAddToProject(for: item) },
                            onManageTags: { showTagPicker(for: item) },
                            isRecommended: false,
                            panelCoordinator: groupPanelCoordinator
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.bottom, 8)
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
                    onAddToProject: { showAddToProject(for: item) },
                    onManageTags: { showTagPicker(for: item) },
                    isRecommended: false,
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
            onAddToProject: { showAddToProject(for: $0) },
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

        Task {
            do {
                try recommendationService.updateUsage(itemId: item.id)
                ClipFlowLogger.info("✅ Updated usage for item: \(item.id)")
                try await recommendationService.recalculateRecommendations()
                await MainActor.run {
                    loadRecommendations()
                }
            } catch {
                ClipFlowLogger.error("❌ Failed to update usage: \(error)")
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 36))
                .foregroundStyle(Color.flexokiTextSecondary)

            Text(showRecommendationHistory ? "暂无推荐历史" : "No clipboard history")
                .font(.subheadline)
                .foregroundStyle(Color.flexokiTextSecondary)

            Text(showRecommendationHistory ? "使用频率高的项目会出现在这里" : "Copy something to see it here")
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

    private var items: [ClipboardItem] {
        filterItemsByTags(clipboardMonitor.capturedItems)
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

    private func showAddToProject(for item: ClipboardItem) {
        itemForAddToProject = item
        showAddToProjectSelector = true
    }

    private func showTagPicker(for item: ClipboardItem) {
        ClipFlowLogger.info("🎯 showTagPicker called for item: \(item.id)")
        editingItem = item
        ClipFlowLogger.info("🎯 editingItem set to: \(String(describing: editingItem))")
    }

    private func createNewTag() {
        newTagName = ""
        newTagColorName = "blue"
        showCreateTagSheet = true
    }

    private func openTagManagement() {
        showTagManagement = true
    }

    private var createTagSheet: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Create Tag")
                    .font(.headline)
                Spacer()
                Button(action: { showCreateTagSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider()

            TextField("Tag name", text: $newTagName)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ThemeManager.shared.borderSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 6) {
                Text("Color")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                HStack(spacing: 8) {
                    ForEach(Tag.availableColors, id: \.name) { colorOption in
                        Circle()
                            .fill(Color.hex(colorOption.hex))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(themeManager.border, lineWidth: newTagColorName == colorOption.name ? 2 : 0)
                            )
                            .onTapGesture {
                                newTagColorName = colorOption.name
                            }
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 12)

            Spacer()

            HStack(spacing: 8) {
                Button(action: { showCreateTagSheet = false }) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Button(action: saveNewTag) {
                    Text("Create")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(newTagName.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 260, height: 200)
        .background(ThemeManager.shared.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func saveNewTag() {
        guard !newTagName.isEmpty else { return }
        do {
            _ = try tagService.createTag(name: newTagName, color: Tag.colorForName(newTagColorName))
            showCreateTagSheet = false
        } catch {
            print("[FloatingWindowView] Failed to create tag: \(error)")
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
