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
    /// The workout is already completed or skipped — history is immutable,
    /// so finished workouts can't be moved (M3-13).
    case workoutFinished
    /// The signed-in user id couldn't be resolved for a profile write.
    case missingUser

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
        case .workoutFinished:
            "That workout is already part of your history, so it stays where it happened."
        case .missingUser:
            "We couldn't confirm your account just now. Please try again in a moment."
        }
    }
}
