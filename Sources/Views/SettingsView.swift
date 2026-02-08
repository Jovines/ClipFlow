import SwiftUI
import ServiceManagement
import AppKit

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
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.titlebarAppearsTransparent = true
                window.backgroundColor = NSColor(ThemeManager.shared.surface)
            }
        }
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case aiService = "AIService"
    case cache = "Cache"
    case update = "Update"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .aiService: return "brain"
        case .cache: return "internaldrive"
        case .update: return "arrow.clockwise.circle"
        case .about: return "info.circle"
        }
    }

    var localizedName: String {
        switch self {
        case .general: return NSLocalizedString("General", comment: "")
        case .aiService: return NSLocalizedString("AI 服务", comment: "")
        case .cache: return NSLocalizedString("Cache", comment: "")
        case .update: return NSLocalizedString("Update", comment: "")
        case .about: return NSLocalizedString("About", comment: "")
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

struct SettingsView: View {
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 100
    @AppStorage("saveImages") private var saveImages = true
    @AppStorage("autoStart") private var autoStart = false
    @AppStorage("recommendationDecayHours") private var recommendationDecayHours = 6.0
    @AppStorage("minUsageCountForRecommendation") private var minUsageCountForRecommendation = 2

    @State private var shortcut = HotKeyManager.Shortcut.defaultShortcut
    @State private var showConflictAlert = false
    @State private var conflictMessage = ""
    @State private var autoStartStatus: AutoStartStatus = .unknown
    @State private var selectedTab: SettingsTab = .general
    
    @StateObject private var themeManager = ThemeManager.shared

    enum AutoStartStatus {
        case unknown
        case enabled
        case disabled
        case error(String)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 140)
                .background(themeManager.surface)

            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 560, height: 500)
        .background(themeManager.background)
        .alert("Shortcut Conflict", isPresented: $showConflictAlert) {
            Button("OK") {}
        } message: {
            Text(conflictMessage)
        }
        .onAppear {
            checkAutoStartStatus()
        }
        .onChange(of: autoStart) { _, newValue in
            setAutoStart(newValue)
        }
        .background(
            TitleBarConfigurator()
        )
        .themeAware()
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    SidebarTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Spacer()
        }
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch selectedTab {
                case .general:
                    generalSettingsContent
                case .aiService:
                    AIProviderSettingsView()
                case .cache:
                    CacheManagementView()
                case .update:
                    UpdateSettingsView()
                case .about:
                    AboutView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(themeManager.background)
    }

    private var generalSettingsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Global Shortcut")
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Click to record a new shortcut")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ShortcutRecorderView(shortcut: Binding(
                        get: { shortcut },
                        set: { newShortcut in
                            shortcut = newShortcut
                            applyShortcut(newShortcut)
                        }
                    ))
                }
                .help("Set the global keyboard shortcut to show ClipFlow")
                .padding(12)
                .background(themeManager.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "paintbrush")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Appearance")
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(spacing: 12) {
                    HStack {
                        SettingLabelWithInfo(
                            label: "Theme",
                            description: "Choose the app theme appearance"
                        )
                        Spacer()
                        Picker("", selection: Binding(
                            get: { ThemeOption.from(themeManager.userPreference) },
                            set: { themeManager.setColorScheme($0.colorScheme) }
                        )) {
                            Text("System").tag(ThemeOption.system)
                            Text("Light").tag(ThemeOption.light)
                            Text("Dark").tag(ThemeOption.dark)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 180)
                    }
                }
                .padding(12)
                .background(themeManager.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("History")
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(spacing: 12) {
                    HStack {
                        SettingLabelWithInfo(
                            label: "Max Items",
                            description: "Maximum number of clipboard items to store"
                        )
                        Spacer()
                        Text("\(maxHistoryItems)")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }

                    HStack {
                        SettingLabelWithInfo(
                            label: "",
                            description: "Adjust the maximum number of clipboard items to store"
                        )
                        Spacer()
                    }

                    Slider(value: Binding(
                        get: { Double(maxHistoryItems) },
                        set: { maxHistoryItems = Int($0) }
                    ), in: 10...1000, step: 10)
                    .controlSize(.small)

                    Toggle(isOn: $saveImages) {
                        HStack(spacing: 6) {
                            Image(systemName: "photo")
                                .font(.system(size: 12))
                            Text("Save Images")
                                .font(.system(size: 13))
                        }
                    }
                    .toggleStyle(.checkbox)
                }
                .padding(12)
                .background(themeManager.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Recommendations")
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(spacing: 12) {
                    HStack {
                        SettingLabelWithInfo(
                            label: "Min Usage Count",
                            description: "Number of uses before an item appears in recommendations"
                        )
                        Spacer()
                        Text("\(minUsageCountForRecommendation)")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(value: Binding(
                        get: { Double(minUsageCountForRecommendation) },
                        set: { minUsageCountForRecommendation = Int($0) }
                    ), in: 1...10, step: 1)
                    .controlSize(.small)

                    HStack {
                        SettingLabelWithInfo(
                            label: "Score Half-Life",
                            description: "How quickly recommendation scores decay over time"
                        )
                        Spacer()
                        Text(decayHoursText)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(value: $recommendationDecayHours, in: 1...168, step: 1)
                        .controlSize(.small)
                }
                .padding(12)
                .background(themeManager.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Launch")
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(spacing: 12) {
                    Toggle(isOn: $autoStart) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.forward.circle")
                                .font(.system(size: 12))
                            Text("Start at Login")
                                .font(.system(size: 13))
                        }
                    }
                    .toggleStyle(.checkbox)

                    HStack {
                        Text("Status")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Spacer()
                        statusBadge
                    }
                }
                .padding(12)
                .background(themeManager.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch autoStartStatus {
        case .unknown:
            Text("Unknown")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.flexokiBase200.opacity(0.5))
                .clipShape(Capsule())
        case .enabled:
            Text("Enabled")
                .font(.system(size: 11))
                .foregroundStyle(Color.flexokiGreen600)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.flexokiGreen400.opacity(0.2))
                .clipShape(Capsule())
        case .disabled:
            Text("Disabled")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.flexokiBase200.opacity(0.5))
                .clipShape(Capsule())
        case .error(let message):
            Text("Error")
                .font(.system(size: 11))
                .foregroundStyle(Color.flexokiRed600)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.flexokiRed400.opacity(0.2))
                .clipShape(Capsule())
                .help(message)
        }
    }

    private var decayHoursText: String {
        if recommendationDecayHours >= 24 {
            let days = recommendationDecayHours / 24.0
            return String(format: "%.1f days", days)
        } else {
            return "\(Int(recommendationDecayHours)) hours"
        }
    }

    private func checkAutoStartStatus() {
        if SMAppService.mainApp.status == .enabled {
            autoStartStatus = .enabled
        } else {
            autoStartStatus = .disabled
        }
    }

    private func setAutoStart(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                autoStartStatus = .enabled
            } else {
                try SMAppService.mainApp.unregister()
                autoStartStatus = .disabled
            }
        } catch {
            autoStartStatus = .error(error.localizedDescription)
            ClipFlowLogger.error("Failed to set auto-start: \(error.localizedDescription)")
        }
    }

    private func applyShortcut(_ newShortcut: HotKeyManager.Shortcut) {
        if newShortcut.isValid && !newShortcut.modifiers.isEmpty {
            if !HotKeyManager.shared.register(newShortcut) {
                conflictMessage = "Unable to register this shortcut. It may be in use by another application."
                showConflictAlert = true
            }
        } else {
            conflictMessage = "Please include at least one modifier key (Command, Shift, Control, or Option)."
            showConflictAlert = true
        }
    }
}

struct SidebarTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    private var themeManager: ThemeManager { ThemeManager.shared }

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
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.flexokiAccent : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

#Preview {
    SettingsView()
}
