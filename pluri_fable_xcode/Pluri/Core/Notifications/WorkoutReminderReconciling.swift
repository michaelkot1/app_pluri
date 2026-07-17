import Foundation

/// Reconciles scheduled workout reminders with the current plan after a
/// successful plan mutation (M3-13 hook; the real service is M3-15's
/// `WorkoutReminderService`).
///
/// The `PlanStore` calls this **after** the remote write succeeds, and the
/// call is deliberately non-throwing: a reminder problem must never roll
/// back an already-persisted plan change. Implementations own their own
/// logging / gentle surfacing. Previews and tests that don't care about
/// reminders keep the default `NoopWorkoutReminderReconciler`.
@MainActor
protocol WorkoutReminderReconciling: AnyObject {
    /// Re-derives upcoming-workout reminders from the plan's current state
    /// (schedule/cancel/update as needed).
    func reconcileReminders(for plan: GeneratedPlan) async
}
