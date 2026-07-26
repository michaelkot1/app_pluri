import Foundation

/// Pure Pluri Score calculator (M5-05 / SPEC §5.1 / §14 #57).
///
/// Modeled on `PlanEngine`: a `nonisolated enum` of static functions with no
/// `@MainActor` / HealthKit / network coupling so it is unit-testable and
/// keeps score inputs on-device (SPEC §13). Formula:
/// `0.7 × consistency + 0.3 × health`, daily Δ clamp ±3, score 0–100.
///
/// When HealthKit is unauthorized or health samples cannot form a trend,
/// the score redistributes to **100% consistency** (no invented health).
nonisolated enum ScoreEngine {
    // MARK: Locked weights / windows (SPEC §14 #57)

    static let consistencyWeight = 0.7
    static let healthWeight = 0.3

    /// Trailing window for plan adherence (4 calendar weeks).
    static let consistencyTrailingDays = 28

    /// Baseline window for health trend (user’s own history).
    static let healthBaselineDays = 30

    /// Recent window compared against the 30-day baseline.
    static let healthRecentDays = 7

    /// Maximum absolute change vs the previous persisted score per calendar day.
    static let maxDailyDelta = 3.0

    // MARK: Tunable consistency additives (SPEC §14 #57 / #59)

    /// Points added to the 0–100 consistency component per consecutive completed day.
    static let streakBonusPerConsecutiveCompletedDay = 1.0
    static let maxStreakBonus = 5.0

    /// Points subtracted for consecutive recent days with incomplete dated workouts.
    static let decayPerConsecutiveMissedDay = 1.0
    static let maxDecay = 5.0

    // MARK: Tunable health-trend mapping (SPEC §14 #59)

    /// At 1.0× baseline the health component lands here (kind mid-high).
    static let healthScoreAtBaseline = 70.0
    /// Ratio span from baseline to the top/bottom of the mapped band.
    static let healthRatioBand = 0.25
    /// Points spanned across `healthRatioBand` above/below baseline.
    static let healthScoreBand = 30.0

    /// Minimum sample days required in baseline / recent windows to use a metric.
    static let minBaselineSampleDays = 3
    static let minRecentSampleDays = 1

    // MARK: Types

    /// Inputs for a single on-device score computation. Never upload.
    struct Input: Sendable {
        var sessions: [PlannedSession]
        var healthHistory: [HealthDaySnapshot]
        /// `true` only when read auth is `.authorized` (denied / undetermined → consistency-only).
        var healthAuthorized: Bool
        var previousScore: Double?
        var previousScoreDayStart: Date?
        var asOf: Date
        var calendar: Calendar

        init(
            sessions: [PlannedSession],
            healthHistory: [HealthDaySnapshot] = [],
            healthAuthorized: Bool = false,
            previousScore: Double? = nil,
            previousScoreDayStart: Date? = nil,
            asOf: Date,
            calendar: Calendar = .current
        ) {
            self.sessions = sessions
            self.healthHistory = healthHistory
            self.healthAuthorized = healthAuthorized
            self.previousScore = previousScore
            self.previousScoreDayStart = previousScoreDayStart
            self.asOf = asOf
            self.calendar = calendar
        }
    }

    /// Result of a score pass — components exposed for tests / future Insights explainer.
    struct Result: Equatable, Sendable {
        /// Display score 0…100 after daily clamp.
        var score: Int
        var consistencyComponent: Double
        /// `nil` when health was redistributed away (unauthorized / insufficient samples).
        var healthComponent: Double?
        var usedHealthComponent: Bool
        /// Combined score before the ±3 daily clamp (still 0…100).
        var rawUnclamped: Double
    }

    // MARK: Entry point

    static func compute(_ input: Input) -> Result {
        let asOfDay = input.calendar.startOfDay(for: input.asOf)
        let consistency = consistencyComponent(
            sessions: input.sessions,
            asOfDay: asOfDay,
            calendar: input.calendar
        )

        let health: Double?
        if input.healthAuthorized {
            health = healthComponent(
                history: input.healthHistory,
                asOfDay: asOfDay,
                calendar: input.calendar
            )
        } else {
            health = nil
        }

        let raw: Double
        if let health {
            raw = clampScore(
                consistencyWeight * consistency + healthWeight * health
            )
        } else {
            // Unauthorized / missing → 100% consistency (SPEC §14 #57a).
            raw = clampScore(consistency)
        }

        let clamped = applyDailyClamp(
            raw: raw,
            previousScore: input.previousScore,
            previousDayStart: input.previousScoreDayStart,
            asOfDay: asOfDay,
            calendar: input.calendar
        )

        return Result(
            score: Int(clamped.rounded()),
            consistencyComponent: consistency,
            healthComponent: health,
            usedHealthComponent: health != nil,
            rawUnclamped: raw
        )
    }

    // MARK: Consistency

    /// Completed ÷ dated sessions over the trailing 4 weeks, plus streak bonus
    /// and gentle decay. Flexible / `date == nil` sessions are excluded.
    /// Skipped counts as not completed. Empty denominator → 100 (nothing to miss).
    static func consistencyComponent(
        sessions: [PlannedSession],
        asOfDay: Date,
        calendar: Calendar
    ) -> Double {
        let windowStart = calendar.date(
            byAdding: .day,
            value: -(consistencyTrailingDays - 1),
            to: asOfDay
        ) ?? asOfDay

        let datedInWindow = sessions.filter { session in
            guard let date = session.date else { return false }
            let day = calendar.startOfDay(for: date)
            return day >= windowStart && day <= asOfDay
        }

        let base: Double
        if datedInWindow.isEmpty {
            base = 100
        } else {
            let completed = datedInWindow.count { $0.status == .completed }
            base = (Double(completed) / Double(datedInWindow.count)) * 100
        }

        let streakBonus = streakBonus(
            sessions: datedInWindow,
            asOfDay: asOfDay,
            calendar: calendar
        )
        let decay = missedDayDecay(
            sessions: datedInWindow,
            asOfDay: asOfDay,
            calendar: calendar
        )

        return clampScore(base + streakBonus - decay)
    }

    /// Consecutive calendar days (walking back from `asOfDay`) where every
    /// dated workout that day is `.completed`. Days with no dated workouts
    /// are skipped (do not break the streak).
    static func streakBonus(
        sessions: [PlannedSession],
        asOfDay: Date,
        calendar: Calendar
    ) -> Double {
        let byDay = Dictionary(grouping: sessions) {
            calendar.startOfDay(for: $0.date ?? .distantPast)
        }

        var streakDays = 0
        var cursor = asOfDay
        for _ in 0..<consistencyTrailingDays {
            if let daySessions = byDay[cursor], !daySessions.isEmpty {
                if daySessions.allSatisfy({ $0.status == .completed }) {
                    streakDays += 1
                } else {
                    break
                }
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return min(Double(streakDays) * streakBonusPerConsecutiveCompletedDay, maxStreakBonus)
    }

    /// Consecutive calendar days (walking back from `asOfDay`) that have at
    /// least one dated workout not completed. Empty days are skipped.
    static func missedDayDecay(
        sessions: [PlannedSession],
        asOfDay: Date,
        calendar: Calendar
    ) -> Double {
        let byDay = Dictionary(grouping: sessions) {
            calendar.startOfDay(for: $0.date ?? .distantPast)
        }

        var missedDays = 0
        var cursor = asOfDay
        for _ in 0..<consistencyTrailingDays {
            if let daySessions = byDay[cursor], !daySessions.isEmpty {
                if daySessions.contains(where: { $0.status != .completed }) {
                    missedDays += 1
                } else {
                    break
                }
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return min(Double(missedDays) * decayPerConsecutiveMissedDay, maxDecay)
    }

    // MARK: Health

    /// Trend of steps / sleep / active energy vs 30-day baseline → 0…100.
    /// Returns `nil` when no metric has enough samples (caller redistributes).
    static func healthComponent(
        history: [HealthDaySnapshot],
        asOfDay: Date,
        calendar: Calendar
    ) -> Double? {
        let recentStart = calendar.date(
            byAdding: .day,
            value: -(healthRecentDays - 1),
            to: asOfDay
        ) ?? asOfDay
        let baselineEnd = calendar.date(byAdding: .day, value: -1, to: recentStart) ?? asOfDay
        let baselineStart = calendar.date(
            byAdding: .day,
            value: -(healthBaselineDays - 1),
            to: baselineEnd
        ) ?? baselineEnd

        let byDay = Dictionary(
            uniqueKeysWithValues: history.map { (calendar.startOfDay(for: $0.dayStart), $0) }
        )

        var components: [Double] = []
        for keyPath in healthMetricKeyPaths {
            if let score = metricTrendScore(
                keyPath: keyPath,
                byDay: byDay,
                recentStart: recentStart,
                recentEnd: asOfDay,
                baselineStart: baselineStart,
                baselineEnd: baselineEnd,
                calendar: calendar
            ) {
                components.append(score)
            }
        }

        guard !components.isEmpty else { return nil }
        return clampScore(components.reduce(0, +) / Double(components.count))
    }

    private static let healthMetricKeyPaths: [KeyPath<HealthDaySnapshot, Double?>] = [
        \.stepCount,
        \.sleepHours,
        \.activeEnergyKilocalories,
    ]

    private static func metricTrendScore(
        keyPath: KeyPath<HealthDaySnapshot, Double?>,
        byDay: [Date: HealthDaySnapshot],
        recentStart: Date,
        recentEnd: Date,
        baselineStart: Date,
        baselineEnd: Date,
        calendar: Calendar
    ) -> Double? {
        let recentValues = values(
            keyPath: keyPath,
            byDay: byDay,
            from: recentStart,
            through: recentEnd,
            calendar: calendar
        )
        let baselineValues = values(
            keyPath: keyPath,
            byDay: byDay,
            from: baselineStart,
            through: baselineEnd,
            calendar: calendar
        )

        guard recentValues.count >= minRecentSampleDays,
              baselineValues.count >= minBaselineSampleDays
        else {
            return nil
        }

        let recentMean = recentValues.reduce(0, +) / Double(recentValues.count)
        let baselineMean = baselineValues.reduce(0, +) / Double(baselineValues.count)
        guard baselineMean > 0 else { return nil }

        let ratio = recentMean / baselineMean
        return scoreFromHealthRatio(ratio)
    }

    private static func values(
        keyPath: KeyPath<HealthDaySnapshot, Double?>,
        byDay: [Date: HealthDaySnapshot],
        from start: Date,
        through end: Date,
        calendar: Calendar
    ) -> [Double] {
        var result: [Double] = []
        var cursor = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while cursor <= endDay {
            if let value = byDay[cursor]?[keyPath: keyPath] {
                result.append(value)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    /// Maps recent÷baseline ratio onto 0…100 around `healthScoreAtBaseline`.
    static func scoreFromHealthRatio(_ ratio: Double) -> Double {
        let delta = (ratio - 1.0) / healthRatioBand * healthScoreBand
        return clampScore(healthScoreAtBaseline + delta)
    }

    // MARK: Clamp

    /// Softens day-to-day movement: clamp vs the caller's day-frozen anchor
    /// (`previousScore` — typically prior day's latest, held for the whole
    /// calendar day). Same-day refreshes must pass the same anchor so the
    /// displayed score cannot ratchet beyond ±`maxDailyDelta` (SPEC §14 #57a).
    static func applyDailyClamp(
        raw: Double,
        previousScore: Double?,
        previousDayStart: Date?,
        asOfDay: Date,
        calendar: Calendar
    ) -> Double {
        guard let previousScore else {
            return clampScore(raw)
        }

        // `previousDayStart` / `asOfDay` document the caller's day-scoped
        // anchor contract; clamp math is always vs `previousScore`.
        _ = previousDayStart
        _ = calendar
        _ = asOfDay
        let lower = previousScore - maxDailyDelta
        let upper = previousScore + maxDailyDelta
        return clampScore(min(max(raw, lower), upper))
    }

    static func clampScore(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}
