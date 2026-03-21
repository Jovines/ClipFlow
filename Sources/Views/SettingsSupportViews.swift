import AppKit
import SwiftUI

enum ThemeOption: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    static func from(_ colorScheme: ColorScheme?) -> ThemeOption {
        switch colorScheme {
        case .light: return .light
        case .dark: return .dark
        case .none: return .system
        @unknown default: return .system
        }
    }
}

struct TitleBarConfigurator: NSViewRepresentable {
    @StateObject private var themeManager = ThemeManager.shared

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            if themeManager.isLiquidGlassEnabled {
                window.titlebarAppearsTransparent = false
                window.backgroundColor = .windowBackgroundColor
            } else {
                window.titlebarAppearsTransparent = true
                window.backgroundColor = NSColor(themeManager.surface)
            }
        }
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case focusTodo = "FocusTodo"
    case aiService = "AIService"
    case language = "Language"
    case cache = "Cache"
    case update = "Update"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .focusTodo: return "checklist"
        case .aiService: return "brain"
        case .language: return "globe"
        case .cache: return "internaldrive"
        case .update: return "arrow.clockwise.circle"
        case .about: return "info.circle"
        }
    }

    var localizedName: String {
        switch self {
        case .general: return "General".localized()
        case .focusTodo: return "Focus Todo".localized()
        case .aiService: return "AI Service".localized()
        case .language: return "Language".localized()
        case .cache: return "Cache".localized()
        case .update: return "Update".localized()
        case .about: return "About".localized()
        }
    }
}

struct SettingLabelWithInfo: View {
    let label: String
    let description: String
    @State private var showPopover = false

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 13))
            Button {
                showPopover = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPopover) {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: 200)
            }
        }
    }
}

struct SidebarTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

    private var selectionBackground: Color {
        themeManager.isLiquidGlassEnabled ? Color.accentColor.opacity(0.14) : themeManager.accent
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13))
                    .frame(width: 18, height: 18)

                Text(tab.localizedName)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))

                Spacer()
            }
            .foregroundStyle(themeManager.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? selectionBackground : Color.clear)
        )
    }
}
