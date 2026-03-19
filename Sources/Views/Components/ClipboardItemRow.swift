import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    @State private var isHovered = false

    private var themeManager: ThemeManager { ThemeManager.shared }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(previewText)
                    .font(.body)
                    .lineLimit(2)

                HStack {
                    Text(TimeFormatter.relativeTime(from: item.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let richTextFormat = item.richTextFormatLabel {
                        Text(richTextFormat)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(themeManager.accent)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(themeManager.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

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
        .background(isHovered ? themeManager.hoverBackground.opacity(0.5) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var iconName: String {
        item.displayIconName
    }

    private var previewText: String {
        switch item.contentType {
        case .text:
            return item.content
        case .image:
            return "Image".localized()
        case .file:
            return item.fileDisplayText
        }
    }

    private func copyItem() {
        ClipboardMonitor.shared.copyToClipboard(item)
    }
}

#Preview {
    ClipboardItemRow(item: ClipboardItem(
        content: "Hello, World!",
        contentType: .text
    ))
    .padding()
}
