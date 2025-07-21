import SwiftUI

struct ChatView: View {
    @ObservedObject var apiClient: AgentAPIClient
    @State private var messageText = ""
    @State private var showingDisconnectAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status bar
                StatusBar(status: apiClient.status)
                
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(apiClient.messages) { message in
                                MessageRow(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: apiClient.messages.count) { _ in
                        if let lastMessage = apiClient.messages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Message input
                MessageInput(
                    text: $messageText,
                    isEnabled: apiClient.status == .stable,
                    onSend: sendMessage
                )
            }
            .navigationTitle("Clauder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Disconnect") {
                        showingDisconnectAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .alert("Disconnect", isPresented: $showingDisconnectAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect", role: .destructive) {
                apiClient.disconnect()
            }
        } message: {
            Text("Are you sure you want to disconnect from Clauder?")
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let content = messageText
        messageText = ""
        
        Task {
            do {
                try await apiClient.sendMessage(content)
            } catch {
                // TODO: Show error to user
                print("Failed to send message: \(error)")
            }
        }
    }
}

struct StatusBar: View {
    let status: AgentStatus
    
    var body: some View {
        HStack {
            Circle()
                .fill(colorForStatus)
                .frame(width: 8, height: 8)
            
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
            
            Spacer()
            
            if status == .responding {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var colorForStatus: Color {
        switch status {
        case .offline:
            return .gray
        case .stable:
            return .green
        case .responding:
            return .blue
        case .error:
            return .red
        }
    }
}

struct MessageInput: View {
    @Binding var text: String
    let isEnabled: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Type your message...", text: $text, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(!isEnabled)
                .onSubmit {
                    if canSend {
                        onSend()
                    }
                }
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(canSend ? .blue : .gray)
            }
            .disabled(!canSend)
        }
        .padding()
    }
    
    private var canSend: Bool {
        isEnabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    ChatView(apiClient: {
        let client = AgentAPIClient()
        return client
    }())
}