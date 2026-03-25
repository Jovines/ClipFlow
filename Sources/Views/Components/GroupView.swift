// swiftlint:disable file_length
import AppKit
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
            .frame(height: 28)
            .frame(maxHeight: .infinity)
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
                Text("Hover to View".localized())
                    .font(.caption2)
                    .foregroundStyle(themeManager.textTertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isHovered ? themeManager.chromeSurfaceElevated : Color.clear)
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
    let isTopRecent: Bool
    @ObservedObject var panelCoordinator: GroupPanelCoordinator
    @State private var isHovered = false
    @StateObject private var tagService = TagService.shared
    @State private var itemTagsData: [Tag] = []

    private var themeManager: ThemeManager { ThemeManager.shared }

    private var isImageItem: Bool {
        item.contentType == .image
    }

    private var rowMinHeight: CGFloat {
        isImageItem ? 36 : 20
    }

    var body: some View {
        HStack(spacing: 8) {
            contentPreview
                .frame(maxWidth: .infinity, alignment: .leading)

            if !itemTags.isEmpty {
                HStack(spacing: 2) {
                    ForEach(Array(itemTags.prefix(3))) { tag in
                        Circle()
                            .fill(Color.hex(tag.color).opacity(themeManager.tagTintOpacity))
                            .frame(width: 6, height: 6)
                    }
                    if itemTags.count > 3 {
                        Text("+\(itemTags.count - 3)")
                            .font(.system(size: 9))
                            .foregroundStyle(themeManager.textSecondary)
                    }
                }
            }

            if let note = item.note, !note.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "note.text")
                        .font(.system(size: 9))
                    Text(note)
                        .font(.system(size: 9))
                        .lineLimit(1)
                }
                .foregroundStyle(themeManager.textSecondary)
            }

            if let richTextFormat = item.richTextFormatLabel {
                RichTextFormatChip(format: richTextFormat)
            }

            if isTopRecent {
                Image(systemName: "clock")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(themeManager.statusBadgeWarningForeground)
                    .frame(width: 18, height: 16)
                    .background(themeManager.statusBadgeWarningBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(themeManager.statusBadgeWarningForeground.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: themeManager.statusBadgeWarningBackground.opacity(0.10), radius: 2, y: 1)
            }

            if isHovered {
                actionButtons
            }
        }
        .frame(minHeight: rowMinHeight)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(isHovered ? themeManager.hoverBackground : .clear)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovered ? themeManager.separator : Color.clear, lineWidth: 1)
        )
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
                Label("Manage Tags".localized(), systemImage: "tag")
            }
            Button(action: onAddToProject) {
                Label("Add to Project".localized(), systemImage: "folder.badge.plus")
            }
            Divider()
            Button(action: onEdit) {
                Label(
                    isImageItem ? "Image Preview".localized() : "Edit".localized(),
                    systemImage: isImageItem ? "eye" : "pencil"
                )
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete".localized(), systemImage: "trash")
            }
        }
        .onAppear { loadItemTags() }
        .onChange(of: tagService.allTags) { _, _ in
            loadItemTags()
        }
        .onChange(of: tagService.itemTagAssociationsChanged) { _, _ in
            loadItemTags()
        }
    }

    private var itemTags: [Tag] {
        itemTagsData
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: onManageTags) {
                Image(systemName: "tag")
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
                    .background(themeManager.iconBadgeAccentBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(themeManager.iconBadgeStroke, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: themeManager.iconBadgeAccentBackground.opacity(themeManager.iconBadgeShadowOpacity), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(themeManager.iconBadgeAccentForeground)
            .help("Manage Tags".localized())
            .accessibilityLabel("Manage Tags".localized())

            Button(action: onAddToProject) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
                    .background(themeManager.iconBadgeAccentBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(themeManager.iconBadgeStroke, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: themeManager.iconBadgeAccentBackground.opacity(themeManager.iconBadgeShadowOpacity), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(themeManager.iconBadgeAccentForeground)
            .help("Add to Project".localized())
            .accessibilityLabel("Add to Project".localized())

            Button(action: onEdit) {
                Image(systemName: isImageItem ? "eye" : "pencil")
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
                    .background(themeManager.iconBadgeAccentBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(themeManager.iconBadgeStroke, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: themeManager.iconBadgeAccentBackground.opacity(themeManager.iconBadgeShadowOpacity), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(themeManager.iconBadgeAccentForeground)
            .help(isImageItem ? "Image Preview".localized() : "Edit".localized())
            .accessibilityLabel(isImageItem ? "Image Preview".localized() : "Edit".localized())

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
                    .background(themeManager.iconBadgeDestructiveBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(themeManager.iconBadgeStroke, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: themeManager.iconBadgeDestructiveBackground.opacity(themeManager.iconBadgeShadowOpacity), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(themeManager.iconBadgeDestructiveForeground)
            .keyboardShortcut(KeyEquivalent.delete, modifiers: [])
            .help("Delete".localized())
            .accessibilityLabel("Delete".localized())
        }
    }

    private func loadItemTags() {
        do {
            itemTagsData = try tagService.getTagsForItem(itemId: item.id)
        } catch {
            itemTagsData = []
        }
    }


    private var contentPreview: some View {
        HStack(spacing: 6) {
            switch item.contentType {
            case .image:
                imageThumbnail
                previewText
            case .text, .file:
                Group {
                    switch item.contentType {
                    case .text:
                        Image(systemName: item.isRichTextText ? "text.alignleft" : item.displayIconName)
                    case .file:
                        Image(systemName: "doc")
                    case .image:
                        EmptyView()
                    }
                }
                .foregroundStyle(themeManager.textSecondary)
                .font(.system(size: 11))

                previewText
            }
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
                Text(sanitizeRichTextPrefixIfNeeded(cleanedContent))
            case .image:
                Text("Image".localized())
            case .file:
                Text(item.fileDisplayText)
            }
        }
        .font(.system(size: 11))
        .lineLimit(1)
        .foregroundStyle(themeManager.text)
    }

    private var imageThumbnail: some View {
        let frameSize = thumbnailFrameSize

        return Group {
            if let thumbnailData,
               let nsImage = NSImage(data: thumbnailData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .background(Color.white)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.95))
                    Image(systemName: "photo")
                        .font(.system(size: 12))
                        .foregroundStyle(themeManager.textSecondary)
                }
            }
        }
        .frame(width: frameSize.width, height: frameSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(themeManager.separator.opacity(0.8), lineWidth: 1)
        )
    }

    private var thumbnailFrameSize: CGSize {
        let maxHeight: CGFloat = 32
        let minWidth: CGFloat = 32
        let maxWidth: CGFloat = 110
        let fallbackWidth: CGFloat = 52

        let ratioSource = imageDataForRatio ?? thumbnailData

        guard let ratioSource,
              let nsImage = NSImage(data: ratioSource),
              nsImage.size.height > 0 else {
            return CGSize(width: fallbackWidth, height: maxHeight)
        }

        let ratio = nsImage.size.width / nsImage.size.height
        let targetWidth = maxHeight * ratio
        let clampedWidth = min(max(targetWidth, minWidth), maxWidth)
        return CGSize(width: clampedWidth, height: maxHeight)
    }

    private var imageDataForRatio: Data? {
        guard let imagePath = item.imagePath else { return nil }
        return ImageCacheManager.shared.loadImage(forKey: imagePath)
    }

    private var thumbnailData: Data? {
        if let thumbnailPath = item.thumbnailPath,
           let thumbnail = ImageCacheManager.shared.loadImage(forKey: thumbnailPath) {
            return thumbnail
        }

        if let imagePath = item.imagePath {
            return ImageCacheManager.shared.loadImage(forKey: imagePath)
        }

        return nil
    }

    private func sanitizeRichTextPrefixIfNeeded(_ text: String) -> String {
        guard item.isRichTextText else { return text }

        let prefixes = ["格式 ", "Format ", "format "]
        for prefix in prefixes where text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return text
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

    private var isImageItem: Bool {
        item.contentType == .image
    }

    private var rowMinHeight: CGFloat {
        isImageItem ? 36 : 20
    }

    var body: some View {
        HStack(spacing: 8) {
            contentPreview
                .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered {
                actionButtons
            }
        }
        .frame(minHeight: rowMinHeight)
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
            switch item.contentType {
            case .image:
                imageThumbnail
                previewText
            case .text, .file:
                Group {
                    switch item.contentType {
                    case .text:
                        Image(systemName: item.isRichTextText ? "text.alignleft" : item.displayIconName)
                    case .file:
                        Image(systemName: "doc")
                    case .image:
                        EmptyView()
                    }
                }
                .foregroundStyle(themeManager.textSecondary)
                .font(.system(size: 11))

                previewText
            }

            if let richTextFormat = item.richTextFormatLabel {
                RichTextFormatChip(format: richTextFormat)
            }
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
                Text(sanitizeRichTextPrefixIfNeeded(cleanedContent))
            case .image:
                Text("Image".localized())
            case .file:
                Text(item.fileDisplayText)
            }
        }
        .font(.system(size: 11))
        .lineLimit(1)
        .foregroundStyle(themeManager.text)
    }

    private var imageThumbnail: some View {
        let frameSize = thumbnailFrameSize

        return Group {
            if let thumbnailData,
               let nsImage = NSImage(data: thumbnailData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .background(Color.white)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.95))
                    Image(systemName: "photo")
                        .font(.system(size: 12))
                        .foregroundStyle(themeManager.textSecondary)
                }
            }
        }
        .frame(width: frameSize.width, height: frameSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(themeManager.separator.opacity(0.8), lineWidth: 1)
        )
    }

    private var thumbnailFrameSize: CGSize {
        let maxHeight: CGFloat = 32
        let minWidth: CGFloat = 32
        let maxWidth: CGFloat = 110
        let fallbackWidth: CGFloat = 52

        let ratioSource = imageDataForRatio ?? thumbnailData

        guard let ratioSource,
              let nsImage = NSImage(data: ratioSource),
              nsImage.size.height > 0 else {
            return CGSize(width: fallbackWidth, height: maxHeight)
        }

        let ratio = nsImage.size.width / nsImage.size.height
        let targetWidth = maxHeight * ratio
        let clampedWidth = min(max(targetWidth, minWidth), maxWidth)
        return CGSize(width: clampedWidth, height: maxHeight)
    }

    private var imageDataForRatio: Data? {
        guard let imagePath = item.imagePath else { return nil }
        return ImageCacheManager.shared.loadImage(forKey: imagePath)
    }

    private var thumbnailData: Data? {
        if let thumbnailPath = item.thumbnailPath,
           let thumbnail = ImageCacheManager.shared.loadImage(forKey: thumbnailPath) {
            return thumbnail
        }

        if let imagePath = item.imagePath {
            return ImageCacheManager.shared.loadImage(forKey: imagePath)
        }

        return nil
    }

    private func sanitizeRichTextPrefixIfNeeded(_ text: String) -> String {
        guard item.isRichTextText else { return text }

        let prefixes = ["格式 ", "Format ", "format "]
        for prefix in prefixes where text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return text
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: onAddToProject) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
                    .background(themeManager.iconBadgeAccentBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(themeManager.iconBadgeStroke, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: themeManager.iconBadgeAccentBackground.opacity(themeManager.iconBadgeShadowOpacity), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(themeManager.iconBadgeAccentForeground)
            .help("Add to Project".localized())
            .accessibilityLabel("Add to Project".localized())

            Button(action: onEdit) {
                Image(systemName: isImageItem ? "eye" : "pencil")
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
                    .background(themeManager.iconBadgeAccentBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(themeManager.iconBadgeStroke, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: themeManager.iconBadgeAccentBackground.opacity(themeManager.iconBadgeShadowOpacity), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(themeManager.iconBadgeAccentForeground)
            .help(isImageItem ? "Image Preview".localized() : "Edit".localized())
            .accessibilityLabel(isImageItem ? "Image Preview".localized() : "Edit".localized())

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .frame(width: 20, height: 20)
                    .background(themeManager.iconBadgeDestructiveBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(themeManager.iconBadgeStroke, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: themeManager.iconBadgeDestructiveBackground.opacity(themeManager.iconBadgeShadowOpacity), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(themeManager.iconBadgeDestructiveForeground)
            .keyboardShortcut(KeyEquivalent.delete, modifiers: [])
            .help("Delete".localized())
            .accessibilityLabel("Delete".localized())
        }
    }
}

private struct RichTextFormatChip: View {
    let format: String

    private var themeManager: ThemeManager { ThemeManager.shared }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 8, weight: .semibold))

            Text(format.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(themeManager.textSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(themeManager.chromeSurfaceElevated.opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(themeManager.separator.opacity(0.9), lineWidth: 1)
        )
    }

    private var iconName: String {
        switch format.uppercased() {
        case "HTML":
            return "curlybraces"
        case "RTF":
            return "textformat"
        default:
            return "doc.richtext"
        }
    }
}
