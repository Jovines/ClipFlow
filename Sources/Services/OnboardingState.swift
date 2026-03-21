import Foundation

enum OnboardingState {
    static let hasCompletedGuidedSetupKey = "hasCompletedGuidedSetup"
    static let hasOpenedClipboardHistoryOnceKey = "hasOpenedClipboardHistoryOnce"
    static let hasCapturedClipboardItemKey = "hasCapturedClipboardItem"

    static func hasCompletedSetup(isAccessibilityTrusted: Bool, defaults: UserDefaults = .standard) -> Bool {
        isAccessibilityTrusted
            && defaults.bool(forKey: hasCapturedClipboardItemKey)
            && defaults.bool(forKey: hasOpenedClipboardHistoryOnceKey)
    }

    static func setCapturedClipboardItem(_ value: Bool, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: hasCapturedClipboardItemKey)
    }
}
