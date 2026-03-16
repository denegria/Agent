import SwiftUI

/// Design system: colors, fonts, spacing, and gradients
enum Theme {
    // MARK: - Colors (flat access)
    
    /// Primary accent — vibrant indigo-blue
    static let accent = Color(hex: "6C5CE7")
    
    /// Warm secondary accent
    static let secondary = Color(hex: "A29BFE")
    
    /// Success / active states
    static let success = Color(hex: "00D2A0")
    
    /// Warning / attention
    static let warning = Color(hex: "FDCB6E")
    
    /// Error / destructive
    static let error = Color(hex: "FF6B6B")
    
    /// Background (dark mode base)
    static let background = Color(hex: "0D0D1A")
    
    /// Slightly elevated surface
    static let surface = Color(hex: "1A1A2E")
    
    /// Card / elevated element
    static let card = Color(hex: "16213E")
    
    /// Primary text
    static let textPrimary = Color.white
    
    /// Secondary text
    static let textSecondary = Color(hex: "A0A0B8")
    
    /// Muted text
    static let textMuted = Color(hex: "6C6C80")
    
    // MARK: - Colors (namespaced — aliases for views that use Theme.Colors.x)
    
    enum Colors {
        static let accent = Theme.accent
        static let accentSecondary = Theme.secondary
        static let background = Theme.background
        static let surface = Theme.surface
        static let card = Theme.card
        static let textPrimary = Theme.textPrimary
        static let textSecondary = Theme.textSecondary
        static let textMuted = Theme.textMuted
        static let success = Theme.success
        static let warning = Theme.warning
        static let error = Theme.error
    }
    
    // MARK: - Gradients
    
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "6C5CE7"), Color(hex: "A29BFE")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let micGradient = LinearGradient(
        colors: [Color(hex: "6C5CE7"), Color(hex: "00D2A0")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "0D0D1A"), Color(hex: "1A1A2E")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let glassGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.15),
            Color.white.opacity(0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Typography (flat access)
    
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 17, weight: .regular, design: .rounded)
    static let callout = Font.system(size: 16, weight: .regular, design: .rounded)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .rounded)
    static let footnote = Font.system(size: 13, weight: .regular, design: .rounded)
    static let caption = Font.system(size: 12, weight: .regular, design: .rounded)
    
    // MARK: - Typography (namespaced)
    
    enum Typography {
        static let largeTitle = Theme.largeTitle
        static let title = Theme.title
        static let title2 = Theme.title2
        static let headline = Theme.headline
        static let body = Theme.body
        static let callout = Theme.callout
        static let subheadline = Theme.subheadline
        static let footnote = Theme.footnote
        static let caption = Theme.caption
    }
    
    // MARK: - Spacing
    
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let spacingXXL: CGFloat = 48
    
    // MARK: - Corner Radius (flat access)
    
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 24
    static let radiusFull: CGFloat = 999
    
    // MARK: - Corner Radius (namespaced)
    
    enum CornerRadius {
        static let small: CGFloat = Theme.radiusSM
        static let medium: CGFloat = Theme.radiusMD
        static let large: CGFloat = Theme.radiusLG
        static let extraLarge: CGFloat = Theme.radiusXL
        static let full: CGFloat = Theme.radiusFull
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusLG)
                    .fill(Theme.glassGradient)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusLG)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLG)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

extension View {
    func glassBackground() -> some View {
        modifier(GlassBackground())
    }
}
