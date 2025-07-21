import SwiftUI

struct MessageRow: View {
    let message: Message
    
    var body: some View {
        ModernMessageRow(message: message, isConsecutive: false)
    }
}

struct ModernMessageRow: View {
    let message: Message
    let isConsecutive: Bool
    @State private var showingDetails = false
    @State private var hasAppeared = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                if message.isUser {
                    Spacer(minLength: 60)
                    userMessageContent
                } else {
                    agentMessageContent
                    Spacer(minLength: 60)
                }
            }
            
            // Timestamp (only show when tapped or for first message)
            if showingDetails || !isConsecutive {
                HStack {
                    if message.isUser {
                        Spacer()
                    }
                    
                    Text(timeString)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.tertiaryLabel)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    if !message.isUser {
                        Spacer()
                    }
                }
                .animation(AnimationConstants.fastSpring, value: showingDetails)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .onAppear {
            withAnimation(AnimationConstants.mediumSpring.delay(0.1)) {
                hasAppeared = true
            }
        }
        .onTapGesture {
            withAnimation(AnimationConstants.fastSpring) {
                showingDetails.toggle()
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    @ViewBuilder
    private var userMessageContent: some View {
        VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
            ModernMessageBubble(
                content: message.content,
                isUser: true,
                isConsecutive: isConsecutive
            )
            
            if message.isAgent {
                MessageStatusIndicator()
            }
        }
    }
    
    @ViewBuilder
    private var agentMessageContent: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            if !isConsecutive {
                AgentAvatar()
                    .transition(.scale.combined(with: .opacity))
            } else {
                Spacer()
                    .frame(width: 32)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                if !isConsecutive {
                    Text("Claude")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .transition(.opacity)
                }
                
                ModernMessageBubble(
                    content: message.content,
                    isUser: false,
                    isConsecutive: isConsecutive
                )
            }
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.time)
    }
}

struct ModernMessageBubble: View {
    let content: String
    let isUser: Bool
    let isConsecutive: Bool
    @State private var isPressed = false
    
    var body: some View {
        Group {
            if isCodeContent {
                CodeMessageView(content: content, isUser: isUser)
            } else {
                RegularMessageView(content: content, isUser: isUser, isConsecutive: isConsecutive)
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(AnimationConstants.fastSpring, value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
            // Handle copy functionality
            UIPasteboard.general.string = content
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
    
    private var isCodeContent: Bool {
        content.contains("```") || content.contains("`") || content.hasPrefix("Error:") || content.hasPrefix("Warning:")
    }
}

struct RegularMessageView: View {
    let content: String
    let isUser: Bool
    let isConsecutive: Bool
    
    var body: some View {
        Text(content)
            .font(DesignSystem.Typography.body)
            .foregroundColor(textColor)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(backgroundView)
            .textSelection(.enabled)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if isUser {
            RoundedRectangle(cornerRadius: bubbleCornerRadius)
                .fill(
                    LinearGradient(
                        colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(
                    color: DesignSystem.Colors.primary.opacity(0.3),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        } else {
            RoundedRectangle(cornerRadius: bubbleCornerRadius)
                .fill(DesignSystem.Colors.agentMessageBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: bubbleCornerRadius)
                        .stroke(DesignSystem.Colors.separator.opacity(0.3), lineWidth: 0.5)
                )
        }
    }
    
    private var bubbleCornerRadius: CGFloat {
        DesignSystem.CornerRadius.lg
    }
    
    private var textColor: Color {
        isUser ? .white : DesignSystem.Colors.label
    }
}

struct CodeMessageView: View {
    let content: String
    let isUser: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if content.contains("```") {
                ForEach(parseCodeBlocks(), id: \.id) { block in
                    if block.isCode {
                        CodeBlock(content: block.content, language: block.language)
                    } else {
                        Text(block.content)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(textColor)
                    }
                }
            } else {
                Text(content)
                    .font(DesignSystem.Typography.code)
                    .foregroundColor(textColor)
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.codeBackground)
                    .cornerRadius(DesignSystem.CornerRadius.md)
            }
        }
        .textSelection(.enabled)
    }
    
    private var textColor: Color {
        isUser ? .white : DesignSystem.Colors.label
    }
    
    private func parseCodeBlocks() -> [CodeBlockItem] {
        // Simple parser for code blocks
        let components = content.components(separatedBy: "```")
        var blocks: [CodeBlockItem] = []
        
        for (index, component) in components.enumerated() {
            if index % 2 == 0 {
                // Regular text
                if !component.isEmpty {
                    blocks.append(CodeBlockItem(id: UUID(), content: component, isCode: false))
                }
            } else {
                // Code block
                let lines = component.components(separatedBy: "\n")
                let language = lines.first ?? ""
                let code = lines.dropFirst().joined(separator: "\n")
                blocks.append(CodeBlockItem(id: UUID(), content: code, isCode: true, language: language))
            }
        }
        
        return blocks
    }
}

struct CodeBlockItem {
    let id: UUID
    let content: String
    let isCode: Bool
    let language: String?
    
    init(id: UUID, content: String, isCode: Bool, language: String? = nil) {
        self.id = id
        self.content = content
        self.isCode = isCode
        self.language = language
    }
}

struct CodeBlock: View {
    let content: String
    let language: String?
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Code header
            HStack {
                if let language = language, !language.isEmpty {
                    Text(language)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryLabel)
                }
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = content
                    withAnimation(AnimationConstants.fastSpring) {
                        copied = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(AnimationConstants.fastSpring) {
                            copied = false
                        }
                    }
                    
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied!" : "Copy")
                    }
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.primary)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.tertiaryBackground)
            
            // Code content
            ScrollView(.horizontal) {
                Text(content)
                    .font(DesignSystem.Typography.code)
                    .foregroundColor(DesignSystem.Colors.label)
                    .padding(DesignSystem.Spacing.md)
            }
            .background(DesignSystem.Colors.codeBackground)
        }
        .cornerRadius(DesignSystem.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(DesignSystem.Colors.separator.opacity(0.3), lineWidth: 0.5)
        )
    }
}

struct AgentAvatar: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [DesignSystem.Colors.primary.opacity(0.8), DesignSystem.Colors.primaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
            
            Image(systemName: "brain")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

struct MessageStatusIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(DesignSystem.Colors.success)
                    .frame(width: 4, height: 4)
                    .scaleEffect(animating ? 1.2 : 1.0)
                    .animation(
                        AnimationConstants.fastSpring
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

// Legacy MessageBubble for backward compatibility
struct MessageBubble: View {
    let content: String
    let isUser: Bool
    
    var body: some View {
        ModernMessageBubble(
            content: content,
            isUser: isUser,
            isConsecutive: false
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        ModernMessageRow(
            message: Message(
                id: "1",
                role: "user",
                content: "Hello, can you help me with my code?",
                time: Date()
            ),
            isConsecutive: false
        )
        
        ModernMessageRow(
            message: Message(
                id: "2",
                role: "agent",
                content: "Of course! I'd be happy to help you with your code. Here's a simple example:\n\n```swift\nfunc greet(name: String) {\n    print(\"Hello, \\(name)!\")\n}\n```\n\nWhat specific issue are you working on?",
                time: Date()
            ),
            isConsecutive: false
        )
        
        ModernMessageRow(
            message: Message(
                id: "3",
                role: "agent",
                content: "I can also help with debugging and code reviews.",
                time: Date()
            ),
            isConsecutive: true
        )
    }
    .padding()
    .background(DesignSystem.Colors.background)
}