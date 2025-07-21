import SwiftUI

struct ConnectionView: View {
    @ObservedObject var apiClient: AgentAPIClient
    @State private var passcode = ""
    @State private var errorMessage: String?
    @State private var showingContent = false
    @State private var logoRotation = 0.0
    @State private var gradientOffset = 0.0
    
    private let passcodeFormatter = PasscodeFormatter()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated background gradient
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.primary.opacity(0.1),
                        DesignSystem.Colors.primaryDark.opacity(0.05),
                        DesignSystem.Colors.background
                    ],
                    startPoint: UnitPoint(x: gradientOffset, y: 0),
                    endPoint: UnitPoint(x: 1 + gradientOffset, y: 1)
                )
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(
                        AnimationConstants.slowEase
                            .repeatForever(autoreverses: true)
                    ) {
                        gradientOffset = 0.5
                    }
                }
                
                // Floating particles
                ForEach(0..<5, id: \.self) { i in
                    FloatingParticle(delay: Double(i) * 0.5)
                }
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        Spacer(minLength: geometry.size.height * 0.1)
                        
                        // Hero section with animated logo
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            ZStack {
                                // Background glow
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                DesignSystem.Colors.primary.opacity(0.3),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 50
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .scaleEffect(apiClient.isConnecting ? 1.2 : 1.0)
                                    .animation(
                                        AnimationConstants.mediumSpring
                                            .repeatForever(autoreverses: true),
                                        value: apiClient.isConnecting
                                    )
                                
                                // Main logo
                                Image(systemName: "terminal.fill")
                                    .font(.system(size: 48, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primaryDark],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .rotationEffect(.degrees(logoRotation))
                                    .onAppear {
                                        withAnimation(
                                            AnimationConstants.slowSpring
                                                .delay(0.5)
                                        ) {
                                            logoRotation = 360
                                        }
                                    }
                            }
                            
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                Text("Clauder Remote")
                                    .font(DesignSystem.Typography.largeTitle)
                                    .foregroundColor(DesignSystem.Colors.label)
                                    .opacity(showingContent ? 1 : 0)
                                    .animation(
                                        AnimationConstants.mediumSpring.delay(0.3),
                                        value: showingContent
                                    )
                                
                                Text("Control Clauder on your Mac\nfrom anywhere")
                                    .font(DesignSystem.Typography.callout)
                                    .foregroundColor(DesignSystem.Colors.secondaryLabel)
                                    .multilineTextAlignment(.center)
                                    .opacity(showingContent ? 1 : 0)
                                    .animation(
                                        AnimationConstants.mediumSpring.delay(0.5),
                                        value: showingContent
                                    )
                            }
                        }
            
                        // Passcode input card
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            PasscodeInputCard(
                                passcode: $passcode,
                                isConnecting: apiClient.isConnecting,
                                errorMessage: errorMessage,
                                passcodeFormatter: passcodeFormatter
                            ) {
                                errorMessage = nil
                            }
                            .opacity(showingContent ? 1 : 0)
                            .offset(y: showingContent ? 0 : 50)
                            .animation(
                                AnimationConstants.mediumSpring.delay(0.7),
                                value: showingContent
                            )
                            
                            // Connect button
                            ConnectButton(
                                isEnabled: isConnectButtonEnabled,
                                isConnecting: apiClient.isConnecting,
                                action: connect
                            )
                            .opacity(showingContent ? 1 : 0)
                            .offset(y: showingContent ? 0 : 50)
                            .animation(
                                AnimationConstants.mediumSpring.delay(0.9),
                                value: showingContent
                            )
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
            
                        Spacer(minLength: DesignSystem.Spacing.xl)
                        
                        // Instructions card
                        InstructionCard()
                            .opacity(showingContent ? 1 : 0)
                            .offset(y: showingContent ? 0 : 30)
                            .animation(
                                AnimationConstants.mediumSpring.delay(1.1),
                                value: showingContent
                            )
                        
                        Spacer(minLength: DesignSystem.Spacing.xl)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }
        }
        .onAppear {
            showingContent = true
        }
        .onChange(of: apiClient.connectionError) { error in
            if let error = error {
                withAnimation(AnimationConstants.fastSpring) {
                    errorMessage = error.localizedDescription
                }
                
                // Haptic feedback for errors
                let impactFeedback = UINotificationFeedbackGenerator()
                impactFeedback.notificationOccurred(.error)
            }
        }
    }
            
    }
    
    private var isConnectButtonEnabled: Bool {
        !passcode.isEmpty && !apiClient.isConnecting && passcodeFormatter.isValid(passcode)
    }
    
    private func connect() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        Task {
            do {
                try await apiClient.connect(with: passcode.uppercased())
                
                // Success haptic feedback
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
            } catch {
                // Error handling is done via the onChange modifier
            }
        }
    }
}

}

