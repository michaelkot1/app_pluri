import AuthenticationServices
import Foundation

/// Thin SIWA bridge: `ASAuthorization` → identity token for Supabase `signInWithIdToken` (M2-04 / M2-11).
enum SignInWithAppleTokenExtractor {
    /// Extracts the Apple identity token string from a completed authorization.
    static func identityToken(from authorization: ASAuthorization) throws -> String {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw PluriAuthError.appleSignInFailed("Unexpected Apple credential type.")
        }
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              !idToken.isEmpty else {
            throw PluriAuthError.appleSignInFailed("Apple did not return an identity token.")
        }
        return idToken
    }
}
