import SwiftUI

/// Onboarding — First-time user setup after sign-in
/// Guides user through adding their first API key
struct OnboardingView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var currentStep = 0
    
    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { step in
                        Circle()
                            .fill(step <= currentStep ? Theme.Colors.accent : Theme.Colors.surface)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 20)
                
                TabView(selection: $currentStep) {
                    welcomeStep.tag(0)
                    apiKeyStep.tag(1)
                    readyStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Step 1: Welcome
    
    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Colors.accent, Theme.Colors.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 12) {
                Text("Welcome to Agent")
                    .font(Theme.Typography.largeTitle)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Your personal AI assistant that works with\nthe LLM provider you already trust.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "mic.fill", title: "Voice First", description: "Talk naturally — just like a real assistant")
                featureRow(icon: "magnifyingglass", title: "Web Search", description: "Search the web, read articles, stay informed")
                featureRow(icon: "brain", title: "Memory", description: "Remembers your preferences across sessions")
                featureRow(icon: "lock.shield", title: "Your Keys", description: "Your API key stays on your device")
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            Button(action: { withAnimation { currentStep = 1 } }) {
                Text("Get Started")
                    .font(Theme.Typography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Theme.Colors.accent, Theme.Colors.accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(Theme.CornerRadius.large)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Step 2: API Key Setup
    
    private var apiKeyStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 12) {
                Text("Add Your API Key")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Choose a provider and paste your API key.\nYou only need one to get started.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                ForEach(LLMProvider.allCases, id: \.self) { provider in
                    providerCard(provider: provider)
                }
            }
            .padding(.horizontal, 24)
            
            if !viewModel.selectedProvider.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Paste your API key here", text: $viewModel.apiKeyInput)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Theme.Colors.surface)
                        .cornerRadius(Theme.CornerRadius.medium)
                    
                    if let error = viewModel.apiKeyError {
                        Text(error)
                            .font(Theme.Typography.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button(action: {
                        if let provider = LLMProvider(rawValue: viewModel.selectedProvider) {
                            KeychainManager.shared.saveAPIKey(viewModel.apiKeyInput, for: provider)
                            viewModel.apiKeySaved = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.shield")
                            Text("Save to Keychain")
                        }
                        .font(Theme.Typography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(viewModel.apiKeyInput.count > 10 ? Theme.Colors.accent : Theme.Colors.surface)
                        .cornerRadius(Theme.CornerRadius.medium)
                    }
                    .disabled(viewModel.apiKeyInput.count < 10)
                }
                .padding(.horizontal, 24)
            }
            
            Spacer()
            
            HStack {
                Button("Skip for Now") {
                    withAnimation { currentStep = 2 }
                }
                .foregroundColor(Theme.Colors.textSecondary)
                
                Spacer()
                
                if viewModel.apiKeySaved {
                    Button(action: { withAnimation { currentStep = 2 } }) {
                        HStack {
                            Text("Next")
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(Theme.Colors.accent)
                        .font(Theme.Typography.headline)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Step 3: Ready
    
    private var readyStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.success)
            
            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(Theme.Typography.largeTitle)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(viewModel.apiKeySaved
                     ? "Your API key is securely stored.\nTap below to start chatting."
                     : "You can add an API key later in Settings.\nTap below to explore the app."
                )
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button(action: {
                router.completeOnboarding()
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text(viewModel.apiKeySaved ? "Start Chatting" : "Explore Agent")
                }
                .font(Theme.Typography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Theme.Colors.accent, Theme.Colors.accentSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(Theme.CornerRadius.large)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Helpers
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Theme.Colors.accent)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(description)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }
    
    private func providerCard(provider: LLMProvider) -> some View {
        Button(action: {
            viewModel.selectedProvider = provider.rawValue
            viewModel.apiKeyInput = ""
            viewModel.apiKeyError = nil
        }) {
            HStack {
                Image(systemName: provider.iconName)
                    .font(.title3)
                    .frame(width: 32)
                Text(provider.displayName)
                    .font(Theme.Typography.body)
                Spacer()
                if viewModel.selectedProvider == provider.rawValue {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Colors.accent)
                }
            }
            .foregroundColor(Theme.Colors.textPrimary)
            .padding()
            .background(
                viewModel.selectedProvider == provider.rawValue
                    ? Theme.Colors.accent.opacity(0.15)
                    : Theme.Colors.surface
            )
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(
                        viewModel.selectedProvider == provider.rawValue
                            ? Theme.Colors.accent
                            : Color.clear,
                        lineWidth: 1
                    )
            )
        }
    }
}


// MARK: - ViewModel

class OnboardingViewModel: ObservableObject {
    @Published var selectedProvider = ""
    @Published var apiKeyInput = ""
    @Published var apiKeyError: String?
    @Published var apiKeySaved = false
}
