import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Identifiable {
    case flexoki = "Flexoki"
    case nord = "Nord"

    var id: String { rawValue }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    static let colorSchemeDidChangeNotification = Notification.Name("ThemeManagerColorSchemeDidChange")

    private static let userPreferenceKey = "themeUserPreference"
    private static let themeTypeKey = "themeType"

    @Published var userPreference: ColorScheme? {
        didSet {
            savePreference()
            updateColorScheme()
        }
    }

    @Published var appTheme: AppTheme = .flexoki {
        didSet {
            saveTheme()
            updateColorScheme()
        }
    }

    @Published var colorScheme: ColorScheme = .light

    var background: Color {
        switch appTheme {
        case .flexoki:
            colorScheme == .dark ? Color.flexokiBackgroundDark : Color.flexokiBackground
        case .nord:
            colorScheme == .dark ? Color.nordBackground : Color.nordBackgroundLight
        }
    }
    var surface: Color {
        switch appTheme {
        case .flexoki:
            colorScheme == .dark ? Color.flexokiSurfaceDark : Color.flexokiSurface
        case .nord:
            colorScheme == .dark ? Color.nordSurface : Color.nordSurfaceLight
        }
    }
    var surfaceElevated: Color {
        switch appTheme {
        case .flexoki:
            colorScheme == .dark ? Color.flexokiSurfaceElevatedDark : Color.flexokiSurfaceElevated
        case .nord:
            colorScheme == .dark ? Color.nordSurfaceElevated : Color.nordSurfaceElevatedLight
        }
    }
    var border: Color {
        switch appTheme {
        case .flexoki:
            colorScheme == .dark ? Color.flexokiBorderDark : Color.flexokiBorder
        case .nord:
            colorScheme == .dark ? Color.nordBorder : Color.nordBorderLight
        }
    }
    var borderSubtle: Color {
        switch appTheme {
        case .flexoki:
            colorScheme == .dark ? Color.flexokiBorderSubtleDark : Color.flexokiBorderSubtle
        case .nord:
            colorScheme == .dark ? Color.nordBorderSubtle : Color.nordBorderSubtleLight
        }
    }
    var text: Color {
        switch appTheme {
        case .flexoki:
            colorScheme == .dark ? Color.flexokiTextDark : Color.flexokiText
        case .nord:
            colorScheme == .dark ? Color.nordText : Color.nordTextLight
        }
    }
    var textSecondary: Color {
        switch appTheme {
        case .flexoki:
            colorScheme == .dark ? Color.flexokiTextSecondaryDark : Color.flexokiTextSecondary
        case .nord:
            colorScheme == .dark ? Color.nordTextSecondary : Color.nordTextSecondaryLight
        }
    }
    var textTertiary: Color {
        switch appTheme {
        case .flexoki:
            colorScheme == .dark ? Color.flexokiTextTertiaryDark : Color.flexokiTextTertiary
        case .nord:
            colorScheme == .dark ? Color.nordTextTertiary : Color.nordTextTertiaryLight
        }
    }
    var accent: Color {
        switch appTheme {
        case .flexoki:
            Color.flexokiAccent
        case .nord:
            Color.nordAccent
        }
    }
    var accentLight: Color {
        switch appTheme {
        case .flexoki:
            Color.flexokiAccentLight
        case .nord:
            Color.nordAccentLight
        }
    }

    private var observation: NSKeyValueObservation?

    private init() {
        loadPreference()
        updateFromSystemAppearance()
        setupAppearanceObserver()
    }

    private func loadPreference() {
        if let rawValue = UserDefaults.standard.string(forKey: Self.themeTypeKey) {
            appTheme = AppTheme(rawValue: rawValue) ?? .flexoki
        }

        guard let rawValue = UserDefaults.standard.string(forKey: Self.userPreferenceKey) else {
            userPreference = nil
            return
        }
        switch rawValue {
        case "light":
            userPreference = .light
        case "dark":
            userPreference = .dark
        default:
            userPreference = nil
        }
    }

    private func savePreference() {
        if let preference = userPreference {
            UserDefaults.standard.set(preference == .dark ? "dark" : "light", forKey: Self.userPreferenceKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.userPreferenceKey)
        }
    }

    private func saveTheme() {
        UserDefaults.standard.set(appTheme.rawValue, forKey: Self.themeTypeKey)
    }

    private func setupAppearanceObserver() {
        observation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in
                self?.updateFromSystemAppearance()
            }
        }
    }

    private func updateFromSystemAppearance() {
        guard userPreference == nil else { return }
        let appearance = NSApp.effectiveAppearance
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            colorScheme = .dark
        } else {
            colorScheme = .light
        }
    }

    private func updateColorScheme() {
        if let preference = userPreference {
            colorScheme = preference
        } else {
            updateFromSystemAppearance()
        }
        NotificationCenter.default.post(name: Self.colorSchemeDidChangeNotification, object: nil)
    }

    func setColorScheme(_ scheme: ColorScheme?) {
        userPreference = scheme
    }

    func setAppTheme(_ theme: AppTheme) {
        appTheme = theme
    }
}

struct ThemeAwareModifier: ViewModifier {
    @StateObject private var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.colorScheme)
    }
}

extension View {
    func themeAware() -> some View {
        modifier(ThemeAwareModifier())
    }
}
