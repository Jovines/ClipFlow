import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            MenuButton(
                icon: "gear",
                label: "设置",
                action: {
                    print("[INFO] MenuBarPopoverView - 点击设置")
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
                    print("[INFO] MenuBarPopoverView - 点击退出")
                    NSApplication.shared.terminate(nil)
                }
            )
        }
        .padding(.vertical, 4)
        .frame(width: 160)
        .task {
            print("[INFO] MenuBarPopoverView - 出现，当前窗口: \(NSApp.windows.map { "\($0.title):\($0.isVisible)" })")
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
        .background(isHovered ? Color.flexokiSurface : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    MenuBarPopoverView()
}
