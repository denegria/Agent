import Foundation
import Security

/// Secure storage for API keys using iOS Keychain
final class KeychainManager: Sendable {
    static let shared = KeychainManager()
    
    private let service = "com.agent.app"
    
    private init() {}
    
    // MARK: - Public API
    
    /// Save an API key for a provider
    func saveAPIKey(_ key: String, for provider: LLMProvider) throws {
        let data = Data(key.utf8)
        
        // Delete existing item first
        try? deleteAPIKey(for: provider)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    /// Retrieve an API key for a provider
    func getAPIKey(for provider: LLMProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    /// Delete an API key for a provider
    func deleteAPIKey(for provider: LLMProvider) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    /// Check if any API key is stored
    func hasAnyAPIKey() -> Bool {
        LLMProvider.allCases.contains { getAPIKey(for: $0) != nil }
    }
    
    /// Get the first available provider with a key
    func firstAvailableProvider() -> LLMProvider? {
        LLMProvider.allCases.first { getAPIKey(for: $0) != nil }
    }
    
    /// Get all providers that have keys configured
    func configuredProviders() -> [LLMProvider] {
        LLMProvider.allCases.filter { getAPIKey(for: $0) != nil }
    }
    
    // MARK: - Auth Token Storage
    
    func saveAuthToken(_ token: String) throws {
        let data = Data(token.utf8)
        try? deleteAuthToken()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "auth_token",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    func getAuthToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "auth_token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    func deleteAuthToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "auth_token"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    // MARK: - Errors
    
    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case deleteFailed(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Failed to save to Keychain (status: \(status))"
            case .deleteFailed(let status):
                return "Failed to delete from Keychain (status: \(status))"
            }
        }
    }
}
