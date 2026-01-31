import SwiftUI

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
        groupHeader
            .padding(.vertical, 4)
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
    @ObservedObject var panelCoordinator: GroupPanelCoordinator
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

struct GroupPanelItemRow: View {
    let item: ClipboardItem
    let index: Int
    let clipboardMonitor: ClipboardMonitor
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
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
