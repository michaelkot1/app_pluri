import Foundation
import Observation

/// Plan page display logic (M3-10/11): plan-card derivation and the week
/// card / Week Overview session labels — kept out of the views so it's
/// unit-testable. Plan data itself stays in the shared `PlanStore`; this
/// model only formats display state from it.
@MainActor
@Observable
final class PlanViewModel {
    /// Day label for a session that has no weekday or date — a flexible
    /// workout stays visibly unassigned; we never invent a date for it
    /// (SPEC §14 #37).
    static let flexibleDayLabel = "Anytime this week"

    /// The top plan card: plan name (falling back to the goal), end date,
    /// and the weeks-completed tracker (SPEC §6).
    func cardModel(for plan: GeneratedPlan, completedWeekCount: Int) -> PlanCardModel {
        PlanCardModel(
            title: plan.name ?? plan.goal.title,
            endDateText: plan.endDate.formatted(date: .abbreviated, time: .omitted),
            completedWeeks: completedWeekCount,
            totalWeeks: plan.weekCount
        )
    }

    /// The day a session happens: its concrete date, else its pinned
    /// weekday, else the honest flexible label (SPEC §14 #37).
    func dayLabel(for session: PlannedSession) -> String {
        if let date = session.date {
            date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        } else if let weekday = session.weekday {
            weekday.shortTitle
        } else {
            Self.flexibleDayLabel
        }
    }

    /// Planned session length, matching Home's duration formatting.
    func durationLabel(for session: PlannedSession) -> String {
        Duration.seconds(session.durationMinutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    /// "3 workouts" header text for a week card (SPEC §6 workout count).
    func workoutCountLabel(for week: PlanWeek) -> String {
        week.sessions.count == 1 ? "1 workout" : "\(week.sessions.count) workouts"
    }
}
