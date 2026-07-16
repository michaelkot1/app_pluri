import Foundation
import Supabase

/// Abstraction over Supabase Auth for live app use, previews, and tests (M2-04).
@MainActor
protocol SupabaseAuthServicing: AnyObject {
    var session: Session? { get }
    var user: User? { get }
    /// Stable id for RevenueCat `logIn` after Supabase auth (M2-11).
    var appUserID: String? { get }
    var isSignedIn: Bool { get }
    /// `true` after the first session restore / auth-state event so M2-18 can avoid flash.
    var hasResolvedSession: Bool { get }
    var isLoading: Bool { get }
    var lastError: PluriAuthError? { get }

    func signInWithApple(idToken: String, nonce: String?) async throws
    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    /// Confirms email after sign-up when the dashboard requires email OTP (M2-11 OTP UX).
    func verifyOTP(email: String, token: String, type: EmailOTPType) async throws
    /// Resends the signup confirmation email / OTP.
    func resendSignupOTP(email: String) async throws
    func signOut() async throws
    /// Refreshes/restores the persisted session (called at launch).
    func restoreSession() async
    /// Invokes the `delete-account` Edge Function with the user's JWT (M2-05). Confirmation UI is M2-17.
    func deleteAccount() async throws
}
