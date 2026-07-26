import Foundation
import Testing
@testable import Pluri

/// M3-07..09 / M5-04..06 — Home display logic: month summary, calendar strip,
/// Record Workout menu, health tile formatting, and live score labeling.
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

    private func makeViewModel(defaults: UserDefaults = .standard) -> HomeViewModel {
        HomeViewModel(calendar: calendar, defaults: defaults)
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

    // MARK: - Health tiles (M5-04)

    @Test("Authorized snapshot formats steps, sleep hours, and BPM")
    func healthTileFormattingPopulated() {
        let viewModel = makeViewModel()
        let snapshot = HealthDaySnapshot(
            dayStart: monday,
            stepCount: 8_432,
            sleepHours: 7.5,
            averageHeartRateBPM: 68,
            activeEnergyKilocalories: 420
        )

        let metrics = viewModel.healthTileMetrics(
            snapshot: snapshot,
            authorizationStatus: .authorized
        )

        #expect(metrics.stepsValue == 8_432.formatted(.number))
        #expect(metrics.sleepValue == "7.5 hr")
        #expect(metrics.heartRateValue == "\(68.formatted(.number)) BPM")
        #expect(metrics.isEmptyPlaceholder == false)
    }

    @Test("Authorized empty metrics say No data yet")
    func healthTileAuthorizedEmpty() {
        let viewModel = makeViewModel()
        let metrics = viewModel.healthTileMetrics(
            snapshot: .empty(dayStart: monday),
            authorizationStatus: .authorized
        )
        #expect(metrics.stepsValue == "No data yet")
        #expect(metrics.sleepValue == "No data yet")
        #expect(metrics.heartRateValue == "No data yet")
        #expect(metrics.isEmptyPlaceholder == true)
    }

    @Test("Not connected metrics say Enable Health")
    func healthTileEnableHealthCopy() {
        let viewModel = makeViewModel()
        let metrics = viewModel.healthTileMetrics(
            snapshot: .empty(dayStart: monday),
            authorizationStatus: .notDetermined
        )
        #expect(metrics.stepsValue == "Enable Health")
        #expect(metrics.value(for: .sleep) == "Enable Health")
    }

    @Test("refreshHealthTiles pulls today snapshot from the reader")
    func refreshHealthTilesUsesReader() async {
        let healthKit = MockHealthKitReading(authorizationStatus: .authorized)
        let viewModel = makeViewModel()

        await viewModel.refreshHealthTiles(using: healthKit)

        #expect(healthKit.refreshCount == 1)
        #expect(healthKit.daySnapshotRequestCount == 1)
        #expect(viewModel.healthTileMetrics.isEmptyPlaceholder == false)
        #expect(viewModel.healthTileMetrics.stepsValue != "No data yet")
    }

    // MARK: - Live score (M5-06)

    @Test("Live score refreshes from plan sessions and persists clamp snapshot")
    func liveScoreRefreshPersists() async {
        let suite = "pluri.tests.home.score.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let healthKit = MockHealthKitReading(authorizationStatus: .denied)
        let viewModel = makeViewModel(defaults: defaults)
        let sessions = [
            PlannedSession(
                title: "A",
                indexInWeek: 1,
                weekday: .monday,
                date: monday,
                status: .completed,
                durationMinutes: 45,
                exercises: []
            ),
        ]

        await viewModel.refreshPluriScore(
            sessions: sessions,
            healthKit: healthKit,
            userID: "test-user",
            asOf: monday
        )

        #expect(viewModel.pluriScore != nil)
        #expect((0...100).contains(viewModel.pluriScore ?? -1))
        #expect(viewModel.scoreSubtitle.localizedStandardContains("consistency"))
        #expect(!viewModel.scoreSubtitle.localizedStandardContains("sample"))
        let stored = PluriScoreStore.load(userID: "test-user", defaults: defaults)
        #expect(stored?.score == Double(viewModel.pluriScore ?? -1))
    }

    @Test("Same-day score refresh does not ratchet the ±3 daily clamp")
    func sameDayRefreshDoesNotAccumulateClamp() async throws {
        let suite = "pluri.tests.home.score.clamp.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let yesterday = day(-1)
        PluriScoreStore.save(score: 50, dayStart: yesterday, userID: "clamp-user", defaults: defaults)

        let healthKit = MockHealthKitReading(authorizationStatus: .denied)
        let viewModel = makeViewModel(defaults: defaults)
        let perfectSessions = (0..<8).map { offset in
            PlannedSession(
                title: "S\(offset)",
                indexInWeek: 1,
                weekday: .monday,
                date: day(-offset),
                status: .completed,
                durationMinutes: 45,
                exercises: []
            )
        }

        await viewModel.refreshPluriScore(
            sessions: perfectSessions,
            healthKit: healthKit,
            userID: "clamp-user",
            asOf: monday
        )
        // New day: +3 from yesterday's latest (50); clamp base stays 50 all day.
        #expect(viewModel.pluriScore == 53)
        let storedAfterFirst = try #require(PluriScoreStore.load(userID: "clamp-user", defaults: defaults))
        #expect(storedAfterFirst.clampBase == 50)
        #expect(storedAfterFirst.latestScore == 53)

        await viewModel.refreshPluriScore(
            sessions: perfectSessions,
            healthKit: healthKit,
            userID: "clamp-user",
            asOf: monday
        )
        // Same-day refresh must stay at 53 — not ratchet to 56 / 59 / …
        #expect(viewModel.pluriScore == 53)
        let storedAfterSecond = try #require(PluriScoreStore.load(userID: "clamp-user", defaults: defaults))
        #expect(storedAfterSecond.clampBase == 50)
        #expect(storedAfterSecond.latestScore == 53)

        await viewModel.refreshPluriScore(
            sessions: perfectSessions,
            healthKit: healthKit,
            userID: "clamp-user",
            asOf: monday
        )
        #expect(viewModel.pluriScore == 53)
        #expect(PluriScoreStore.load(userID: "clamp-user", defaults: defaults)?.clampBase == 50)
    }

    @Test("Score refresh token changes when a session status changes")
    func scoreRefreshTokenTracksStatus() {
        let a = PlannedSession(
            title: "A",
            indexInWeek: 1,
            weekday: .monday,
            date: monday,
            status: .scheduled,
            durationMinutes: 45,
            exercises: []
        )
        let b = PlannedSession(
            id: a.id,
            title: "A",
            indexInWeek: 1,
            weekday: .monday,
            date: monday,
            status: .completed,
            durationMinutes: 45,
            exercises: []
        )
        #expect(
            HomeViewModel.scoreRefreshToken(sessions: [a])
                != HomeViewModel.scoreRefreshToken(sessions: [b])
        )
    }
}
