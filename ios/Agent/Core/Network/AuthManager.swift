import Foundation

/// Manages JWT auth tokens for backend communication
class AuthManager {
    static let shared = AuthManager()
    
    private let tokenKey = "auth_jwt_token"
    private let userIDKey = "auth_user_id"
    
    var currentToken: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
    }
    
    var currentUserID: String? {
        get { UserDefaults.standard.string(forKey: userIDKey) }
        set { UserDefaults.standard.set(newValue, forKey: userIDKey) }
    }
    
    var isAuthenticated: Bool {
        currentToken != nil
    }
    
    func setAuth(token: String, userID: String) {
        currentToken = token
        currentUserID = userID
    }
    
    func clearAuth() {
        currentToken = nil
        currentUserID = nil
    }
}
