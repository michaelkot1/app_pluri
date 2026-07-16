import Foundation

/// Errors surfaced gently from auth flows (SPEC §2).
enum PluriAuthError: Error, Equatable, Sendable {
    case notSignedIn
    case invalidCredentials
    case emailAlreadyRegistered
    case weakPassword
    case appleSignInFailed(String)
    case sessionRestoreFailed(String)
    case accountDeletionFailed(String)
    case networkUnavailable
    case invalidOTP
    case otpResendFailed(String)
    case unknown(String)

    var userFacingMessage: String {
        switch self {
        case .notSignedIn:
            "You’re not signed in. Please sign in and try again."
        case .invalidCredentials:
            "That email or password didn’t work. Please try again."
        case .emailAlreadyRegistered:
            "An account with that email already exists. Try signing in instead."
        case .weakPassword:
            "Please choose a stronger password and try again."
        case .appleSignInFailed(let detail):
            detail.isEmpty
                ? "Sign in with Apple didn’t complete. Please try again."
                : detail
        case .sessionRestoreFailed(let detail):
            detail.isEmpty
                ? "We couldn’t restore your session. Please sign in again."
                : detail
        case .accountDeletionFailed(let detail):
            detail.isEmpty
                ? "We couldn’t delete your account. Please try again."
                : detail
        case .networkUnavailable:
            "Check your connection and try again."
        case .invalidOTP:
            "That code didn’t work. Check the email and try again."
        case .otpResendFailed(let detail):
            detail.isEmpty
                ? "We couldn’t resend the code. Please try again in a moment."
                : detail
        case .unknown(let detail):
            detail.isEmpty
                ? "Something went wrong. Please try again."
                : detail
        }
    }
}
