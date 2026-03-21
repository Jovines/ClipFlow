import AppKit
import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @AppStorage(FocusTodoPreferences.isEnabledKey) private var focusTodoEnabled = FocusTodoPreferences.defaultIsEnabled
    @AppStorage(OnboardingState.hasCompletedGuidedSetupKey) private var hasCompletedGuidedSetup = false
    @AppStorage(OnboardingState.hasOpenedClipboardHistoryOnceKey) private var hasOpenedClipboardHistoryOnce = false
    @AppStorage(OnboardingState.hasCapturedClipboardItemKey) private var hasCapturedClipboardItem = false
    @State private var accessibilityTrusted = AXIsProcessTrustedWithOptions(nil)

    private var hasAllSetupStepsComplete: Bool {
        accessibilityTrusted && hasCapturedClipboardItem && hasOpenedClipboardHistoryOnce
    }

    private var guidedSetupCompletionCount: Int {
        [accessibilityTrusted, hasCapturedClipboardItem, hasOpenedClipboardHistoryOnce].filter { $0 }.count
    }

    private var shortcutHint: String {
        HotKeyManager.shared.loadSavedShortcut().displayString
    }

    var body: some View {
        VStack(spacing: 0) {
            if !hasCompletedGuidedSetup {
                GuidedSetupCard(
                    hasAccessibilityPermission: accessibilityTrusted,
                    hasCopiedItem: hasCapturedClipboardItem,
                    hasOpenedHistory: hasOpenedClipboardHistoryOnce,
                    shortcutHint: shortcutHint,
                    onGrantPermission: requestAccessibilityPermission,
                    onCopyDemoText: copyDemoText,
                    onOpenHistory: openClipboardHistory,
                    onOpenSettings: openSettings,
                    onSkip: skipGuidedSetup,
                    onFinish: {
                        hasCompletedGuidedSetup = true
                    }
                )

                Divider()
                    .padding(.horizontal, 8)
                    .background(themeManager.borderSubtle)
            }

            MenuButton(
                icon: "doc.on.clipboard",
                label: "Open Clipboard History".localized(comment: "Menu item"),
                action: openClipboardHistory
            )

            MenuInfoRow(
                icon: "keyboard",
                text: "Shortcut: %1$@".localized(shortcutHint)
            )

            Divider()
                .padding(.horizontal, 8)
                .background(themeManager.borderSubtle)

            MenuButton(
                icon: "gear",
                label: "Settings".localized(comment: "Menu item"),
                action: openSettings
            )

            Divider()
                .padding(.horizontal, 8)
                .background(themeManager.borderSubtle)

            MenuButton(
                icon: focusTodoEnabled ? "checklist.checked" : "checklist",
                label: focusTodoEnabled ? "Turn Focus Todo Off".localized() : "Turn Focus Todo On".localized(),
                action: {
                    focusTodoEnabled.toggle()
                }
            )

            Divider()
                .padding(.horizontal, 8)
                .background(themeManager.borderSubtle)

            MenuButton(
                icon: "power",
                label: "Quit".localized(comment: "Menu item"),
                action: {
                    NSApplication.shared.terminate(nil)
                }
            )
        }
        .padding(.vertical, 4)
        .frame(width: 240)
        .preferredColorScheme(themeManager.colorScheme)
        .onAppear {
            refreshGuidedSetupState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshGuidedSetupState()
        }
    }

    private func openClipboardHistory() {
        hasOpenedClipboardHistoryOnce = true
        dismiss()
        if FloatingWindowManager.shared.isWindowVisible {
            FloatingWindowManager.shared.bringWindowToFront()
        } else {
            FloatingWindowManager.shared.toggleWindow()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            refreshGuidedSetupState()
        }
    }

    private func openSettings() {
        FloatingWindowManager.shared.hideWindow()
        dismiss()
        SettingsWindowManager.shared.show()
    }

    private func skipGuidedSetup() {
        hasCompletedGuidedSetup = true
    }

    private func copyDemoText() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("ClipFlow demo text".localized(), forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            hasCapturedClipboardItem = UserDefaults.standard.bool(forKey: OnboardingState.hasCapturedClipboardItemKey)
            refreshGuidedSetupState()
        }
    }

    private func requestAccessibilityPermission() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.requestAccessibilityPermissionPrompt()
            appDelegate.openAccessibilitySettings()
        } else {
            let options: [String: Bool] = ["AXTrustedCheckOptionPrompt": true]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
            if let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(settingsURL)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            refreshGuidedSetupState()
        }
    }

    private func refreshGuidedSetupState() {
        accessibilityTrusted = AXIsProcessTrustedWithOptions(nil)
        hasCapturedClipboardItem = UserDefaults.standard.bool(forKey: OnboardingState.hasCapturedClipboardItemKey)
        if hasAllSetupStepsComplete {
            hasCompletedGuidedSetup = true
        }
    }
}

struct GuidedSetupCard: View {
    let hasAccessibilityPermission: Bool
    let hasCopiedItem: Bool
    let hasOpenedHistory: Bool
    let shortcutHint: String
    let onGrantPermission: () -> Void
    let onCopyDemoText: () -> Void
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void
    let onSkip: () -> Void
    let onFinish: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    private var completedCount: Int {
        [hasAccessibilityPermission, hasCopiedItem, hasOpenedHistory].filter { $0 }.count
    }

    private var progressValue: Double {
        Double(completedCount) / 3.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("First-Time Setup".localized())
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(completedCount == 3 ? "Complete".localized() : "In Progress".localized())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(completedCount == 3 ? themeManager.success : themeManager.warning)
                Text("%1$d/3".localized(completedCount))
                    .font(.system(size: 11))
                    .foregroundStyle(themeManager.textSecondary)
            }

            ProgressView(value: progressValue)
                .tint(themeManager.accent)

            GuidedSetupStepRow(
                title: "Enable Accessibility Permission".localized(),
                subtitle: "Needed for global shortcut.".localized(),
                isDone: hasAccessibilityPermission,
                actionTitle: "Grant".localized(),
                onAction: onGrantPermission
            )

            GuidedSetupStepRow(
                title: "Copy any text once".localized(),
                subtitle: "Use any app and press copy once.".localized(),
                isDone: hasCopiedItem,
                actionTitle: "Copy Demo Text".localized(),
                onAction: onCopyDemoText
            )

            GuidedSetupStepRow(
                title: "Open history with %1$@".localized(shortcutHint),
                subtitle: "Use shortcut or menu action.".localized(),
                isDone: hasOpenedHistory,
                actionTitle: "Open Now".localized(),
                onAction: onOpenHistory
            )

            HStack(spacing: 8) {
                Button("Settings".localized(), action: onOpenSettings)
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Spacer()

                Button("Skip for now".localized(), action: onSkip)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            if completedCount == 3 {
                Button("Finish Setup".localized(), action: onFinish)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct GuidedSetupStepRow: View {
    let title: String
    let subtitle: String
    let isDone: Bool
    let actionTitle: String
    let onAction: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isDone ? Color.green : themeManager.textTertiary)
                .font(.system(size: 11))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(themeManager.textSecondary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(themeManager.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !isDone {
                Button(actionTitle, action: onAction)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help(title)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

struct MenuButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    @State private var isHovered = false
    @StateObject private var themeManager = ThemeManager.shared

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
        .background(isHovered ? themeManager.surfaceElevated : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct MenuInfoRow: View {
    let icon: String
    let text: String
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(themeManager.textSecondary)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(themeManager.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

#Preview {
    MenuBarPopoverView()
}
