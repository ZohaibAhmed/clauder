// Claude Code Remote - Complete iOS App with Real Networking
import SwiftUI
import Foundation
import Combine

@main
struct AgentCodeRemoteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Models

struct Session: Codable {
    let passcode: String
    let tunnelURL: String
    let token: String
    let connectedAt: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(connectedAt) > 86400 // 24 hours
    }
}

struct CoordinatorResponse: Codable {
    let tunnel_url: String
    let token: String
}

struct CoordinatorError: Codable {
    let error: String
}

struct AgentMessage: Identifiable {
    let id = UUID()
    let content: String
    let type: MessageType
    let timestamp: Date
    
    enum MessageType: String {
        case user = "user"
        case agent = "agent"
    }
}

struct MessageRequest: Codable {
    let content: String
    let type: String
}

// MARK: - API Client

class AgentAPIClient: ObservableObject {
    @Published var messages: [AgentMessage] = []
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var connectionError: String?
    @Published var isLoading = false
    
    private var session: Session?
    private var eventSource: URLSessionDataTask?
    private var cancellables = Set<AnyCancellable>()
    private var pollingTimer: Timer?
    private var lastMessageCount = 0
    private var lastMessageContents: [String] = [] // Track content changes
    
    private let coordinatorURL = "https://claude-code-coordinator.team-ad9.workers.dev"
    
    func connect(with passcode: String) async {
        await MainActor.run {
            isConnecting = true
            connectionError = nil
        }
        
        do {
            // 1. Look up session from coordinator
            let session = try await lookupSession(passcode: passcode)
            
            // 2. Test connection to tunnel
            try await testConnection(session: session)
            
            // 3. Fetch initial messages
            try await fetchMessages(session: session)
            
            // 4. Connect to event stream
            await connectEventSource(session: session)
            
            // 5. Start polling fallback (in case SSE doesn't work)
            startPollingFallback(session: session)
            
            // 6. Save session and update UI
            await MainActor.run {
                self.session = session
                self.isConnected = true
                self.isConnecting = false
            }
            
        } catch {
            await MainActor.run {
                self.connectionError = error.localizedDescription
                self.isConnecting = false
            }
        }
    }
    
    private func lookupSession(passcode: String) async throws -> Session {
        let url = URL(string: "\(coordinatorURL)/lookup/\(passcode)")!
        print("🔍 Looking up passcode: \(passcode)")
        print("🌐 Coordinator URL: \(url)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0  // 10 second timeout
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 404 {
            let error = try JSONDecoder().decode(CoordinatorError.self, from: data)
            throw APIError.invalidPasscode(error.error)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.networkError("HTTP \(httpResponse.statusCode)")
        }
        
        let coordinatorResponse = try JSONDecoder().decode(CoordinatorResponse.self, from: data)
        
        print("✅ Session found:")
        print("   Tunnel URL: \(coordinatorResponse.tunnel_url)")
        print("   Token: \(coordinatorResponse.token.prefix(16))...")
        
        return Session(
            passcode: passcode,
            tunnelURL: coordinatorResponse.tunnel_url,
            token: coordinatorResponse.token,
            connectedAt: Date()
        )
    }
    
    private func testConnection(session: Session) async throws {
        let url = URL(string: "\(session.tunnelURL)/health")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.connectionFailed
        }
    }
    
    private func fetchMessages(session: Session) async throws {
        let url = URL(string: "\(session.tunnelURL)/messages")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.messagesFetchFailed
        }
        
        // Parse existing messages from the response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let messagesArray = json["messages"] as? [[String: Any]] {
            
            var fetchedMessages: [AgentMessage] = []
            
            for messageData in messagesArray {
                if let content = messageData["content"] as? String,
                   let role = messageData["role"] as? String {
                    
                    let messageType: AgentMessage.MessageType = role == "user" ? .user : .agent
                    let message = AgentMessage(content: content, type: messageType, timestamp: Date())
                    fetchedMessages.append(message)
                }
            }
            
