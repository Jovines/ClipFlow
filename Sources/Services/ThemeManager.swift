import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let userPreferenceKey = "themeUserPreference"

    @Published var userPreference: ColorScheme? {
        didSet {
            savePreference()
            updateColorScheme()
        }
    }

    @Published var colorScheme: ColorScheme = .light

    var background: Color {
        colorScheme == .dark ? Color.flexokiBackgroundDark : Color.flexokiBackground
    }
    var surface: Color {
        colorScheme == .dark ? Color.flexokiSurfaceDark : Color.flexokiSurface
    }
    var surfaceElevated: Color {
        colorScheme == .dark ? Color.flexokiSurfaceElevatedDark : Color.flexokiSurfaceElevated
    }
    var border: Color {
        colorScheme == .dark ? Color.flexokiBorderDark : Color.flexokiBorder
    }
    var borderSubtle: Color {
        colorScheme == .dark ? Color.flexokiBorderSubtleDark : Color.flexokiBorderSubtle
    }
    var text: Color {
        colorScheme == .dark ? Color.flexokiTextDark : Color.flexokiText
    }
    var textSecondary: Color {
        colorScheme == .dark ? Color.flexokiTextSecondaryDark : Color.flexokiTextSecondary
    }
    var textTertiary: Color {
        colorScheme == .dark ? Color.flexokiTextTertiaryDark : Color.flexokiTextTertiary
    }
    var accent: Color {
        Color.flexokiAccent
    }
    var accentLight: Color {
        Color.flexokiAccentLight
    }

    private var observation: NSKeyValueObservation?

    private init() {
        loadPreference()
        updateFromSystemAppearance()
        setupAppearanceObserver()
    }

    private func loadPreference() {
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
    }

    func setColorScheme(_ scheme: ColorScheme?) {
        userPreference = scheme
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
