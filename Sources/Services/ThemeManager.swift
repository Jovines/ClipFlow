import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

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
        updateFromSystemAppearance()
        setupAppearanceObserver()
    }

    private func setupAppearanceObserver() {
        observation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in
                self?.updateFromSystemAppearance()
            }
        }
    }

    private func updateFromSystemAppearance() {
        let appearance = NSApp.effectiveAppearance
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            colorScheme = .dark
        } else {
            colorScheme = .light
        }
    }

    func toggle() {
        colorScheme = colorScheme == .dark ? .light : .dark
    }

    func setColorScheme(_ scheme: ColorScheme) {
        colorScheme = scheme
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