            await MainActor.run {
                self.messages = fetchedMessages
                print("📥 Loaded \(fetchedMessages.count) existing messages")
            }
        } else {
            // If no messages or parsing fails, start with empty
            await MainActor.run {
                self.messages = []
                print("📥 No existing messages found")
            }
        }
    }
    
    func sendMessage(_ content: String) async throws {
        guard let session = session else { throw APIError.notConnected }
        
        await MainActor.run {
            isLoading = true
        }
        
        // Add user message immediately
        let userMessage = AgentMessage(content: content, type: .user, timestamp: Date())
        await MainActor.run {
            messages.append(userMessage)
        }
        
        do {
            let url = URL(string: "\(session.tunnelURL)/message")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body = MessageRequest(content: content, type: "user")
            request.httpBody = try JSONEncoder().encode(body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw APIError.sendFailed
            }
            
        } catch {
            // Remove the message we added optimistically
            await MainActor.run {
                if let index = messages.firstIndex(where: { $0.content == content && $0.type == .user }) {
                    messages.remove(at: index)
                }
            }
            throw error
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    func sendSpecialKey(_ key: String) async throws {
        guard let session = session else { throw APIError.notConnected }
        
        print("🔑 Sending special key: \(key)")
        
        do {
            let url = URL(string: "\(session.tunnelURL)/message")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Map special keys to terminal escape sequences
            let keystroke = mapSpecialKey(key)
            
            // Use type "raw" for keystrokes (not saved in conversation history)
            let body = MessageRequest(content: keystroke, type: "raw")
            request.httpBody = try JSONEncoder().encode(body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                if let httpResponse = response as? HTTPURLResponse {
                    print("❌ Keystroke failed: HTTP \(httpResponse.statusCode)")
                } else {
                    print("❌ Keystroke failed: Invalid response")
                }
                throw APIError.sendFailed
            }
            
            print("✅ Special key sent successfully")
            
        } catch {
            print("❌ Failed to send special key: \(error)")
            throw error
        }
    }
    
    private func mapSpecialKey(_ key: String) -> String {
        switch key {
        case "ArrowUp": return "\u{1B}[A"
        case "ArrowDown": return "\u{1B}[B"
        case "ArrowRight": return "\u{1B}[C"
        case "ArrowLeft": return "\u{1B}[D"
        case "Enter": return "\r"
        case "Escape": return "\u{1B}"
        case "1", "2", "3": return key
        default: return key
        }
    }
    
    private func connectEventSource(session: Session) async {
        let url = URL(string: "\(session.tunnelURL)/events")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.timeoutInterval = 0 // No timeout for SSE
        
        print("🔗 Connecting to SSE: \(url)")
        
        // Use a custom URLSession for SSE with streaming
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 0
        config.timeoutIntervalForResource = 0
        let sseSession = URLSession(configuration: config)
        
        eventSource = sseSession.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ SSE Error: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 SSE Response Status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    print("❌ SSE: Non-200 status code")
                    return
                }
            }
            
            guard let data = data else {
                print("⚠️ SSE: No data received")
                return
            }
            
            if let eventString = String(data: data, encoding: .utf8) {
                print("📨 SSE Data Received (\(data.count) bytes): \(eventString)")
                self?.handleServerSentEvent(eventString)
            }
        }
        
        eventSource?.resume()
        print("✅ SSE connection started")
    }
    
    private func handleServerSentEvent(_ eventString: String) {
        print("🔍 Parsing SSE: \(eventString)")
        
        // Parse SSE format: "event: message_update\ndata: {...}\n\n"
        let lines = eventString.components(separatedBy: "\n")
        var eventType: String?
        
        for line in lines {
            if line.hasPrefix("event: ") {
                eventType = String(line.dropFirst(7)) // Remove "event: "
                print("📋 SSE Event Type: \(eventType ?? "nil")")
            } else if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6)) // Remove "data: "
                print("📦 SSE Data: \(jsonString)")
                
                if let data = jsonString.data(using: .utf8) {
                    do {
                        // Parse AgentAPI message format
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("✅ Parsed JSON: \(json)")
                            
                            if eventType == "message_update",
                               let messageContent = json["message"] as? String,
                               let role = json["role"] as? String {
                                
                                print("🎯 Found message - Role: \(role), Content: \(messageContent.prefix(50))...")
                                
                                let messageType: AgentMessage.MessageType = role == "user" ? .user : .agent
                                let message = AgentMessage(content: messageContent, type: messageType, timestamp: Date())
                                
                                DispatchQueue.main.async {
                                    // Only add agent messages (user messages are added immediately when sent)
                                    if messageType == .agent {
                                        // Check if we already have this message to avoid duplicates
                                        if !self.messages.contains(where: { $0.content == messageContent && $0.type == .agent }) {
                                            print("➕ Adding agent message to UI")
                                            self.messages.append(message)
                                        } else {
                                            print("⚠️ Duplicate agent message, skipping")
                                        }
                                    }
                                }
                            } else {
                                print("❌ SSE: Missing required fields or wrong event type")
                                print("   Event Type: \(eventType ?? "nil")")
                                print("   Has message: \(json["message"] != nil)")
                                print("   Has role: \(json["role"] != nil)")
                            }
                        }
                    } catch {
                        print("❌ Failed to parse SSE JSON: \(error)")
                    }
                }
            }
        }
    }
    
    private func startPollingFallback(session: Session) {
        print("🔄 Starting polling fallback every 1 second")
        
        // Ensure timer runs on main thread
        DispatchQueue.main.async { [weak self] in
            self?.pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                print("⏰ Timer fired - polling for messages")
                Task { @MainActor in
                    await self?.pollForNewMessages(session: session)
                }
            }
        }
    }
    
    private func pollForNewMessages(session: Session) async {
        do {
            let url = URL(string: "\(session.tunnelURL)/messages")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
            
            print("🔄 Polling messages from: \(url)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Polling response status: \(httpResponse.statusCode)")
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let messagesArray = json["messages"] as? [[String: Any]] {
                
                // Extract current message contents for comparison
                let currentContents = messagesArray.compactMap { messageData -> String? in
                    guard let content = messageData["content"] as? String else { return nil }
                    return content
                }
                
                print("📝 Total messages in API: \(messagesArray.count), Last count: \(lastMessageCount)")
                
                // Check if anything changed (count or content)
                let countChanged = messagesArray.count != self.lastMessageCount
                let contentChanged = currentContents != self.lastMessageContents
                
                if countChanged || contentChanged {
                    print("🔄 Changes detected - Count: \(countChanged), Content: \(contentChanged)")
                    
                    await MainActor.run {
                        // Rebuild entire message list to ensure latest content
                        var newMessages: [AgentMessage] = []
                        
                        for (index, messageData) in messagesArray.enumerated() {
                            if let content = messageData["content"] as? String,
                               let role = messageData["role"] as? String {
                                
                                print("📋 Processing message \(index): role=\(role), content=\(content.prefix(50))...")
                                
                                let messageType: AgentMessage.MessageType = role == "user" ? .user : .agent
                                let message = AgentMessage(content: content, type: messageType, timestamp: Date())
                                newMessages.append(message)
                            }
                        }
                        
                        print("🔄 Updating UI with \(newMessages.count) messages")
                        self.messages = newMessages
                        self.lastMessageCount = messagesArray.count
                        self.lastMessageContents = currentContents
                    }
                } else {
                    print("📊 No changes detected")
                }
            } else {
                print("❌ Failed to parse messages JSON")
                print("📄 Raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
            }
        } catch {
            print("❌ Polling error: \(error)")
        }
    }
    
    func testPoll() async {
        guard let session = session else {
            print("❌ No session available for test poll")
            return
        }
        print("🧪 Manual test poll triggered")
        await pollForNewMessages(session: session)
    }
    
    func disconnect() {
        eventSource?.cancel()
        eventSource = nil
        pollingTimer?.invalidate()
        pollingTimer = nil
        session = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.messages = []
            self.lastMessageCount = 0
            self.lastMessageContents = []
        }
    }
}

