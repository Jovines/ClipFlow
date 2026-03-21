// swiftlint:disable file_length
import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case flexoki = "Flexoki"
    case nord = "Nord"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System (Adaptive Glass)"
        case .flexoki: return "Flexoki"
        case .nord: return "Nord"
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    static let colorSchemeDidChangeNotification = Notification.Name("ThemeManagerColorSchemeDidChange")

    private static let userPreferenceKey = "themeUserPreference"
    private static let themeTypeKey = "themeType"
    private static let liquidGlassWindowOpacityKey = "liquidGlassWindowOpacity"

    static let defaultLiquidGlassWindowOpacity = 1.0
    static let minLiquidGlassWindowOpacity = 0.35

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

    @Published var liquidGlassWindowOpacity: Double = 1.0 {
        didSet {
            let clampedValue = min(max(liquidGlassWindowOpacity, Self.minLiquidGlassWindowOpacity), 1.0)
            if liquidGlassWindowOpacity != clampedValue {
                liquidGlassWindowOpacity = clampedValue
                return
            }
            saveLiquidGlassWindowOpacity()
        }
    }

@Published var colorScheme: ColorScheme = .light

    private var observation: NSKeyValueObservation?

    private init() {
        loadPreference()
        updateFromSystemAppearance()
        setupAppearanceObserver()
    }
}

extension ThemeManager {
    var isLiquidGlassEnabled: Bool {
        appTheme == .system
    }

    var background: Color {
        switch appTheme {
        case .system:
            // Liquid Glass: 使用系统材质，返回 clear
            return .clear
        case .flexoki:
            return colorScheme == .dark ? Color.flexokiBackgroundDark : Color.flexokiBackground
        case .nord:
            return colorScheme == .dark ? Color.nordBackground : Color.nordBackgroundLight
        }
    }
    var surface: Color {
        switch appTheme {
        case .system:
            return Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.07)
        case .flexoki:
            return colorScheme == .dark ? Color.flexokiSurfaceDark : Color.flexokiSurface
        case .nord:
            return colorScheme == .dark ? Color.nordSurface : Color.nordSurfaceLight
        }
    }
    var surfaceElevated: Color {
        switch appTheme {
        case .system:
            return Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.10)
        case .flexoki:
            return colorScheme == .dark ? Color.flexokiSurfaceElevatedDark : Color.flexokiSurfaceElevated
        case .nord:
            return colorScheme == .dark ? Color.nordSurfaceElevated : Color.nordSurfaceElevatedLight
        }
    }
    var border: Color {
        switch appTheme {
        case .system:
            return Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.12)
        case .flexoki:
            return colorScheme == .dark ? Color.flexokiBorderDark : Color.flexokiBorder
        case .nord:
            return colorScheme == .dark ? Color.nordBorder : Color.nordBorderLight
        }
    }
    var borderSubtle: Color {
        switch appTheme {
        case .system:
            return Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08)
        case .flexoki:
            return colorScheme == .dark ? Color.flexokiBorderSubtleDark : Color.flexokiBorderSubtle
        case .nord:
            return colorScheme == .dark ? Color.nordBorderSubtle : Color.nordBorderSubtleLight
        }
    }
    var text: Color {
        switch appTheme {
        case .system:
            return liquidGlassPrimaryForeground
        case .flexoki:
            return colorScheme == .dark ? Color.flexokiTextDark : Color.flexokiText
        case .nord:
            return colorScheme == .dark ? Color.nordText : Color.nordTextLight
        }
    }
    var textSecondary: Color {
        switch appTheme {
        case .system:
            return liquidGlassSecondaryForeground
        case .flexoki:
            return colorScheme == .dark ? Color.flexokiTextSecondaryDark : Color.flexokiTextSecondary
        case .nord:
            return colorScheme == .dark ? Color.nordTextSecondary : Color.nordTextSecondaryLight
        }
    }
    var textTertiary: Color {
        switch appTheme {
        case .system:
            return liquidGlassTertiaryForeground
        case .flexoki:
            return colorScheme == .dark ? Color.flexokiTextTertiaryDark : Color.flexokiTextTertiary
        case .nord:
            return colorScheme == .dark ? Color.nordTextTertiary : Color.nordTextTertiaryLight
        }
    }
    var accent: Color {
        switch appTheme {
        case .system:
            return .accentColor
        case .flexoki:
            return Color.flexokiAccent
        case .nord:
            return Color.nordAccent
        }
    }
    var accentLight: Color {
        switch appTheme {
        case .system:
            return .accentColor.opacity(0.8)
        case .flexoki:
            return Color.flexokiAccentLight
        case .nord:
            return Color.nordAccentLight
        }
    }

    var hoverBackground: Color {
        switch appTheme {
        case .system:
            return Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08)
        case .flexoki:
            return colorScheme == .dark ? Color.flexokiHoverBackgroundDark : Color.flexokiHoverBackground
        case .nord:
            return colorScheme == .dark ? Color.nord2 : Color.nord5
        }
    }

    var selectedBackground: Color {
        switch appTheme {
        case .system:
            return accent.opacity(colorScheme == .dark ? 0.22 : 0.16)
        case .flexoki:
            return colorScheme == .dark ? Color.flexokiSelectedBackgroundDark : Color.flexokiSelectedBackground
        case .nord:
            return colorScheme == .dark ? Color.nord1 : Color.nord6
        }
    }

    var chromeSurface: Color {
        if appTheme == .system {
            return Color.primary.opacity(colorScheme == .dark ? 0.11 : 0.08)
        }
        return surface
    }

    var chromeSurfaceElevated: Color {
        if appTheme == .system {
            return Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.11)
        }
        return surfaceElevated
    }

    var separator: Color {
        if appTheme == .system {
            return Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.10)
        }
        return borderSubtle
    }

    var activeBackground: Color {
        if appTheme == .system {
            return accent.opacity(0.15)
        }
        return colorScheme == .dark ? accent.opacity(0.15) : accent.opacity(0.10)
    }
}

