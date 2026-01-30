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
    
    var body: some View {
        Text(name)
            .font(size.font)
            .padding(size.padding)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }
    
    private var backgroundColor: Color {
        Color.fromHex(color).opacity(0.2)
    }
    
    private var foregroundColor: Color {
        Color.fromHex(color)
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
