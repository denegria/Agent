import SwiftUI

/// App-wide navigation and auth state coordinator
@Observable
final class AppRouter: ObservableObject {
    enum AuthState: Equatable {
        case unauthenticated
        case onboarding   // authenticated but needs API key setup
        case authenticated
    }
    
    enum Tab: Hashable {
        case home
        case chat
        case marketplace
        case settings
    }
    
    var authState: AuthState = .unauthenticated
    var selectedTab: Tab = .home
    var activeHarnessID: String = "default"
    
    // MARK: - Navigation Helpers
    
    func signIn() {
        let hasKeys = KeychainManager.shared.hasAnyAPIKey()
        authState = hasKeys ? .authenticated : .onboarding
    }
    
    func completeOnboarding() {
        authState = .authenticated
        selectedTab = .chat
    }
    
    func signOut() {
        authState = .unauthenticated
    }
    
    func switchHarness(to id: String) {
        activeHarnessID = id
    }
}
