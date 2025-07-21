import Foundation

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
    let created_at: Double?
    let expires_at: Double?
}

struct ErrorResponse: Codable {
    let error: String
}