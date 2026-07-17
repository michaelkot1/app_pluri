import Foundation

/// No-op reminder reconciler used as the `PlanStore` default for previews
/// and tests that don't care about reminders. Production injects the live
/// `WorkoutReminderService` from `AppRootView`.
@MainActor
final class NoopWorkoutReminderReconciler: WorkoutReminderReconciling {
    // Nonisolated so the type can be a default argument of `PlanStore.init`,
    // whose default expressions are evaluated outside the main actor.
    nonisolated init() {}

    func reconcileReminders(for plan: GeneratedPlan) async {}
}
