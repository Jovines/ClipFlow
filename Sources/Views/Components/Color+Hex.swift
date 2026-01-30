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
    static let flexokiBase50 = Color.hex("#F2F0E5")
    static let flexokiBase100 = Color.hex("#E6E4D9")
    static let flexokiBase150 = Color.hex("#DAD8CE")
    static let flexokiBase200 = Color.hex("#CECDC3")
    static let flexokiBase300 = Color.hex("#B7B5AC")
    static let flexokiBase400 = Color.hex("#9F9D96")
    static let flexokiBase500 = Color.hex("#878580")
    static let flexokiBase600 = Color.hex("#6F6E69")
    static let flexokiBase700 = Color.hex("#575653")
    static let flexokiBase800 = Color.hex("#403E3C")
    static let flexokiBase850 = Color.hex("#343331")
    static let flexokiBase900 = Color.hex("#282726")
    static let flexokiBase950 = Color.hex("#1C1B1A")
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
    static let flexokiSurface = flexokiBase50
    static let flexokiSurfaceElevated = flexokiBase100
    static let flexokiBorder = flexokiBase200
    static let flexokiBorderSubtle = flexokiBase150
    static let flexokiText = flexokiBase900
    static let flexokiTextSecondary = flexokiBase600
    static let flexokiTextTertiary = flexokiBase400
    static let flexokiAccent = flexokiBlue600
    static let flexokiAccentLight = flexokiBlue400
    
    static let tagRed = flexokiRed600
    static let tagOrange = flexokiOrange600
    static let tagYellow = flexokiYellow600
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
}
