import Foundation

/// Builds Share Workout snapshots from local completed sessions (M8-07 / SPEC §14 #72e).
/// Isolated so the Community hub can open without touching SwiftData or PlanStore.
enum CommunityWorkoutSnapshotLoader {
    @MainActor
    static func recentSnapshots(
        from workoutSessionRepository: SwiftDataWorkoutSessionRepository,
        planStore: PlanStore
    ) -> [WorkoutSnapshot] {
        let sessions: [WorkoutSessionRecord]
        do {
            sessions = try workoutSessionRepository.fetchAllCompletedSessions()
        } catch {
            return []
        }

        var titlesByPlanID: [UUID: String] = [:]
        if let plan = planStore.plan {
            for week in plan.weeks {
                for session in week.sessions {
                    titlesByPlanID[session.id] = session.title
                }
            }
        }

        return sessions
            .sorted { ($0.endedAt ?? $0.startedAt) > ($1.endedAt ?? $1.startedAt) }
            .prefix(12)
            .map { session in
                let title = session.planWorkoutId.flatMap { titlesByPlanID[$0] }
                return WorkoutSnapshot.from(session: session, title: title)
            }
    }
}
