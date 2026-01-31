import SwiftUI

struct ProviderRow: View {
    let provider: AIProviderConfig
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .green : .secondary)
                .font(.system(size: 14))
                .onTapGesture { onSelect() }

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.system(size: 13))

                Text(provider.baseURL)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 6) {
                if !provider.apiKey.isEmpty {
                    Image(systemName: "checkmark.shield")
                        .foregroundStyle(.green)
                        .font(.system(size: 11))
                }

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(isSelected ? Color.flexokiAccent.opacity(0.1) : Color.clear)
    }
}
