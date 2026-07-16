import Foundation

/// Writes onboarding answers + generated plan to Supabase after paywall unlock (M2-14).
@MainActor
protocol OnboardingFlushServicing: AnyObject {
    /// Upserts `profiles` and inserts the plan tree under RLS. Retries transient failures.
    /// Local answers/plan are not cleared on failure; a UserDefaults checkpoint is kept until success.
    func flush(userID: UUID, answers: OnboardingAnswers, plan: GeneratedPlan) async throws
    /// Retries a previously checkpointed flush (e.g. after relaunch). Returns `true` if a checkpoint was written.
    @discardableResult
    func retryPendingCheckpointIfNeeded() async throws -> Bool
}
