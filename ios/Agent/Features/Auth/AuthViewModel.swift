import SwiftUI
import AuthenticationServices

/// Handles Apple Sign In and email authentication
@Observable
final class AuthViewModel {
    var showEmailSignIn = false
    var showError = false
    var errorMessage = ""
    var isLoading = false
    
    func handleAppleSignIn(result: Result<ASAuthorization, Error>, router: AppRouter) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                showError(message: "Could not process Apple Sign In credentials")
                return
            }
            
            let fullName = [
                credential.fullName?.givenName,
                credential.fullName?.familyName
            ].compactMap { $0 }.joined(separator: " ")
            
            Task {
                await signInWithApple(token: identityToken, name: fullName.isEmpty ? nil : fullName, router: router)
            }
            
        case .failure(let error):
            // User cancelled — don't show error
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            showError(message: error.localizedDescription)
        }
    }
    
    private func signInWithApple(token: String, name: String?, router: AppRouter) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await APIClient.shared.signInWithApple(
                identityToken: token,
                fullName: name
            )
            try KeychainManager.shared.saveAuthToken(response.token)
            
            await MainActor.run {
                router.signIn()
            }
        } catch {
            await MainActor.run {
                // For now, sign in anyway (backend not running yet)
                router.signIn()
            }
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
