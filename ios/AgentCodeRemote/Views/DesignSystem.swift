import SwiftUI

// MARK: - Design System
struct DesignSystem {
    
    // MARK: - Colors
    struct Colors {
        static let primary = Color(red: 0.2, green: 0.4, blue: 1.0)
        static let primaryDark = Color(red: 0.1, green: 0.3, blue: 0.9)
        static let secondary = Color(red: 0.5, green: 0.5, blue: 0.5)
        static let success = Color(red: 0.2, green: 0.8, blue: 0.3)
        static let warning = Color(red: 1.0, green: 0.6, blue: 0.0)
        static let error = Color(red: 1.0, green: 0.3, blue: 0.3)
        
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let tertiaryBackground = Color(.tertiarySystemBackground)
        
        static let label = Color(.label)
        static let secondaryLabel = Color(.secondaryLabel)
        static let tertiaryLabel = Color(.tertiaryLabel)
        
        static let separator = Color(.separator)
        static let opaqueSeparator = Color(.opaqueSeparator)
        
        // Chat specific colors
        static let userMessageBackground = primary
        static let agentMessageBackground = Color(.systemGray5)
        static let codeBackground = Color(.systemGray6)
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
        static let title1 = Font.system(.title, design: .rounded, weight: .semibold)
        static let title2 = Font.system(.title2, design: .rounded, weight: .semibold)
        static let title3 = Font.system(.title3, design: .rounded, weight: .medium)
        static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
        static let body = Font.system(.body, design: .default, weight: .regular)
        static let bodyMedium = Font.system(.body, design: .default, weight: .medium)
        static let callout = Font.system(.callout, design: .default, weight: .regular)
        static let caption = Font.system(.caption, design: .default, weight: .regular)
        static let caption2 = Font.system(.caption2, design: .default, weight: .regular)
        static let footnote = Font.system(.footnote, design: .default, weight: .regular)
        
        // Code font
        static let code = Font.system(.body, design: .monospaced, weight: .regular)
        static let codeSmall = Font.system(.caption, design: .monospaced, weight: .regular)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let sm = (color: Color.black.opacity(0.1), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
        static let md = (color: Color.black.opacity(0.15), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let lg = (color: Color.black.opacity(0.2), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
    }
}

// MARK: - Animation Constants
struct AnimationConstants {
    static let fastSpring = Animation.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)
    static let mediumSpring = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    static let slowSpring = Animation.spring(response: 0.7, dampingFraction: 0.8, blendDuration: 0)
    
    static let fastEase = Animation.easeInOut(duration: 0.2)
    static let mediumEase = Animation.easeInOut(duration: 0.3)
    static let slowEase = Animation.easeInOut(duration: 0.5)
    
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)
}

// MARK: - Custom Modifiers
struct GlassEffect: ViewModifier {
    let intensity: Double
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(.ultraThinMaterial)
                    .opacity(intensity)
            )
    }
}

struct NeumorphicStyle: ViewModifier {
    let isPressed: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.background)
                    .shadow(
                        color: isPressed ? .clear : Color.black.opacity(0.2),
                        radius: isPressed ? 0 : 8,
                        x: isPressed ? 0 : -4,
                        y: isPressed ? 0 : -4
                    )
                    .shadow(
                        color: isPressed ? .clear : Color.white.opacity(0.7),
                        radius: isPressed ? 0 : 8,
                        x: isPressed ? 0 : 4,
                        y: isPressed ? 0 : 4
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(AnimationConstants.fastSpring, value: configuration.isPressed)
    }
}

// MARK: - View Extensions
extension View {
    func glassEffect(intensity: Double = 0.8) -> some View {
        modifier(GlassEffect(intensity: intensity))
    }
    
    func neumorphic(isPressed: Bool = false) -> some View {
        modifier(NeumorphicStyle(isPressed: isPressed))
    }
    
    func cardStyle() -> some View {
        self
            .background(DesignSystem.Colors.background)
            .cornerRadius(DesignSystem.CornerRadius.lg)
            .shadow(
                color: DesignSystem.Shadow.md.color,
                radius: DesignSystem.Shadow.md.radius,
                x: DesignSystem.Shadow.md.x,
                y: DesignSystem.Shadow.md.y
            )
    }
    
    func primaryButton() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(
                        LinearGradient(
                            colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }
    
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: style)
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - Custom Components
struct LoadingDots: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(DesignSystem.Colors.primary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.2 : 0.8)
                    .opacity(animating ? 1.0 : 0.5)
                    .animation(
                        AnimationConstants.mediumEase
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

struct PulsingOrb: View {
    @State private var isPulsing = false
    let color: Color
    let size: CGFloat
    
    init(color: Color = DesignSystem.Colors.primary, size: CGFloat = 20) {
        self.color = color
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(
                AnimationConstants.mediumSpring
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

struct FloatingActionButton: View {
    let action: () -> Void
    let icon: String
    let isEnabled: Bool
    
    init(icon: String, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.icon = icon
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isEnabled ? 
                                    [DesignSystem.Colors.primary, DesignSystem.Colors.primaryDark] :
                                    [DesignSystem.Colors.secondary.opacity(0.5), DesignSystem.Colors.secondary.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: isEnabled ? DesignSystem.Colors.primary.opacity(0.3) : Color.clear,
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
    }
}