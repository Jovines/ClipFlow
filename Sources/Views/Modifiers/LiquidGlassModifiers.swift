import SwiftUI

// MARK: - Liquid Glass Surface

/// 为视图添加 Liquid Glass 表面效果
struct LiquidGlassSurface: ViewModifier {
    @StateObject private var themeManager = ThemeManager.shared
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = 16) {
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if themeManager.isLiquidGlassEnabled {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(themeManager.surface)
                    }
                }
            )
    }
}

// MARK: - Liquid Glass Highlight Effect

/// 为视图添加 Liquid Glass 高亮效果（用于选中/悬停状态）
struct LiquidGlassHighlight: ViewModifier {
    @StateObject private var themeManager = ThemeManager.shared
    let isActive: Bool
    let cornerRadius: CGFloat
    
    init(isActive: Bool, cornerRadius: CGFloat = 8) {
        self.isActive = isActive
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if themeManager.isLiquidGlassEnabled && isActive {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.thinMaterial.opacity(0.5))
                    } else if isActive {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(themeManager.hoverBackground)
                    } else {
                        Color.clear
                    }
                }
            )
    }
}

// MARK: - Liquid Glass Material Background

/// 为视图添加标准材质背景（适用于输入框、按钮等控件）
struct LiquidGlassMaterialBackground: ViewModifier {
    @StateObject private var themeManager = ThemeManager.shared
    let cornerRadius: CGFloat
    let material: Material
    
    init(cornerRadius: CGFloat = 12, material: Material = .ultraThinMaterial) {
        self.cornerRadius = cornerRadius
        self.material = material
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if themeManager.isLiquidGlassEnabled {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(material)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.surface)
                    }
                }
            )
    }
}

// MARK: - True Liquid Glass Effects (macOS 26+)

/// 为卡片/面板添加真正的 Liquid Glass 效果
struct LiquidGlassCardModifier: ViewModifier {
    @StateObject private var themeManager = ThemeManager.shared
    let cornerRadius: CGFloat
    let useClearVariant: Bool
    
    init(cornerRadius: CGFloat = 16, useClearVariant: Bool = true) {
        self.cornerRadius = cornerRadius
        self.useClearVariant = useClearVariant
    }
    
    func body(content: Content) -> some View {
        Group {
            if themeManager.isLiquidGlassEnabled {
                if #available(macOS 26.0, *) {
                    content
                        .glassEffect(useClearVariant ? .clear : .regular, in: .rect(cornerRadius: cornerRadius))
                } else {
                    content
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(.ultraThinMaterial)
                        )
                }
            } else {
                content
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(themeManager.surface)
                    )
            }
        }
    }
}



/// 为按钮添加 Liquid Glass 效果
struct LiquidGlassButtonModifier: ViewModifier {
    @StateObject private var themeManager = ThemeManager.shared
    let isSelected: Bool
    let cornerRadius: CGFloat
    
    init(isSelected: Bool = false, cornerRadius: CGFloat = 8) {
        self.isSelected = isSelected
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        Group {
            if themeManager.isLiquidGlassEnabled {
                if #available(macOS 26.0, *) {
                    content
                        .glassEffect(isSelected ? .regular.interactive() : .regular, in: .rect(cornerRadius: cornerRadius))
                } else {
                    content
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(isSelected ? themeManager.accent.opacity(0.2) : Color.clear)
                        )
                }
            } else {
                content
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(isSelected ? themeManager.accent : Color.clear)
                    )
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// 添加 Liquid Glass 表面效果（自动根据主题切换）
    func liquidGlassSurface(cornerRadius: CGFloat = 16) -> some View {
        modifier(LiquidGlassSurface(cornerRadius: cornerRadius))
    }
    
    /// 添加 Liquid Glass 高亮效果
    func liquidGlassHighlight(isActive: Bool, cornerRadius: CGFloat = 8) -> some View {
        modifier(LiquidGlassHighlight(isActive: isActive, cornerRadius: cornerRadius))
    }
    
    /// 添加材质背景效果
    func liquidGlassBackground(cornerRadius: CGFloat = 12, material: Material = .ultraThinMaterial) -> some View {
        modifier(LiquidGlassMaterialBackground(cornerRadius: cornerRadius, material: material))
    }
    
    /// 为卡片添加真正的 Liquid Glass 效果（macOS 26+）
    /// - Parameters:
    ///   - cornerRadius: 圆角半径
    ///   - useClearVariant: 是否使用更透明的 .clear 变体（默认 false，使用 .regular 确保可读性）
    func liquidGlassCard(cornerRadius: CGFloat = 16, useClearVariant: Bool = false) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, useClearVariant: useClearVariant))
    }
    
    /// 为按钮添加 Liquid Glass 效果（macOS 26+）
    func liquidGlassButton(isSelected: Bool = false, cornerRadius: CGFloat = 8) -> some View {
        modifier(LiquidGlassButtonModifier(isSelected: isSelected, cornerRadius: cornerRadius))
    }
}
