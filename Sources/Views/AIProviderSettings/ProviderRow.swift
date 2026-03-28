import SwiftUI

struct ProviderRow: View {
    let provider: AIProviderConfig
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .green : .secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select Provider".localized())
            .help("Select Provider".localized())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(provider.name)
                        .font(.system(size: 13))
                    Text(provider.providerType == .api ? "API" : "CLI")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.flexokiAccent.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(provider.providerType == .api ? provider.baseURL : "Local command execution".localized())
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 6) {
                if provider.providerType == .api && !provider.apiKey.isEmpty {
                    Image(systemName: "checkmark.shield")
                        .foregroundStyle(.green)
                        .font(.system(size: 11))
                } else if provider.providerType == .cli && !provider.cliCommandTemplate.isEmpty {
                    Image(systemName: "terminal")
                        .foregroundStyle(.green)
                        .font(.system(size: 11))
                }

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Edit Provider".localized())
                .help("Edit Provider".localized())

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .accessibilityLabel("Delete Provider".localized())
                .help("Delete Provider".localized())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(isSelected ? Color.flexokiAccent.opacity(0.1) : Color.clear)
        .onTapGesture {
            onSelect()
        }
    }
}
