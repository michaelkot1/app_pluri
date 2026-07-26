import Foundation
import Observation

/// Home screen logic (M3-07..09 / M5-04..06): calendar-strip day selection,
/// month summary counting, Record Workout menu derivation, Today's Health
/// tile formatting, and live Pluri Score refresh — kept out of the views so
/// it's unit-testable. Plan data itself stays in the shared `PlanStore`.
@MainActor
@Observable
final class HomeViewModel {
    /// Explicit day the user tapped on the strip (start-of-day); `nil` means
    /// "follow today" (SPEC §14 #41 default).
    private(set) var selectedDay: Date?

    /// Formatted Today's Health tile values (M5-04).
    private(set) var healthTileMetrics = HomeHealthTileMetrics.empty

    /// Live Pluri Score 0…100 (M5-06). `nil` until the first refresh completes.
    private(set) var pluriScore: Int?

    /// Short kind subtitle under the score numeral.
    private(set) var scoreSubtitle =
        "Consistency first — HealthKit adds a gentle second layer on this device."

    private let calendar: Calendar
    private let defaults: UserDefaults

    init(
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) {
        self.calendar = calendar
        self.defaults = defaults
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

    // MARK: - Today's Health tiles (M5-04)

    /// Formats tile values from a day snapshot + auth posture (SPEC §14 #57c).
    /// Authorized empties → "No data yet"; not connected → "Enable Health".
    func healthTileMetrics(
        snapshot: HealthDaySnapshot,
        authorizationStatus: HealthKitReadAuthorizationStatus
    ) -> HomeHealthTileMetrics {
        let emptyCopy = emptyHealthCopy(for: authorizationStatus)
        return HomeHealthTileMetrics(
            stepsValue: formatSteps(snapshot.stepCount) ?? emptyCopy,
            sleepValue: formatSleepHours(snapshot.sleepHours) ?? emptyCopy,
            heartRateValue: formatHeartRate(snapshot.averageHeartRateBPM) ?? emptyCopy,
            isEmptyPlaceholder: snapshot.stepCount == nil
                && snapshot.sleepHours == nil
                && snapshot.averageHeartRateBPM == nil
        )
    }

    /// Pulls today's snapshot and updates tile display state.
    func refreshHealthTiles(using healthKit: any HealthKitReading) async {
        await healthKit.refreshAuthorizationStatus()
        let snapshot = await healthKit.todaySnapshot(calendar: calendar)
        healthTileMetrics = healthTileMetrics(
            snapshot: snapshot,
            authorizationStatus: healthKit.authorizationStatus
        )
    }

    // MARK: - Pluri Score (M5-05 / M5-06)

    /// Recomputes the live score from plan sessions + on-device health history,
    /// persists the clamped result for the daily Δ guard, and updates display.
    func refreshPluriScore(
        sessions: [PlannedSession],
        healthKit: any HealthKitReading,
        userID: String?,
        asOf: Date = .now
    ) async {
        await healthKit.refreshAuthorizationStatus()
        let asOfDay = calendar.startOfDay(for: asOf)
        let historyStart = calendar.date(
            byAdding: .day,
            value: -(ScoreEngine.healthBaselineDays + ScoreEngine.healthRecentDays),
            to: asOfDay
        ) ?? asOfDay

        let history: [HealthDaySnapshot]
        let authorized = healthKit.authorizationStatus == .authorized
        if authorized {
            history = await healthKit.dailyHistory(
                from: historyStart,
                through: asOfDay,
                calendar: calendar
            )
        } else {
            history = []
        }

        let previous = PluriScoreStore.load(userID: userID, defaults: defaults)
        let isSameDay = previous.map {
            calendar.isDate($0.dayStart, inSameDayAs: asOfDay)
        } ?? false

        // Clamp against a day-frozen base: same day → stored clampBase;
        // new day → previous day's latest display (SPEC §14 #57a ±3/day).
        let clampBase: Double?
        if let previous {
            clampBase = isSameDay ? previous.clampBase : previous.latestScore
        } else {
            clampBase = nil
        }

        let result = ScoreEngine.compute(
            ScoreEngine.Input(
                sessions: sessions,
                healthHistory: history,
                healthAuthorized: authorized,
                previousScore: clampBase,
                previousScoreDayStart: previous?.dayStart,
                asOf: asOf,
                calendar: calendar
            )
        )

        let newClampBase: Double
        if let previous, isSameDay {
            newClampBase = previous.clampBase
        } else if let clampBase {
            newClampBase = clampBase
        } else {
            newClampBase = Double(result.score)
        }

        PluriScoreStore.save(
            clampBase: newClampBase,
            latestScore: Double(result.score),
            dayStart: asOfDay,
            userID: userID,
            defaults: defaults
        )
        pluriScore = result.score
        scoreSubtitle = result.usedHealthComponent
            ? "Consistency first, with a gentle HealthKit layer — moves slowly (±3/day)."
            : "Based on plan consistency for now — connect Apple Health for a second layer."
    }

    /// Fingerprint of dated session statuses so Home can refresh when completion changes.
    static func scoreRefreshToken(sessions: [PlannedSession]) -> String {
        sessions
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString):\($0.status.rawValue)" }
            .joined(separator: "|")
    }

    // MARK: - Formatting helpers

    func formatSteps(_ value: Double?) -> String? {
        guard let value else { return nil }
        return Int(value.rounded()).formatted(.number)
    }

    func formatSleepHours(_ value: Double?) -> String? {
        guard let value else { return nil }
        let hours = value.formatted(.number.precision(.fractionLength(1)))
        return "\(hours) hr"
    }

    func formatHeartRate(_ value: Double?) -> String? {
        guard let value else { return nil }
        let bpm = Int(value.rounded()).formatted(.number)
        return "\(bpm) BPM"
    }

    private func emptyHealthCopy(for status: HealthKitReadAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "No data yet"
        case .notDetermined, .denied:
            return "Enable Health"
        case .unavailable:
            return "Not available"
        }
    }
}

/// Display strings for the three Today's Health tiles (M5-04).
struct HomeHealthTileMetrics: Equatable, Sendable {
    var stepsValue: String
    var sleepValue: String
    var heartRateValue: String
    var isEmptyPlaceholder: Bool

    static let empty = HomeHealthTileMetrics(
        stepsValue: "No data yet",
        sleepValue: "No data yet",
        heartRateValue: "No data yet",
        isEmptyPlaceholder: true
    )

    func value(for section: InsightsSection) -> String {
        switch section {
        case .steps, .general: stepsValue
        case .sleep: sleepValue
        case .activeHeartRate: heartRateValue
        case .calories: "—"
        }
    }
}
