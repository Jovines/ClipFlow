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

enum ColorSchemeOption: String, CaseIterable, Identifiable {
    case flexoki = "Flexoki"
    case nord = "Nord"

    var id: String { rawValue }
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
    case language = "Language"
    case cache = "Cache"
    case update = "Update"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
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
    @StateObject private var languageManager = LanguageManager.shared
    @State private var showRestartAlert = false
    @State private var previousLanguage: AppLanguage = .en

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
        .alert("Shortcut Conflict".localized(), isPresented: $showConflictAlert) {
            Button("OK".localized()) {}
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
                case .language:
                    languageSettingsContent
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
                    Text("Global Shortcut".localized())
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Click to record a new shortcut".localized())
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
                .help("Set the global keyboard shortcut to show ClipFlow".localized())
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
                        Text("Appearance".localized())
                            .font(.system(size: 14, weight: .semibold))
                    }

                    VStack(spacing: 12) {
                        HStack {
                            SettingLabelWithInfo(
                                label: "Color Scheme".localized(),
                                description: "Choose the color scheme for the app".localized()
                            )
                            Spacer()
                            Picker("", selection: Binding(
                                get: { themeManager.appTheme },
                                set: { themeManager.setAppTheme($0) }
                            )) {
                                Text("Flexoki".localized()).tag(AppTheme.flexoki)
                                Text("Nord".localized()).tag(AppTheme.nord)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 140)
                        }

                        HStack {
                            SettingLabelWithInfo(
                                label: "Theme".localized(),
                                description: "Choose between light and dark mode".localized()
                            )
                            Spacer()
                            Picker("", selection: Binding(
                                get: { ThemeOption.from(themeManager.userPreference) },
                                set: { themeManager.setColorScheme($0.colorScheme) }
                            )) {
                                Text("System".localized()).tag(ThemeOption.system)
                                Text("Light".localized()).tag(ThemeOption.light)
                                Text("Dark".localized()).tag(ThemeOption.dark)
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
                    Text("History".localized())
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(spacing: 12) {
                    HStack {
                            SettingLabelWithInfo(
                                label: "Max Items".localized(),
                                description: "Maximum number of clipboard items to store".localized()
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
                                description: "Adjust the maximum number of clipboard items to store".localized()
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
                            Text("Save Images".localized())
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
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Top Recent".localized())
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(spacing: 12) {
                    HStack {
                            SettingLabelWithInfo(
                                label: "Min Usage Count".localized(),
                                description: "Number of uses before an item appears in Top Recent".localized()
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
                                label: "Score Half-Life".localized(),
                                description: "How quickly Top Recent scores decay over time".localized()
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
                    Text("Launch".localized())
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(spacing: 12) {
                    Toggle(isOn: $autoStart) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.forward.circle")
                                .font(.system(size: 12))
                            Text("Start at Login".localized())
                                .font(.system(size: 13))
                        }
                    }
                    .toggleStyle(.checkbox)

                    HStack {
                        Text("Status".localized())
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
    private var languageSettingsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Language".localized())
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Current Language".localized())
                            .font(.system(size: 13))
                        Spacer()
                        Text(LanguageManager.shared.currentLanguage.displayName)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Language".localized())
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(AppLanguage.allCases) { language in
                            Button {
                                previousLanguage = languageManager.currentLanguage
                                languageManager.setLanguage(language)
                                if language != previousLanguage {
                                    showRestartAlert = true
                                }
                            } label: {
                                HStack {
                                    Text(language.displayName)
                                        .font(.system(size: 13))

                                    Spacer()

                                    if languageManager.currentLanguage == language {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .alert("Restart Required".localized(), isPresented: $showRestartAlert) {
                    Button("OK".localized(), role: .cancel) { }
                    Button("Restart Now".localized()) {
                        NSApplication.shared.terminate(nil)
                    }
                } message: {
                    Text("Please restart ClipFlow to apply the language change.".localized())
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
            Text("Unknown".localized())
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(themeManager.surfaceElevated)
                .clipShape(Capsule())
        case .enabled:
            Text("Enabled".localized())
                .font(.system(size: 11))
                .foregroundStyle(themeManager.success)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(themeManager.success.opacity(0.15))
                .clipShape(Capsule())
        case .disabled:
            Text("Disabled".localized())
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(themeManager.surfaceElevated)
                .clipShape(Capsule())
        case .error(let message):
            Text("Error".localized())
                .font(.system(size: 11))
                .foregroundStyle(themeManager.error)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(themeManager.error.opacity(0.15))
                .clipShape(Capsule())
                .help(message)
        }
    }

    private var decayHoursText: String {
        if recommendationDecayHours >= 24 {
            let days = recommendationDecayHours / 24.0
            return String(format: "%.1f days".localized(), days)
        } else {
            return "\(Int(recommendationDecayHours)) hours".localized()
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
                conflictMessage = "Unable to register this shortcut. It may be in use by another application.".localized()
                showConflictAlert = true
            }
        } else {
            conflictMessage = "Please include at least one modifier key (Command, Shift, Control, or Option).".localized()
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
