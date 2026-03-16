import SwiftUI

@main
struct AgentApp: App {
    @State private var router = AppRouter()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .preferredColorScheme(.dark)
        }
    }
}

/// Root view that handles navigation based on auth state
struct RootView: View {
    @Environment(AppRouter.self) private var router
    
    var body: some View {
        Group {
            switch router.authState {
            case .unauthenticated:
                AuthView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            case .authenticated:
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            case .onboarding:
                APIKeyOnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.5), value: router.authState)
    }
}

/// Placeholder for API key onboarding (shown after first auth)
struct APIKeyOnboardingView: View {
    @Environment(AppRouter.self) private var router
    
    var body: some View {
        NavigationStack {
            SettingsView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            router.authState = .authenticated
                        }
                        .font(.headline)
                        .foregroundStyle(Theme.accentGradient)
                    }
                }
        }
    }
}

/// Main tab-based navigation
struct MainTabView: View {
    @State private var selectedTab: AppRouter.Tab = .home
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: .home) {
                NavigationStack {
                    HomeView()
                }
            }
            
            Tab("Chat", systemImage: "waveform.circle.fill", value: .chat) {
                NavigationStack {
                    ChatView()
                }
            }
            
            Tab("Harnesses", systemImage: "square.grid.2x2.fill", value: .marketplace) {
                NavigationStack {
                    MarketplaceView()
                }
            }
            
            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(Theme.accent)
    }
}
