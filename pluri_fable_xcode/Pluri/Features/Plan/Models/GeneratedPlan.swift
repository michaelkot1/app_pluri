import Foundation

/// A fully generated multi-week training plan (M1-16), the output of
/// `PlanEngine.generate`.
///
/// Deliberately a plain `Sendable` value type with no persistence or
/// `@MainActor` coupling: the engine produces it off the main actor, the UI
/// renders it, and the sync layer maps it onto the Supabase `plans` /
/// `plan_workouts` schema.
///
/// M3-03 adds the persisted plan metadata (`plans` columns) a remote restore
/// must not discard: `name`, `status`, and a stored `endDate` (which can
/// diverge from the computed start+weeks value after Manage Plan edits).
nonisolated struct GeneratedPlan: Identifiable, Hashable, Sendable {
    let id: UUID

    /// Plan name/goal shown on the Plan card (SPEC §6).
    let goal: Goal
    let scheduleType: ScheduleType
    let sessionDurationMinutes: Int
    let startDate: Date
    let weeks: [PlanWeek]

    /// The seed the plan was generated from — kept so the same plan can be
    /// reproduced deterministically (PLAN §1.4). `0` for restored plans whose
    /// seed the schema doesn't persist.
    let seed: UInt64

    /// Persisted `plans.name`; `nil` falls back to the goal for display.
    let name: String?

    /// Persisted `plans.status`. Restore only fetches `active` plans today.
    let status: PlanStatus

    /// Persisted `plans.end_date` when it differs from the computed value.
    private let storedEndDate: Date?

    init(
        id: UUID = UUID(),
        goal: Goal,
        scheduleType: ScheduleType,
        sessionDurationMinutes: Int,
        startDate: Date,
        weeks: [PlanWeek],
        seed: UInt64,
        name: String? = nil,
        status: PlanStatus = .active,
        endDate: Date? = nil
    ) {
        self.id = id
        self.goal = goal
        self.scheduleType = scheduleType
        self.sessionDurationMinutes = sessionDurationMinutes
        self.startDate = startDate
        self.weeks = weeks
        self.seed = seed
        self.name = name
        self.status = status
        self.storedEndDate = endDate
    }

    var weekCount: Int { weeks.count }

    /// Sessions per week (constant across the plan in v1).
    var sessionsPerWeek: Int { weeks.first?.sessions.count ?? 0 }

    /// Total number of workouts across the whole plan.
    var totalSessions: Int { weeks.reduce(0) { $0 + $1.sessions.count } }

    /// The plan's end date: the stored `plans.end_date` when hydrated, else
    /// `startDate` + `weekCount` weeks, minus a day so it lands on the last
    /// day of the final week (SPEC §6 "plan end date").
    var endDate: Date {
        if let storedEndDate { return storedEndDate }
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: weekCount * 7 - 1, to: startDate)
        return end ?? startDate
    }

    /// The first session of week 1, used for the "Plan Ready" teaser preview.
    var firstSession: PlannedSession? { weeks.first?.sessions.first }
}
