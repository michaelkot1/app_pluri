import Foundation

/// Reconciles scheduled workout reminders with the current plan after a
/// successful plan mutation (M3-13 hook for the M3-15 notification service).
///
/// The `PlanStore` calls this **after** the remote write succeeds, and the
/// call is deliberately non-throwing: a reminder problem must never roll
/// back an already-persisted plan change. Implementations own their own
/// logging / gentle surfacing. Until M3-15 lands, the injected default is
/// `NoopWorkoutReminderReconciler`.
@MainActor
protocol WorkoutReminderReconciling: AnyObject {
    /// Re-derives upcoming-workout reminders from the plan's current state
    /// (schedule/cancel/update as needed).
    func reconcileReminders(for plan: GeneratedPlan) async
}
