import Foundation

/// Test/preview reconciler (M3-13): records every plan it was asked to
/// reconcile so tests can assert the hook fires only after successful
/// remote persistence.
@MainActor
final class MockWorkoutReminderReconciler: WorkoutReminderReconciling {
    private(set) var reconciledPlans: [GeneratedPlan] = []

    func reconcileReminders(for plan: GeneratedPlan) async {
        reconciledPlans.append(plan)
    }
}
