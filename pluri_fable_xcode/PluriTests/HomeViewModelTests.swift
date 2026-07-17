import Foundation
import Testing
@testable import Pluri

/// M3-07..09 — Home display logic: month summary counting, calendar-strip
/// day derivation, selected-day resolution, Record Workout menu options, and
/// the honestly-labeled stub score.
@Suite("HomeViewModel")
@MainActor
struct HomeViewModelTests {
    private let calendar = Calendar.current

    /// A fixed reference day walked to a Monday so fixtures are deterministic
    /// in any time zone (same approach as `PlanStoreTests`).
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

    private func makeSession(title: String, status: WorkoutStatus = .scheduled) -> PlannedSession {
        PlannedSession(
            title: title,
            indexInWeek: 1,
            weekday: nil,
            date: nil,
            status: status,
            durationMinutes: 45,
            exercises: []
        )
    }

    private func makeViewModel() -> HomeViewModel {
        HomeViewModel(calendar: calendar)
    }

    // MARK: - Day selection

    @Test("Selected day defaults to today and follows taps at start-of-day")
    func selectedDayResolution() {
        let viewModel = makeViewModel()

        #expect(viewModel.resolvedSelectedDay(today: monday) == monday)

        let afternoon = monday.addingTimeInterval(60 * 60 * 15 + 60 * 60 * 24 * 2)
        viewModel.select(day: afternoon)
        #expect(viewModel.resolvedSelectedDay(today: monday) == day(2))
    }

    // MARK: - Calendar strip

    @Test("Month days cover the whole month at start-of-day")
    func monthDays() throws {
        let viewModel = makeViewModel()
        let days = viewModel.monthDays(containing: monday)

        let month = try #require(calendar.dateInterval(of: .month, for: monday))
        let expectedCount = calendar.dateComponents([.day], from: month.start, to: month.end).day
        #expect(days.count == expectedCount)
        #expect(days.first == month.start)
        #expect(days.allSatisfy { calendar.startOfDay(for: $0) == $0 })
        #expect(days.contains(monday))
    }

    // MARK: - Month summary

    @Test("Month summary counts only that month's dated workouts, completed as done")
    func monthSummaryCounting() {
        let viewModel = makeViewModel()

        // Two workouts inside monday's month; one far away in another month.
        let insideDone = calendar.startOfDay(for: monday)
        let insideScheduled = day(1)
        let outside = calendar.date(byAdding: .month, value: 2, to: monday) ?? monday
        let sessionsByDay: [Date: [PlannedSession]] = [
            insideDone: [makeSession(title: "Done", status: .completed)],
            insideScheduled: [makeSession(title: "Scheduled"), makeSession(title: "Skipped", status: .skipped)],
            calendar.startOfDay(for: outside): [makeSession(title: "Elsewhere", status: .completed)],
        ]

        let summary = viewModel.monthSummary(containing: monday, sessionsByDay: sessionsByDay)

        #expect(summary.completedCount == 1)
        #expect(summary.totalCount == 3)
        #expect(summary.completionText == "1 of 3 done")
        #expect(summary.title == monday.formatted(.dateTime.month(.wide).year()))
    }

    @Test("Month summary hides the fraction when the month has no dated workouts")
    func monthSummaryEmptyMonth() {
        let viewModel = makeViewModel()

        let summary = viewModel.monthSummary(containing: monday, sessionsByDay: [:])

        #expect(summary.totalCount == 0)
        #expect(summary.completionText == nil)
        #expect(!summary.title.isEmpty)
    }

    // MARK: - Record Workout menu (M3-09)

    @Test("Record menu offers only Outdoor Run when nothing is scheduled today")
    func recordOptionsWithoutTodaySession() {
        let viewModel = makeViewModel()

        #expect(viewModel.recordOptions(todaysSessions: []) == [.outdoorRun])
    }

    @Test("Record menu offers today's workout first, using the first of several")
    func recordOptionsWithTodaySessions() {
        let viewModel = makeViewModel()
        let first = makeSession(title: "Upper Body")
        let second = makeSession(title: "Extra Credit")

        let options = viewModel.recordOptions(todaysSessions: [first, second])

        #expect(options == [.scheduledWorkout(first), .outdoorRun])
    }

    // MARK: - Stub score (M3-08)

    @Test("Stub score is in range and clearly labeled as sample, not live")
    func stubScoreLabeling() {
        #expect((0...100).contains(HomeViewModel.stubScoreValue))
        #expect(HomeViewModel.stubScoreBadge.localizedStandardContains("sample"))
        #expect(HomeViewModel.stubScoreDisclaimer.localizedStandardContains("sample"))
    }
}
