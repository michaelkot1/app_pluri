import Foundation
import Supabase

/// In-memory auth stand-in for previews and unit tests (M2-04 / M2-05 / M2-11).
@MainActor
@Observable
final class MockSupabaseAuthService: SupabaseAuthServicing {
    private(set) var session: Session?
    private(set) var hasResolvedSession: Bool
    private(set) var isLoading = false
    private(set) var lastError: PluriAuthError?

    /// When `true`, `deleteAccount()` throws `accountDeletionFailed`.
    var shouldFailAccountDeletion = false
    /// When set, the next email/Apple auth call throws this error.
    var nextAuthError: PluriAuthError?
    /// When `true`, `signUp` succeeds without leaving the user signed in (email confirm).
    var signUpLeavesSignedOut = false
    /// Expected OTP for `verifyOTP` in tests; defaults to `"123456"`.
    var expectedOTP = "123456"
    private(set) var verifyOTPCallCount = 0
    private(set) var resendOTPCallCount = 0
    private(set) var lastResendEmail: String?

    private var signedIn: Bool
    /// Stand-in id when signed in without a real Supabase `Session`/`User`.
    var mockAppUserID = UUID().uuidString

    var user: User? { session?.user }
    var appUserID: String? { signedIn ? (user?.id.uuidString ?? mockAppUserID) : nil }
    var isSignedIn: Bool { signedIn }

    init(isSignedIn: Bool = false, hasResolvedSession: Bool = false) {
        self.signedIn = isSignedIn
        self.hasResolvedSession = hasResolvedSession
    }

    func signInWithApple(idToken: String, nonce: String?) async throws {
        _ = idToken
        _ = nonce
        try await completeAuth(signedInAfterSuccess: true)
    }

    func signUp(email: String, password: String) async throws {
        _ = email
        _ = password
        try await completeAuth(signedInAfterSuccess: !signUpLeavesSignedOut)
    }

    func signIn(email: String, password: String) async throws {
        _ = email
        _ = password
        try await completeAuth(signedInAfterSuccess: true)
    }

    func verifyOTP(email: String, token: String, type: EmailOTPType) async throws {
        _ = email
        _ = type
        verifyOTPCallCount += 1
        isLoading = true
        defer {
            isLoading = false
            hasResolvedSession = true
        }
        if let nextAuthError {
            let error = nextAuthError
            self.nextAuthError = nil
            lastError = error
            throw error
        }
        guard token == expectedOTP else {
            lastError = .invalidOTP
            throw PluriAuthError.invalidOTP
        }
        signedIn = true
        lastError = nil
    }

    func resendSignupOTP(email: String) async throws {
        resendOTPCallCount += 1
        lastResendEmail = email
        isLoading = true
        defer { isLoading = false }
        if let nextAuthError {
            let error = nextAuthError
            self.nextAuthError = nil
            lastError = error
            throw error
        }
        lastError = nil
    }

    private func completeAuth(signedInAfterSuccess: Bool) async throws {
        isLoading = true
        defer {
            isLoading = false
            hasResolvedSession = true
        }
        if let nextAuthError {
            let error = nextAuthError
            self.nextAuthError = nil
            lastError = error
            throw error
        }
        signedIn = signedInAfterSuccess
        lastError = nil
    }

    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }
        if let idString = appUserID, let userID = UUID(uuidString: idString) {
            OnboardingCompletionHintStore.clear(userID: userID)
        }
        signedIn = false
        session = nil
        lastError = nil
        hasResolvedSession = true
    }

    func restoreSession() async {
        isLoading = true
        defer {
            isLoading = false
            hasResolvedSession = true
        }
        lastError = nil
    }

    func deleteAccount() async throws {
        guard signedIn else {
            let missing = PluriAuthError.notSignedIn
            lastError = missing
            throw missing
        }
        isLoading = true
        defer { isLoading = false }
        if shouldFailAccountDeletion {
            let failure = PluriAuthError.accountDeletionFailed("Mock deletion failure")
            lastError = failure
            throw failure
        }
        if let idString = appUserID, let userID = UUID(uuidString: idString) {
            OnboardingCompletionHintStore.clear(userID: userID)
        }
        signedIn = false
        session = nil
        lastError = nil
    }
}
