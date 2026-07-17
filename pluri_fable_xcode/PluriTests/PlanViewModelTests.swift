import Foundation
import Testing
@testable import Pluri

/// M3-10/11 — Plan page display logic: plan-card derivation (name fallback,
/// end date, weeks-completed tracker), session day labels (never inventing a
/// date for flexible workouts — SPEC §14 #37), durations, and week workout
/// counts.
@Suite("PlanViewModel")
@MainActor
struct PlanViewModelTests {
    private let calendar = Calendar.current

    /// A Monday at start-of-day, walked forward from a fixed epoch so the
    /// fixture is deterministic in any time zone (same approach as
    /// `PlanStoreTests`).
    private var monday: Date {
        var date = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_752_364_800))
        while calendar.component(.weekday, from: date) != Weekday.monday.rawValue {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return date
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: monday) ?? monday
    }

    private func makeSession(
        title: String = "Workout",
        weekday: Weekday? = nil,
        date: Date? = nil,
        status: WorkoutStatus = .scheduled,
        durationMinutes: Int = 45
    ) -> PlannedSession {
        PlannedSession(
            title: title,
            indexInWeek: 1,
            weekday: weekday,
            date: date,
            status: status,
            durationMinutes: durationMinutes,
            exercises: []
        )
    }

    private func makePlan(name: String? = nil, weeks: [PlanWeek]) -> GeneratedPlan {
        GeneratedPlan(
            goal: .buildMuscle,
            scheduleType: .scheduled,
            sessionDurationMinutes: 45,
            startDate: monday,
            weeks: weeks,
            seed: 1,
            name: name
        )
    }

    private func makeViewModel() -> PlanViewModel {
        PlanViewModel()
    }

    // MARK: - Plan card

    @Test("Plan card prefers the stored plan name and falls back to the goal")
    func cardTitleFallback() {
        let viewModel = makeViewModel()
        let weeks = [PlanWeek(number: 1, sessions: [makeSession()])]

        let named = viewModel.cardModel(for: makePlan(name: "Summer Strength", weeks: weeks), completedWeekCount: 0)
        #expect(named.title == "Summer Strength")

        let unnamed = viewModel.cardModel(for: makePlan(weeks: weeks), completedWeekCount: 0)
        #expect(unnamed.title == Goal.buildMuscle.title)
    }

    @Test("Plan card shows the plan end date and the weeks-completed tracker")
    func cardEndDateAndTracker() {
        let viewModel = makeViewModel()
        let plan = makePlan(weeks: [
            PlanWeek(number: 1, sessions: [makeSession(status: .completed)]),
            PlanWeek(number: 2, sessions: [makeSession()]),
        ])

        let card = viewModel.cardModel(for: plan, completedWeekCount: 1)

        #expect(card.endDateText == plan.endDate.formatted(date: .abbreviated, time: .omitted))
        #expect(card.completedWeeks == 1)
        #expect(card.totalWeeks == 2)
        #expect(card.trackerText == "1/2")
        #expect(card.progress == 0.5)
    }

    @Test("Tracker progress stays at zero for a plan with no weeks")
    func trackerProgressGuardsEmptyPlan() {
        let viewModel = makeViewModel()

        let card = viewModel.cardModel(for: makePlan(weeks: []), completedWeekCount: 0)

        #expect(card.progress == 0)
        #expect(card.trackerText == "0/0")
    }

    // MARK: - Session day labels (SPEC §14 #37)

    @Test("Dated sessions show their concrete date")
    func dayLabelForDatedSession() {
        let viewModel = makeViewModel()
        let date = day(2)
        let session = makeSession(weekday: Weekday(rawValue: calendar.component(.weekday, from: date)), date: date)

        let label = viewModel.dayLabel(for: session)

        #expect(label == date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
    }

    @Test("Weekday-only sessions show the weekday name")
    func dayLabelForWeekdayOnlySession() {
        let viewModel = makeViewModel()
        let session = makeSession(weekday: .friday)

        #expect(viewModel.dayLabel(for: session) == Weekday.friday.shortTitle)
    }

    @Test("Flexible sessions stay honestly unassigned — no invented date")
    func dayLabelForFlexibleSession() {
        let viewModel = makeViewModel()
        let session = makeSession()

        let label = viewModel.dayLabel(for: session)

        #expect(label == PlanViewModel.flexibleDayLabel)
        let containsDigits = label.contains { $0.isNumber }
        #expect(!containsDigits)
    }

    // MARK: - Duration & workout count labels

    @Test("Duration labels match Home's hour/minute formatting")
    func durationLabels() {
        let viewModel = makeViewModel()

        let short = viewModel.durationLabel(for: makeSession(durationMinutes: 45))
        #expect(short == Duration.seconds(45 * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))

        let long = viewModel.durationLabel(for: makeSession(durationMinutes: 90))
        #expect(long == Duration.seconds(90 * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
    }

    @Test("Workout count label pluralizes correctly")
    func workoutCountLabels() {
        let viewModel = makeViewModel()

        let single = PlanWeek(number: 1, sessions: [makeSession()])
        #expect(viewModel.workoutCountLabel(for: single) == "1 workout")

        let triple = PlanWeek(number: 2, sessions: [makeSession(), makeSession(), makeSession()])
        #expect(viewModel.workoutCountLabel(for: triple) == "3 workouts")
    }
}
