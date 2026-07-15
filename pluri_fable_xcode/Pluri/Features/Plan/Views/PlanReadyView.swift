import SwiftUI

/// "Your plan is ready" screen (M1-18 / SPEC §3.3 → §4). Teases the generated
/// plan — weeks, sessions per week, and a first-session preview — then hands
/// off to the paywall. The paywall itself is M2, so the forward transition is
/// a stub (`PlanReadyPaywallStubView`).
///
/// In DEBUG builds a "View full plan" button opens `PlanDumpView`, the M1 exit
/// check's plan-dump view.
struct PlanReadyView: View {
    var plan: GeneratedPlan
    var userName: String

    @State private var showsPaywallStub = false
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

            Button("Unlock my plan", action: { showsPaywallStub = true })
                .buttonStyle(.pluriPrimary)
                .padding(.horizontal, PluriSpacing.lg)
                .padding(.bottom, PluriSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PluriColor.bgCanvas)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showsPaywallStub) {
            PlanReadyPaywallStubView()
        }
        #if DEBUG
        .sheet(isPresented: $showsDebugDump) {
            NavigationStack {
                PlanDumpView(plan: plan)
            }
        }
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
        PlanReadyView(plan: plan, userName: "Alex")
    }
}
