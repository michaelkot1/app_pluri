import Foundation
import os.log

/// Root navigation phase per PLAN §1.2 (M2-18): Splash → Onboarding → Paywall → Main.
enum AppPhase: Equatable {
    /// Brand splash while auth session + RevenueCat customer info hydrate — avoids
    /// flashing onboarding or the paywall before launch routing is known.
    case splash
    /// Fresh install, signed-out, or signed-in with incomplete onboarding.
    case onboarding
    /// Either the end-of-onboarding paywall (payload present) or the locked
    /// lapsed-entitlement paywall (restored state present, payload nil).
    case paywall
    /// Main TabView shell (Home · Plan · Insights · Community · Recipe).
    case main
}

/// Answers + generated plan carried from onboarding into the paywall phase, kept
/// until the post-unlock flush succeeds so nothing is lost on failure (M2-14).
/// Stored outside `AppPhase` because `OnboardingAnswers` is a reference type.
@MainActor
struct OnboardingPaywallPayload {
    let answers: OnboardingAnswers
    let plan: GeneratedPlan
}

/// Root router (M2-18): resolves the launch phase from auth session + entitlement
/// state, then drives phase transitions for the onboarding → paywall → Main funnel,
/// the lapsed locked paywall, and sign-out / delete-account reroutes.
@MainActor
@Observable
final class AppRouter {
    private(set) var phase: AppPhase = .splash
    /// Set while a new user is in the paywall phase; cleared after a successful flush.
    private(set) var paywallPayload: OnboardingPaywallPayload?
    /// Remotely restored profile + plan for returning users (M2-15). Preserved across
    /// the locked paywall so lapsing never discards content (SPEC §4).
    private(set) var restoredState: RestoredUserState?

    private var isSplashFinished = false
    private var resolvedLaunchPhase: AppPhase?

    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "AppRouter")

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

    // MARK: - Splash gating

    /// Called when the splash brand moment has played; the first transition waits
    /// for both this and `resolve` so neither can flash the wrong phase.
    func finishSplash() {
        isSplashFinished = true
        applyResolvedLaunchPhaseIfReady()
    }

    // MARK: - Launch resolution

    /// Launch-time routing: wait for session/entitlement hydration, retry the flush
    /// checkpoint, re-alias RevenueCat, restore remote state, then pick the phase:
    /// signed-out / incomplete → Onboarding; completed + entitled → Main;
    /// completed + lapsed → locked Paywall (content preserved).
    func resolve(
        authService: any SupabaseAuthServicing,
        subscriptionService: any SubscriptionServicing,
        flushService: any OnboardingFlushServicing,
        restoreService: any RemotePlanRestoreServicing
    ) async {
        await waitUntilHydrated(authService: authService, subscriptionService: subscriptionService)

        guard authService.isSignedIn,
              let idString = authService.appUserID,
              let userID = UUID(uuidString: idString) else {
            setResolvedLaunchPhase(.onboarding, restored: nil)
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

        guard Self.shouldSkipQuestionnaire(
            restored: restored,
            userID: userID,
            restoreFailed: restoreFailed
        ) else {
            setResolvedLaunchPhase(.onboarding, restored: nil)
            return
        }

        if !restoreFailed, restored != nil {
            OnboardingCompletionHintStore.markCompleted(userID: userID)
        }

        if subscriptionService.isPluriProActive {
            setResolvedLaunchPhase(.main, restored: restored)
        } else {
            // Lapsed: locked paywall, restored content preserved (SPEC §4).
            setResolvedLaunchPhase(.paywall, restored: restored)
        }
    }

    /// Returning entitled sign-in mid-onboarding (M2-12/M2-15): re-run the full
    /// launch classification so restore + entitlement decide Main vs locked paywall.
    func reclassifyAfterReturningSignIn(
        authService: any SupabaseAuthServicing,
        subscriptionService: any SubscriptionServicing,
        flushService: any OnboardingFlushServicing,
        restoreService: any RemotePlanRestoreServicing
    ) async {
        phase = .splash
        resolvedLaunchPhase = nil
        await resolve(
            authService: authService,
            subscriptionService: subscriptionService,
            flushService: flushService,
            restoreService: restoreService
        )
    }

    // MARK: - Funnel transitions

    /// End of onboarding: the generated plan + answers enter the paywall phase.
    func showPaywall(answers: OnboardingAnswers, plan: GeneratedPlan) {
        paywallPayload = OnboardingPaywallPayload(answers: answers, plan: plan)
        phase = .paywall
    }

    /// Successful post-unlock flush (M2-14) → Main with the locally generated plan.
    func completeOnboardingFlush() {
        if let payload = paywallPayload {
            restoredState = Self.restoredState(from: payload)
        }
        paywallPayload = nil
        phase = .main
    }

    /// Lapsed user restored or repurchased the entitlement on the locked paywall.
    func unlockFromLockedPaywall() {
        phase = .main
    }

    /// Reroute after a successful sign-out / account deletion (M2-17).
    func resetToOnboarding() {
        paywallPayload = nil
        restoredState = nil
        phase = .onboarding
    }

    // MARK: - Private

    private func setResolvedLaunchPhase(_ resolved: AppPhase, restored: RestoredUserState?) {
        restoredState = restored
        resolvedLaunchPhase = resolved
        applyResolvedLaunchPhaseIfReady()
    }

    private func applyResolvedLaunchPhaseIfReady() {
        guard phase == .splash, isSplashFinished, let resolvedLaunchPhase else { return }
        phase = resolvedLaunchPhase
    }

    /// Main/Profile content for a just-flushed new user, built from the same mapper
    /// round-trip the remote restore would produce (the throwaway id is dropped).
    private static func restoredState(from payload: OnboardingPaywallPayload) -> RestoredUserState? {
        guard let row = try? OnboardingSyncMapper.profileRow(userID: UUID(), answers: payload.answers) else {
            return nil
        }
        return RestoredUserState(
            profile: OnboardingSyncMapper.hydrateProfile(from: row),
            plan: payload.plan
        )
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