// MARK: - Error Types

enum APIError: LocalizedError {
    case invalidPasscode(String)
    case connectionFailed
    case networkError(String)
    case invalidResponse
    case notConnected
    case sendFailed
    case messagesFetchFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidPasscode(let message):
            return message
        case .connectionFailed:
            return "Failed to connect to Claude Code"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid server response"
        case .notConnected:
            return "Not connected to Claude Code"
        case .sendFailed:
            return "Failed to send message"
        case .messagesFetchFailed:
            return "Failed to fetch messages"
        }
    }
}

// MARK: - Views

struct ContentView: View {
    @StateObject private var apiClient = AgentAPIClient()
    @State private var showingSplash = true
    
    var body: some View {
        ZStack {
            if showingSplash {
                SplashView()
                    .transition(.opacity)
            } else if apiClient.isConnected {
                ChatView(apiClient: apiClient)
            } else {
                ConnectionView(apiClient: apiClient)
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
    @State private var logoOpacity: Double = 0
    @State private var textOffset: CGFloat = 30
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.16),
                    Color(red: 0.12, green: 0.12, blue: 0.25),
                    Color(red: 0.18, green: 0.18, blue: 0.35)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()
            
            // Subtle animated background elements
            Circle()
                .fill(LinearGradient(colors: [.blue.opacity(0.1), .clear], startPoint: .center, endPoint: .trailing))
                .frame(width: 300, height: 300)
                .offset(x: -100, y: -200)
                .blur(radius: 50)
            
            Circle()
                .fill(LinearGradient(colors: [.purple.opacity(0.08), .clear], startPoint: .center, endPoint: .trailing))
                .frame(width: 200, height: 200)
                .offset(x: 150, y: 200)
                .blur(radius: 40)
            
            VStack(spacing: 32) {
                // Modern logo design
                ZStack {
                    // Background circle
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 120, height: 120)
                        .blur(radius: 1)
                    
                    // Logo icon
                    Image(systemName: "command.circle.fill")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                
                VStack(spacing: 12) {
                    Text("Clauder")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .offset(y: textOffset)
                        .opacity(logoOpacity)
                    
                    Text("Remote coding companion")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .offset(y: textOffset)
                        .opacity(logoOpacity)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
                textOffset = 0
            }
        }
    }
}

// Simple ConnectionView that uses proper DesignSystem colors
struct ConnectionView: View {
    @ObservedObject var apiClient: AgentAPIClient
    @State private var passcode = ""
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
                    .foregroundColor(Color(.label))  // System color that adapts
                    .opacity(showContent ? 1 : 0)
                
