import SwiftUI

extension Color {
    static func hex(_ hex: String) -> Color {
        fromHex(hex)
    }

    static func fromHex(_ hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }

    static let flexokiPaper = Color.hex("#FFFCF0")
    static let flexokiPaperDark = Color.hex("#1C1B1A")
    static let flexokiBase50 = Color.hex("#F2F0E5")
    static let flexokiBase50Dark = Color.hex("#282726")
    static let flexokiBase100 = Color.hex("#E6E4D9")
    static let flexokiBase100Dark = Color.hex("#343331")
    static let flexokiBase150 = Color.hex("#DAD8CE")
    static let flexokiBase150Dark = Color.hex("#403E3C")
    static let flexokiBase200 = Color.hex("#CECDC3")
    static let flexokiBase200Dark = Color.hex("#4A4945")
    static let flexokiBase300 = Color.hex("#B7B5AC")
    static let flexokiBase300Dark = Color.hex("#575653")
    static let flexokiBase400 = Color.hex("#9F9D96")
    static let flexokiBase400Dark = Color.hex("#6F6E69")
    static let flexokiBase500 = Color.hex("#878580")
    static let flexokiBase600 = Color.hex("#6F6E69")
    static let flexokiBase600Dark = Color.hex("#9F9D96")
    static let flexokiBase700 = Color.hex("#575653")
    static let flexokiBase800 = Color.hex("#403E3C")
    static let flexokiBase850 = Color.hex("#343331")
    static let flexokiBase900 = Color.hex("#282726")
    static let flexokiBase900Dark = Color.hex("#F2F0E5")
    static let flexokiBase950 = Color.hex("#1C1B1A")
    static let flexokiBase950Dark = Color.hex("#FFFCF0")
    static let flexokiBlack = Color.hex("#100F0F")

    static let flexokiRed400 = Color.hex("#D14D41")
    static let flexokiRed600 = Color.hex("#AF3029")
    static let flexokiOrange400 = Color.hex("#DA702C")
    static let flexokiOrange600 = Color.hex("#BC5215")
    static let flexokiYellow400 = Color.hex("#D0A215")
    static let flexokiYellow600 = Color.hex("#AD8301")
    static let flexokiGreen400 = Color.hex("#879A39")
    static let flexokiGreen600 = Color.hex("#66800B")
    static let flexokiCyan400 = Color.hex("#3AA99F")
    static let flexokiCyan600 = Color.hex("#24837B")
    static let flexokiBlue400 = Color.hex("#4385BE")
    static let flexokiBlue600 = Color.hex("#205EA6")
    static let flexokiPurple400 = Color.hex("#8B7EC8")
    static let flexokiPurple600 = Color.hex("#5E409D")
    static let flexokiMagenta400 = Color.hex("#CE5D97")
    static let flexokiMagenta600 = Color.hex("#A02F6F")

    static let flexokiBackground = flexokiPaper
    static let flexokiBackgroundDark = flexokiPaperDark
    static let flexokiSurface = flexokiBase50
    static let flexokiSurfaceDark = flexokiBase50Dark
    static let flexokiSurfaceElevated = flexokiBase100
    static let flexokiSurfaceElevatedDark = flexokiBase100Dark
    static let flexokiBorder = flexokiBase200
    static let flexokiBorderDark = flexokiBase200Dark
    static let flexokiBorderSubtle = flexokiBase150
    static let flexokiBorderSubtleDark = flexokiBase150Dark
    static let flexokiText = flexokiBase900
    static let flexokiTextDark = flexokiBase900Dark
    static let flexokiTextSecondary = flexokiBase600
    static let flexokiTextSecondaryDark = flexokiBase600Dark
    static let flexokiTextTertiary = flexokiBase400
    static let flexokiTextTertiaryDark = flexokiBase400Dark
    static let flexokiAccent = flexokiBlue600
    static let flexokiAccentLight = flexokiBlue400

    static let tagRed = flexokiRed600
    static let tagOrange = flexokiOrange600
    static let tagYellow = flexokiYellow600
    static let flexokiYellow = flexokiYellow600
    static let tagGreen = flexokiGreen600
    static let tagCyan = flexokiCyan600
    static let tagBlue = flexokiBlue600
    static let tagPurple = flexokiPurple600
    static let tagMagenta = flexokiMagenta600

