import Foundation
import Observation

/// Home presentation logic for schedule selection, Health goals/baselines, and
/// the live Pluri Score. Plan data itself stays in the shared `PlanStore`.
@MainActor
@Observable
final class HomeViewModel {
    /// Explicit day the user tapped on the strip (start-of-day); `nil` means
    /// "follow today" (SPEC §14 #41 default).
    private(set) var selectedDay: Date?

    private(set) var healthMetrics = HomeHealthMetricPresentation.emptyMetrics
    private(set) var scoreResult: ScoreEngine.Result?
    private(set) var scorePresentation = HomePluriScorePresentation.loading

    var pluriScore: Int? { scoreResult?.score }

    private let calendar: Calendar
    private let defaults: UserDefaults
    private let goalStore: HealthMetricGoalStore

    init(
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) {
        self.calendar = calendar
        self.defaults = defaults
        goalStore = HealthMetricGoalStore(defaults: defaults)
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

    /// Compact seven-day window containing the selected date.
    func weekDays(containing date: Date) -> [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return [calendar.startOfDay(for: date)]
        }
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: interval.start)
        }
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

    /// Real workouts available to start from Home. Completed/skipped sessions
    /// and the former Outdoor Run stub are intentionally absent.
    func recordOptions(
        todaysSessions: [PlannedSession],
        flexibleSessions: [PlannedSession] = []
    ) -> [HomeRecordOption] {
        let available = (todaysSessions + flexibleSessions).filter { $0.status == .scheduled }
        return available.map(HomeRecordOption.scheduledWorkout)
    }

    // MARK: - Health metrics and goals

    /// Pulls today's values and the user's own Health history. Goals are local
    /// and user-scoped; when absent, cards show an honest baseline comparison.
    func refreshHealthMetrics(
        using healthKit: any HealthKitReading,
        userID: String?,
        asOf: Date = .now
    ) async {
        await healthKit.refreshAuthorizationStatus()
        let snapshot = await healthKit.daySnapshot(for: asOf, calendar: calendar)
        let asOfDay = calendar.startOfDay(for: asOf)
        let historyStart = calendar.date(
            byAdding: .day,
            value: -(ScoreEngine.healthBaselineDays + ScoreEngine.healthRecentDays),
            to: asOfDay
        ) ?? asOfDay
        let history = healthKit.authorizationStatus == .authorized
            ? await healthKit.dailyHistory(from: historyStart, through: asOfDay, calendar: calendar)
            : []
        healthMetrics = makeHealthMetrics(
            snapshot: snapshot,
            history: history,
            authorizationStatus: healthKit.authorizationStatus,
            userID: userID,
            asOf: asOf
        )
    }

    func setHealthGoal(_ target: Double, for kind: HealthMetricGoal.Kind, userID: String?) {
        goalStore.setGoal(target, for: kind, userID: userID)
    }

    /// Goals are optional (SPEC §14 #81), so a user can always step back to
    /// baseline-only framing.
    func clearHealthGoal(for kind: HealthMetricGoal.Kind, userID: String?) {
        goalStore.removeGoal(for: kind, userID: userID)
    }

    func makeHealthMetrics(
        snapshot: HealthDaySnapshot,
        history: [HealthDaySnapshot],
        authorizationStatus: HealthKitReadAuthorizationStatus,
        userID: String?,
        asOf: Date
    ) -> [HomeHealthMetricPresentation] {
        [
            makeHealthMetric(
                kind: .steps,
                value: snapshot.stepCount,
                insight: HealthInsightsEngine.insight(
                    for: .steps, history: history, asOf: asOf, calendar: calendar
                ),
                authorizationStatus: authorizationStatus,
                userID: userID
            ),
            makeHealthMetric(
                kind: .sleep,
                value: snapshot.sleepHours,
                insight: HealthInsightsEngine.insight(
                    for: .sleep, history: history, asOf: asOf, calendar: calendar
                ),
                authorizationStatus: authorizationStatus,
                userID: userID
            ),
            makeHealthMetric(
                kind: .activeEnergy,
                value: snapshot.activeEnergyKilocalories,
                insight: HealthInsightsEngine.insight(
                    for: .calories, history: history, asOf: asOf, calendar: calendar
                ),
                authorizationStatus: authorizationStatus,
                userID: userID
            ),
            makeHealthMetric(
                kind: .averageHeartRate,
                value: snapshot.averageHeartRateBPM,
                insight: HealthInsightsEngine.insight(
                    for: .activeHeartRate, history: history, asOf: asOf, calendar: calendar
                ),
                authorizationStatus: authorizationStatus,
                userID: userID
            ),
        ]
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
        scoreResult = result
        scorePresentation = HomePluriScorePresentation(result: result)
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

    func formatActiveEnergy(_ value: Double?) -> String? {
        guard let value else { return nil }
        return "\(Int(value.rounded()).formatted(.number)) kcal"
    }

    private func makeHealthMetric(
        kind: HomeHealthMetricPresentation.Kind,
        value: Double?,
        insight: HealthInsightsEngine.MetricInsight,
        authorizationStatus: HealthKitReadAuthorizationStatus,
        userID: String?
    ) -> HomeHealthMetricPresentation {
        let formattedValue = format(value, for: kind) ?? emptyHealthCopy(for: authorizationStatus)
        let goalKind = kind.goalKind
        let goal = goalKind.flatMap { goalStore.goal(for: $0, userID: userID) }
        let progress = goal.flatMap { goal in
            value.map { min(max($0 / goal.target, 0), 1) }
        }
        let detail: String
        if let goal {
            detail = "Goal \(format(goal.target, for: kind) ?? "")"
        } else if let baseline = insight.baselineAverage {
            detail = "Usual \(format(baseline, for: kind) ?? "")"
        } else if kind == .averageHeartRate {
            detail = "Baseline builds from your history"
        } else {
            detail = "Set a personal goal"
        }

        return HomeHealthMetricPresentation(
            kind: kind,
            value: formattedValue,
            detail: detail,
            progress: progress,
            goal: goal?.target,
            suggestedGoal: suggestedGoal(from: insight.baselineAverage, for: kind)
        )
    }

    private func format(_ value: Double?, for kind: HomeHealthMetricPresentation.Kind) -> String? {
        switch kind {
        case .steps:
            formatSteps(value)
        case .sleep:
            formatSleepHours(value)
        case .activeEnergy:
            formatActiveEnergy(value)
        case .averageHeartRate:
            formatHeartRate(value)
        }
    }

    private func suggestedGoal(
        from baseline: Double?,
        for kind: HomeHealthMetricPresentation.Kind
    ) -> Double? {
        guard let baseline, baseline > 0 else { return nil }
        switch kind {
        case .steps:
            return max((baseline / 500).rounded() * 500, 500)
        case .sleep:
            return max((baseline * 2).rounded() / 2, 0.5)
        case .activeEnergy:
            return max((baseline / 25).rounded() * 25, 25)
        case .averageHeartRate:
            return nil
        }
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

struct HomePluriScorePresentation: Equatable, Sendable {
    var score: Int?
    var consistency: String
    var health: String
    var subtitle: String

    static let loading = HomePluriScorePresentation(
        score: nil,
        consistency: "Consistency —",
        health: "Health —",
        subtitle: "Updating from your plan and on-device health history."
    )

    init(result: ScoreEngine.Result) {
        score = result.score
        consistency = "Consistency \(Int(result.consistencyComponent.rounded()))"
        if let healthComponent = result.healthComponent {
            health = "Health \(Int(healthComponent.rounded()))"
            subtitle = "Your plan consistency and personal health trend, balanced gently."
        } else {
            health = "Health not available"
            subtitle = "Based on plan consistency until enough Apple Health history is available."
        }
    }

    private init(score: Int?, consistency: String, health: String, subtitle: String) {
        self.score = score
        self.consistency = consistency
        self.health = health
        self.subtitle = subtitle
    }
}

struct HomeHealthMetricPresentation: Identifiable, Equatable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case steps
        case sleep
        case activeEnergy
        case averageHeartRate

        var goalKind: HealthMetricGoal.Kind? {
            switch self {
            case .steps: .steps
            case .sleep: .sleep
            case .activeEnergy: .activeEnergy
            case .averageHeartRate: nil
            }
        }
    }

    var id: Kind { kind }
    var kind: Kind
    var value: String
    var detail: String
    var progress: Double?
    var goal: Double?
    var suggestedGoal: Double?

    static let emptyMetrics = Kind.allCases.map {
        HomeHealthMetricPresentation(
            kind: $0,
            value: "No data yet",
            detail: $0 == .averageHeartRate
                ? "Baseline builds from your history"
                : "Set a personal goal",
            progress: nil,
            goal: nil,
            suggestedGoal: nil
        )
    }
}
