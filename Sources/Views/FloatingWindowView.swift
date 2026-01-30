import AppKit
import Combine
import SwiftUI

final class FloatingWindowManager: ObservableObject {
    static let shared = FloatingWindowManager()

    @Published private(set) var isWindowVisible = false
    @Published private(set) var isWindowLoaded = false

    private(set) var floatingWindow: NSWindow?
    private var floatingWindowHostingController: NSHostingController<FloatingWindowView>?
    private let clipboardMonitor: ClipboardMonitor
    private var cancellables = Set<AnyCancellable>()
    private var clickOutsideMonitor: Any?
    private var previousActiveApp: NSRunningApplication?
    private var isPasting = false

    private let windowWidth: CGFloat = 360
    private let windowHeight: CGFloat = 420
    private let maxVisibleItems = 10

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

        floatingWindowHostingController = NSHostingController(rootView: floatingView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        window.contentView = floatingWindowHostingController?.view
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .transient]
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
        if windowOrigin.y + windowHeight > screenFrame.maxY - menuBarHeight {
            // Position below mouse instead
            windowOrigin.y = mouseLocation.y + 20
        }
        if windowOrigin.y < screenFrame.minY {
            windowOrigin.y = screenFrame.minY + 10
        }

        // Final safety check
        if windowOrigin.y + windowHeight > screenFrame.maxY {
            windowOrigin.y = screenFrame.maxY - windowHeight - 10
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

    var body: some View {
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
            contentView
        }
        .background(Color.flexokiSurface.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
        .frame(width: 360, height: 420)
        .onAppear {
            clipboardMonitor.refresh()
            resetSearch()
            loadAllTags()
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
            toggleMode()
            return .handled
        }
        .onKeyPress(.return) {
            if let item = getSelectedItem() {
                handleItemSelection(item)
            }
            return .handled
        }
        .onKeyPress(.delete) {
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
            if isSelectionMode {
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
            handleKeyPress(press)
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
        let maxIndex = min(filteredItems.count - 1, maxVisibleItems - 1)

        switch direction {
        case .down:
            if selectedIndex < 0 {
                selectedIndex = -1
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
                        ForEach(Array(filteredItems.prefix(maxVisibleItems).enumerated()), id: \.element.id) { index, item in
                            itemRow(for: item, index: index)
                        }
                    }
                    .padding(8)
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
            onSelect: {
                handleItemSelection(item)
            },
            onDelete: {
                clipboardMonitor.deleteItem(item)
            },
            clipboardMonitor: clipboardMonitor
        )
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

// MARK: - Floating Item Row

struct FloatingItemRow: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let clipboardMonitor: ClipboardMonitor
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            if index < 9 {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isSelected ? Color.flexokiAccent : .secondary)
                    .frame(width: 16, height: 16)
        .background(isSelected ? Color.flexokiAccent.opacity(0.2) : Color.flexokiSurface.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            contentPreview

            Spacer()

            if isHovered {
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
        .padding(.vertical, 8)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
