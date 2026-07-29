import Foundation
import Testing
@testable import Pluri

/// M5-02 — HealthKit read protocol mock: auth, today/history, denied/unavailable empties.
@Suite("HealthKitReading")
@MainActor
struct HealthKitReadingTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private var todayStart: Date {
        calendar.startOfDay(for: Date(timeIntervalSince1970: 1_753_488_000)) // 2025-07-26 UTC
    }

    // MARK: - Authorization

    @Test("requestAuthorization moves mock to authorized")
    func requestAuthorizationSucceeds() async {
        let reader = MockHealthKitReading(authorizationStatus: .notDetermined)
        #expect(reader.authorizationStatus == .notDetermined)

        await reader.requestAuthorization()

        #expect(reader.authorizationRequestCount == 1)
        #expect(reader.authorizationStatus == .authorized)
    }

    @Test("requestAuthorization can land on denied for Settings guidance")
    func requestAuthorizationDenied() async {
        let reader = MockHealthKitReading(authorizationStatus: .notDetermined)
        reader.statusAfterAuthorizationRequest = .denied

        await reader.requestAuthorization()

        #expect(reader.authorizationStatus == .denied)
    }

    @Test("refreshAuthorizationStatus is callable for post-Settings refresh")
    func refreshIncrements() async {
        let reader = MockHealthKitReading()
        await reader.refreshAuthorizationStatus()
        #expect(reader.refreshCount == 1)
    }

    // MARK: - Today / history

    @Test("todaySnapshot returns fixture when authorized")
    func todaySnapshotAuthorized() async {
        let fixture = HealthDaySnapshot(
            dayStart: todayStart,
            stepCount: 9_001,
            sleepHours: 6.5,
            averageHeartRateBPM: 72,
            activeEnergyKilocalories: 510
        )
        let reader = MockHealthKitReading(
            authorizationStatus: .authorized,
            todayFixture: fixture,
            calendar: calendar
        )

        let snapshot = await reader.todaySnapshot(calendar: calendar, now: todayStart)

        #expect(snapshot.stepCount == 9_001)
        #expect(snapshot.sleepHours == 6.5)
        #expect(snapshot.averageHeartRateBPM == 72)
        #expect(snapshot.activeEnergyKilocalories == 510)
        #expect(snapshot.hasAnyMetric)
        #expect(reader.daySnapshotRequestCount == 1)
    }

    @Test("dailyHistory returns 30 calendar days of fixtures")
    func dailyHistoryThirtyDays() async {
        let start = calendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
        var history: [Date: HealthDaySnapshot] = [:]
        for offset in 0..<29 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            history[day] = HealthDaySnapshot(
                dayStart: day,
                stepCount: Double(5_000 + offset),
                sleepHours: 7,
                averageHeartRateBPM: 65,
                activeEnergyKilocalories: 300
            )
        }

        let reader = MockHealthKitReading(
            authorizationStatus: .authorized,
            todayFixture: HealthDaySnapshot(
                dayStart: todayStart,
                stepCount: 8_000,
                sleepHours: 7.5,
                averageHeartRateBPM: 70,
                activeEnergyKilocalories: 400
            ),
            historyByDayStart: history,
            calendar: calendar
        )

        let days = await reader.dailyHistory(from: start, through: todayStart, calendar: calendar)

        #expect(days.count == 30)
        #expect(days.first?.stepCount == 5_000)
        #expect(days.last?.stepCount == 8_000)
        #expect(days.last?.dayStart == todayStart)
        #expect(reader.historyRequestCount == 1)
        #expect(reader.daySnapshotRequestCount == 0)
    }

    // MARK: - Denied / unavailable

    @Test("denied authorization returns honest empty today snapshot")
    func deniedTodayEmpty() async {
        let reader = MockHealthKitReading(
            authorizationStatus: .denied,
            todayFixture: HealthDaySnapshot(
                dayStart: todayStart,
                stepCount: 12_000,
                sleepHours: 8,
                averageHeartRateBPM: 60,
                activeEnergyKilocalories: 600
            ),
            calendar: calendar
        )

        let snapshot = await reader.daySnapshot(for: todayStart, calendar: calendar)

        #expect(snapshot.dayStart == todayStart)
        #expect(snapshot.stepCount == nil)
        #expect(snapshot.sleepHours == nil)
        #expect(snapshot.averageHeartRateBPM == nil)
        #expect(snapshot.activeEnergyKilocalories == nil)
        #expect(!snapshot.hasAnyMetric)
    }

    @Test("unavailable authorization returns empty history days")
    func unavailableHistoryEmpty() async {
        let start = calendar.date(byAdding: .day, value: -2, to: todayStart) ?? todayStart
        let reader = MockHealthKitReading(authorizationStatus: .unavailable, calendar: calendar)

        let days = await reader.dailyHistory(from: start, through: todayStart, calendar: calendar)

        #expect(days.count == 3)
        #expect(days.allSatisfy { !$0.hasAnyMetric })
    }

    @Test("notDetermined returns empty until authorized")
    func notDeterminedEmpty() async {
        let reader = MockHealthKitReading(
            authorizationStatus: .notDetermined,
            todayFixture: HealthDaySnapshot(
                dayStart: todayStart,
                stepCount: 1_000,
                sleepHours: 7,
                averageHeartRateBPM: 66,
                activeEnergyKilocalories: 200
            ),
            calendar: calendar
        )
        let before = await reader.daySnapshot(for: todayStart, calendar: calendar)
        #expect(!before.hasAnyMetric)

        await reader.requestAuthorization()
        let after = await reader.daySnapshot(for: todayStart, calendar: calendar)
        #expect(after.hasAnyMetric)
    }

    // MARK: - Separation from write path

    @Test("read mock exposes four metric fields and no workout write API surface in usage")
    func readPathSeparateFromWrite() async {
        let reader: any HealthKitReading = MockHealthKitReading(authorizationStatus: .authorized)
        let writer = MockWorkoutHealthWriter()

        await reader.requestAuthorization()
        _ = await reader.todaySnapshot()
        #expect(writer.writeCalls.isEmpty)
        #expect(writer.authorizationRequestCount == 0)

        // Distinct protocol roles: reader never invokes writer; writer stays unused.
        #expect(reader.authorizationStatus == .authorized)
    }

    @Test("empty snapshot helper")
    func emptyHelper() {
        let empty = HealthDaySnapshot.empty(dayStart: todayStart)
        #expect(empty.dayStart == todayStart)
        #expect(!empty.hasAnyMetric)
    }

    // MARK: - Foreground observer (M5-18)

    @Test("Mock observer invokes registered handler on simulateHealthChange")
    func mockObserverInvokesHandler() {
        let reader = MockHealthKitReading(authorizationStatus: .authorized)
        var invokeCount = 0

        reader.startObservingHealthChanges {
            invokeCount += 1
        }
        #expect(reader.isObserving)
        #expect(reader.startObservingCount == 1)

        reader.simulateHealthChange()
        reader.simulateHealthChange()

        #expect(invokeCount == 2)
    }

    @Test("Mock observer does not start when unauthorized")
    func mockObserverSkippedWhenDenied() {
        let reader = MockHealthKitReading(authorizationStatus: .denied)
        var invokeCount = 0

        reader.startObservingHealthChanges {
            invokeCount += 1
        }
        #expect(!reader.isObserving)

        reader.simulateHealthChange()
        #expect(invokeCount == 0)
    }

    @Test("Mock observer teardown clears handler")
    func mockObserverStopClearsHandler() {
        let reader = MockHealthKitReading(authorizationStatus: .authorized)
        var invokeCount = 0

        reader.startObservingHealthChanges {
            invokeCount += 1
        }
        reader.stopObservingHealthChanges()
        #expect(!reader.isObserving)
        #expect(reader.stopObservingCount == 1)

        reader.simulateHealthChange()
        #expect(invokeCount == 0)
    }

    @Test("Mock observer change can drive score refresh (M5-18)")
    func mockObserverDrivesScoreRefresh() async {
        let suite = "pluri.tests.health.observer.score.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let reader = MockHealthKitReading(authorizationStatus: .authorized, calendar: calendar)
        let viewModel = HomeViewModel(calendar: calendar, defaults: defaults)
        var refreshCount = 0

        reader.startObservingHealthChanges {
            refreshCount += 1
            Task {
                await viewModel.refreshHealthMetrics(
                    using: reader,
                    userID: "observer-user",
                    asOf: todayStart
                )
                await viewModel.refreshPluriScore(
                    sessions: [],
                    healthKit: reader,
                    userID: "observer-user",
                    asOf: todayStart
                )
            }
        }

        reader.simulateHealthChange()
        // Allow the Task scheduled by the handler to run.
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(refreshCount == 1)
        #expect(viewModel.pluriScore != nil)
        #expect(reader.daySnapshotRequestCount >= 1)
    }
}
