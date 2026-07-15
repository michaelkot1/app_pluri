import Foundation

/// A fully generated multi-week training plan (M1-16), the output of
/// `PlanEngine.generate`.
///
/// Deliberately a plain `Sendable` value type with no persistence or
/// `@MainActor` coupling: the engine produces it off the main actor, the UI
/// renders it, and a later milestone (PLAN §1.3) maps it onto the Supabase
/// `plans` / `plan_workouts` schema.
nonisolated struct GeneratedPlan: Identifiable, Hashable, Sendable {
    let id: UUID

    /// Plan name/goal shown on the Plan card (SPEC §6).
    let goal: Goal
    let scheduleType: ScheduleType
    let sessionDurationMinutes: Int
    let startDate: Date
    let weeks: [PlanWeek]

    /// The seed the plan was generated from — kept so the same plan can be
    /// reproduced deterministically (PLAN §1.4).
    let seed: UInt64

    init(
        id: UUID = UUID(),
        goal: Goal,
        scheduleType: ScheduleType,
        sessionDurationMinutes: Int,
        startDate: Date,
        weeks: [PlanWeek],
        seed: UInt64
    ) {
        self.id = id
        self.goal = goal
        self.scheduleType = scheduleType
        self.sessionDurationMinutes = sessionDurationMinutes
        self.startDate = startDate
        self.weeks = weeks
        self.seed = seed
    }

    var weekCount: Int { weeks.count }

    /// Sessions per week (constant across the plan in v1).
    var sessionsPerWeek: Int { weeks.first?.sessions.count ?? 0 }

    /// Total number of workouts across the whole plan.
    var totalSessions: Int { weeks.reduce(0) { $0 + $1.sessions.count } }

    /// The plan's end date: `startDate` + `weekCount` weeks, minus a day so it
    /// lands on the last day of the final week (SPEC §6 "plan end date").
    var endDate: Date {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: weekCount * 7 - 1, to: startDate)
        return end ?? startDate
    }

    /// The first session of week 1, used for the "Plan Ready" teaser preview.
    var firstSession: PlannedSession? { weeks.first?.sessions.first }
}
