import Foundation

/// A user account
struct User: Codable, Identifiable, Sendable {
    let id: String
    var appleID: String?
    var email: String?
    var displayName: String?
    var activeHarnessID: String
    var tier: UserTier
    var createdAt: Date?
    
    enum UserTier: String, Codable, Sendable {
        case free
        case premium
        case pro
    }
    
    static let guest = User(
        id: "guest",
        displayName: "Guest",
        activeHarnessID: "default",
        tier: .free
    )
}
