import Foundation
import Supabase
import os.log

/// Live Supabase Auth service (M2-04 / M2-05). Reuses the shared `SupabaseService` client —
/// no second naked `SupabaseClient`.
@MainActor
@Observable
final class SupabaseAuthService: SupabaseAuthServicing {
    private(set) var session: Session?
    private(set) var hasResolvedSession = false
    private(set) var isLoading = false
    private(set) var lastError: PluriAuthError?

    private let supabaseService: SupabaseService
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "SupabaseAuthService")

    var user: User? { session?.user }
    var appUserID: String? { user?.id.uuidString }
    var isSignedIn: Bool { session != nil }

    private var client: SupabaseClient { supabaseService.client }

    init(supabaseService: SupabaseService, restoreOnLaunch: Bool = true) {
        self.supabaseService = supabaseService
        startListeningToAuthState()
        if restoreOnLaunch {
            Task { await restoreSession() }
        }
    }

    func signInWithApple(idToken: String, nonce: String?) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let nextSession = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
            apply(session: nextSession)
            logger.info("Signed in with Apple")
        } catch {
            let wrapped = mapAuthError(error, fallback: .appleSignInFailed(error.localizedDescription))
            lastError = wrapped
            logger.error("Apple sign-in failed: \(error.localizedDescription)")
            throw wrapped
        }
    }

    func signUp(email: String, password: String) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let response = try await client.auth.signUp(email: email, password: password)
            if let nextSession = response.session {
                apply(session: nextSession)
            } else {
                // Email confirmation may leave the session empty until the user confirms.
                apply(session: nil)
            }
            logger.info("Signed up with email")
        } catch {
            let wrapped = mapAuthError(error, fallback: .unknown(error.localizedDescription))
            lastError = wrapped
            logger.error("Email sign-up failed: \(error.localizedDescription)")
            throw wrapped
        }
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let nextSession = try await client.auth.signIn(email: email, password: password)
            apply(session: nextSession)
            logger.info("Signed in with email")
        } catch {
            let wrapped = mapAuthError(error, fallback: .invalidCredentials)
            lastError = wrapped
            logger.error("Email sign-in failed: \(error.localizedDescription)")
            throw wrapped
        }
    }

    func verifyOTP(email: String, token: String, type: EmailOTPType) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let response = try await client.auth.verifyOTP(email: email, token: token, type: type)
            guard let nextSession = response.session else {
                let missing = PluriAuthError.invalidOTP
                lastError = missing
                throw missing
            }
            apply(session: nextSession)
            logger.info("Verified email OTP")
        } catch let error as PluriAuthError {
            lastError = error
            throw error
        } catch {
            let wrapped = mapAuthError(error, fallback: .invalidOTP)
            lastError = wrapped
            logger.error("OTP verify failed: \(error.localizedDescription)")
            throw wrapped
        }
    }

    func resendSignupOTP(email: String) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            try await client.auth.resend(email: email, type: .signup)
            logger.info("Resent signup OTP email")
        } catch {
            let wrapped = mapAuthError(error, fallback: .otpResendFailed(error.localizedDescription))
            lastError = wrapped
            logger.error("OTP resend failed: \(error.localizedDescription)")
            throw wrapped
        }
    }

    func signOut() async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let hintUserID = appUserID.flatMap(UUID.init(uuidString:))
        do {
            try await client.auth.signOut()
            if let hintUserID {
                OnboardingCompletionHintStore.clear(userID: hintUserID)
            }
            apply(session: nil)
            logger.info("Signed out")
        } catch {
            let wrapped = PluriAuthError.unknown(error.localizedDescription)
            lastError = wrapped
            logger.error("Sign-out failed: \(error.localizedDescription)")
            throw wrapped
        }
    }

    func restoreSession() async {
        isLoading = true
        lastError = nil
        defer {
            isLoading = false
            markSessionResolved()
        }

        do {
            let nextSession = try await client.auth.session
            apply(session: nextSession)
            logger.info("Restored Supabase session")
        } catch AuthError.sessionMissing {
            apply(session: nil)
            logger.debug("No persisted Supabase session")
        } catch {
            apply(session: client.auth.currentSession)
            lastError = .sessionRestoreFailed(error.localizedDescription)
            logger.error("Session restore failed: \(error.localizedDescription)")
        }
    }

    /// Calls `delete-account` with the user's JWT. Requires a real
    /// `SUPABASE_SERVICE_ROLE_KEY` on the function (M0-11); never ship that key in the app.
    func deleteAccount() async throws {
        guard isSignedIn else {
            let missing = PluriAuthError.notSignedIn
            lastError = missing
            throw missing
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let hintUserID = appUserID.flatMap(UUID.init(uuidString:))
            try await client.functions.invoke("delete-account")
            if let hintUserID {
                OnboardingCompletionHintStore.clear(userID: hintUserID)
            }
            apply(session: nil)
            try? await client.auth.signOut()
            logger.info("Account deleted via delete-account Edge Function")
        } catch {
            let wrapped = PluriAuthError.accountDeletionFailed(error.localizedDescription)
            lastError = wrapped
            logger.error("Account deletion failed: \(error.localizedDescription)")
            throw wrapped
        }
    }

    // MARK: - Private

    private func startListeningToAuthState() {
        Task { [weak self] in
            guard let self else { return }
            for await (_, nextSession) in client.auth.authStateChanges {
                self.apply(session: nextSession)
                self.markSessionResolved()
            }
        }
    }

    private func apply(session nextSession: Session?) {
        session = nextSession
    }

    private func markSessionResolved() {
        if !hasResolvedSession {
            hasResolvedSession = true
        }
    }

    private func mapAuthError(_ error: Error, fallback: PluriAuthError) -> PluriAuthError {
        let message = error.localizedDescription.lowercased()
        if message.localizedStandardContains("invalid login")
            || message.localizedStandardContains("invalid credentials") {
            return .invalidCredentials
        }
        if message.localizedStandardContains("already registered")
            || message.localizedStandardContains("already been registered")
            || message.localizedStandardContains("user already exists") {
            return .emailAlreadyRegistered
        }
        if message.localizedStandardContains("password")
            && (message.localizedStandardContains("weak")
                || message.localizedStandardContains("at least")) {
            return .weakPassword
        }
        if message.localizedStandardContains("network")
            || message.localizedStandardContains("offline")
            || message.localizedStandardContains("internet") {
            return .networkUnavailable
        }
        if message.localizedStandardContains("otp")
            || message.localizedStandardContains("token")
            || (message.localizedStandardContains("invalid") && message.localizedStandardContains("code")) {
            return .invalidOTP
        }
        return fallback
    }
}
