import SwiftUI
import AppKit

struct ModeIndicatorView: View {
    let isSelectionMode: Bool
    let searchText: String

    private var themeManager: ThemeManager { ThemeManager.shared }

    var body: some View {
        HStack(spacing: 8) {
            modeButton(icon: "magnifyingglass", label: "Search".localized(), isActive: !isSelectionMode)
            modeButton(icon: "number", label: "Select".localized(), isActive: isSelectionMode)

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
                    Text("Tab".localized())
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(themeManager.textTertiary)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 8))
                        .foregroundStyle(themeManager.textTertiary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(themeManager.chromeSurface)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(themeManager.chromeSurface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(themeManager.separator)
                .frame(height: 1)
        }
    }

    private func modeButton(icon: String, label: String, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(isActive ? themeManager.accent : themeManager.textSecondary)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(isActive ? themeManager.accent : themeManager.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isActive ? themeManager.accent.opacity(0.15) : Color.clear)
        .clipShape(Capsule())
    }
}

struct SelectionModeHintView: View {
    private var themeManager: ThemeManager { ThemeManager.shared }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "number")
                .font(.system(size: 10))
                .foregroundStyle(themeManager.accent)

            Text("Press number 1-9 for quick select".localized())
                .font(.system(size: 10))
                .foregroundStyle(themeManager.accent)

            Spacer()

            Text("Enter to confirm".localized())
                .font(.system(size: 9))
                .foregroundStyle(themeManager.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(themeManager.surface)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(themeManager.selectedBackground)
    }
}
