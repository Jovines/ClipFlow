import AppKit
import Combine
import SwiftUI

final class FloatingWindowManager: ObservableObject {
    static let shared = FloatingWindowManager()

    @Published private(set) var isWindowVisible = false
    @Published private(set) var isWindowLoaded = false

    private var floatingWindow: NSWindow?
    private var floatingWindowHostingController: NSHostingController<FloatingWindowView>?
    private let clipboardMonitor: ClipboardMonitor
    private var cancellables = Set<AnyCancellable>()

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

        if floatingWindow == nil {
            createWindow()
        }

        positionWindow()
        floatingWindow?.orderFront(nil)
        floatingWindow?.makeKeyAndOrderFront(nil)
        isWindowVisible = true
    }

    func hideWindow() {
        floatingWindow?.orderOut(nil)
        isWindowVisible = false
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

    private func createWindow() {
        let floatingView = FloatingWindowView(
            onClose: { [weak self] in
                self?.hideWindow()
            },
            onItemSelected: { [weak self] item in
                self?.clipboardMonitor.copyToClipboard(item)
                self?.hideWindow()
            },
            maxVisibleItems: maxVisibleItems
        )

        floatingWindowHostingController = NSHostingController(rootView: floatingView)
        floatingWindowHostingController?.rootView.environmentObject(clipboardMonitor)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
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

        setupKeyboardShortcuts()
    }

    private func positionWindow() {
        guard let window = floatingWindow else { return }

        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.screens.first

        guard let targetScreen = screen else { return }

        let screenFrame = targetScreen.visibleFrame
        var windowOrigin = NSPoint(
            x: mouseLocation.x - windowWidth / 2,
            y: mouseLocation.y - windowHeight - 20
        )

        if windowOrigin.x < screenFrame.minX {
            windowOrigin.x = screenFrame.minX + 10
        }
        if windowOrigin.x + windowWidth > screenFrame.maxX {
            windowOrigin.x = screenFrame.maxX - windowWidth - 10
        }
        if windowOrigin.y < screenFrame.minY {
            windowOrigin.y = mouseLocation.y + 20
        }

        window.setFrameOrigin(windowOrigin)
    }

    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.hideWindow()
                return nil
            }
            return event
        }
    }

    func cleanup() {
        hideWindow()
        floatingWindowHostingController = nil
        floatingWindow = nil
        isWindowLoaded = false
    }
}

// MARK: - Floating Window View

struct FloatingWindowView: View {
    let onClose: () -> Void
    let onItemSelected: (ClipboardItem) -> Void
    let maxVisibleItems: Int

    @EnvironmentObject private var clipboardMonitor: ClipboardMonitor
    @State private var searchText = ""
    @State private var selectedItem: ClipboardItem?
    @State private var showImagePreview = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
        .frame(width: 360, height: 420)
        .onAppear {
            clipboardMonitor.refresh()
            isSearchFocused = true
        }
        .sheet(isPresented: $showImagePreview) {
            if let item = selectedItem {
                ImagePreviewView(item: item)
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))

            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isSearchFocused)
                .onSubmit {
                    if let firstItem = filteredItems.first {
                        onItemSelected(firstItem)
                    }
                }

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }

            Divider()
                .frame(height: 20)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    @ViewBuilder
    private var contentView: some View {
        if filteredItems.isEmpty {
            emptyStateView
        } else {
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

    @ViewBuilder
    private func itemRow(for item: ClipboardItem, index: Int) -> some View {
        FloatingItemRow(
            item: item,
            isSelected: selectedItem?.id == item.id,
            onSelect: {
                handleItemSelection(item)
            },
            onDelete: {
                clipboardMonitor.deleteItem(item)
            }
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
                .foregroundStyle(.secondary)

            Text("No clipboard history")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Copy something to see it here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardMonitor.capturedItems
        }
        return clipboardMonitor.capturedItems.filter {
            $0.content.localizedCaseInsensitiveContains(searchText) ||
            $0.tags.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
}

// MARK: - Floating Item Row

struct FloatingItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject private var clipboardMonitor: ClipboardMonitor
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            contentPreview

            Spacer()

            if isHovered {
                Button(action: onSelect) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent.return, modifiers: [])

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
                            ForEach(item.tags.prefix(2)) { tag in
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
                .foregroundStyle(.secondary)
            }
        }
    }

    private var contentIcon: some View {
        Group {
            switch item.contentType {
            case .text:
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
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
        Text(item.createdAt, style: .relative)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.3)
        }
        return isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.5) : .clear
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
                } else if let imageData = item.imageData,
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