                Text("Enter the passcode from your Mac")
                    .font(.subheadline)
                    .foregroundColor(Color(.secondaryLabel))  // System color that adapts
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1 : 0)
            }
            
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Passcode")
                        .font(.caption)
                        .foregroundColor(Color(.secondaryLabel))
                    
                    TextField("ALPHA-TIGER-OCEAN-1234", text: $passcode)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                        .disabled(apiClient.isConnecting)
                }
                .padding(.horizontal)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 50)
                
                // Error message
                if let error = apiClient.connectionError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .transition(.slide.combined(with: .opacity))
                }
                
                Button("Connect") {
                    connect()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: passcode.isEmpty || apiClient.isConnecting ? 
                            [Color.gray.opacity(0.6)] : 
                            [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(passcode.isEmpty || apiClient.isConnecting)
                .opacity(passcode.isEmpty ? 0.6 : 1.0)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 50)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Text("How to connect:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.secondaryLabel))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("1.")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Run 'clauder quickstart' on your Mac")
                            .foregroundColor(Color(.label))
                    }
                    HStack {
                        Text("2.")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Copy the generated passcode")
                            .foregroundColor(Color(.label))
                    }
                    HStack {
                        Text("3.")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Enter it above and tap Connect")
                            .foregroundColor(Color(.label))
                    }
                }
                .font(.caption)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .opacity(showContent ? 1 : 0)
        }
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                showContent = true
            }
        }
    }
    
    private func connect() {
        Task {
            await apiClient.connect(with: passcode.uppercased())
        }
    }
}

