import Foundation

/// HTTP + WebSocket API client for backend communication
@Observable
final class APIClient {
    static let shared = APIClient()
    
    #if DEBUG
    private let baseURL = URL(string: "http://localhost:8000")!
    #else
    private let baseURL = URL(string: "https://agent-api.fly.dev")!
    #endif
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        self.encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Auth
    
    func signInWithApple(identityToken: String, fullName: String?) async throws -> AuthResponse {
        try await post(
            Endpoints.authApple,
            body: AppleSignInRequest(identityToken: identityToken, fullName: fullName)
        )
    }
    
    // MARK: - Chat
    
    func connectChat(sessionID: String, harnessID: String) -> URLRequest {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/v1/chat/\(sessionID)"
        components.queryItems = [URLQueryItem(name: "harness_id", value: harnessID)]
        
        // Switch to WebSocket scheme
        if components.scheme == "https" {
            components.scheme = "wss"
        } else {
            components.scheme = "ws"
        }
        
        var request = URLRequest(url: components.url!)
        if let token = KeychainManager.shared.getAuthToken() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    // MARK: - Harnesses
    
    func fetchHarnesses() async throws -> [Harness] {
        try await get(Endpoints.harnesses)
    }
    
    // MARK: - IAP
    
    func verifyPurchase(transactionID: String, productID: String) async throws -> PurchaseVerifyResponse {
        try await post(
            Endpoints.verifyPurchase,
            body: PurchaseVerifyRequest(transactionId: transactionID, productId: productID)
        )
    }
    
    // MARK: - HTTP Helpers
    
    private func get<T: Decodable>(_ endpoint: String) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeader(&request)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }
    
    private func post<Body: Encodable, T: Decodable>(_ endpoint: String, body: Body) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        addAuthHeader(&request)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }
    
    private func addAuthHeader(_ request: inout URLRequest) {
        if let token = KeychainManager.shared.getAuthToken() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Types
    
    enum APIError: LocalizedError {
        case invalidResponse
        case httpError(Int)
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Invalid server response"
            case .httpError(let code): return "Server error (\(code))"
            }
        }
    }
}

// MARK: - Request/Response Types

struct AppleSignInRequest: Encodable {
    let identityToken: String
    let fullName: String?
}

struct AuthResponse: Decodable {
    let token: String
    let user: User
}

struct PurchaseVerifyRequest: Encodable {
    let transactionId: String
    let productId: String
}

struct PurchaseVerifyResponse: Decodable {
    let verified: Bool
    let productId: String
}
