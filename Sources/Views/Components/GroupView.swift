import SwiftUI

struct GroupView: View {
    let groupInfo: FloatingWindowView.GroupInfo
    let items: [ClipboardItem]
    let groupIndex: Int
    let onToggleExpand: () -> Void
    let clipboardMonitor: ClipboardMonitor
    let onItemSelected: (ClipboardItem) -> Void
    let onItemEdit: (ClipboardItem) -> Void
    let onItemDelete: (ClipboardItem) -> Void
    let onAddToProject: (ClipboardItem) -> Void
    @ObservedObject var panelCoordinator: GroupPanelCoordinator

    @State private var isHovered = false

    private let itemsPerGroup = 10

    private var themeManager: ThemeManager { ThemeManager.shared }

    private var displayIndex: Int {
        if groupIndex == 0 {
            return -1
        }
        let offset = 10 + (groupIndex - 1) * itemsPerGroup
        return offset
    }

    var body: some View {
        groupHeader
            .padding(.vertical, 2)
            .frame(height: 36)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    panelCoordinator.startHoverDelay(groupIndex: groupIndex, groupInfo: groupInfo, items: items)
                } else {
                    panelCoordinator.cancelHoverDelay()
                }
            }
    }

    private var groupHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(themeManager.textSecondary)

            Text("\(groupInfo.startIndex)-\(groupInfo.endIndex)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(themeManager.textSecondary)

            Spacer()

            if isHovered {
                Text("悬停查看")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isHovered ? themeManager.surface.opacity(0.5) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }
}

struct CompactItemRow: View {
    let item: ClipboardItem
    let clipboardMonitor: ClipboardMonitor
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onAddToProject: () -> Void
    let onManageTags: () -> Void
    let isRecommended: Bool
    @ObservedObject var panelCoordinator: GroupPanelCoordinator
    @State private var isHovered = false

    private var themeManager: ThemeManager { ThemeManager.shared }

    var body: some View {
        HStack(spacing: 8) {
            contentPreview

            Spacer()

            if !itemTags.isEmpty {
                HStack(spacing: 2) {
                    ForEach(Array(itemTags.prefix(3))) { tag in
                        Circle()
                            .fill(Color.hex(tag.color))
                            .frame(width: 6, height: 6)
                    }
                    if itemTags.count > 3 {
                        Text("+\(itemTags.count - 3)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if isRecommended {
                Text("✨")
                    .font(.system(size: 10))
            }

            if isHovered {
                Button(action: onManageTags) {
                    Image(systemName: "tag")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(themeManager.textSecondary)

                Button(action: onAddToProject) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(themeManager.accent)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(themeManager.accent)

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
        .padding(.vertical, 3)
        .background(isHovered ? themeManager.borderSubtle.opacity(0.3) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                panelCoordinator.hidePanel()
            }
        }
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button(action: onManageTags) {
                Label("Manage Tags", systemImage: "tag")
            }
            Button(action: onAddToProject) {
                Label("Add to Project", systemImage: "folder.badge.plus")
            }
            Divider()
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .onAppear { loadItemTags() }
    }

    @State private var itemTagsData: [Tag] = []

    private var itemTags: [Tag] {
        itemTagsData
    }

    private func loadItemTags() {
        do {
            itemTagsData = try TagService.shared.getTagsForItem(itemId: item.id)
        } catch {
            itemTagsData = []
        }
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
            .foregroundStyle(themeManager.textSecondary)
            .font(.system(size: 11))

            previewText
        }
    }

    private var previewText: some View {
        Group {
            switch item.contentType {
            case .text:
                let cleanedContent = item.content
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\r", with: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                Text(cleanedContent)
            case .image:
                Text("Image")
            }
        }
        .font(.system(size: 11))
        .lineLimit(1)
        .foregroundStyle(themeManager.text)
    }
}

struct GroupPanelItemRow: View {
    let item: ClipboardItem
    let index: Int
    let clipboardMonitor: ClipboardMonitor
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onAddToProject: () -> Void
    @State private var isHovered = false

    private var themeManager: ThemeManager { ThemeManager.shared }

    var body: some View {
        HStack(spacing: 8) {
            contentPreview

            Spacer()

            if isHovered {
                Button(action: onAddToProject) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(themeManager.accent)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(themeManager.accent)

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
        .background(isHovered ? themeManager.borderSubtle.opacity(0.5) : .clear)
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
            .foregroundStyle(themeManager.textSecondary)
            .font(.system(size: 11))

            previewText
        }
    }

    private var previewText: some View {
        Group {
            switch item.contentType {
            case .text:
                let cleanedContent = item.content
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\r", with: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                Text(cleanedContent)
            case .image:
                Text("Image")
            }
        }
        .font(.system(size: 11))
        .lineLimit(1)
        .foregroundStyle(themeManager.text)
    }
}