    static func flexokiTagColor(for name: String) -> Color {
        switch name.lowercased() {
        case "red": return tagRed
        case "orange": return tagOrange
        case "yellow": return tagYellow
        case "green": return tagGreen
        case "cyan": return tagCyan
        case "blue": return tagBlue
        case "purple": return tagPurple
        case "magenta": return tagMagenta
        default: return tagBlue
        }
    }

    static let nord0 = Color.hex("#2e3440")
    static let nord1 = Color.hex("#3b4252")
    static let nord2 = Color.hex("#434c5e")
    static let nord3 = Color.hex("#4c566a")
    static let nord4 = Color.hex("#d8dee9")
    static let nord5 = Color.hex("#e5e9f0")
    static let nord6 = Color.hex("#eceff4")
    static let nord7 = Color.hex("#8fbcbb")
    static let nord8 = Color.hex("#88c0d0")
    static let nord9 = Color.hex("#81a1c1")
    static let nord10 = Color.hex("#5e81ac")
    static let nord11 = Color.hex("#bf616a")
    static let nord12 = Color.hex("#d08770")
    static let nord13 = Color.hex("#ebcb8b")
    static let nord14 = Color.hex("#a3be8c")
    static let nord15 = Color.hex("#b48ead")

    static let nordBackground = nord0
    static let nordBackgroundLight = nord6
    static let nordSurface = nord1
    static let nordSurfaceLight = nord5
    static let nordSurfaceElevated = nord2
    static let nordSurfaceElevatedLight = nord4
    static let nordBorder = nord3
    static let nordBorderLight = nord3
    static let nordBorderSubtle = nord2
    static let nordBorderSubtleLight = nord4
    static let nordText = nord4
    static let nordTextLight = nord0
    static let nordTextSecondary = nord3
    static let nordTextSecondaryLight = nord2
    static let nordTextTertiary = nord3
    static let nordTextTertiaryLight = nord3
    static let nordAccent = nord9
    static let nordAccentLight = nord10
    static let nordCold = nord8
    static let nordFrost = nord7

    static let flexokiHoverBackground = Color.hex("#E6E4D9")
    static let flexokiHoverBackgroundDark = Color.hex("#6F6E69")
    static let flexokiSelectedBackground = Color.hex("#DAD8CE")
    static let flexokiSelectedBackgroundDark = Color.hex("#575653")
    static let flexokiActiveBackground = Color.hex("#205EA6").opacity(0.10)
    static let flexokiActiveBackgroundDark = Color.hex("#4385BE").opacity(0.15)

    static let flexokiSuccess = Color.hex("#66800B")
    static let flexokiSuccessDark = Color.hex("#879A39")
    static let flexokiError = Color.hex("#AF3029")
    static let flexokiErrorDark = Color.hex("#D14D41")
    static let flexokiWarning = Color.hex("#BC5215")
    static let flexokiWarningDark = Color.hex("#DA702C")
}

extension Color {
    static func appBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .flexokiBackgroundDark : .flexokiBackground
    }

    static func appSurface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .flexokiSurfaceDark : .flexokiSurface
    }

    static func appSurfaceElevated(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .flexokiSurfaceElevatedDark : .flexokiSurfaceElevated
    }

    static func appBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .flexokiBorderDark : .flexokiBorder
    }

    static func appBorderSubtle(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .flexokiBorderSubtleDark : .flexokiBorderSubtle
    }

    static func appText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .flexokiTextDark : .flexokiText
    }

    static func appTextSecondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .flexokiTextSecondaryDark : .flexokiTextSecondary
    }

    static func appTextTertiary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .flexokiTextTertiaryDark : .flexokiTextTertiary
    }
}

extension View {
    func appBackground(_ colorScheme: ColorScheme) -> some View {
        self.background(Color.appBackground(for: colorScheme))
    }

    func appSurface(_ colorScheme: ColorScheme) -> some View {
        self.background(Color.appSurface(for: colorScheme))
    }

    func appSurfaceElevated(_ colorScheme: ColorScheme) -> some View {
        self.background(Color.appSurfaceElevated(for: colorScheme))
    }

    func appBorder(_ colorScheme: ColorScheme) -> some View {
        self.overlay(Rectangle().fill(Color.appBorder(for: colorScheme)))
    }

    func appText(_ colorScheme: ColorScheme) -> some View {
        self.foregroundColor(Color.appText(for: colorScheme))
    }

    func appTextSecondary(_ colorScheme: ColorScheme) -> some View {
        self.foregroundColor(Color.appTextSecondary(for: colorScheme))
    }
}
