import SwiftUI

/// A harness configuration — the core product unit
struct Harness: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let category: HarnessCategory
    let isFree: Bool
    let productID: String?     // StoreKit product ID for purchase
    let systemPrompt: String
    let toolsConfig: [String]? // Tool identifiers enabled for this harness
    
    // Non-codable computed properties
    var gradientColors: [Color] {
        switch category {
        case .general:     return [Color(hex: "6C5CE7"), Color(hex: "A29BFE")]
        case .creative:    return [Color(hex: "E17055"), Color(hex: "FDCB6E")]
        case .business:    return [Color(hex: "00B894"), Color(hex: "00CEC9")]
        case .personal:    return [Color(hex: "6C5CE7"), Color(hex: "E17055")]
        case .research:    return [Color(hex: "0984E3"), Color(hex: "74B9FF")]
        case .developer:   return [Color(hex: "2D3436"), Color(hex: "636E72")]
        }
    }
    
    enum HarnessCategory: String, Codable, CaseIterable, Sendable {
        case general = "General"
        case creative = "Creative"
        case business = "Business"
        case personal = "Personal"
        case research = "Research"
        case developer = "Developer"
    }
    
    // MARK: - Defaults
    
    static let defaultHarness = Harness(
        id: "default",
        name: "Assistant",
        description: "Your everyday AI — search the web, do math, remember things, and set reminders. Voice or text.",
        iconName: "sparkles",
        category: .general,
        isFree: true,
        productID: nil,
        systemPrompt: "You are Agent, a helpful personal AI assistant.",
        toolsConfig: ["web_search", "web_fetch", "calculator", "get_datetime", "memory_note", "set_reminder"]
    )
    
    /// All available harnesses (synced from backend in production)
    static let allHarnesses: [Harness] = [
        .defaultHarness,
        Harness(
            id: "startup_founder",
            name: "Startup Founder",
            description: "Your AI co-founder for pitch decks, market analysis, fundraising, and strategic planning.",
            iconName: "lightbulb.fill",
            category: .business,
            isFree: false,
            productID: "com.agent.harness.startup",
            systemPrompt: "You are a seasoned startup advisor.",
            toolsConfig: ["web_search", "web_fetch", "calculator", "get_datetime", "memory_note", "document_writer"]
        ),
        Harness(
            id: "musician_helper",
            name: "Musician",
            description: "Write lyrics, find chords, explore music theory, and brainstorm song ideas.",
            iconName: "music.note",
            category: .creative,
            isFree: false,
            productID: "com.agent.harness.musician",
            systemPrompt: "You are a skilled musician and songwriter.",
            toolsConfig: ["chord_lookup", "rhyme_finder", "web_search", "memory_note"]
        ),
        Harness(
            id: "research_agent",
            name: "Research Agent",
            description: "Deep research, article summaries, fact-checking, and knowledge synthesis.",
            iconName: "magnifyingglass.circle.fill",
            category: .research,
            isFree: false,
            productID: "com.agent.harness.research",
            systemPrompt: "You are a thorough research analyst.",
            toolsConfig: ["web_search", "web_fetch", "summarizer", "calculator", "get_datetime", "memory_note", "document_writer"]
        ),
        Harness(
            id: "life_os",
            name: "Life OS",
            description: "Personal productivity, goal tracking, habit building, and life planning.",
            iconName: "heart.circle.fill",
            category: .personal,
            isFree: false,
            productID: "com.agent.harness.lifeos",
            systemPrompt: "You are a personal life coach and productivity expert.",
            toolsConfig: ["memory_note", "set_reminder", "get_datetime", "calculator", "web_search", "document_writer"]
        ),
        Harness(
            id: "website_maintainer",
            name: "Website Builder",
            description: "Build websites, debug code, get SEO advice, and review design patterns.",
            iconName: "globe",
            category: .developer,
            isFree: false,
            productID: "com.agent.harness.website",
            systemPrompt: "You are a full-stack web development expert.",
            toolsConfig: ["web_search", "web_fetch", "document_writer", "calculator", "memory_note"]
        )
    ]
    
    // MARK: - Preview helpers
    
    static func preview(icon: String = "sparkles", name: String = "Preview") -> Harness {
        Harness(
            id: "preview_\(name.lowercased())",
            name: name,
            description: "Preview harness",
            iconName: icon,
            category: .general,
            isFree: false,
            productID: nil,
            systemPrompt: "",
            toolsConfig: nil
        )
    }
}
