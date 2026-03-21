import AppKit
import SwiftUI

struct AboutView: View {
    @StateObject private var themeManager = ThemeManager.shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown".localized()
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }

    private var versionText: String {
        "Version %1$@ (%2$@)".localized(appVersion, appBuild)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: themeManager.text.opacity(0.12), radius: 12, x: 0, y: 6)

                VStack(spacing: 4) {
                    Text("ClipFlow".localized())
                        .font(.system(size: 20, weight: .bold))

                    Text(versionText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)

            VStack(spacing: 0) {
                LinkRow(
                    icon: "globe",
                    title: "GitHub Repository".localized(),
                    url: URL(string: "https://github.com/Jovines/ClipFlow") ?? URL(string: "https://github.com")!
                )

                Divider()
                    .padding(.leading, 44)

                LinkRow(
                    icon: "exclamationmark.bubble",
                    title: "Report Issue".localized(),
                    url: URL(string: "https://github.com/Jovines/ClipFlow/issues") ?? URL(string: "https://github.com")!
                )

                Divider()
                    .padding(.leading, 44)

                InfoRow(
                    icon: "character.book.closed",
                    title: "Current Language".localized(),
                    value: LanguageManager.shared.currentLanguage.displayName
                )
            }
            .background(themeManager.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            Text("© 2026 ClipFlow. All rights reserved.".localized())
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

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)

            Text(title)
                .font(.system(size: 13))

            Spacer()

            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
