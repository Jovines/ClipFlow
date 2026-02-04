import SwiftUI

struct TagPillView: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.hex(tag.color))
                    .frame(width: 6, height: 6)
                Text(tag.name)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.hex(tag.color).opacity(0.2) : ThemeManager.shared.surface)
            .foregroundStyle(isSelected ? Color.hex(tag.color) : ThemeManager.shared.textSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.hex(tag.color).opacity(0.5) : ThemeManager.shared.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TagPillCompactView: View {
    let tag: Tag
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(Color.hex(tag.color))
                .frame(width: 8, height: 8)
        }
        .buttonStyle(.plain)
    }
}
