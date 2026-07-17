import Foundation

/// Placeholder reminder reconciler until the M3-15 local notification
/// service exists: does nothing, on purpose. Keeping the hook wired now
/// means M3-15 only swaps the injected implementation.
@MainActor
final class NoopWorkoutReminderReconciler: WorkoutReminderReconciling {
    // Nonisolated so the type can be a default argument of `PlanStore.init`,
    // whose default expressions are evaluated outside the main actor.
    nonisolated init() {}

    func reconcileReminders(for plan: GeneratedPlan) async {}
}
