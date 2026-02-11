import SwiftUI

struct ProviderPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (ProviderPreset) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Provider".localized())
                    .font(.headline)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()
                .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(ProviderPreset.allPresets) { preset in
                        PresetRow(preset: preset) {
                            onSelect(preset)
                            dismiss()
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 380, height: 520)
    }
}
