import Foundation

/// API configuration for backend connection
enum APIConfig {
    /// Base URL for HTTP requests
    static var baseURL: String {
        #if DEBUG
        return "http://localhost:8000"
        #else
        return "https://agent-api.fly.dev"
        #endif
    }
    
    /// Base URL for WebSocket connections
    static var wsBaseURL: String {
        #if DEBUG
        return "ws://localhost:8000"
        #else
        return "wss://agent-api.fly.dev"
        #endif
    }
}
