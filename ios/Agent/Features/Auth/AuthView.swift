import SwiftUI
import AuthenticationServices

/// Sign-in screen with Apple Sign In + email fallback
struct AuthView: View {
    @Environment(AppRouter.self) private var router
    @State private var viewModel = AuthViewModel()
    
    var body: some View {
        ZStack {
            // Background gradient
            Theme.background.ignoresSafeArea()
            
            // Subtle animated gradient orbs
            GeometryReader { geo in
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -50, y: geo.size.height * 0.15)
                
                Circle()
                    .fill(Theme.success.opacity(0.1))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: geo.size.width * 0.5, y: geo.size.height * 0.6)
            }
            
            VStack(spacing: Theme.spacingXL) {
                Spacer()
                
                // App icon + title
                VStack(spacing: Theme.spacingMD) {
                    ZStack {
                        Circle()
                            .fill(Theme.accentGradient)
                            .frame(width: 100, height: 100)
                            .shadow(color: Theme.accent.opacity(0.5), radius: 20)
                        
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.white)
                    }
                    
                    Text("Agent")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Your Personal AI Harness")
                        .font(Theme.title2)
                        .foregroundStyle(Theme.textSecondary)
                }
                
                Spacer()
                
                // Feature highlights
                VStack(spacing: Theme.spacingSM) {
                    featureRow(icon: "mic.fill", text: "Voice-first conversations")
                    featureRow(icon: "square.grid.2x2.fill", text: "Swappable AI harnesses")
                    featureRow(icon: "key.fill", text: "Bring your own API keys")
                    featureRow(icon: "lock.shield.fill", text: "Private & secure")
                }
                .padding(.horizontal, Theme.spacingXL)
                
                Spacer()
                
                // Sign in buttons
                VStack(spacing: Theme.spacingMD) {
                    // Apple Sign In
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        viewModel.handleAppleSignIn(result: result, router: router)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .cornerRadius(Theme.radiusLG)
                    
                    // Email fallback
                    Button {
                        viewModel.showEmailSignIn = true
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Continue with Email")
                        }
                        .font(Theme.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Theme.surface)
                        .cornerRadius(Theme.radiusLG)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusLG)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    
                    // Skip for now (dev/testing)
                    Button("Skip for now") {
                        router.signIn()
                    }
                    .font(Theme.footnote)
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, Theme.spacingSM)
                }
                .padding(.horizontal, Theme.spacingLG)
                .padding(.bottom, Theme.spacingXL)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .sheet(isPresented: $viewModel.showEmailSignIn) {
            EmailSignInSheet()
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: Theme.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            
            Text(text)
                .font(Theme.body)
                .foregroundStyle(Theme.textSecondary)
            
            Spacer()
        }
    }
}

/// Email sign-in sheet placeholder
struct EmailSignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: Theme.spacingLG) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                    
                    Button {
                        // TODO: Email auth implementation
                        dismiss()
                    } label: {
                        Text("Sign In")
                            .font(Theme.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Theme.accentGradient)
                            .cornerRadius(Theme.radiusMD)
                    }
                }
                .padding(Theme.spacingLG)
            }
            .navigationTitle("Email Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AuthView()
        .environment(AppRouter())
}
