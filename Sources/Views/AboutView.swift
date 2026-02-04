import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color.flexokiAccent.opacity(0.8), Color.flexokiAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.flexokiAccent.opacity(0.3), radius: 10, x: 0, y: 4)

                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(Color.flexokiPaper)
                }

                VStack(spacing: 4) {
                    Text("ClipFlow")
                        .font(.system(size: 20, weight: .bold))

                    Text("Version 1.0.0")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)

            VStack(spacing: 0) {
                LinkRow(
                    icon: "globe",
                    title: "GitHub Repository",
                    url: URL(string: "https://github.com/Jovines/ClipFlow") ?? URL(string: "https://github.com")!
                )

                Divider()
                    .padding(.leading, 44)

                LinkRow(
                    icon: "exclamationmark.bubble",
                    title: "Report Issue",
                    url: URL(string: "https://github.com/Jovines/ClipFlow/issues") ?? URL(string: "https://github.com")!
                )
            }
            .background(ThemeManager.shared.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            Text("© 2026 ClipFlow. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
    }
}

struct LinkRow: View {
    let icon: String
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(.system(size: 13))

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
