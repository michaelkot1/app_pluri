import Foundation
import Observation

/// Home screen logic (M3-07..09): calendar-strip day selection, month
/// summary counting, and Record Workout menu derivation — kept out of the
/// views so it's unit-testable. Plan data itself stays in the shared
/// `PlanStore`; this model only derives display state from it.
@MainActor
@Observable
final class HomeViewModel {
    /// Explicit day the user tapped on the strip (start-of-day); `nil` means
    /// "follow today" (SPEC §14 #41 default).
    private(set) var selectedDay: Date?

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: - Day selection

    func select(day: Date) {
        selectedDay = calendar.startOfDay(for: day)
    }

    /// The day whose workouts Home shows: the tapped day, else today.
    func resolvedSelectedDay(today: Date) -> Date {
        selectedDay ?? today
    }

    // MARK: - Calendar strip

    /// Every day (start-of-day) of the month containing `date`, for the
    /// scrollable strip.
    func monthDays(containing date: Date) -> [Date] {
        guard let month = calendar.dateInterval(of: .month, for: date) else {
            return [calendar.startOfDay(for: date)]
        }
        var days: [Date] = []
        var cursor = month.start
        while cursor < month.end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    // MARK: - Month summary

    /// Month name + completion fraction among the month's dated workouts
    /// (SPEC §14 #41). "Done" counts `completed` only — a skipped workout
    /// isn't celebrated, but it isn't scolded either.
    func monthSummary(
        containing date: Date,
        sessionsByDay: [Date: [PlannedSession]]
    ) -> HomeMonthSummary {
        let monthSessions = sessionsByDay
            .filter { calendar.isDate($0.key, equalTo: date, toGranularity: .month) }
            .values
            .flatMap { $0 }
        return HomeMonthSummary(
            title: date.formatted(.dateTime.month(.wide).year()),
            completedCount: monthSessions.count { $0.status == .completed },
            totalCount: monthSessions.count
        )
    }

    // MARK: - Record Workout menu (M3-09)

    /// The floating-menu options: today's first scheduled workout when one
    /// exists (hidden, not disabled, when none — SPEC §14 #41), then Outdoor
    /// Run always.
    func recordOptions(todaysSessions: [PlannedSession]) -> [HomeRecordOption] {
        var options: [HomeRecordOption] = []
        if let first = todaysSessions.first {
            options.append(.scheduledWorkout(first))
        }
        options.append(.outdoorRun)
        return options
    }

    // MARK: - Pluri Score stub (M3-08 — real engine is M5)

    /// Fixed sample value, clearly labeled as such in the UI.
    static let stubScoreValue = 72
    /// Badge marking the score card as sample data.
    static let stubScoreBadge = "Sample"
    /// Copy making clear the score is not live (SPEC §5.1 — engine is M5).
    static let stubScoreDisclaimer =
        "This is a sample score — your real Pluri Score arrives with Insights."
}
