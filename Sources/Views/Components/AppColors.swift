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
    @Environment(\.colorScheme) private var colorScheme
    let color: AppSurfaceColor

    func body(content: Content) -> some View {
        switch color {
        case .background:
            content.background(Color.appBackground(for: colorScheme))
        case .surface:
            content.background(Color.appSurface(for: colorScheme))
        case .surfaceElevated:
            content.background(Color.appSurfaceElevated(for: colorScheme))
        case .border:
            content.background(Color.appBorder(for: colorScheme))
        case .text:
            content.foregroundColor(Color.appText(for: colorScheme))
        case .textSecondary:
            content.foregroundColor(Color.appTextSecondary(for: colorScheme))
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
