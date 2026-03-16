import Foundation

/// Supported LLM providers
enum LLMProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case anthropic = "Anthropic"
    case openai = "OpenAI"
    case gemini = "Google Gemini"
    case xai = "xAI (Grok)"
    
    var id: String { rawValue }
    
    /// Display name
    var displayName: String { rawValue }
    
    /// Backend identifier (what the API expects)
    var backendIdentifier: String {
        switch self {
        case .anthropic: return "anthropic"
        case .openai:    return "openai"
        case .gemini:    return "gemini"
        case .xai:       return "xai"
        }
    }
    
    /// Short description
    var tagline: String {
        switch self {
        case .anthropic: return "Claude models — exceptional reasoning"
        case .openai:    return "GPT & o-series — versatile & powerful"
        case .gemini:    return "Gemini models — multimodal intelligence"
        case .xai:       return "Grok models — real-time knowledge"
        }
    }
    
    /// SF Symbol icon
    var iconName: String {
        switch self {
        case .anthropic: return "brain.head.profile"
        case .openai:    return "circle.hexagongrid.fill"
        case .gemini:    return "diamond.fill"
        case .xai:       return "bolt.fill"
        }
    }
    
    /// Keychain key for storing API key
    var keychainKey: String {
        "api_key_\(rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }
    
    /// Placeholder for API key input
    var apiKeyPlaceholder: String {
        switch self {
        case .anthropic: return "sk-ant-..."
        case .openai:    return "sk-..."
        case .gemini:    return "AIza..."
        case .xai:       return "xai-..."
        }
    }
    
    /// URL for getting an API key
    var apiKeyURL: URL? {
        switch self {
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")
        case .openai:    return URL(string: "https://platform.openai.com/api-keys")
        case .gemini:    return URL(string: "https://aistudio.google.com/apikey")
        case .xai:       return URL(string: "https://console.x.ai/")
        }
    }
}
