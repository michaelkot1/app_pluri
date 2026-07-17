import Foundation
import Observation

/// Calendar page logic (M3-13 / SPEC §5.4): week-by-week navigation state
/// and the per-week day derivations — kept out of the views so it's
/// unit-testable. Plan data itself stays in the shared `PlanStore`; this
/// model only derives display state from it.
@MainActor
@Observable
final class CalendarViewModel {
    /// Week the user explicitly navigated to; `nil` means "follow the
    /// initial week" (today's week when the plan is in progress).
    private(set) var selectedWeekNumber: Int?

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: - Week selection

    /// The week the page opens on: the plan week containing today when the
    /// plan is in progress; week 1 before the plan starts; the last week
    /// after it ends.
    func initialWeekNumber(plan: GeneratedPlan, today: Date) -> Int {
        if let current = PlanMutator.weekNumber(containing: today, in: plan, calendar: calendar) {
            return current
        }
        let start = calendar.startOfDay(for: plan.startDate)
        return calendar.startOfDay(for: today) < start ? 1 : max(plan.weekCount, 1)
    }

    /// The visible week: the explicitly chosen one (clamped to the plan)
    /// or the initial week.
    func resolvedWeekNumber(plan: GeneratedPlan, today: Date) -> Int {
        let resolved = selectedWeekNumber ?? initialWeekNumber(plan: plan, today: today)
        return min(max(resolved, 1), max(plan.weekCount, 1))
    }

    func canShowPreviousWeek(plan: GeneratedPlan, today: Date) -> Bool {
        resolvedWeekNumber(plan: plan, today: today) > 1
    }

    func canShowNextWeek(plan: GeneratedPlan, today: Date) -> Bool {
        resolvedWeekNumber(plan: plan, today: today) < plan.weekCount
    }

    func showPreviousWeek(plan: GeneratedPlan, today: Date) {
        guard canShowPreviousWeek(plan: plan, today: today) else { return }
        selectedWeekNumber = resolvedWeekNumber(plan: plan, today: today) - 1
    }

    func showNextWeek(plan: GeneratedPlan, today: Date) {
        guard canShowNextWeek(plan: plan, today: today) else { return }
        selectedWeekNumber = resolvedWeekNumber(plan: plan, today: today) + 1
    }

    // MARK: - Week days

    /// The 7 start-of-day dates of the given plan week (rolling weeks from
    /// the plan's start date, matching `PlanMutator.weekNumber`).
    func days(ofWeek number: Int, in plan: GeneratedPlan) -> [Date] {
        let start = calendar.startOfDay(for: plan.startDate)
        guard number >= 1,
              let weekStart = calendar.date(byAdding: .day, value: (number - 1) * 7, to: start)
        else {
            return []
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    /// "Jul 20 – Jul 26" range label for the week header.
    func weekRangeLabel(forWeek number: Int, in plan: GeneratedPlan) -> String {
        let weekDays = days(ofWeek: number, in: plan)
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return "\(first.formatted(format)) – \(last.formatted(format))"
    }
}
