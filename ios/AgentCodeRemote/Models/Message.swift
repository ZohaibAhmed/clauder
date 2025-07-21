import Foundation

struct Message: Codable, Identifiable {
    let id: String
    let role: String
    let content: String
    let time: Date
    
    var isUser: Bool {
        role == "user"
    }
    
    var isAgent: Bool {
        role == "agent"
    }
}

struct MessagesResponse: Codable {
    let messages: [Message]
}

struct MessageRequest: Codable {
    let content: String
    let type: String
}

struct MessageResponse: Codable {
    let ok: Bool
}