import Foundation
import Supabase

/// In-memory auth stand-in for previews and unit tests (M2-04 / M2-05).
@MainActor
@Observable
final class MockSupabaseAuthService: SupabaseAuthServicing {
    private(set) var session: Session?
    private(set) var hasResolvedSession: Bool
    private(set) var isLoading = false
    private(set) var lastError: PluriAuthError?

    /// When `true`, `deleteAccount()` throws `accountDeletionFailed`.
    var shouldFailAccountDeletion = false

    private var signedIn: Bool

    var user: User? { session?.user }
    var isSignedIn: Bool { signedIn }

    init(isSignedIn: Bool = false, hasResolvedSession: Bool = false) {
        self.signedIn = isSignedIn
        self.hasResolvedSession = hasResolvedSession
    }

    func signInWithApple(idToken: String, nonce: String?) async throws {
        _ = idToken
        _ = nonce
        isLoading = true
        defer {
            isLoading = false
            hasResolvedSession = true
        }
        signedIn = true
        lastError = nil
    }

    func signUp(email: String, password: String) async throws {
        _ = email
        _ = password
        isLoading = true
        defer {
            isLoading = false
            hasResolvedSession = true
        }
        signedIn = true
        lastError = nil
    }

    func signIn(email: String, password: String) async throws {
        _ = email
        _ = password
        isLoading = true
        defer {
            isLoading = false
            hasResolvedSession = true
        }
        signedIn = true
        lastError = nil
    }

    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }
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
        signedIn = false
        session = nil
        lastError = nil
    }
}
