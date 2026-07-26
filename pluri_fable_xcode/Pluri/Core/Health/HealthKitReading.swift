import Foundation
import Observation

/// On-device HealthKit *reads* for Home tiles, Insights, and Pluri Score health (M5-02).
/// Samples and aggregates never leave the device (SPEC §13 / §14 #57).
/// Workout *writes* stay on `WorkoutHealthWriting` — this protocol does not share or upload.
@MainActor
protocol HealthKitReading: AnyObject {
    /// Connection / auth status for Connected Apps + Profile (M5-03).
    var authorizationStatus: HealthKitReadAuthorizationStatus { get }

    /// Re-check availability and whether HealthKit still wants a prompt (e.g. after Settings).
    func refreshAuthorizationStatus() async

    /// Prompt for read access to steps, sleep, heart rate, and active energy.
    func requestAuthorization() async

    /// Calendar-day aggregates for the day containing `date`. Unauthorized / unavailable → honest empty (nils).
    func daySnapshot(for date: Date, calendar: Calendar) async -> HealthDaySnapshot

    /// One snapshot per calendar day from `startDate` through `endDate` (inclusive, start-of-day normalized).
    /// Enough for a 30-day baseline and Insights history. Unauthorized / unavailable → empty snapshots.
    func dailyHistory(
        from startDate: Date,
        through endDate: Date,
        calendar: Calendar
    ) async -> [HealthDaySnapshot]

    /// Starts foreground observation of HealthKit changes (steps / sleep / HR / active energy).
    /// Invokes `onChange` (coalesced) when samples update while authorized. Does **not** enable
    /// HealthKit background delivery (M5-18 / SPEC §14 #65). Call `stopObservingHealthChanges`
    /// on deny / unavailable / teardown.
    func startObservingHealthChanges(onChange: @escaping @MainActor () -> Void)

    /// Stops any active HealthKit observer queries.
    func stopObservingHealthChanges()
}

extension HealthKitReading {
    /// Convenience for "today" tiles / score inputs.
    func todaySnapshot(calendar: Calendar = .current, now: Date = .now) async -> HealthDaySnapshot {
        await daySnapshot(for: now, calendar: calendar)
    }
}

/// Apple Health read-connection posture for Insights / Connected Apps (SPEC §14 #57b).
enum HealthKitReadAuthorizationStatus: Equatable, Sendable {
    /// Device has no HealthKit.
    case unavailable
    /// User has not been prompted yet (`shouldRequest`).
    case notDetermined
    /// Prompt completed successfully; reads may still be empty (Apple's opaque read auth).
    case authorized
    /// Request failed or explicitly marked denied — UI should offer Settings guidance (M5-03).
    case denied
}

/// Per-calendar-day HealthKit aggregates. Nil fields mean no readable samples (honest empty).
struct HealthDaySnapshot: Equatable, Sendable {
    var dayStart: Date
    var stepCount: Double?
    var sleepHours: Double?
    var averageHeartRateBPM: Double?
    var activeEnergyKilocalories: Double?

    static func empty(dayStart: Date) -> HealthDaySnapshot {
        HealthDaySnapshot(
            dayStart: dayStart,
            stepCount: nil,
            sleepHours: nil,
            averageHeartRateBPM: nil,
            activeEnergyKilocalories: nil
        )
    }

    var hasAnyMetric: Bool {
        stepCount != nil
            || sleepHours != nil
            || averageHeartRateBPM != nil
            || activeEnergyKilocalories != nil
    }
}

/// Test / preview double for Insights HealthKit reads (M5-02 / M5-18).
@MainActor
@Observable
final class MockHealthKitReading: HealthKitReading {
    private(set) var authorizationStatus: HealthKitReadAuthorizationStatus
    private(set) var authorizationRequestCount = 0
    private(set) var refreshCount = 0
    private(set) var daySnapshotRequestCount = 0
    private(set) var historyRequestCount = 0
    private(set) var startObservingCount = 0
    private(set) var stopObservingCount = 0
    private(set) var isObserving = false

    /// When set, `requestAuthorization` lands on this status (default: `.authorized`).
    var statusAfterAuthorizationRequest: HealthKitReadAuthorizationStatus = .authorized

    /// Fixture used when authorized; ignored when denied / unavailable / notDetermined.
    var todayFixture: HealthDaySnapshot
    /// Historical fixtures keyed by start-of-day. Missing days → empty when authorized.
    var historyByDayStart: [Date: HealthDaySnapshot]

    private var observerHandler: (@MainActor () -> Void)?

    init(
        authorizationStatus: HealthKitReadAuthorizationStatus = .notDetermined,
        todayFixture: HealthDaySnapshot? = nil,
        historyByDayStart: [Date: HealthDaySnapshot] = [:],
        calendar: Calendar = .current
    ) {
        self.authorizationStatus = authorizationStatus
        let todayStart = calendar.startOfDay(for: .now)
        self.todayFixture = todayFixture ?? HealthDaySnapshot(
            dayStart: todayStart,
            stepCount: 8_432,
            sleepHours: 7.25,
            averageHeartRateBPM: 68,
            activeEnergyKilocalories: 420
        )
        self.historyByDayStart = historyByDayStart
    }

    func refreshAuthorizationStatus() async {
        refreshCount += 1
    }

    func requestAuthorization() async {
        authorizationRequestCount += 1
        authorizationStatus = statusAfterAuthorizationRequest
    }

    func daySnapshot(for date: Date, calendar: Calendar) async -> HealthDaySnapshot {
        daySnapshotRequestCount += 1
        return snapshot(for: date, calendar: calendar)
    }

    func dailyHistory(
        from startDate: Date,
        through endDate: Date,
        calendar: Calendar
    ) async -> [HealthDaySnapshot] {
        historyRequestCount += 1
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        guard start <= end else { return [] }

        var days: [HealthDaySnapshot] = []
        var cursor = start
        while cursor <= end {
            days.append(snapshot(for: cursor, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    func startObservingHealthChanges(onChange: @escaping @MainActor () -> Void) {
        startObservingCount += 1
        guard authorizationStatus == .authorized else {
            isObserving = false
            observerHandler = nil
            return
        }
        observerHandler = onChange
        isObserving = true
    }

    func stopObservingHealthChanges() {
        stopObservingCount += 1
        observerHandler = nil
        isObserving = false
    }

    /// Test helper: fire the registered observer callback (M5-18).
    func simulateHealthChange() {
        observerHandler?()
    }

    private func snapshot(for date: Date, calendar: Calendar) -> HealthDaySnapshot {
        let dayStart = calendar.startOfDay(for: date)
        guard authorizationStatus == .authorized else {
            return .empty(dayStart: dayStart)
        }
        if calendar.isDate(dayStart, inSameDayAs: todayFixture.dayStart) {
            return HealthDaySnapshot(
                dayStart: dayStart,
                stepCount: todayFixture.stepCount,
                sleepHours: todayFixture.sleepHours,
                averageHeartRateBPM: todayFixture.averageHeartRateBPM,
                activeEnergyKilocalories: todayFixture.activeEnergyKilocalories
            )
        }
        return historyByDayStart[dayStart] ?? .empty(dayStart: dayStart)
    }

    /// Test helper: set status without going through the request path.
    func setAuthorizationStatus(_ status: HealthKitReadAuthorizationStatus) {
        authorizationStatus = status
        if status != .authorized, isObserving {
            stopObservingHealthChanges()
        }
    }
}
