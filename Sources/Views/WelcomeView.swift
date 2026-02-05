import SwiftUI

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var permissionManager = PermissionManager.shared

    var onComplete: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            contentSection

            Divider()
                .padding(.horizontal, 24)

            privacySection

            Divider()
                .padding(.horizontal, 24)

            actionButtons
        }
        .frame(width: 420, height: 480)
        .themeAware()
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("欢迎使用 ClipFlow")
                .font(.system(size: 22, weight: .semibold))

            Text("macOS 菜单栏剪贴板管理工具")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 32)
        .padding(.bottom, 24)
    }

    private var contentSection: some View {
        HStack(spacing: 20) {
            featureCard(
                icon: "hand.tap",
                title: "基础功能",
                description: "点击菜单栏图标查看剪贴板历史",
                isEnabled: true
            )

            featureCard(
                icon: "keyboard",
                title: "全局快捷键",
                description: "使用 Command+Shift+V 快速唤出",
                requiresPermission: true
            )

            featureCard(
                icon: "doc.on.clipboard",
                title: "自动监控",
                description: "自动保存剪贴板内容",
                requiresPermission: true
            )
        }
        .padding(.horizontal, 24)
    }

    private func featureCard(icon: String, title: String, description: String, isEnabled: Bool = false, requiresPermission: Bool = false) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(requiresPermission ? Color.flexokiBase200 : Color.flexokiGreen400.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(requiresPermission ? Color.secondary : Color.green)
            }

            Text(title)
                .font(.system(size: 12, weight: .medium))

            Text(description)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.flexokiSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var privacySection: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 14))
                .foregroundStyle(.green)

            Text("所有数据仅存储在本地，不收集、不上传任何信息")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                permissionManager.markWelcomeShown()
                dismiss()
            }) {
                Text("仅使用基础功能")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.flexokiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Button(action: {
                permissionManager.markWelcomeShown()
                requestFullAccess()
                dismiss()
            }) {
                Text("授权并开启完整功能")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func requestFullAccess() {
        permissionManager.requestAccessibilityPermission { granted in
            if granted {
                HotKeyManager.shared.register(HotKeyManager.Shortcut.defaultShortcut)
                HotKeyManager.shared.onHotKeyPressed = {
                    FloatingWindowManager.shared.toggleWindow()
                }
            }
        }
        permissionManager.requestClipboardMonitoringConsent()
    }
}

#Preview {
    WelcomeView()
}