// MARK: - Supporting Views

struct FloatingParticle: View {
    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 0
    let delay: Double
    
    var body: some View {
        Circle()
            .fill(DesignSystem.Colors.primary.opacity(0.1))
            .frame(width: CGFloat.random(in: 4...8))
            .position(
                x: CGFloat.random(in: 50...350),
                y: yOffset
            )
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    AnimationConstants.slowEase
                        .repeatForever(autoreverses: false)
                        .delay(delay)
                ) {
                    yOffset = -100
                    opacity = 1
                }
            }
    }
}

struct PasscodeInputCard: View {
    @Binding var passcode: String
    let isConnecting: Bool
    let errorMessage: String?
    let passcodeFormatter: PasscodeFormatter
    let onEditingChanged: () -> Void
    
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Enter Passcode")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.label)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(width: 20)
                    
                    TextField("ALPHA-TIGER-OCEAN-1234", text: $passcode)
                        .font(DesignSystem.Typography.code)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .disabled(isConnecting)
                        .focused($isFieldFocused)
                        .onChange(of: passcode) { newValue in
                            passcode = passcodeFormatter.format(newValue)
                            onEditingChanged()
                        }
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.tertiaryBackground)
                .cornerRadius(DesignSystem.CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(
                            passcodeFormatter.isValid(passcode) ? 
                                DesignSystem.Colors.success : 
                                (passcode.isEmpty ? DesignSystem.Colors.separator : DesignSystem.Colors.error),
                            lineWidth: 1
                        )
                        .animation(AnimationConstants.fastSpring, value: passcode)
                )
                
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(DesignSystem.Colors.error)
                        Text(error)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.error)
                        Spacer()
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .cardStyle()
        .onTapGesture {
            isFieldFocused = true
        }
    }
}

struct ConnectButton: View {
    let isEnabled: Bool
    let isConnecting: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if isConnecting {
                    LoadingDots()
                } else {
                    Image(systemName: "arrow.right")
                        .font(DesignSystem.Typography.headline)
                }
                
                Text(isConnecting ? "Connecting" : "Connect")
                    .font(DesignSystem.Typography.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if isEnabled {
                        LinearGradient(
                            colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        LinearGradient(
                            colors: [DesignSystem.Colors.secondary.opacity(0.3), DesignSystem.Colors.secondary.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            )
            .cornerRadius(DesignSystem.CornerRadius.lg)
            .shadow(
                color: isEnabled ? DesignSystem.Colors.primary.opacity(0.3) : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled)
    }
}

struct InstructionCard: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(DesignSystem.Colors.warning)
                Text("How to connect")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.label)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                InstructionStep(
                    number: 1,
                    title: "Run command on Mac",
                    description: "clauder quickstart",
                    icon: "terminal.fill"
                )
                
                InstructionStep(
                    number: 2,
                    title: "Copy the passcode",
                    description: "Format: WORD-WORD-WORD-1234",
                    icon: "doc.on.doc.fill"
                )
                
                InstructionStep(
                    number: 3,
                    title: "Enter and connect",
                    description: "Paste above and tap Connect",
                    icon: "link"
                )
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .cardStyle()
    }
}

struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.label)
                
                Text(description)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryLabel)
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.primary)
        }
    }
}

class PasscodeFormatter: ObservableObject {
    func format(_ input: String) -> String {
        // Remove any non-alphanumeric characters except hyphens
        let cleanInput = input.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
        
        // Split by hyphens and rejoin with proper formatting
        let parts = cleanInput.components(separatedBy: "-")
        var formattedParts: [String] = []
        
        for (index, part) in parts.enumerated() {
            if index < 3 {
                // Word parts - limit to reasonable length
                formattedParts.append(String(part.prefix(10)))
            } else if index == 3 {
                // Number part - limit to 4 digits
                let numbers = part.filter { $0.isNumber }
                formattedParts.append(String(numbers.prefix(4)))
            }
        }
        
        return formattedParts.joined(separator: "-")
    }
    
    func isValid(_ passcode: String) -> Bool {
        let regex = #"^[A-Z]+-[A-Z]+-[A-Z]+-\d{4}$"#
        return passcode.range(of: regex, options: .regularExpression) != nil
    }
}

#Preview {
    ConnectionView(apiClient: AgentAPIClient())
}