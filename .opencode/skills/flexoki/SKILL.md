---
name: flexoki
description: MUST USE when user asks about colors, color scheme, Flexoki, SwiftUI styling, UI design, backgrounds, text colors, accents, borders, surfaces, or any UI appearance changes in macOS apps.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  framework: swiftui
  platform: macos
---

# Flexoki Color Scheme Integration for SwiftUI macOS Apps

## Overview
Flexoki is an inky color scheme for prose and code, inspired by analog printing inks and warm shades of paper. Use this skill to apply consistent, professional coloring to SwiftUI macOS applications.

## Flexoki Color Palette

### Base Colors (Light Theme)
| Name | Hex | Usage |
|------|-----|-------|
| Paper | `#FFFCF0` | App background |
| Base50 | `#F2F0E5` | Surface |
| Base100 | `#E6E4D9` | Elevated surface |
| Base150 | `#DAD8CE` | Subtle border |
| Base200 | `#CECDC3` | Border |
| Base600 | `#6F6E69` | Secondary text |
| Base900 | `#282726` | Primary text |

### Accent Colors
| Color | 400 (Light) | 600 (Dark) |
|-------|-------------|------------|
| Red | `#D14D41` | `#AF3029` |
| Orange | `#DA702C` | `#BC5215` |
| Yellow | `#D0A215` | `#AD8301` |
| Green | `#879A39` | `#66800B` |
| Cyan | `#3AA99F` | `#24837B` |
| Blue | `#4385BE` | `#205EA6` |
| Purple | `#8B7EC8` | `#5E409D` |
| Magenta | `#CE5D97` | `#A02F6F` |

### Semantic Mappings
```swift
flexokiBackground   // Paper - App background
flexokiSurface      // Base50 - Content surfaces
flexokiSurfaceElevated // Base100 - Elevated surfaces
flexokiBorder       // Base200 - Borders
flexokiBorderSubtle // Base150 - Subtle borders
flexokiText         // Base900 - Primary text
flexokiTextSecondary // Base600 - Secondary text
flexokiAccent       // Blue600 - Primary accent
```

## Implementation

### 1. Add Color Extension to Color+Hex.swift
```swift
import SwiftUI

extension Color {
    static func hex(_ hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
    
    // Base colors
    static let flexokiPaper = Color.hex("#FFFCF0")
    static let flexokiBase50 = Color.hex("#F2F0E5")
    static let flexokiBase100 = Color.hex("#E6E4D9")
    static let flexokiBase150 = Color.hex("#DAD8CE")
    static let flexokiBase200 = Color.hex("#CECDC3")
    static let flexokiBase600 = Color.hex("#6F6E69")
    static let flexokiBase900 = Color.hex("#282726")
    
    // Accent colors
    static let flexokiBlue600 = Color.hex("#205EA6")
    static let flexokiBlue400 = Color.hex("#4385BE")
    
    // Semantic colors
    static let flexokiBackground = flexokiPaper
    static let flexokiSurface = flexokiBase50
    static let flexokiBorder = flexokiBase200
    static let flexokiText = flexokiBase900
    static let flexokiTextSecondary = flexokiBase600
    static let flexokiAccent = flexokiBlue600
    
    // Tag colors
    static let tagRed = Color.hex("#AF3029")
    static let tagBlue = Color.hex("#205EA6")
    // ... add other accent colors
    
    static func flexokiTagColor(for name: String) -> Color {
        switch name.lowercased() {
        case "red": return tagRed
        case "blue": return tagBlue
        case "green": return Color.hex("#66800B")
        case "orange": return Color.hex("#BC5215")
        case "purple": return Color.hex("#5E409D")
        case "magenta": return Color.hex("#A02F6F")
        case "yellow": return Color.hex("#AD8301")
        case "cyan": return Color.hex("#24837B")
        default: return tagBlue
        }
    }
}
```

### 2. Update Tag Colors (ClipboardItem.swift)
```swift
static let availableColors: [(name: String, hex: String)] = [
    ("blue", "#205EA6"),
    ("green", "#66800B"),
    ("red", "#AF3029"),
    ("orange", "#BC5215"),
    ("purple", "#5E409D"),
    ("magenta", "#A02F6F"),
    ("yellow", "#AD8301"),
    ("cyan", "#24837B")
]
```

### 3. Usage Examples

#### Search Bar
```swift
HStack {
    Image(systemName: "magnifyingglass")
        .foregroundStyle(Color.flexokiTextSecondary)
    TextField("Search...", text: $text)
}
.padding(10)
.background(Color.flexokiSurface)
.clipShape(RoundedRectangle(cornerRadius: 8))
```

#### List Items with Hover
```swift
.padding(12)
.background(isHovered ? Color.flexokiAccent.opacity(0.15) : Color.clear)
.clipShape(RoundedRectangle(cornerRadius: 8))
```

#### Sidebar/Panel Background
```swift
.background(Color.flexokiSurface)
```

#### Tags
```swift
Text(tag.name)
    .font(.caption)
    .padding(.horizontal, 8, vertical: 4)
    .background(Color.flexokiTagColor(for: tag.color).opacity(0.2))
    .foregroundStyle(Color.flexokiTagColor(for: tag.color))
    .clipShape(Capsule())
```

## Color Replacement Strategy
When migrating an existing app to Flexoki:
- `Color.accentColor` → `Color.flexokiAccent`
- `.primary` → `Color.flexokiText`
- `.secondary` → `Color.flexokiTextSecondary`
- `NSColor.controlBackgroundColor` → `Color.flexokiSurface`
- `NSColor.windowBackgroundColor` → `Color.flexokiBackground`
- `NSColor.selectedContentBackgroundColor` → `Color.flexokiAccent.opacity(0.15)`

## Resources
- GitHub: https://github.com/kepano/flexoki
- Website: https://stephango.com/flexoki
