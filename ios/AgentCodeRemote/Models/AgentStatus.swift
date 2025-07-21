import Foundation

enum AgentStatus: String, Codable {
    case offline = "offline"
    case stable = "stable"
    case responding = "responding"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .offline:
            return "Offline"
        case .stable:
            return "Ready"
        case .responding:
            return "Responding"
        case .error:
            return "Error"
        }
    }
    
    var color: String {
        switch self {
        case .offline:
            return "gray"
        case .stable:
            return "green"
        case .responding:
            return "blue"
        case .error:
            return "red"
        }
    }
}

struct StatusResponse: Codable {
    let status: AgentStatus
}