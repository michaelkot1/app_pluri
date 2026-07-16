import SwiftUI

/// Returning entitled / completed-onboarding landing (M2-12 / M2-15 / launch gate).
/// Hydrates profile + active plan remotely when not preloaded. Main TabView routing remains M2-18.
struct WelcomeBackStubView: View {
    var restoreService: any RemotePlanRestoreServicing
    /// When set (e.g. by `AppLaunchGate`), skips a second remote fetch.
    var preloadedState: RestoredUserState? = nil

    @Environment(SupabaseAuthService.self) private var authService

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var restored: RestoredUserState?

    var body: some View {
        VStack(spacing: PluriSpacing.lg) {
            Spacer()

            Image(systemName: iconName)
                .font(.system(size: 64))
                .foregroundStyle(PluriColor.brandOrange)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: PluriSpacing.sm) {
                Text(title)
                    .font(PluriFont.title)
                    .foregroundStyle(PluriColor.textPrimary)

                Text(subtitle)
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
                    .multilineTextAlignment(.center)

                if let plan = restored?.plan {
                    Text("\(plan.weekCount) weeks · \(plan.sessionsPerWeek) workouts / week · \(plan.goal.title)")
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textTertiary)
                        .multilineTextAlignment(.center)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.statusRedSoft)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, PluriSpacing.lg)

            if isLoading {
                ProgressView()
            } else if errorMessage != nil {
                Button("Try again") {
                    Task { await load() }
                }
                .buttonStyle(.pluriPrimary)
                .padding(.horizontal, PluriSpacing.lg)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PluriColor.bgCanvas)
        .navigationBarBackButtonHidden(true)
        .task { await load() }
    }

    private var iconName: String {
        if restored?.plan != nil {
            "checkmark.seal.fill"
        } else {
            "person.crop.circle.badge.checkmark"
        }
    }

    private var title: String {
        if let name = restored?.profile.displayName, !name.isEmpty {
            "Welcome back, \(name)"
        } else {
            "Welcome back"
        }
    }

    private var subtitle: String {
        if restored?.plan != nil {
            "Your plan is restored on this device. Home lands with Main routing next (M2-18)."
        } else if restored != nil {
            "You’re signed in. We couldn’t find an active plan yet — Main routing is next (M2-18)."
        } else if isLoading {
            "Restoring your plan…"
        } else {
            "You’re signed in. Home lands with Main routing next (M2-18)."
        }
    }

    private func load() async {
        if let preloadedState {
            restored = preloadedState
            isLoading = false
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let idString = authService.appUserID, let userID = UUID(uuidString: idString) else {
            errorMessage = PluriSyncError.notSignedIn.userFacingMessage
            return
        }

        do {
            restored = try await restoreService.restore(userID: userID)
        } catch let error as PluriSyncError {
            errorMessage = error.userFacingMessage
        } catch {
            errorMessage = PluriSyncError.restoreFailed(error.localizedDescription).userFacingMessage
        }
    }
}

#Preview {
    NavigationStack {
        WelcomeBackStubView(restoreService: MockRemotePlanRestoreService())
            .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
    }
}
