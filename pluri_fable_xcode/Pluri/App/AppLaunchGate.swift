import Foundation
import os.log

/// Cold-launch destination before Main TabView exists (pre–M2-18).
enum AppLaunchRoute: Equatable {
    /// Waiting on auth session + RevenueCat customer-info resolution.
    case resolving
    /// Fresh install, signed-out, or signed-in incomplete → questionnaire stack.
    case onboarding
    /// Signed-in with completed onboarding and/or an active plan → skip questionnaire.
    case welcomeBack(RestoredUserState?)
}

/// Launch-time routing: wait for session/entitlement hydration, retry flush checkpoint,
/// re-alias RevenueCat, restore remote state, and skip the questionnaire when completed.
@MainActor
@Observable
final class AppLaunchGate {
    private(set) var route: AppLaunchRoute = .resolving

    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "AppLaunchGate")

    /// Pure skip criterion (owner): `onboardingCompleted` **or** an active plan.
    /// Local UserDefaults hint applies only when remote restore is unavailable.
    static func shouldSkipQuestionnaire(
        restored: RestoredUserState?,
        userID: UUID,
        restoreFailed: Bool
    ) -> Bool {
        if restoreFailed {
            return OnboardingCompletionHintStore.isCompleted(userID: userID)
        }
        guard let restored else { return false }
        return restored.profile.onboardingCompleted || restored.plan != nil
    }

    func resolve(
        authService: any SupabaseAuthServicing,
        subscriptionService: any SubscriptionServicing,
        flushService: any OnboardingFlushServicing,
        restoreService: any RemotePlanRestoreServicing
    ) async {
        route = .resolving
        await waitUntilHydrated(authService: authService, subscriptionService: subscriptionService)

        guard authService.isSignedIn,
              let idString = authService.appUserID,
              let userID = UUID(uuidString: idString) else {
            route = .onboarding
            return
        }

        // Cold launch may not have run auth-path RevenueCat logIn yet.
        do {
            try await subscriptionService.logIn(appUserID: idString)
        } catch {
            logger.error("Launch RevenueCat logIn failed: \(error.localizedDescription)")
        }

        do {
            let flushedCheckpoint = try await flushService.retryPendingCheckpointIfNeeded()
            if flushedCheckpoint {
                OnboardingCompletionHintStore.markCompleted(userID: userID)
            }
        } catch {
            logger.error("Checkpoint retry failed: \(error.localizedDescription)")
        }

        let restored: RestoredUserState?
        let restoreFailed: Bool
        do {
            restored = try await restoreService.restore(userID: userID)
            restoreFailed = false
        } catch {
            logger.error("Launch restore failed: \(error.localizedDescription)")
            restored = nil
            restoreFailed = true
        }

        if Self.shouldSkipQuestionnaire(
            restored: restored,
            userID: userID,
            restoreFailed: restoreFailed
        ) {
            if !restoreFailed, restored != nil {
                OnboardingCompletionHintStore.markCompleted(userID: userID)
            }
            route = .welcomeBack(restored)
        } else {
            route = .onboarding
        }
    }

    private func waitUntilHydrated(
        authService: any SupabaseAuthServicing,
        subscriptionService: any SubscriptionServicing
    ) async {
        let deadline = ContinuousClock.now + .seconds(30)
        while ContinuousClock.now < deadline {
            if authService.hasResolvedSession, subscriptionService.hasResolvedCustomerInfo {
                return
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        logger.error("Timed out waiting for auth/subscription hydration")
    }
}
