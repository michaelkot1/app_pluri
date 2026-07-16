import SwiftUI

/// Post-paywall confirmation + onboarding flush (M2-14). Unlock does **not**
/// imply account creation — the user is already authenticated (SPEC §14 #29).
/// Main TabView remains M2-18.
struct PaywallUnlockedPlaceholderView: View {
    var answers: OnboardingAnswers
    var plan: GeneratedPlan

    @Environment(SupabaseAuthService.self) private var authService
    @Environment(SupabaseOnboardingFlushService.self) private var flushService

    @State private var phase: Phase = .flushing
    @State private var errorMessage: String?

    private enum Phase {
        case flushing
        case success
        case failed
    }

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

                if let errorMessage {
                    Text(errorMessage)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.statusRedSoft)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, PluriSpacing.lg)

            if phase == .flushing {
                ProgressView()
            } else if phase == .failed {
                Button("Try again") {
                    Task { await flush() }
                }
                .buttonStyle(.pluriPrimary)
                .padding(.horizontal, PluriSpacing.lg)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PluriColor.bgCanvas)
        .navigationBarBackButtonHidden(true)
        .task { await flush() }
    }

    private var iconName: String {
        switch phase {
        case .flushing: "icloud.and.arrow.up"
        case .success: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var title: String {
        switch phase {
        case .flushing: "Saving your plan"
        case .success: "You're in"
        case .failed: "Couldn't save yet"
        }
    }

    private var subtitle: String {
        switch phase {
        case .flushing:
            "We’re writing your profile and plan to your account."
        case .success:
            "Your plan is unlocked and saved. Home lands with Main routing next (M2-18)."
        case .failed:
            "Your plan is still on this device. We’ll keep it until saving succeeds."
        }
    }

    private func flush() async {
        phase = .flushing
        errorMessage = nil

        guard let idString = authService.appUserID, let userID = UUID(uuidString: idString) else {
            phase = .failed
            errorMessage = PluriSyncError.notSignedIn.userFacingMessage
            return
        }

        do {
            try await flushService.flush(userID: userID, answers: answers, plan: plan)
            phase = .success
        } catch let error as PluriSyncError {
            phase = .failed
            errorMessage = error.userFacingMessage
        } catch {
            phase = .failed
            errorMessage = PluriSyncError.flushFailed(error.localizedDescription).userFacingMessage
        }
    }
}

#Preview {
    let answers = OnboardingAnswers()
    answers.name = "Alex"
    answers.goal = .buildMuscle
    answers.experience = .oneToSixMonths
    answers.regularity = .onAndOff
    answers.location = .commercialGym
    let input = PlanInput(answers: answers)
    let plan = try! PlanEngine.generate(
        input: input,
        catalog: .workoutXPreviewFixtures,
        seed: input.deterministicSeed
    )
    return NavigationStack {
        PaywallUnlockedPlaceholderView(answers: answers, plan: plan)
            .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
            .environment(SupabaseOnboardingFlushService(supabaseService: SupabaseService()))
    }
}
