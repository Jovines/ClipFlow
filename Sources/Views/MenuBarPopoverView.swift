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
        .frame(width: 160)
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
