import Foundation

/// A chat message in a conversation
struct Message: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let role: Role
    var content: String
    let timestamp: Date
    var isStreaming: Bool
    
    enum Role: String, Codable, Sendable {
        case user
        case assistant
        case system
    }
    
    init(
        id: String = UUID().uuidString,
        role: Role,
        content: String,
        timestamp: Date = .now,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }
    
    static func userMessage(_ text: String) -> Message {
        Message(role: .user, content: text)
    }
    
    static func assistantMessage(_ text: String, streaming: Bool = false) -> Message {
        Message(role: .assistant, content: text, isStreaming: streaming)
    }
}
