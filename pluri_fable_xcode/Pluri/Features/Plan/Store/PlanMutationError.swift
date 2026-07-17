import Foundation

/// Typed errors for calendar/manage-plan mutations (M3-05). Surfaced gently —
/// this app never scolds (design tone).
nonisolated enum PlanMutationError: Error, Equatable, Sendable {
    /// No active plan is loaded, so there is nothing to mutate.
    case noPlan
    /// The referenced workout doesn't exist in the current plan.
    case workoutNotFound
    /// The target date falls outside the plan's start…end window.
    case dateOutsidePlan
    /// The target day already has a workout (one workout per day in v1,
    /// SPEC §14 #38).
    case dayOccupied

    var userFacingMessage: String {
        switch self {
        case .noPlan:
            "There's no active plan to update just now."
        case .workoutNotFound:
            "We couldn't find that workout in your plan."
        case .dateOutsidePlan:
            "That day is outside your current plan. Try a date within the plan."
        case .dayOccupied:
            "That day already has a workout. Pick an empty day, or move the other workout first."
        }
    }
}
