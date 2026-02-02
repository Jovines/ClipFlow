import SwiftUI

struct FloatingItemRow: View {
    let item: ClipboardItem
    let isEditing: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let clipboardMonitor: ClipboardMonitor
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
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

    private var timeText: Text {
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
