import Foundation
import Combine

class EventSourceClient: NSObject, ObservableObject {
    private let url: URL
    private let token: String
    private var task: URLSessionDataTask?
    private let session: URLSession
    
    @Published var messageSubject = PassthroughSubject<ServerSentEvent, Never>()
    
    var messagePublisher: AnyPublisher<ServerSentEvent, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    
    init(url: URL, token: String) {
        self.url = url
        self.token = token
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 0
        config.timeoutIntervalForResource = 0
        self.session = URLSession(configuration: config)
        
        super.init()
    }
    
    func connect() {
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        task = session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("EventSource error: \(error)")
                return
            }
            
            guard let data = data else { return }
            
            let string = String(data: data, encoding: .utf8) ?? ""
            self?.parseEventData(string)
        }
        
        task?.resume()
    }
    
    func disconnect() {
        task?.cancel()
        task = nil
    }
    
    private func parseEventData(_ data: String) {
        let lines = data.components(separatedBy: .newlines)
        var event = ServerSentEvent()
        
        for line in lines {
            if line.isEmpty {
                // Empty line indicates end of event
                if !event.data.isEmpty {
                    DispatchQueue.main.async {
                        self.messageSubject.send(event)
                    }
                    event = ServerSentEvent()
                }
                continue
            }
            
            if line.hasPrefix("event:") {
                event.type = String(line.dropFirst(6).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("data:") {
                let eventData = String(line.dropFirst(5).trimmingCharacters(in: .whitespaces))
                event.data = eventData
            }
        }
    }
}

struct ServerSentEvent {
    var type: String = ""
    var data: String = ""
}