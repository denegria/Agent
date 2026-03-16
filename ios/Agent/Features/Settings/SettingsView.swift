import SwiftUI

/// Settings screen — API key management + app preferences
struct SettingsView: View {
    @Environment(AppRouter.self) private var router
    @State private var configuredProviders: [LLMProvider] = []
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Theme.spacingLG) {
                    // Header
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        Text("Settings")
                            .font(Theme.largeTitle)
                            .foregroundStyle(Theme.textPrimary)
                        
                        Text("Manage your API keys and preferences")
                            .font(Theme.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.spacingLG)
                    .padding(.top, Theme.spacingSM)
                    
                    // API Keys Section
                    VStack(alignment: .leading, spacing: Theme.spacingMD) {
                        sectionHeader("API Keys", icon: "key.fill")
                        
                        ForEach(LLMProvider.allCases) { provider in
                            APIKeyRow(provider: provider) {
                                refreshConfigured()
                            }
                        }
                    }
                    .padding(.horizontal, Theme.spacingLG)
                    
                    // Voice Settings
                    VStack(alignment: .leading, spacing: Theme.spacingMD) {
                        sectionHeader("Voice", icon: "waveform")
                        
                        GlassCard {
                            VStack(spacing: Theme.spacingMD) {
                                settingsRow(
                                    icon: "mic.fill",
                                    title: "Speech Recognition",
                                    subtitle: "Apple Speech (on-device)",
                                    color: Theme.accent
                                )
                                
                                Divider().background(Color.white.opacity(0.05))
                                
                                settingsRow(
                                    icon: "speaker.wave.2.fill",
                                    title: "Text-to-Speech",
                                    subtitle: "Apple TTS (free fallback)",
                                    color: Theme.success
                                )
                            }
                        }
                    }
                    .padding(.horizontal, Theme.spacingLG)
                    
                    // Account Section
                    VStack(alignment: .leading, spacing: Theme.spacingMD) {
                        sectionHeader("Account", icon: "person.fill")
                        
                        GlassCard {
                            VStack(spacing: Theme.spacingMD) {
                                settingsRow(
                                    icon: "crown.fill",
                                    title: "Subscription",
                                    subtitle: "Free tier",
                                    color: Theme.warning
                                )
                                
                                Divider().background(Color.white.opacity(0.05))
                                
                                Button {
                                    router.signOut()
                                } label: {
                                    settingsRow(
                                        icon: "rectangle.portrait.and.arrow.right",
                                        title: "Sign Out",
                                        subtitle: "",
                                        color: Theme.error
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.spacingLG)
                    
                    // App Info
                    VStack(spacing: Theme.spacingSM) {
                        Text("Agent v1.0.0")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.textMuted)
                        
                        Text("Your Personal AI Harness")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.textMuted)
                    }
                    .padding(.top, Theme.spacingLG)
                    
                    Spacer(minLength: 80)
                }
            }
        }
        .navigationTitle("")
        .onAppear { refreshConfigured() }
    }
    
    private func refreshConfigured() {
        configuredProviders = KeychainManager.shared.configuredProviders()
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: Theme.spacingSM) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(Theme.headline)
                .foregroundStyle(Theme.textSecondary)
        }
    }
    
    private func settingsRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: Theme.spacingMD) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textPrimary)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - API Key Row

struct APIKeyRow: View {
    let provider: LLMProvider
    let onUpdate: () -> Void
    
    @State private var isExpanded = false
    @State private var apiKey = ""
    @State private var hasKey = false
    @State private var showSaved = false
    
    var body: some View {
        GlassCard {
            VStack(spacing: Theme.spacingMD) {
                // Provider header
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: Theme.spacingMD) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.accent.opacity(0.15))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: provider.iconName)
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.accent)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.displayName)
                                .font(Theme.headline)
                                .foregroundStyle(Theme.textPrimary)
                            
                            Text(provider.tagline)
                                .font(Theme.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Status indicator
                        if hasKey {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.success)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .buttonStyle(.plain)
                
                // Expandable key entry
                if isExpanded {
                    VStack(spacing: Theme.spacingSM) {
                        HStack {
                            SecureField(provider.apiKeyPlaceholder, text: $apiKey)
                                .font(Theme.body)
                                .foregroundStyle(Theme.textPrimary)
                                .textContentType(.password)
                                .autocorrectionDisabled()
                            
                            if showSaved {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.success)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(Theme.spacingSM)
                        .background(Theme.background)
                        .cornerRadius(Theme.radiusSM)
                        
                        HStack {
                            if let url = provider.apiKeyURL {
                                Link(destination: url) {
                                    Text("Get API Key →")
                                        .font(Theme.caption)
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            
                            Spacer()
                            
                            if hasKey {
                                Button("Remove") {
                                    removeKey()
                                }
                                .font(Theme.caption)
                                .foregroundStyle(Theme.error)
                            }
                            
                            Button("Save") {
                                saveKey()
                            }
                            .font(Theme.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(apiKey.isEmpty ? Theme.surface : Theme.accent)
                            .cornerRadius(Theme.radiusFull)
                            .disabled(apiKey.isEmpty)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .onAppear {
            hasKey = KeychainManager.shared.getAPIKey(for: provider) != nil
        }
    }
    
    private func saveKey() {
        guard !apiKey.isEmpty else { return }
        
        do {
            try KeychainManager.shared.saveAPIKey(apiKey, for: provider)
            hasKey = true
            apiKey = ""
            
            withAnimation {
                showSaved = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSaved = false
                }
            }
            
            onUpdate()
        } catch {
            print("SettingsView: Failed to save API key - \(error)")
        }
    }
    
    private func removeKey() {
        try? KeychainManager.shared.deleteAPIKey(for: provider)
        hasKey = false
        apiKey = ""
        onUpdate()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppRouter())
}
