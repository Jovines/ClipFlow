// swiftlint:disable file_length
import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 100
    @AppStorage("saveImages") private var saveImages = true
    @AppStorage("autoStart") private var autoStart = false
    @AppStorage(FocusTodoPreferences.isEnabledKey) private var focusTodoEnabled = FocusTodoPreferences.defaultIsEnabled
    @AppStorage("pasteAfterSelectionEnabled") private var pasteAfterSelectionEnabled = true
    @AppStorage("recommendationDecayHours") private var recommendationDecayHours = 6.0
    @AppStorage("minUsageCountForRecommendation") private var minUsageCountForRecommendation = 2
    @AppStorage(FocusTodoPreferences.clipboardPrefillSecondsKey) private var focusTodoClipboardPrefillSeconds = FocusTodoPreferences.defaultClipboardPrefillSeconds
    @AppStorage(FocusTodoPreferences.collapsedOpacityKey) private var focusTodoCollapsedOpacity = FocusTodoPreferences.defaultCollapsedOpacity
    @AppStorage(FocusTodoPreferences.rewriteAutoFromClipboardKey) private var focusTodoRewriteAutoFromClipboard = FocusTodoPreferences.defaultRewriteAutoFromClipboard
    @AppStorage(FocusTodoPreferences.rewriteProviderIdKey) private var focusTodoRewriteProviderId = FocusTodoPreferences.defaultRewriteProviderId

    @State private var shortcut = HotKeyManager.Shortcut.defaultShortcut
    @State private var todoToggleShortcut = FocusTodoShortcutManager.Action.togglePanel.defaultShortcut
    @State private var todoPreviousShortcut = FocusTodoShortcutManager.Action.previousTask.defaultShortcut
    @State private var todoNextShortcut = FocusTodoShortcutManager.Action.nextTask.defaultShortcut
    @State private var todoDoneShortcut = FocusTodoShortcutManager.Action.markDone.defaultShortcut
    @State private var showConflictAlert = false
    @State private var conflictMessage = ""
    @State private var conflictNeedsAccessibility = false
    @State private var showActionFeedbackAlert = false
    @State private var actionFeedbackMessage = ""
    @State private var autoStartStatus: AutoStartStatus = .unknown
    @State private var selectedTab: SettingsTab = .general
    
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var aiService = OpenAIService.shared
    @State private var showRestartAlert = false
    @State private var previousLanguage: AppLanguage = .en
    @State private var accessibilityTrusted = AXIsProcessTrustedWithOptions(nil)

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 176)

            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 620, height: 500)
        .background(settingsWindowBackground)
        .alert("Shortcut Conflict".localized(), isPresented: $showConflictAlert) {
            if conflictNeedsAccessibility {
                Button("Open Accessibility Settings".localized()) {
                    requestAccessibilityPermission()
                }
            }
            Button("OK".localized()) {}
        } message: {
            Text(conflictMessage)
        }
        .alert("Done".localized(), isPresented: $showActionFeedbackAlert) {
            Button("OK".localized()) {}
        } message: {
            Text(actionFeedbackMessage)
        }
        .onAppear {
            shortcut = HotKeyManager.shared.loadSavedShortcut()
            todoToggleShortcut = FocusTodoShortcutManager.shared.shortcut(for: .togglePanel)
            todoPreviousShortcut = FocusTodoShortcutManager.shared.shortcut(for: .previousTask)
            todoNextShortcut = FocusTodoShortcutManager.shared.shortcut(for: .nextTask)
            todoDoneShortcut = FocusTodoShortcutManager.shared.shortcut(for: .markDone)
            checkAutoStartStatus()
            refreshAccessibilityStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityStatus()
        }
        .onChange(of: autoStart) { _, newValue in
            setAutoStart(newValue)
        }
        .background(
            TitleBarConfigurator()
        )
        .themeAware()
        .id(languageManager.refreshTrigger)
    }
}

extension SettingsView {
    enum AutoStartStatus {
        case unknown
        case enabled
        case disabled
        case error(String)
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
        .background(settingsSidebarBackground)
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch selectedTab {
                case .general:
                    generalSettingsContent
                case .focusTodo:
                    focusTodoSettingsContent
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
        .background(settingsWindowBackground)
    }
}

extension SettingsView {
    private var settingsWindowBackground: Color {
        themeManager.isLiquidGlassEnabled ? Color(NSColor.windowBackgroundColor) : themeManager.background
    }

