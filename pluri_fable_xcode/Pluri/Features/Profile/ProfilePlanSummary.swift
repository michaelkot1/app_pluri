import Foundation

/// Pure, testable formatting of the restored plan for the Profile screen
/// (SPEC §5.2 "basic plan info: goal, dates, schedule").
nonisolated struct ProfilePlanSummary: Equatable, Sendable {
    var goalTitle: String
    var dateRangeText: String
    var scheduleText: String

    /// `nil` when there is no active plan — the screen shows an honest empty
    /// state instead of inventing data. `@MainActor` because `Goal.title` /
    /// `ScheduleType.title` follow the project's main-actor default isolation.
    @MainActor
    static func make(from plan: GeneratedPlan?) -> ProfilePlanSummary? {
        guard let plan else { return nil }
        let start = plan.startDate.formatted(date: .abbreviated, time: .omitted)
        let end = plan.endDate.formatted(date: .abbreviated, time: .omitted)
        return ProfilePlanSummary(
            goalTitle: plan.goal.title,
            dateRangeText: "\(start) – \(end)",
            scheduleText: scheduleText(for: plan)
        )
    }

    @MainActor
    private static func scheduleText(for plan: GeneratedPlan) -> String {
        let sessions = plan.sessionsPerWeek
        let sessionsPart = sessions == 1 ? "1 workout / week" : "\(sessions) workouts / week"
        return "\(plan.scheduleType.title) · \(sessionsPart) · \(plan.sessionDurationMinutes) min"
    }
}
