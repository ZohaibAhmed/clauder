import Foundation
import Combine

enum APIError: Error {
    case invalidPasscode
    case notConnected
    case sendFailed
    case networkError(Error)
    case invalidResponse
    case authenticationFailed
    
    var localizedDescription: String {
        switch self {
        case .invalidPasscode:
            return "Invalid or expired passcode"
        case .notConnected:
            return "Not connected to Clauder"
        case .sendFailed:
            return "Failed to send message"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}

class AgentAPIClient: ObservableObject {
    @Published var messages: [Message] = []
    @Published var status: AgentStatus = .offline
    @Published var connectionError: Error?
    @Published var isConnecting: Bool = false
    
    private var session: Session?
    private var eventSource: EventSourceClient?
    private var cancellables = Set<AnyCancellable>()
    
    private let coordinatorURL = "https://coordinator.claudecode.app"
    
    init() {
        // Try to load existing session
        loadSavedSession()
    }
    
    private func loadSavedSession() {
        do {
            let savedSession = try KeychainService.loadSession()
            if !savedSession.isExpired {
                self.session = savedSession
                connectToExistingSession()
            } else {
                KeychainService.deleteSession()
            }
        } catch {
            // No saved session or error loading
        }
    }
    
    private func connectToExistingSession() {
        guard let session = session else { return }
        
        Task {
            do {
                // Test connection with a status check
                let _ = try await getStatus()
                
                // If successful, connect event source and fetch messages
                await MainActor.run {
                    connectEventSource()
                }
                
                try await fetchMessages()
            } catch {
                await MainActor.run {
                    self.status = .offline
                    self.connectionError = error
                    self.session = nil
                    KeychainService.deleteSession()
                }
            }
        }
    }
    
    func connect(with passcode: String) async throws {
        await MainActor.run {
            isConnecting = true
            connectionError = nil
        }
        
        // 1. Look up session from coordinator
        let coordinatorURL = URL(string: "\(self.coordinatorURL)/lookup/\(passcode)")!
        
        do {
            let (data, response) = try await URLSession.shared.data(from: coordinatorURL)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode == 404 {
                let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                throw APIError.invalidPasscode
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.invalidResponse
            }
            
            let coordinatorResponse = try JSONDecoder().decode(CoordinatorResponse.self, from: data)
            
            // 2. Create session
            let newSession = Session(
                passcode: passcode,
                tunnelURL: coordinatorResponse.tunnel_url,
                token: coordinatorResponse.token,
                connectedAt: Date()
            )
            
            // 3. Test connection
            let _ = try await testConnection(session: newSession)
            
            await MainActor.run {
                self.session = newSession
                self.status = .stable
                self.isConnecting = false
            }
            
            // 4. Save to keychain
            try KeychainService.save(newSession)
            
            // 5. Connect to event stream
            connectEventSource()
            
            // 6. Fetch initial messages
            try await fetchMessages()
            
        } catch {
            await MainActor.run {
                self.isConnecting = false
                self.connectionError = error
            }
            throw error
        }
    }
    
    private func testConnection(session: Session) async throws -> StatusResponse {
        guard let url = URL(string: "\(session.tunnelURL)/status") else {
            throw APIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.authenticationFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(StatusResponse.self, from: data)
    }
    
    private func getStatus() async throws -> StatusResponse {
        guard let session = session else { throw APIError.notConnected }
        return try await testConnection(session: session)
    }
    
    func sendMessage(_ content: String) async throws {
        guard let session = session else { throw APIError.notConnected }
        
        var request = URLRequest(url: URL(string: "\(session.tunnelURL)/message")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = MessageRequest(content: content, type: "user")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.authenticationFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.sendFailed
        }
    }
    
    private func fetchMessages() async throws {
        guard let session = session else { throw APIError.notConnected }
        
        var request = URLRequest(url: URL(string: "\(session.tunnelURL)/messages")!)
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let messagesResponse = try JSONDecoder().decode(MessagesResponse.self, from: data)
        
        await MainActor.run {
            self.messages = messagesResponse.messages
        }
    }
    
    private func connectEventSource() {
        guard let session = session else { return }
        
        eventSource = EventSourceClient(
            url: URL(string: "\(session.tunnelURL)/events")!,
            token: session.token
        )
        
        eventSource?.messagePublisher
            .sink { [weak self] event in
                self?.handleServerSentEvent(event)
            }
            .store(in: &cancellables)
        
        eventSource?.connect()
    }
    
    private func handleServerSentEvent(_ event: ServerSentEvent) {
        switch event.type {
        case "message_update":
            handleMessageUpdate(event.data)
        case "status_change":
            handleStatusChange(event.data)
        default:
            print("Unknown event type: \(event.type)")
        }
    }
    
    private func handleMessageUpdate(_ data: String) {
        guard let jsonData = data.data(using: .utf8) else { return }
        
        do {
            let message = try JSONDecoder().decode(Message.self, from: jsonData)
            
            DispatchQueue.main.async {
                if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                    self.messages[index] = message
                } else {
                    self.messages.append(message)
                }
            }
        } catch {
            print("Failed to decode message update: \(error)")
        }
    }
    
    private func handleStatusChange(_ data: String) {
        guard let jsonData = data.data(using: .utf8) else { return }
        
        do {
            let statusResponse = try JSONDecoder().decode(StatusResponse.self, from: jsonData)
            
            DispatchQueue.main.async {
                self.status = statusResponse.status
            }
        } catch {
            print("Failed to decode status change: \(error)")
        }
    }
    
    func disconnect() {
        eventSource?.disconnect()
        eventSource = nil
        cancellables.removeAll()
        session = nil
        KeychainService.deleteSession()
        
        DispatchQueue.main.async {
            self.status = .offline
            self.messages = []
            self.connectionError = nil
        }
    }
}