import SwiftUI

/// "Your plan is ready" screen (M1-18 / SPEC §3.3 → §4). Teases the generated
/// plan — weeks, sessions per week, and a first-session preview — then presents
/// the RevenueCat paywall (M2-09). Successful unlock (or DEBUG long-press bypass)
/// advances to a temporary post-unlock placeholder until flush (M2-14) and Main (M2-18).
/// The user is already authenticated (auth after name — M2-11).
///
/// In DEBUG builds a "View full plan" button opens `PlanDumpView`, the M1 exit
/// check's plan-dump view.
struct PlanReadyView: View {
    var plan: GeneratedPlan
    var userName: String
    var answers: OnboardingAnswers

    @Environment(SubscriptionService.self) private var subscriptionService

    @State private var showsPaywall = false
    @State private var isUnlocked = false
    #if DEBUG
    @State private var showsDebugDump = false
    #endif

    private var trimmedName: String {
        userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var title: String {
        trimmedName.isEmpty ? "Your plan is ready!" : "\(trimmedName), your plan is ready!"
    }

    var body: some View {
        Group {
            if isUnlocked || subscriptionService.isPluriProActive {
                PaywallUnlockedPlaceholderView(answers: answers, plan: plan)
            } else {
                planReadyContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PluriColor.bgCanvas)
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $showsPaywall) {
            PluriPaywallView {
                isUnlocked = true
            }
            .environment(subscriptionService)
        }
        #if DEBUG
        .sheet(isPresented: $showsDebugDump) {
            NavigationStack {
                PlanDumpView(plan: plan)
            }
        }
        #endif
        .onAppear {
            if subscriptionService.isPluriProActive {
                isUnlocked = true
            }
        }
    }

    private var planReadyContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: PluriSpacing.lg) {
                    hero
                    PlanSummaryCard(plan: plan)
                    if let firstSession = plan.firstSession {
                        PlanFirstSessionCard(session: firstSession)
                    }
                    #if DEBUG
                    Button("View full plan", systemImage: "ladybug") {
                        showsDebugDump = true
                    }
                    .buttonStyle(.pluriSecondary)
                    #endif
                }
                .padding(.horizontal, PluriSpacing.lg)
                .padding(.vertical, PluriSpacing.lg)
            }
            .scrollIndicators(.hidden)

            unlockButton
                .padding(.horizontal, PluriSpacing.lg)
                .padding(.bottom, PluriSpacing.md)
        }
    }

    private var unlockButton: some View {
        Button("Unlock my plan") {
            showsPaywall = true
        }
        .buttonStyle(.pluriPrimary)
        #if DEBUG
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.8).onEnded { _ in
                subscriptionService.enableDebugPaywallBypass()
                isUnlocked = true
            }
        )
        .accessibilityHint("Long-press to skip paywall (DEBUG)")
        #endif
    }

    private var hero: some View {
        VStack(spacing: PluriSpacing.md) {
            ZStack {
                Circle()
                    .fill(PluriColor.sunriseGradient)
                    .frame(width: 160, height: 160)
                Image(systemName: "checkmark")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(title)
                .font(PluriFont.title)
                .foregroundStyle(PluriColor.textPrimary)
                .multilineTextAlignment(.center)

            Text("Built from everything you told us — your equipment, goal, schedule, and any injuries.")
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, PluriSpacing.md)
    }
}

#Preview {
    let input = PlanInput(
        goal: .buildMuscle,
        experience: .oneToSixMonths,
        regularity: .onAndOff,
        equipment: Set(EquipmentCatalog.all),
        injuries: [:],
        trainingDays: [.monday, .wednesday, .friday],
        scheduleType: .scheduled,
        planLengthWeeks: 6,
        sessionDurationMinutes: 60,
        startDate: .now
    )
    let plan = try! PlanEngine.generate(
        input: input,
        catalog: .workoutXPreviewFixtures,
        seed: input.deterministicSeed
    )
    return NavigationStack {
        PlanReadyView(plan: plan, userName: "Alex", answers: OnboardingAnswers())
            .environment(SubscriptionService(configurePurchases: false))
    }
}
