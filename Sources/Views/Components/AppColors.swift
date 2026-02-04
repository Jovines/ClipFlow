import SwiftUI

enum AppSurfaceColor {
    case background
    case surface
    case surfaceElevated
    case border
    case text
    case textSecondary
}

struct AppColorModifier: ViewModifier {
    let color: AppSurfaceColor

    func body(content: Content) -> some View {
        switch color {
        case .background:
            content.background(ThemeManager.shared.background)
        case .surface:
            content.background(ThemeManager.shared.surface)
        case .surfaceElevated:
            content.background(ThemeManager.shared.surfaceElevated)
        case .border:
            content.background(ThemeManager.shared.border)
        case .text:
            content.foregroundColor(ThemeManager.shared.text)
        case .textSecondary:
            content.foregroundColor(ThemeManager.shared.textSecondary)
        }
    }
}

extension View {
    func appBackground(_ color: AppSurfaceColor = .background) -> some View {
        modifier(AppColorModifier(color: color))
    }

    func appSurface(_ color: AppSurfaceColor = .surface) -> some View {
        modifier(AppColorModifier(color: color))
    }
}
