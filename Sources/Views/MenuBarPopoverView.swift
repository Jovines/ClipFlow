import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var permissionManager = PermissionManager.shared

    var body: some View {
        VStack(spacing: 0) {
            MenuButton(
                icon: "doc.on.clipboard",
                label: "打开剪贴板",
                action: {
                    FloatingWindowManager.shared.showWindow()
                    dismiss()
                }
            )

            Divider()
                .padding(.horizontal, 8)

            MenuButton(
                icon: "keyboard",
                label: "快捷键设置",
                action: {
                    FloatingWindowManager.shared.hideWindow()
                    dismiss()
                    SettingsWindowManager.shared.show()
                }
            )

            permissionStatusSection
                .padding(.vertical, 4)

            Divider()
                .padding(.horizontal, 8)

            MenuButton(
                icon: "gear",
                label: "设置",
                action: {
                    FloatingWindowManager.shared.hideWindow()
                    dismiss()
                    SettingsWindowManager.shared.show()
                }
            )

            Divider()
                .padding(.horizontal, 8)

            MenuButton(
                icon: "power",
                label: "退出",
                action: {
                    NSApplication.shared.terminate(nil)
                }
            )
        }
        .padding(.vertical, 4)
        .frame(width: 180)
        .themeAware()
    }

    @ViewBuilder
    private var permissionStatusSection: some View {
        if !permissionManager.hasAccessibilityPermission {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text("快捷键未授权")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Button(action: {
                    permissionManager.openAccessibilityPreferences()
                    dismiss()
                }) {
                    Text("去授权")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

struct MenuButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(label)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(isHovered ? ThemeManager.shared.surface : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    MenuBarPopoverView()
}
