import SwiftUI

/// Home screen showing active harness and quick actions
struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @State private var viewModel = HomeViewModel()
    @State private var showGreeting = false
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Theme.spacingLG) {
                    // Greeting
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        Text(viewModel.greeting)
                            .font(Theme.largeTitle)
                            .foregroundStyle(Theme.textPrimary)
                            .opacity(showGreeting ? 1 : 0)
                            .offset(y: showGreeting ? 0 : 10)
                        
                        Text("What would you like to work on?")
                            .font(Theme.body)
                            .foregroundStyle(Theme.textSecondary)
                            .opacity(showGreeting ? 1 : 0)
                            .offset(y: showGreeting ? 0 : 10)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.spacingLG)
                    .padding(.top, Theme.spacingMD)
                    
                    // Active harness card
                    Button {
                        router.selectedTab = .chat
                    } label: {
                        activeHarnessCard
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Theme.spacingLG)
                    
                    // Quick actions
                    VStack(alignment: .leading, spacing: Theme.spacingMD) {
                        Text("Quick Actions")
                            .font(Theme.headline)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, Theme.spacingLG)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: Theme.spacingMD) {
                            quickAction(icon: "mic.fill", title: "Voice Chat", color: Theme.accent) {
                                router.selectedTab = .chat
                            }
                            quickAction(icon: "keyboard.fill", title: "Text Chat", color: Theme.success) {
                                router.selectedTab = .chat
                            }
                            quickAction(icon: "square.grid.2x2.fill", title: "Browse Harnesses", color: Theme.warning) {
                                router.selectedTab = .marketplace
                            }
                            quickAction(icon: "key.fill", title: "API Keys", color: Theme.secondary) {
                                router.selectedTab = .settings
                            }
                        }
                        .padding(.horizontal, Theme.spacingLG)
                    }
                    
                    // Tips section
                    VStack(alignment: .leading, spacing: Theme.spacingMD) {
                        Text("Tips")
                            .font(Theme.headline)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, Theme.spacingLG)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.spacingMD) {
                                tipCard(
                                    icon: "brain",
                                    title: "Memory",
                                    subtitle: "Say \"remember that I like...\" and your agent will save it forever.",
                                    color: Theme.accent
                                )
                                tipCard(
                                    icon: "globe",
                                    title: "Web Search",
                                    subtitle: "Ask anything current — your agent searches the web in real time.",
                                    color: Theme.success
                                )
                                tipCard(
                                    icon: "bell.fill",
                                    title: "Reminders",
                                    subtitle: "\"Remind me to call mom in 30 minutes\" — it just works.",
                                    color: Theme.warning
                                )
                            }
                            .padding(.horizontal, Theme.spacingLG)
                        }
                    }
                    
                    // Available harnesses
                    VStack(alignment: .leading, spacing: Theme.spacingMD) {
                        Text("Available Harnesses")
                            .font(Theme.headline)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, Theme.spacingLG)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.spacingMD) {
                                ForEach(Harness.allHarnesses) { harness in
                                    harnessPreviewCard(harness)
                                }
                            }
                            .padding(.horizontal, Theme.spacingLG)
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
            }
        }
        .navigationTitle("")
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                showGreeting = true
            }
        }
    }
    
    // MARK: - Active Harness Card
    
    private var activeHarnessCard: some View {
        let harness = viewModel.activeHarness
        
        return GlassCard {
            HStack(spacing: Theme.spacingMD) {
                HarnessAvatar(harness, size: 60)
                
                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    Text("Active Harness")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textMuted)
                        .textCase(.uppercase)
                    
                    Text(harness.name)
                        .font(Theme.title2)
                        .foregroundStyle(Theme.textPrimary)
                    
                    Text(harness.description)
                        .font(Theme.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.textMuted)
                    Text("Chat")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
    }
    
    // MARK: - Quick Action Button
    
    private func quickAction(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Theme.spacingSM) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radiusMD)
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(color)
                }
                
                Text(title)
                    .font(Theme.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.spacingMD)
            .glassBackground()
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Tip Card
    
    private func tipCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
            }
            
            Text(title)
                .font(Theme.headline)
                .foregroundStyle(Theme.textPrimary)
            
            Text(subtitle)
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(3)
        }
        .frame(width: 160)
        .padding(Theme.spacingMD)
        .glassBackground()
    }
    
    // MARK: - Harness Preview Card
    
    private func harnessPreviewCard(_ harness: Harness) -> some View {
        Button {
            router.selectedTab = .marketplace
        } label: {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                HarnessAvatar(harness, size: 44)
                
                Text(harness.name)
                    .font(Theme.headline)
                    .foregroundStyle(Theme.textPrimary)
                
                Text(harness.description)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                
                if harness.isFree {
                    Text("FREE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.success.opacity(0.15))
                        .clipShape(Capsule())
                } else {
                    Text("PREMIUM")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.warning.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .frame(width: 140)
            .padding(Theme.spacingMD)
            .glassBackground()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(AppRouter())
}
