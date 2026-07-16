import Foundation
import Observation
import os.log

/// Account action currently in flight, so the UI can show progress and the
/// view model can reject duplicate submissions (M2-17).
enum ProfileAccountAction: Equatable, Sendable {
    case signOut
    case deleteAccount
}

/// Orchestrates Profile account actions (M2-17): sign out and delete account
/// against protocol-injected auth + subscription services, then asks the root
/// to reroute to the signed-out entry via `onAccountEnded`.
@MainActor
@Observable
final class ProfileViewModel {
    private(set) var activeAction: ProfileAccountAction?
    private(set) var lastError: PluriAuthError?
    var isDeleteConfirmationPresented = false

    var isBusy: Bool { activeAction != nil }

    private let authService: any SupabaseAuthServicing
    private let subscriptionService: any SubscriptionServicing
    private let onAccountEnded: @MainActor @Sendable () -> Void
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "ProfileViewModel")

    init(
        authService: any SupabaseAuthServicing,
        subscriptionService: any SubscriptionServicing,
        onAccountEnded: @escaping @MainActor @Sendable () -> Void
    ) {
        self.authService = authService
        self.subscriptionService = subscriptionService
        self.onAccountEnded = onAccountEnded
    }

    /// Ends the Supabase session (which also clears the onboarding hint),
    /// drops the RevenueCat alias, and clears this user's pending checkpoint.
    func signOut() async {
        guard activeAction == nil else { return }
        activeAction = .signOut
        lastError = nil
        defer { activeAction = nil }

        let userID = currentUserID
        do {
            try await authService.signOut()
        } catch let error as PluriAuthError {
            lastError = error
            return
        } catch {
            lastError = .unknown(error.localizedDescription)
            return
        }

        await endLocalIdentity(userID: userID)
        onAccountEnded()
    }

    /// Opens the destructive confirmation dialog (SPEC §5.2).
    func requestDeleteAccount() {
        guard activeAction == nil else { return }
        isDeleteConfirmationPresented = true
    }

    func cancelDeleteAccount() {
        isDeleteConfirmationPresented = false
    }

    /// Invokes the `delete-account` Edge Function; local state is wiped only
    /// after the remote deletion succeeds. On failure the user stays signed in
    /// with local state intact.
    func confirmDeleteAccount() async {
        guard activeAction == nil else { return }
        isDeleteConfirmationPresented = false
        activeAction = .deleteAccount
        lastError = nil
        defer { activeAction = nil }

        let userID = currentUserID
        do {
            try await authService.deleteAccount()
        } catch let error as PluriAuthError {
            lastError = error
            return
        } catch {
            lastError = .accountDeletionFailed(error.localizedDescription)
            return
        }

        await endLocalIdentity(userID: userID)
        onAccountEnded()
    }

    // MARK: - Private

    private var currentUserID: UUID? {
        authService.appUserID.flatMap(UUID.init(uuidString:))
    }

    private func endLocalIdentity(userID: UUID?) async {
        if let userID {
            FlushCheckpointStore.clear(userID: userID)
        }
        do {
            try await subscriptionService.logOut()
        } catch {
            // Non-fatal: the next sign-in re-aliases RevenueCat (M2-11 / launch gate).
            logger.error("RevenueCat logOut failed after account action: \(error.localizedDescription)")
        }
    }
}
