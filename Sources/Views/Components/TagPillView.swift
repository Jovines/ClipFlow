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
            .background(isSelected ? Color.hex(tag.color).opacity(0.2) : Color.flexokiSurface)
            .foregroundStyle(isSelected ? Color.hex(tag.color) : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.hex(tag.color).opacity(0.5) : Color.flexokiBorder, lineWidth: 1)
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
