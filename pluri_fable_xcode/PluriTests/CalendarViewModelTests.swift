import Foundation
import Testing
@testable import Pluri

/// M3-13 — the Calendar page's week navigation: initial week resolution,
/// prev/next bounds, and the per-week day derivations.
@Suite("CalendarViewModel")
@MainActor
struct CalendarViewModelTests {
    private let calendar = Calendar.current

    /// A Monday at start-of-day, walked forward from a fixed epoch so the
    /// fixture is deterministic in any time zone.
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

    /// Two-week plan starting Monday; sessions aren't needed for navigation.
    private func makePlan() -> GeneratedPlan {
        GeneratedPlan(
            goal: .buildMuscle,
            scheduleType: .scheduled,
            sessionDurationMinutes: 45,
            startDate: monday,
            weeks: [
                PlanWeek(number: 1, sessions: []),
                PlanWeek(number: 2, sessions: []),
            ],
            seed: 1
        )
    }

    @Test("Initial week is today's plan week while the plan is in progress")
    func initialWeekInsidePlan() {
        let viewModel = CalendarViewModel(calendar: calendar)
        let plan = makePlan()

        #expect(viewModel.initialWeekNumber(plan: plan, today: day(0)) == 1)
        #expect(viewModel.initialWeekNumber(plan: plan, today: day(6)) == 1)
        #expect(viewModel.initialWeekNumber(plan: plan, today: day(7)) == 2)
        #expect(viewModel.resolvedWeekNumber(plan: plan, today: day(8)) == 2)
    }

    @Test("Before the plan starts the page opens on week 1; after it ends, on the last week")
    func initialWeekOutsidePlan() {
        let viewModel = CalendarViewModel(calendar: calendar)
        let plan = makePlan()

        #expect(viewModel.initialWeekNumber(plan: plan, today: day(-3)) == 1)
        #expect(viewModel.initialWeekNumber(plan: plan, today: day(20)) == 2)
    }

    @Test("Week navigation moves one week at a time and stops at the plan edges")
    func weekNavigationBounds() {
        let viewModel = CalendarViewModel(calendar: calendar)
        let plan = makePlan()
        let today = day(0) // week 1

        #expect(!viewModel.canShowPreviousWeek(plan: plan, today: today))
        #expect(viewModel.canShowNextWeek(plan: plan, today: today))

        viewModel.showPreviousWeek(plan: plan, today: today)
        #expect(viewModel.resolvedWeekNumber(plan: plan, today: today) == 1)

        viewModel.showNextWeek(plan: plan, today: today)
        #expect(viewModel.resolvedWeekNumber(plan: plan, today: today) == 2)
        #expect(!viewModel.canShowNextWeek(plan: plan, today: today))

        viewModel.showNextWeek(plan: plan, today: today)
        #expect(viewModel.resolvedWeekNumber(plan: plan, today: today) == 2)

        viewModel.showPreviousWeek(plan: plan, today: today)
        #expect(viewModel.resolvedWeekNumber(plan: plan, today: today) == 1)
        #expect(!viewModel.canShowPreviousWeek(plan: plan, today: today))
    }

    @Test("Each plan week derives its 7 rolling days from the start date")
    func weekDays() {
        let viewModel = CalendarViewModel(calendar: calendar)
        let plan = makePlan()

        let week1 = viewModel.days(ofWeek: 1, in: plan)
        #expect(week1 == (0..<7).map(day))

        let week2 = viewModel.days(ofWeek: 2, in: plan)
        #expect(week2 == (7..<14).map(day))

        #expect(viewModel.days(ofWeek: 0, in: plan).isEmpty)
    }

    @Test("The week range label spans the first and last day of the week")
    func weekRangeLabel() {
        let viewModel = CalendarViewModel(calendar: calendar)
        let plan = makePlan()
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day()

        let label = viewModel.weekRangeLabel(forWeek: 1, in: plan)
        #expect(label == "\(day(0).formatted(format)) – \(day(6).formatted(format))")
    }
}
