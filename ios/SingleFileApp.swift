// Single file version of Claude Code Remote
// Copy this into a new Xcode project to get started quickly

import SwiftUI

// @main - Commented out to avoid conflicts with main app
struct SingleFileAgentCodeRemoteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var passcode = ""
    @State private var isConnected = false
    @State private var showingSplash = true
    
    var body: some View {
        ZStack {
            if showingSplash {
                SplashView()
                    .transition(.opacity)
            } else if isConnected {
                ChatView()
            } else {
                ConnectionView(passcode: $passcode, isConnected: $isConnected)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showingSplash = false
                }
            }
        }
    }
}

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoRotation: Double = 0
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.1), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(logoScale)
                    .rotationEffect(.degrees(logoRotation))
                
                VStack(spacing: 8) {
                    Text("Clauder Remote")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Control Clauder from anywhere")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                logoScale = 1.0
            }
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.5)) {
                logoRotation = 360
            }
        }
    }
}

struct ConnectionView: View {
    @Binding var passcode: String
    @Binding var isConnected: Bool
    @State private var showContent = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.5)
                
                Text("Clauder Remote")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .opacity(showContent ? 1 : 0)
                
                Text("Enter the passcode from your Mac")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1 : 0)
            }
            
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Passcode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("ALPHA-TIGER-OCEAN-1234", text: $passcode)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.horizontal)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 50)
                
                Button("Connect") {
                    withAnimation(.spring()) {
                        isConnected = true
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(passcode.isEmpty)
                .opacity(passcode.isEmpty ? 0.6 : 1.0)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 50)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Text("How to connect:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("1.")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Run 'clauder quickstart' on your Mac")
                    }
                    HStack {
                        Text("2.")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Copy the generated passcode")
                    }
                    HStack {
                        Text("3.")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Enter it above and tap Connect")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                showContent = true
            }
        }
    }
}

struct ChatView: View {
    @State private var messages: [String] = [
        "Hello! I'm connected to Clauder on your Mac.",
        "You can now send commands and code directly from your iPhone!",
        "Try typing a message below to get started."
    ]
    @State private var newMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Status bar
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Connected")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                
                // Messages
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                            HStack {
                                if index % 2 == 0 {
                                    MessageBubble(text: message, isUser: false)
                                    Spacer(minLength: 50)
                                } else {
                                    Spacer(minLength: 50)
                                    MessageBubble(text: message, isUser: true)
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                // Input
                HStack {
                    TextField("Type your message...", text: $newMessage)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Send") {
                        if !newMessage.isEmpty {
                            withAnimation(.spring()) {
                                messages.append(newMessage)
                                newMessage = ""
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(newMessage.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Clauder")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MessageBubble: View {
    let text: String
    let isUser: Bool
    
    var body: some View {
        Text(text)
            .padding()
            .background(isUser ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isUser ? .white : .primary)
            .cornerRadius(16)
    }
}

#Preview {
    ContentView()
}