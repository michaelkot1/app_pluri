import SwiftUI

/// Root of the onboarding flow (M1-04 / M2-11): owns the answers container and the
/// router, and wires every screen into one `NavigationStack`. Splash is the
/// stack's root content; everything else is pushed via `router.path`, which
/// both a Continue tap and a back-swipe mutate identically — that's what
/// lets the progress bar (M1-07) recede correctly on back navigation.
///
/// Auth sits between name and Q1 (SPEC §3.1 / §14 #29) and is not a progress step.
struct OnboardingRootView: View {
    @Environment(SupabaseAuthService.self) private var authService

    @State private var answers = OnboardingAnswers()
    @State private var router = OnboardingRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            SplashView {
                router.start()
            }
            .navigationDestination(for: OnboardingDestination.self) { destination in
                view(for: destination)
            }
        }
    }

    @ViewBuilder
    private func view(for destination: OnboardingDestination) -> some View {
        switch destination {
        case .name:
            NameEntryView(answers: answers) {
                if authService.isSignedIn {
                    router.advance(to: .q1FitnessType)
                } else {
                    router.advance(to: .account)
                }
            }
        case .account:
            AccountAuthView(
                onContinueOnboarding: { router.advance(to: .q1FitnessType) }
            )
        case .q1FitnessType:
            Q1FitnessTypeView(answers: answers, progress: destination.progress) { router.advance(from: destination) }
        case .q2Goal:
            Q2GoalView(answers: answers, progress: destination.progress) { router.advance(from: destination) }
        case .q3Experience:
            Q3ExperienceView(answers: answers, progress: destination.progress) { router.advance(from: destination) }
        case .q4Regularity:
            Q4RegularityView(answers: answers, progress: destination.progress) { router.advance(from: destination) }
        case .q5Location:
            Q5LocationView(answers: answers, progress: destination.progress) { router.advance(from: destination) }
        case .q6Equipment:
            Q6EquipmentView(answers: answers, progress: destination.progress) { router.advance(from: destination) }
        case .q7Injuries:
            Q7InjuriesView(answers: answers, progress: destination.progress) { router.advance(from: destination) }
        case .q8TrainingDays:
            Q8TrainingDaysView(answers: answers, progress: destination.progress) { router.advance(from: destination) }
        case .q9Schedule:
            Q9ScheduleView(answers: answers, progress: destination.progress) { router.advance(from: destination) }
        case .q10Duration:
            Q10DurationView(answers: answers, progress: destination.progress) { router.advance(from: destination) }
        case .q11AboutYou:
            Q11AboutYouView(answers: answers, progress: destination.progress) { router.advance(from: destination) }
        case .q12CaloriesAllergies:
            Q12CaloriesAllergiesView(answers: answers, progress: destination.progress) { router.advance(from: destination) }
        case .q13StartDate:
            Q13StartDateView(answers: answers, progress: destination.progress) { router.advance(from: destination) }
        case .planGeneration:
            PlanGeneratingView(answers: answers)
        }
    }
}

#Preview {
    OnboardingRootView()
        .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
        .environment(SubscriptionService(configurePurchases: false))
        .environment(SupabaseOnboardingFlushService(supabaseService: SupabaseService()))
        .environment(SupabaseRemotePlanRestoreService(supabaseService: SupabaseService()))
}
