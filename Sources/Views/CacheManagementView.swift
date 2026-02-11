import SwiftUI

struct CacheManagementView: View {
    @State private var cacheSize: Int64 = 0
    @State private var itemCount: Int = 0
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "internaldrive")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                Text("Image Cache".localized())
                    .font(.system(size: 14, weight: .semibold))
            }

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    StatCard(
                        icon: "photo.stack",
                        title: "Items".localized(),
                        value: "\(itemCount)"
                    )

                    StatCard(
                        icon: "memorychip",
                        title: "Size".localized(),
                        value: formattedCacheSize
                    )
                }

                Divider()

                Button(role: .destructive) {
                    clearCache()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Clear Cache".localized())
                    }
                }
                .disabled(isLoading)
                .controlSize(.regular)
            }
            .padding(12)
            .background(ThemeManager.shared.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()
        }
        .onAppear {
            loadCacheInfo()
        }
    }

    private var formattedCacheSize: String {
        if cacheSize < 1024 {
            return "\(cacheSize) B"
        } else if cacheSize < 1024 * 1024 {
            return String(format: "%.1f KB", Double(cacheSize) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(cacheSize) / (1024.0 * 1024.0))
        }
    }

    private func loadCacheInfo() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let size = ImageCacheManager.shared.cacheSize()
            let count = ImageCacheManager.shared.itemCount()
            DispatchQueue.main.async {
                self.cacheSize = size
                self.itemCount = count
                self.isLoading = false
            }
        }
    }

    private func clearCache() {
        ImageCacheManager.shared.clearCache()
        loadCacheInfo()
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(ThemeManager.shared.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