extension ThemeManager {

    var iconAccent: Color {
        if appTheme == .system {
            return accent.opacity(colorScheme == .dark ? 0.88 : 0.78)
        }
        return accent
    }

    var iconWarning: Color {
        if appTheme == .system {
            return warning.opacity(colorScheme == .dark ? 0.84 : 0.72)
        }
        return warning
    }

    var iconDestructive: Color {
        if appTheme == .system {
            return error.opacity(colorScheme == .dark ? 0.86 : 0.74)
        }
        return error
    }

    var iconDestructiveMuted: Color {
        if appTheme == .system {
            return error.opacity(colorScheme == .dark ? 0.68 : 0.56)
        }
        return error.opacity(0.85)
    }

    var iconSecondary: Color {
        if appTheme == .system {
            return textSecondary.opacity(colorScheme == .dark ? 0.92 : 0.88)
        }
        return textSecondary
    }

    var iconBadgeBackground: Color {
        if appTheme == .system {
            return Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08)
        }
        return surfaceElevated.opacity(0.9)
    }

    var iconBadgeAccentBackground: Color {
        if appTheme == .system {
            return colorScheme == .dark ? accent.opacity(0.22) : accent.opacity(0.56)
        }
        return accent.opacity(colorScheme == .dark ? 0.22 : 0.14)
    }

    var iconBadgeDestructiveBackground: Color {
        if appTheme == .system {
            return colorScheme == .dark ? error.opacity(0.20) : error.opacity(0.52)
        }
        return error.opacity(colorScheme == .dark ? 0.18 : 0.12)
    }

    var iconBadgeStroke: Color {
        if appTheme == .system {
            return liquidGlassStroke
        }
        return separator.opacity(0.8)
    }

    var iconBadgeShadowOpacity: Double {
        if appTheme == .system {
            return colorScheme == .dark ? 0.08 : 0.10
        }
        return 0.08
    }

    var iconBadgeAccentForeground: Color {
        if appTheme == .system {
            return Color.white.opacity(0.96)
        }
        return .white
    }

    var iconBadgeDestructiveForeground: Color {
        if appTheme == .system {
            return Color.white.opacity(0.96)
        }
        return .white
    }

    var statusBadgeWarningBackground: Color {
        if appTheme == .system {
            return colorScheme == .dark ? warning.opacity(0.26) : warning.opacity(0.58)
        }
        return warning.opacity(colorScheme == .dark ? 0.18 : 0.12)
    }

    var statusBadgeWarningForeground: Color {
        if appTheme == .system {
            return Color.white.opacity(0.96)
        }
        return .white
    }

    private var liquidGlassPrimaryForeground: Color {
        colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.82)
    }

    private var liquidGlassSecondaryForeground: Color {
        colorScheme == .dark ? Color.white.opacity(0.74) : Color.black.opacity(0.58)
    }

    private var liquidGlassTertiaryForeground: Color {
        colorScheme == .dark ? Color.white.opacity(0.52) : Color.black.opacity(0.42)
    }

    private var liquidGlassStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    var tagTintOpacity: Double {
        if appTheme == .system {
            return colorScheme == .dark ? 0.68 : 0.56
        }
        return 1.0
    }

    var tagFillOpacity: Double {
        if appTheme == .system {
            return colorScheme == .dark ? 0.12 : 0.10
        }
        return 0.15
    }

    var success: Color {
        switch appTheme {
        case .system:
            return Color.green
        case .flexoki:
            return colorScheme == .dark ? Color.flexokiSuccessDark : Color.flexokiSuccess
        case .nord:
            return Color.nord14
        }
    }

    var error: Color {
        switch appTheme {
        case .system:
            return Color.red
        case .flexoki:
            return colorScheme == .dark ? Color.flexokiErrorDark : Color.flexokiError
        case .nord:
            return Color.nord11
        }
    }

    var warning: Color {
        switch appTheme {
        case .system:
            return Color.orange
        case .flexoki:
            return colorScheme == .dark ? Color.flexokiWarningDark : Color.flexokiWarning
        case .nord:
            return Color.nord12
        }
    }
}

extension ThemeManager {

    private func loadPreference() {
        if let rawValue = UserDefaults.standard.string(forKey: Self.themeTypeKey) {
            appTheme = AppTheme(rawValue: rawValue) ?? .flexoki
        }

        let savedOpacity = UserDefaults.standard.double(forKey: Self.liquidGlassWindowOpacityKey)
        if savedOpacity == 0 {
            liquidGlassWindowOpacity = Self.defaultLiquidGlassWindowOpacity
        } else {
            liquidGlassWindowOpacity = min(max(savedOpacity, Self.minLiquidGlassWindowOpacity), 1.0)
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

    private func saveLiquidGlassWindowOpacity() {
        UserDefaults.standard.set(liquidGlassWindowOpacity, forKey: Self.liquidGlassWindowOpacityKey)
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

    func setLiquidGlassWindowOpacity(_ opacity: Double) {
        liquidGlassWindowOpacity = opacity
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
