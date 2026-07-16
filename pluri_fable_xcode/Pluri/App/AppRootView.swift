import SwiftUI

/// Root of the app: launch gate → Onboarding **or** welcome-back (pre–M2-18).
/// Later milestones extend this into Splash → Onboarding → Paywall → Main (PLAN §1.2).
/// Owns shared services so entitlement (M2-08) and auth session (M2-04) hydrate
/// at launch — skips the questionnaire when the account already has a completed onboarding/plan.
struct AppRootView: View {
    @State private var authService: SupabaseAuthService
    @State private var subscriptionService: SubscriptionService
    @State private var flushService: SupabaseOnboardingFlushService
    @State private var restoreService: SupabaseRemotePlanRestoreService
    @State private var launchGate = AppLaunchGate()

    #if DEBUG
    @State private var showsDebugGallery = false
    #endif

    init() {
        let supabase = SupabaseService()
        _authService = State(initialValue: SupabaseAuthService(supabaseService: supabase))
        _subscriptionService = State(initialValue: SubscriptionService())
        _flushService = State(initialValue: SupabaseOnboardingFlushService(supabaseService: supabase))
        _restoreService = State(initialValue: SupabaseRemotePlanRestoreService(supabaseService: supabase))
    }

    var body: some View {
        Group {
            switch launchGate.route {
            case .resolving:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PluriColor.bgCanvas)
            case .onboarding:
                OnboardingRootView()
            case .welcomeBack(let restored):
                NavigationStack {
                    WelcomeBackStubView(
                        restoreService: restoreService,
                        preloadedState: restored
                    )
                }
            }
        }
        .environment(subscriptionService)
        .environment(authService)
        .environment(flushService)
        .environment(restoreService)
        .task {
            await launchGate.resolve(
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
}

#Preview {
    AppRootView()
}
