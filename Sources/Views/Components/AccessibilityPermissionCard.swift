import SwiftUI

struct AccessibilityPermissionCard: View {
    let isTrusted: Bool
    let cardBackground: Color
    let onOpenSettings: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "accessibility")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                Text("Accessibility Permission".localized())
                    .font(.system(size: 14, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Status".localized())
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    statusBadge
                }

                Text(isTrusted
                    ? "Global shortcut is ready to use.".localized()
                    : "Grant permission so ClipFlow can listen to global shortcuts.".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(isTrusted ? "Open Accessibility Settings".localized() : "Grant Accessibility Permission".localized()) {
                    onOpenSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isTrusted {
            Text("Granted".localized())
                .font(.system(size: 11))
                .foregroundStyle(themeManager.success)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(themeManager.success.opacity(0.15))
                .clipShape(Capsule())
        } else {
            Text("Not Granted".localized())
                .font(.system(size: 11))
                .foregroundStyle(themeManager.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(themeManager.warning.opacity(0.15))
                .clipShape(Capsule())
        }
    }
}
