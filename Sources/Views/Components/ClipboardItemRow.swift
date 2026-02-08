import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    @State private var isHovered = false

    private var themeManager: ThemeManager { ThemeManager.shared }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(previewText)
                    .font(.body)
                    .lineLimit(2)

                HStack {
                    Text(formatTimeAgo(from: item.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let note = item.note, !note.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: { copyItem() }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
            }
            .opacity(isHovered ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .padding(12)
        .background(isHovered ? themeManager.accent.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var iconName: String {
        switch item.contentType {
        case .text:
            return "doc.text"
        case .image:
            return "photo"
        }
    }

    private var previewText: String {
        switch item.contentType {
        case .text:
            return item.content
        case .image:
            return "Image"
        }
    }

    private func copyItem() {
        ClipboardMonitor.shared.copyToClipboard(item)
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
}

#Preview {
    ClipboardItemRow(item: ClipboardItem(
        content: "Hello, World!",
        contentType: .text
    ))
    .padding()
}