    private var settingsSidebarBackground: Color {
        themeManager.isLiquidGlassEnabled ? Color(NSColor.controlBackgroundColor) : themeManager.surface
    }

    private var settingsCardBackground: Color {
        themeManager.isLiquidGlassEnabled ? Color(NSColor.controlBackgroundColor) : themeManager.surface
    }

    private var liquidGlassOpacityPercentText: String {
        "\(Int(themeManager.liquidGlassWindowOpacity * 100))%"
    }

    private var shortcutReady: Bool {
        accessibilityTrusted && HotKeyManager.shared.currentShortcut != nil
    }

    private var shortcutStatusText: String {
        if shortcutReady {
            return "Shortcut is ready".localized()
        }
        if !accessibilityTrusted {
            return "Accessibility permission needed".localized()
        }
        return "Shortcut is not active".localized()
    }
}

extension SettingsView {

    @ViewBuilder
    private func settingsSectionCard<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }

            content()
        }
        .padding(14)
        .background(settingsCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var generalSettingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsSectionCard(icon: "keyboard", title: "Global Shortcut".localized()) {
                VStack(alignment: .leading, spacing: 10) {
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

                    HStack(spacing: 8) {
                        Circle()
                            .fill(shortcutReady ? themeManager.success : themeManager.warning)
                            .frame(width: 8, height: 8)
                        Text(shortcutStatusText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Re-register Shortcut".localized()) {
                            reRegisterShortcut()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Toggle(isOn: $pasteAfterSelectionEnabled) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 12))
                            Text("Paste immediately after selection".localized())
                                .font(.system(size: 13))
                        }
                    }
                    .toggleStyle(.checkbox)

                    Text("When disabled, selecting an item only copies it to clipboard.".localized())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .help("Set the global keyboard shortcut to show ClipFlow".localized())
            }

            AccessibilityPermissionCard(
                isTrusted: accessibilityTrusted,
                cardBackground: settingsCardBackground,
                onOpenSettings: requestAccessibilityPermission
            )

            settingsSectionCard(icon: "paintbrush", title: "Appearance".localized()) {
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
                            // Theme names are technical terms and should not be localized
                            // Color scheme names like "Flexoki" and "Nord" are brand/technical names
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 240)
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

                    if themeManager.isLiquidGlassEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                SettingLabelWithInfo(
                                    label: "Floating Window Transparency".localized(),
                                    description: "Adjust the transparency of the floating window when Liquid Glass is enabled".localized()
                                )
                                Spacer()
                                Text(liquidGlassOpacityPercentText)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .frame(width: 44, alignment: .trailing)
                            }

                            Slider(value: Binding(
                                get: { themeManager.liquidGlassWindowOpacity },
                                set: { themeManager.setLiquidGlassWindowOpacity($0) }
                            ), in: ThemeManager.minLiquidGlassWindowOpacity...1.0, step: 0.05)
                            .controlSize(.small)
                        }
                    }
                }
            }

            settingsSectionCard(icon: "clock.arrow.circlepath", title: "History".localized()) {
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
            }

            settingsSectionCard(icon: "clock", title: "Suggested".localized()) {
                VStack(spacing: 12) {
                    HStack {
                        SettingLabelWithInfo(
                            label: "Min Usage Count".localized(),
                            description: "Number of uses before an item appears in Suggested".localized()
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
                            description: "How quickly Suggested scores decay over time".localized()
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
            }

            settingsSectionCard(icon: "power", title: "Launch".localized()) {
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
            }

            Spacer(minLength: 0)
        }
    }

    private var focusTodoSettingsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Feature".localized())
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(spacing: 12) {
                    Toggle(isOn: $focusTodoEnabled) {
                        HStack(spacing: 6) {
                            Image(systemName: "checklist")
                                .font(.system(size: 12))
                            Text("Enable Focus Todo Overlay".localized())
                                .font(.system(size: 13))
                        }
                    }
                    .toggleStyle(.checkbox)

                    Text("Focus Todo is off by default for new users. Turn it on anytime here.".localized())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(settingsCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Overlay Appearance".localized())
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(spacing: 12) {
                    HStack {
                        SettingLabelWithInfo(
                            label: "Collapsed Transparency".localized(),
                            description: "Adjust transparency of the collapsed Focus Todo bar.".localized()
                        )
                        Spacer()
                        Text("%1$d%%".localized(Int(focusTodoCollapsedOpacity * 100)))
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(
                        value: $focusTodoCollapsedOpacity,
                        in: 0.05...0.7,
                        step: 0.01
                    )
                    .controlSize(.small)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Collapsed Mode Gesture Guide".localized())
                            .font(.system(size: 13, weight: .medium))

                        Text("In collapsed mode, move the pointer over the Focus Todo bar and swipe on the trackpad.".localized())
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Text("Left/right switches columns, up/down switches rows.".localized())
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        FocusTodoCollapsedSwipeDemoView()
                    }
                }
                .padding(12)
                .background(settingsCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(!focusTodoEnabled)
                .opacity(focusTodoEnabled ? 1 : 0.5)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Clipboard Prefill".localized())
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(spacing: 12) {
                    HStack {
                        SettingLabelWithInfo(
                            label: "Auto-paste threshold".localized(),
                            description: "If the most recent copied text is within this many seconds when opening Focus Todo, it will prefill the task input and be selected.".localized()
                        )
                        Spacer()
                        Text("%1$d s".localized(Int(focusTodoClipboardPrefillSeconds)))
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(
                        value: $focusTodoClipboardPrefillSeconds,
                        in: 0...120,
                        step: 1
                    )
                    .controlSize(.small)

                    Text("Set to 0 to disable clipboard auto-paste.".localized())
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(settingsCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(!focusTodoEnabled)
                .opacity(focusTodoEnabled ? 1 : 0.5)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Task Rewrite".localized())
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $focusTodoRewriteAutoFromClipboard) {
                        Text("Auto rewrite copied text when Focus Todo opens".localized())
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.checkbox)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rewrite AI Service".localized())
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        Picker("Rewrite AI Service".localized(), selection: $focusTodoRewriteProviderId) {
                            Text("Follow global AI Service selection".localized())
                                .tag(FocusTodoPreferences.defaultRewriteProviderId)

                            ForEach(aiService.availableProviders.filter(\.isEnabled)) { provider in
                                Text(rewriteProviderDisplayName(provider))
                                    .tag(provider.id.uuidString)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    Text("You can choose a dedicated provider for rewrite, or follow the global AI Service selection.".localized())
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(settingsCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(!focusTodoEnabled)
                .opacity(focusTodoEnabled ? 1 : 0.5)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Focus Todo Shortcuts".localized())
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 10) {
                    shortcutSettingRow(
                        title: "Toggle Panel".localized(),
                        shortcut: Binding(
                            get: { todoToggleShortcut },
                            set: { newShortcut in
                                todoToggleShortcut = newShortcut
                                applyFocusTodoShortcut(newShortcut, action: .togglePanel)
                            }
                        )
                    )

                    shortcutSettingRow(
                        title: "Switch to Previous Task".localized(),
                        shortcut: Binding(
                            get: { todoPreviousShortcut },
                            set: { newShortcut in
                                todoPreviousShortcut = newShortcut
                                applyFocusTodoShortcut(newShortcut, action: .previousTask)
                            }
                        )
                    )

                    shortcutSettingRow(
                        title: "Switch to Next Task".localized(),
                        shortcut: Binding(
                            get: { todoNextShortcut },
                            set: { newShortcut in
                                todoNextShortcut = newShortcut
                                applyFocusTodoShortcut(newShortcut, action: .nextTask)
                            }
                        )
                    )

                    shortcutSettingRow(
                        title: "Complete Current Task".localized(),
                        shortcut: Binding(
                            get: { todoDoneShortcut },
                            set: { newShortcut in
                                todoDoneShortcut = newShortcut
                                applyFocusTodoShortcut(newShortcut, action: .markDone)
                            }
                        )
                    )
                }
                .padding(12)
                .background(settingsCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(!focusTodoEnabled)
                .opacity(focusTodoEnabled ? 1 : 0.5)
            }

            Spacer()
        }
    }
}

extension SettingsView {

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
                    Button("Quit Now".localized()) {
                        NSApplication.shared.terminate(nil)
                    }
                } message: {
                    Text("Please quit and reopen ClipFlow to apply the language change.".localized())
                }
                .padding(12)
                .background(settingsCardBackground)
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
            return "%.1f days".localized(days)
        } else {
            return "%1$d hours".localized(Int(recommendationDecayHours))
        }
    }
}

extension SettingsView {

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
        conflictNeedsAccessibility = false

        if let validationError = HotKeyManager.shared.validationError(for: newShortcut) {
            shortcut = HotKeyManager.shared.currentShortcut ?? HotKeyManager.shared.loadSavedShortcut()
            conflictMessage = validationError
            showConflictAlert = true
            return
        }

        if !AXIsProcessTrustedWithOptions(nil) {
            shortcut = HotKeyManager.shared.currentShortcut ?? HotKeyManager.shared.loadSavedShortcut()
            conflictNeedsAccessibility = true
            conflictMessage = "Accessibility permission is required to register global shortcuts.".localized()
            showConflictAlert = true
            requestAccessibilityPermission()
            return
        }

        if !HotKeyManager.shared.register(newShortcut) {
            shortcut = HotKeyManager.shared.currentShortcut ?? HotKeyManager.shared.loadSavedShortcut()
            conflictMessage = AXIsProcessTrustedWithOptions(nil)
                ? "Unable to register this shortcut. It may be in use by another application.".localized()
                : "Accessibility permission is required to register global shortcuts.".localized()
            conflictNeedsAccessibility = !AXIsProcessTrustedWithOptions(nil)
            showConflictAlert = true
        }

        refreshAccessibilityStatus()
    }

    private func reRegisterShortcut() {
        let savedShortcut = HotKeyManager.shared.loadSavedShortcut()

        guard AXIsProcessTrustedWithOptions(nil) else {
            conflictNeedsAccessibility = true
            conflictMessage = "Accessibility permission is required to register global shortcuts.".localized()
            showConflictAlert = true
            requestAccessibilityPermission()
            return
        }

        if HotKeyManager.shared.register(savedShortcut) {
            shortcut = savedShortcut
            actionFeedbackMessage = "Shortcut re-registered successfully".localized()
            showActionFeedbackAlert = true
        } else {
            conflictNeedsAccessibility = false
            conflictMessage = "Unable to register this shortcut. It may be in use by another application.".localized()
            showConflictAlert = true
        }

        refreshAccessibilityStatus()
    }

    private func refreshAccessibilityStatus() {
        accessibilityTrusted = AXIsProcessTrustedWithOptions(nil)
    }

    private func requestAccessibilityPermission() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            if !accessibilityTrusted {
                appDelegate.requestAccessibilityPermissionPrompt()
            }
            appDelegate.openAccessibilitySettings()
        } else {
            if !accessibilityTrusted {
                let options: [String: Bool] = ["AXTrustedCheckOptionPrompt": true]
                _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
            }
            if let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(settingsURL)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            refreshAccessibilityStatus()
        }
    }
    private func applyFocusTodoShortcut(_ newShortcut: HotKeyManager.Shortcut, action: FocusTodoShortcutManager.Action) {
        if let validationError = HotKeyManager.shared.validationError(for: newShortcut) {
            restoreFocusTodoShortcut(for: action)
            conflictMessage = validationError
            showConflictAlert = true
            return
        }

        if FocusTodoShortcutManager.shared.hasDuplicate(with: newShortcut, excluding: action) {
            restoreFocusTodoShortcut(for: action)
            conflictMessage = "This shortcut is already used by another Focus Todo action.".localized()
            showConflictAlert = true
            return
        }

        FocusTodoShortcutManager.shared.update(shortcut: newShortcut, for: action)
    }

    private func restoreFocusTodoShortcut(for action: FocusTodoShortcutManager.Action) {
        let savedShortcut = FocusTodoShortcutManager.shared.shortcut(for: action)
        switch action {
        case .togglePanel:
            todoToggleShortcut = savedShortcut
        case .previousTask:
            todoPreviousShortcut = savedShortcut
        case .nextTask:
            todoNextShortcut = savedShortcut
        case .markDone:
            todoDoneShortcut = savedShortcut
        }
    }

    private func rewriteProviderDisplayName(_ provider: AIProviderConfig) -> String {
        let name = provider.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let localizedName: String
        if name == "Local CLI" {
            localizedName = "Local CLI".localized
        } else {
            localizedName = name
        }

        let displayName = localizedName.isEmpty ? "Unnamed Provider".localized : localizedName
        return "\(displayName) [\(provider.providerType.displayName)]"
    }

    private func shortcutSettingRow(title: String, shortcut: Binding<HotKeyManager.Shortcut>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            Spacer()
            ShortcutRecorderView(shortcut: shortcut)
                .frame(width: 220)
        }
    }
}

#Preview {
    SettingsView()
}
