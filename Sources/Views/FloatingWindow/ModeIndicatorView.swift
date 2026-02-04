import SwiftUI
import AppKit

struct ModeIndicatorView: View {
    let isSelectionMode: Bool
    let searchText: String

    private var themeManager: ThemeManager { ThemeManager.shared }

    var body: some View {
        HStack(spacing: 8) {
            modeButton(icon: "magnifyingglass", label: "搜索", isActive: !isSelectionMode)
            modeButton(icon: "number", label: "选择", isActive: isSelectionMode)

            Spacer()

            HStack(spacing: 4) {
                if !searchText.isEmpty && !isSelectionMode {
                    Text(searchText)
                        .font(.system(size: 11))
                        .foregroundStyle(themeManager.textSecondary)
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
                .background(themeManager.surface)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(themeManager.surface.opacity(0.8))
    }

    private func modeButton(icon: String, label: String, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(isActive ? themeManager.accent : .secondary)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(isActive ? themeManager.accent : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isActive ? themeManager.accent.opacity(0.15) : Color.clear)
        .clipShape(Capsule())
    }
}

struct SelectionModeHintView: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "number")
                .font(.system(size: 10))
                .foregroundStyle(ThemeManager.shared.accent)

            Text("按数字 1-9 快速选择")
                .font(.system(size: 10))
                .foregroundStyle(ThemeManager.shared.accent)

            Spacer()

            Text("Enter 确认")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ThemeManager.shared.surface)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(ThemeManager.shared.accent.opacity(0.08))
    }
}
