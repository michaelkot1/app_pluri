import SwiftData
import SwiftUI
import os.log

/// M1-18 — the terminal onboarding screen. Runs `PlanEngine` (via
/// `PlanGenerationService`) with a deliberate progress animation (SPEC §3.3),
/// silently retries on failure, and only then shows a gentle "try again"
/// state. On success it swaps to `PlanReadyView`.
///
/// This view coordinates the whole generate → ready flow itself rather than
/// pushing more `OnboardingDestination`s, because the generated `GeneratedPlan`
/// is a value that the `Hashable` destination enum can't carry.
struct PlanGeneratingView: View {
    var answers: OnboardingAnswers

    @Environment(\.modelContext) private var modelContext

    @State private var phase: Phase = .generating
    @State private var plan: GeneratedPlan?
    @State private var attempt = 0

    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "PlanGeneratingView")

    /// Silent background retries before surfacing a failure (SPEC §3.3).
    private let maxRetries = 2
    /// Minimum time on screen so generation "feels deliberate" (SPEC §3.3),
    /// even when the engine returns almost instantly.
    private let minimumDisplay: Duration = .seconds(2.5)

    enum Phase {
        case generating
        case failed
    }

    var body: some View {
        Group {
            if let plan {
                PlanReadyView(plan: plan, userName: answers.name, answers: answers)
            } else {
                switch phase {
                case .generating:
                    PlanGeneratingProgressView(userName: answers.name)
                case .failed:
                    PlanGenerationFailedView { retry() }
                }
            }
        }
        .navigationBarBackButtonHidden(plan != nil || phase == .generating)
        .task(id: attempt) { await generate() }
    }

    private func retry() {
        phase = .generating
        attempt += 1
    }

    private func generate() async {
        let input = PlanInput(answers: answers)
        // Catalog reads come from the Supabase-seeded snapshot, not the live
        // WorkoutX API — the free tier can't serve a full catalog fetch within
        // its rate limits (SPEC §14 decision #25).
        let service = PlanGenerationService(
            store: ExerciseCatalogStore(modelContext: modelContext, client: SupabaseExerciseCatalogClient())
        )

        let clock = ContinuousClock()
        let started = clock.now

        for tryIndex in 0...maxRetries {
            do {
                let generated = try await service.generatePlan(for: input)
                await enforceMinimumDisplay(since: started, clock: clock)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut) { plan = generated }
                return
            } catch {
                logger.error("Plan generation attempt \(tryIndex + 1) failed: \(error.localizedDescription)")
                if tryIndex < maxRetries {
                    try? await Task.sleep(for: .seconds(0.6))
                }
            }
        }

        await enforceMinimumDisplay(since: started, clock: clock)
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut) { phase = .failed }
    }

    private func enforceMinimumDisplay(since started: ContinuousClock.Instant, clock: ContinuousClock) async {
        let elapsed = clock.now - started
        if elapsed < minimumDisplay {
            try? await Task.sleep(for: minimumDisplay - elapsed)
        }
    }
}

#Preview {
    NavigationStack {
        PlanGeneratingView(answers: OnboardingAnswers())
    }
    .modelContainer(for: [CachedExercise.self, ExerciseCatalogSyncState.self], inMemory: true)
}
