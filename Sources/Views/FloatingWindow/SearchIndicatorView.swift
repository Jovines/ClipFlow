import SwiftUI
import AppKit

struct SearchIndicatorView: View {
    let searchText: String
    let isSelectionMode: Bool
    let filteredCount: Int
    let onReset: () -> Void

    private var themeManager: ThemeManager { ThemeManager.shared }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isSelectionMode ? "number" : "magnifyingglass")
                .foregroundStyle(isSelectionMode ? themeManager.accent : .secondary)
                .font(.system(size: 13))

            if isSelectionMode {
                Text("选择模式")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeManager.accent)
            } else {
                Text(searchText)
                    .font(.system(size: 13))
                    .lineLimit(1)
            }

            Spacer()

            Text("\(filteredCount)")
                .font(.caption)
                .foregroundStyle(themeManager.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(themeManager.surface)
                .clipShape(Capsule())

            Button(action: onReset) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(themeManager.textSecondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}
