import Foundation
import Observation

/// Loads week Performance stats, all-time totals, and HealthKit insights
/// for the Performance tab (M5-08 / M5-09 / M5-10).
@MainActor
@Observable
final class InsightsPerformanceViewModel {
    private let repository: any WorkoutSessionRepository
    private let healthKit: any HealthKitReading
    private let calendar: Calendar

    /// Inclusive start of the displayed calendar week.
    var weekStart: Date
    var exerciseStats: [PerformanceStatsEngine.ExerciseStats] = []
    var allTimeStats: AllTimeStatsEngine.Stats = .empty
    var healthInsights: [HealthInsightsEngine.MetricInsight] = []
    var healthAuthorizationStatus: HealthKitReadAuthorizationStatus = .notDetermined
    var loadErrorMessage: String?
    var healthLoadErrorMessage: String?

    init(
        repository: any WorkoutSessionRepository,
        healthKit: any HealthKitReading,
        calendar: Calendar = .current,
        now: Date = .now
    ) {
        self.repository = repository
        self.healthKit = healthKit
        self.calendar = calendar
        self.weekStart = PerformanceStatsEngine.weekStart(containing: now, calendar: calendar)
    }

    var weekEndExclusive: Date {
        PerformanceStatsEngine.weekWindow(starting: weekStart, calendar: calendar).end
    }

    /// Last calendar day included in the week (for labels).
    var weekEndInclusive: Date {
        calendar.date(byAdding: .day, value: -1, to: weekEndExclusive) ?? weekStart
    }

    var weekLabel: String {
        let startText = weekStart.formatted(.dateTime.month(.abbreviated).day())
        let endText = weekEndInclusive.formatted(.dateTime.month(.abbreviated).day())
        return "\(startText) – \(endText)"
    }

    var isWeekEmpty: Bool {
        exerciseStats.isEmpty && loadErrorMessage == nil
    }

    var isAllTimeEmpty: Bool {
        allTimeStats.isEmpty && loadErrorMessage == nil
    }

    /// Empty / unauthorized copy mirrored from Home (SPEC §14 #57c / #61).
    var healthEmptyCopy: String {
        switch healthAuthorizationStatus {
        case .authorized:
            "No data yet"
        case .notDetermined, .denied:
            "Enable Health"
        case .unavailable:
            "Not available"
        }
    }

    func goToPreviousWeek() {
        guard let previous = calendar.date(byAdding: .day, value: -7, to: weekStart) else { return }
        weekStart = previous
        refreshWeekStats()
    }

    func goToNextWeek() {
        guard let next = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return }
        weekStart = next
        refreshWeekStats()
    }

    /// Snaps the Performance week navigator to the week containing `date`
    /// (Insights calendar day filter — M5-13 / SPEC §14 #62).
    func snapWeek(to date: Date) {
        weekStart = PerformanceStatsEngine.weekStart(containing: date, calendar: calendar)
        refreshWeekStats()
    }

    /// Reloads week stats, all-time totals, and health insights.
    func refresh() {
        refreshWeekStats()
        refreshAllTimeStats()
        Task {
            await refreshHealthInsights()
        }
    }

    func refreshWeekStats() {
        let window = PerformanceStatsEngine.weekWindow(starting: weekStart, calendar: calendar)
        do {
            let sessions = try repository.fetchCompletedSessions(
                endingOnOrAfter: window.start,
                endingBefore: window.end
            )
            let inputs = sessions.map { session in
                PerformanceStatsEngine.SessionInput(
                    id: session.id,
                    endedAt: session.endedAt ?? session.startedAt,
                    setLogs: session.setLogs.map { log in
                        PerformanceStatsEngine.SetLogInput(
                            exerciseName: log.exerciseName,
                            reps: log.reps,
                            weightKg: log.weightKg
                        )
                    }
                )
            }
            exerciseStats = PerformanceStatsEngine.aggregate(
                sessions: inputs,
                weekStart: weekStart,
                calendar: calendar
            )
            loadErrorMessage = nil
        } catch {
            exerciseStats = []
            loadErrorMessage = "Couldn't load performance yet."
        }
    }

    func refreshAllTimeStats() {
        do {
            let sessions = try repository.fetchAllCompletedSessions()
            let inputs = sessions.map { session in
                AllTimeStatsEngine.SessionInput(
                    id: session.id,
                    durationSeconds: session.durationSeconds,
                    setLogs: session.setLogs.map { log in
                        AllTimeStatsEngine.SetLogInput(
                            reps: log.reps,
                            weightKg: log.weightKg
                        )
                    }
                )
            }
            allTimeStats = AllTimeStatsEngine.aggregate(sessions: inputs)
        } catch {
            allTimeStats = .empty
            if loadErrorMessage == nil {
                loadErrorMessage = "Couldn't load performance yet."
            }
        }
    }

    func refreshHealthInsights(asOf: Date = .now) async {
        await healthKit.refreshAuthorizationStatus()
        healthAuthorizationStatus = healthKit.authorizationStatus

        let asOfDay = calendar.startOfDay(for: asOf)
        let historyStart = calendar.date(
            byAdding: .day,
            value: -(ScoreEngine.healthBaselineDays + ScoreEngine.healthRecentDays),
            to: asOfDay
        ) ?? asOfDay

        let authorized = healthAuthorizationStatus == .authorized
        let history: [HealthDaySnapshot]
        if authorized {
            history = await healthKit.dailyHistory(
                from: historyStart,
                through: asOfDay,
                calendar: calendar
            )
        } else {
            history = []
        }

        healthInsights = HealthInsightsEngine.insights(
            history: history,
            asOf: asOf,
            calendar: calendar
        )
        healthLoadErrorMessage = nil
    }

    func visibleHealthInsights(for section: InsightsSection) -> [HealthInsightsEngine.MetricInsight] {
        if let metric = section.healthMetric {
            return healthInsights.filter { $0.metric == metric }
        }
        return healthInsights
    }
}
