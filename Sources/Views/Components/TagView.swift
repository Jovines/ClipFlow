import SwiftUI

struct TagView: View {
    let name: String
    let color: String
    var size: TagSize = .medium
    
    enum TagSize {
        case small
        case medium
        case large
        
        var font: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .subheadline
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
            case .medium: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .large: return EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            }
        }
    }
    
    private func colorFromHex(_ hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
    
    var body: some View {
        Text(name)
            .font(size.font)
            .padding(size.padding)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }
    
    private var backgroundColor: Color {
        Color.flexokiTagColor(for: color).opacity(0.2)
    }
    
    private var foregroundColor: Color {
        Color.flexokiTagColor(for: color)
    }
}

#Preview {
    VStack(spacing: 10) {
        TagView(name: "Work", color: "#007AFF", size: .small)
        TagView(name: "Personal", color: "#34C759", size: .medium)
        TagView(name: "Important", color: "#FF3B30", size: .large)
    }
    .padding()
}
