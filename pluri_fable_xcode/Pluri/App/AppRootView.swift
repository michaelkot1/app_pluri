import SwiftUI

/// Root of the app: Splash → Onboarding (M1). Later milestones extend this
/// into the full Splash → Onboarding → Paywall → Main router (PLAN §1.2).
/// Owns shared services so entitlement (M2-08) and auth session (M2-04) hydrate
/// at launch for Paywall and future routing (M2-18) — without flashing locked UI.
struct AppRootView: View {
    @State private var authService: SupabaseAuthService
    @State private var subscriptionService: SubscriptionService

    #if DEBUG
    @State private var showsDebugGallery = false
    #endif

    init() {
        let supabase = SupabaseService()
        _authService = State(initialValue: SupabaseAuthService(supabaseService: supabase))
        _subscriptionService = State(initialValue: SubscriptionService())
    }

    var body: some View {
        OnboardingRootView()
            .environment(subscriptionService)
            .environment(authService)
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
