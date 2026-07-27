import Foundation

/// Applies EF-returned Ask Pluri actions through `PlanStore` after the user
/// confirms (M6-09 / M6-10 / SPEC §14 #66h). Invalid or unknown payloads are
/// skipped (#66g). Valid actions run **in order**; the first failure stops
/// the batch (partial apply possible for earlier successes — each action has
/// its own optimistic/rollback boundary inside `PlanStore`).
@MainActor
enum AskPluriPlanActionApplier {
    /// One human-readable line for the confirm sheet summary.
    struct SummaryLine: Identifiable, Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            case add
            case remove
        }

        let id: String
        let kind: Kind
        let title: String
        let detail: String
    }

    /// Builds confirm-sheet rows from actions + current plan lookups.
    /// Unparseable actions are omitted (they will also be skipped on apply).
    static func summaryLines(
        for actions: [AskPluriAction],
        plan: GeneratedPlan?,
        calendar: Calendar = .current
    ) -> [SummaryLine] {
        actions.enumerated().compactMap { index, action in
            switch action {
            case let .addWorkout(sourceWorkoutId, dateString):
                guard let sourceID = UUID(uuidString: sourceWorkoutId),
                      let parsed = DatabaseCodeMappings.date(from: dateString)
                else {
                    return nil
                }
                let day = calendar.startOfDay(for: parsed)
                let sourceTitle: String = {
                    guard let plan else { return "Workout" }
                    return PlanMutator.session(withID: sourceID, in: plan)?.title ?? "Workout"
                }()
                return SummaryLine(
                    id: "add-\(index)-\(sourceWorkoutId)-\(dateString)",
                    kind: .add,
                    title: "Add \(sourceTitle)",
                    detail: day.formatted(date: .abbreviated, time: .omitted)
                )
            case let .removeWorkout(planWorkoutId):
                guard let workoutID = UUID(uuidString: planWorkoutId) else { return nil }
                let title: String = {
                    guard let plan else { return "Workout" }
                    return PlanMutator.session(withID: workoutID, in: plan)?.title ?? "Workout"
                }()
                let detail: String = {
                    guard let plan,
                          let session = PlanMutator.session(withID: workoutID, in: plan),
                          let date = session.date
                    else {
                        return "From your plan"
                    }
                    return date.formatted(date: .abbreviated, time: .omitted)
                }()
                return SummaryLine(
                    id: "remove-\(index)-\(planWorkoutId)",
                    kind: .remove,
                    title: "Remove \(title)",
                    detail: detail
                )
            }
        }
    }

    /// Applies actions sequentially via `PlanStore`. Stops on the first thrown
    /// error from a parseable action; unparseable actions are ignored.
    static func apply(
        _ actions: [AskPluriAction],
        to planStore: PlanStore,
        calendar: Calendar = .current
    ) async throws {
        for action in actions {
            switch action {
            case let .addWorkout(sourceWorkoutId, dateString):
                guard let sourceID = UUID(uuidString: sourceWorkoutId),
                      let parsed = DatabaseCodeMappings.date(from: dateString)
                else {
                    continue
                }
                let day = calendar.startOfDay(for: parsed)
                try await planStore.addWorkout(cloning: sourceID, on: day)
            case let .removeWorkout(planWorkoutId):
                guard let workoutID = UUID(uuidString: planWorkoutId) else { continue }
                try await planStore.removeWorkout(id: workoutID)
            }
        }
    }
}
