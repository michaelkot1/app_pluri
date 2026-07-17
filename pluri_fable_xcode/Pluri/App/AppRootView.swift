import SwiftUI

/// Root of the app (M2-18): `AppRouter` phase switching per PLAN §1.2 —
/// Splash → Onboarding → Paywall → Main. Owns shared services so entitlement
/// (M2-08) and auth session (M2-04) hydrate behind the splash, with no
/// onboarding/paywall flash before launch routing is known.
struct AppRootView: View {
    @State private var authService: SupabaseAuthService
    @State private var subscriptionService: SubscriptionService
    @State private var flushService: SupabaseOnboardingFlushService
    @State private var restoreService: SupabaseRemotePlanRestoreService
    @State private var planStore: PlanStore
    @State private var router = AppRouter()
    @State private var themeStore = ThemeStore()

    #if DEBUG
    @State private var showsDebugGallery = false
    #endif

    init() {
        let supabase = SupabaseService()
        _authService = State(initialValue: SupabaseAuthService(supabaseService: supabase))
        _subscriptionService = State(initialValue: SubscriptionService())
        _flushService = State(initialValue: SupabaseOnboardingFlushService(supabaseService: supabase))
        _restoreService = State(initialValue: SupabaseRemotePlanRestoreService(supabaseService: supabase))
        _planStore = State(
            initialValue: PlanStore(
                mutationService: SupabasePlanMutationService(supabaseService: supabase)
            )
        )
    }

    var body: some View {
        Group {
            switch router.phase {
            case .splash:
                SplashView { router.finishSplash() }
            case .onboarding:
                OnboardingRootView(
                    onPlanReady: { answers, plan in
                        router.showPaywall(answers: answers, plan: plan)
                    },
                    onReturningEntitledSignIn: {
                        Task { await reclassifyReturningUser() }
                    }
                )
            case .paywall:
                if let payload = router.paywallPayload {
                    // End-of-onboarding paywall: answers + plan → unlock → flush → Main.
                    NavigationStack {
                        PlanReadyView(
                            plan: payload.plan,
                            userName: payload.answers.name,
                            answers: payload.answers,
                            onFlushSucceeded: { router.completeOnboardingFlush() }
                        )
                    }
                } else {
                    // Lapsed entitlement: locked paywall, restored content preserved (SPEC §4).
                    PluriPaywallView(isDismissable: false) {
                        router.unlockFromLockedPaywall()
                    }
                }
            case .main:
                MainTabView(
                    restored: router.restoredState,
                    onAccountEnded: { router.resetToOnboarding() }
                )
            }
        }
        .preferredColorScheme(themeStore.selection.colorScheme)
        .environment(subscriptionService)
        .environment(authService)
        .environment(flushService)
        .environment(restoreService)
        .environment(planStore)
        .environment(themeStore)
        .onChange(of: router.phase) { _, newPhase in
            // The shared plan store (M3-04) tracks the Main phase: hydrate it
            // from the router's restored state on entry, blank it on reroute
            // back to onboarding (sign-out / delete account).
            switch newPhase {
            case .main:
                planStore.configure(from: router.restoredState)
            case .onboarding:
                planStore.reset()
            case .splash, .paywall:
                break
            }
        }
        .task {
            await router.resolve(
                authService: authService,
                subscriptionService: subscriptionService,
                flushService: flushService,
                restoreService: restoreService
            )
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            Button("Gallery", systemImage: "paintpalette") {
                showsDebugGallery = true
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(PluriColor.textTertiary)
            .padding()
        }
        .sheet(isPresented: $showsDebugGallery) {
            ComponentGalleryView()
        }
        #endif
    }

    private func reclassifyReturningUser() async {
        await router.reclassifyAfterReturningSignIn(
            authService: authService,
            subscriptionService: subscriptionService,
            flushService: flushService,
            restoreService: restoreService
        )
    }
}

#Preview {
    AppRootView()
}