struct ChatView: View {
    @ObservedObject var apiClient: AgentAPIClient
    @State private var newMessage = ""
    @State private var sendingKey: String? = nil
    @State private var showContent = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // System background that adapts to light/dark mode
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Modern status bar
                    HStack(spacing: 12) {
                        // Connection indicator
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.2))
                                    .frame(width: 16, height: 16)
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                            }
                            
                            Text("Connected")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(.label))
                        }
                        
                        Spacer()
                        
                        // Action buttons
                        HStack(spacing: 8) {
                            Button(action: {
                                Task {
                                    await apiClient.testPoll()
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(width: 32, height: 32)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            Button(action: {
                                apiClient.disconnect()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)
                                    .frame(width: 32, height: 32)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                
                    // Messages area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                if apiClient.messages.isEmpty {
                                    VStack(spacing: 24) {
                                        Spacer(minLength: 80)
                                        
                                        // Welcome state
                                        ZStack {
                                            Circle()
                                                .fill(LinearGradient(
                                                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ))
                                                .frame(width: 80, height: 80)
                                            
                                            Image(systemName: "command.circle.fill")
                                                .font(.system(size: 40, weight: .light))
                                                .foregroundStyle(
                                                    LinearGradient(
                                                        colors: [.blue, .purple],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        }
                                        .scaleEffect(showContent ? 1 : 0.8)
                                        .opacity(showContent ? 1 : 0)
                                        
                                        VStack(spacing: 12) {
                                            Text("Ready to Code!")
                                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                                .foregroundColor(Color(.label))
                                            
                                            Text("Clauder is connected and ready to help.\nSend a message or use the controls below.")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(Color(.secondaryLabel))
                                                .multilineTextAlignment(.center)
                                                .lineSpacing(4)
                                        }
                                        .opacity(showContent ? 1 : 0)
                                        .offset(y: showContent ? 0 : 20)
                                        
                                        Spacer(minLength: 80)
                                    }
                                } else {
                                    ForEach(apiClient.messages) { message in
                                        HStack {
                                            if message.type == .user {
                                                Spacer(minLength: 60)
                                                ModernMessageBubble(message: message)
                                            } else {
                                                ModernMessageBubble(message: message)
                                                Spacer(minLength: 60)
                                            }
                                        }
                                        .id(message.id)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                        .onChange(of: apiClient.messages.count) { _ in
                            if let lastMessage = apiClient.messages.last {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                
                    // Modern Interactive Controls
                    VStack(spacing: 16) {
                        // Control section header
                        HStack {
                            Text("Quick Controls")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(.secondaryLabel))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // Arrow navigation group
                                HStack(spacing: 8) {
                                    ModernControlButton(symbol: "chevron.up", color: .blue, key: "ArrowUp", isActive: sendingKey == "ArrowUp") {
                                        sendSpecialKey("ArrowUp")
                                    }
                                    
                                    ModernControlButton(symbol: "chevron.left", color: .blue, key: "ArrowLeft", isActive: sendingKey == "ArrowLeft") {
                                        sendSpecialKey("ArrowLeft")
                                    }
                                    
                                    ModernControlButton(symbol: "chevron.down", color: .blue, key: "ArrowDown", isActive: sendingKey == "ArrowDown") {
                                        sendSpecialKey("ArrowDown")
                                    }
                                    
                                    ModernControlButton(symbol: "chevron.right", color: .blue, key: "ArrowRight", isActive: sendingKey == "ArrowRight") {
                                        sendSpecialKey("ArrowRight")
                                    }
                                }
                                .padding(12)
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                                
                                // Enter key
                                ModernControlButton(symbol: "return", color: .green, key: "Enter", isActive: sendingKey == "Enter", isLarge: true) {
                                    sendSpecialKey("Enter")
                                }
                                
                                // Number group
                                HStack(spacing: 8) {
                                    ForEach(1...3, id: \.self) { number in
                                        ModernNumberButton(number: number, isActive: sendingKey == "\(number)") {
                                            sendSpecialKey("\(number)")
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                                
                                // Escape key
                                ModernControlButton(symbol: "escape", color: .red, key: "Escape", isActive: sendingKey == "Escape", isLarge: true) {
                                    sendSpecialKey("Escape")
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 16)
                
                    // Modern Text Input
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.secondarySystemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                            
                            HStack(spacing: 12) {
                                TextField("Type your message...", text: $newMessage)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(.label))
                                    .disabled(apiClient.isLoading)
                                    .padding(.leading, 20)
                                
                                if apiClient.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 20)
                                } else if !newMessage.isEmpty {
                                    Button(action: sendMessage) {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 28, weight: .medium))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.blue, .purple],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                    .padding(.trailing, 16)
                                }
                            }
                        }
                        .frame(height: 56)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Clauder")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
        }
    }
    
    private func sendMessage() {
        let message = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        newMessage = ""
        
        Task {
            do {
                try await apiClient.sendMessage(message)
            } catch {
                print("Failed to send message: \(error)")
            }
        }
    }
    
    private func sendSpecialKey(_ key: String) {
        // Add visual feedback
        sendingKey = key
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        Task {
            do {
                try await apiClient.sendSpecialKey(key)
                
                // Clear visual feedback after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    sendingKey = nil
                }
            } catch {
                print("Failed to send special key: \(error)")
                sendingKey = nil
            }
        }
    }
}

struct ModernMessageBubble: View {
    let message: AgentMessage
    
    var body: some View {
        VStack(alignment: message.type == .user ? .trailing : .leading, spacing: 8) {
            HStack {
                if message.type == .user {
                    Spacer(minLength: 0)
                }
                
                VStack(alignment: message.type == .user ? .trailing : .leading, spacing: 6) {
                    Text(message.content)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(message.type == .user ? .white : Color(.label))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            Group {
                                if message.type == .user {
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                } else {
                                    Color(.secondarySystemBackground)
                                }
                            }
                        )
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    
                    HStack {
                        if message.type == .user {
                            Spacer()
                        }
                        
                        Text(DateFormatter.time.string(from: message.timestamp))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(.secondaryLabel))
                        
                        if message.type == .agent {
                            Spacer()
                        }
                    }
                }
                
                if message.type == .agent {
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: AgentMessage
    
    var body: some View {
        ModernMessageBubble(message: message)
    }
}

extension DateFormatter {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Modern Control Components

struct ModernControlButton: View {
    let symbol: String
    let color: Color
    let key: String
    let isActive: Bool
    let isLarge: Bool
    let action: () -> Void
    
    init(symbol: String, color: Color, key: String, isActive: Bool, isLarge: Bool = false, action: @escaping () -> Void) {
        self.symbol = symbol
        self.color = color
        self.key = key
        self.isActive = isActive
        self.isLarge = isLarge
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: isLarge ? 18 : 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: isLarge ? 52 : 44, height: isLarge ? 52 : 44)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(isLarge ? 16 : 12)
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .scaleEffect(isActive ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
}

struct ModernNumberButton: View {
    let number: Int
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color.red.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .scaleEffect(isActive ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
}

// Legacy components for compatibility
struct CompactButton: View {
    let symbol: String
    let color: Color
    let key: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        ModernControlButton(symbol: symbol, color: color, key: key, isActive: isActive, action: action)
    }
}

struct CompactNumberButton: View {
    let number: Int
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        ModernNumberButton(number: number, isActive: isActive, action: action)
    }
}

#Preview {
    ContentView()
}