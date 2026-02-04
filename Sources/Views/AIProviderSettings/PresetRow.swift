import SwiftUI

struct PresetRow: View {
    let preset: ProviderPreset
    let onTap: () -> Void

    private var themeManager: ThemeManager { ThemeManager.shared }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: preset.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.flexokiAccent)
                    .frame(width: 36, height: 36)
                    .background(themeManager.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(themeManager.text)

                    Text(preset.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(themeManager.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeManager.border.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
