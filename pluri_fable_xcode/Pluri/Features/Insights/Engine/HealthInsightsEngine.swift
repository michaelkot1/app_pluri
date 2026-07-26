import Foundation

/// Pure HealthKit averages / trend / kind guidance for Insights Performance
/// (M5-10 / SPEC §9.1 / §14 #61).
///
/// Windows and minimum sample counts reuse `ScoreEngine` constants (30-day
/// baseline, 7-day recent). Includes heart-rate averages even though score
/// ignores HR. Auth / empty display copy stays in the view model (mirror Home).
nonisolated enum HealthInsightsEngine {
    // MARK: - Types

    enum Metric: String, CaseIterable, Sendable, Equatable {
        case steps
        case sleep
        case calories
        case activeHeartRate
    }

    enum Trend: String, Sendable, Equatable {
        case up
        case down
        case flat
        case insufficientData
    }

    struct MetricInsight: Sendable, Equatable, Identifiable {
        var id: Metric { metric }
        var metric: Metric
        /// Mean over the recent window when enough samples exist.
        var recentAverage: Double?
        /// Mean over the baseline window when enough samples exist.
        var baselineAverage: Double?
        var trend: Trend
        /// Kind, non-scolding sentence when a trend is available; otherwise `nil`.
        var guidance: String?
    }

    /// ±5% vs baseline (min absolute epsilon per metric) for up/down vs flat.
    static let trendRatioThreshold = 0.05

    // MARK: - Aggregation

    /// Builds insights for every metric from on-device day snapshots.
    static func insights(
        history: [HealthDaySnapshot],
        asOf: Date,
        calendar: Calendar = .current
    ) -> [MetricInsight] {
        Metric.allCases.map { metric in
            insight(for: metric, history: history, asOf: asOf, calendar: calendar)
        }
    }

    static func insight(
        for metric: Metric,
        history: [HealthDaySnapshot],
        asOf: Date,
        calendar: Calendar = .current
    ) -> MetricInsight {
        let asOfDay = calendar.startOfDay(for: asOf)
        let recentStart = calendar.date(
            byAdding: .day,
            value: -(ScoreEngine.healthRecentDays - 1),
            to: asOfDay
        ) ?? asOfDay
        let baselineEnd = calendar.date(byAdding: .day, value: -1, to: recentStart) ?? asOfDay
        let baselineStart = calendar.date(
            byAdding: .day,
            value: -(ScoreEngine.healthBaselineDays - 1),
            to: baselineEnd
        ) ?? baselineEnd

        let byDay = Dictionary(
            uniqueKeysWithValues: history.map { (calendar.startOfDay(for: $0.dayStart), $0) }
        )
        let keyPath = keyPath(for: metric)

        let recentValues = values(
            keyPath: keyPath,
            byDay: byDay,
            from: recentStart,
            through: asOfDay,
            calendar: calendar
        )
        let baselineValues = values(
            keyPath: keyPath,
            byDay: byDay,
            from: baselineStart,
            through: baselineEnd,
            calendar: calendar
        )

        let recentAverage: Double? = recentValues.isEmpty
            ? nil
            : recentValues.reduce(0, +) / Double(recentValues.count)
        let baselineAverage: Double? = baselineValues.isEmpty
            ? nil
            : baselineValues.reduce(0, +) / Double(baselineValues.count)

        guard recentValues.count >= ScoreEngine.minRecentSampleDays,
              baselineValues.count >= ScoreEngine.minBaselineSampleDays,
              let recentAverage,
              let baselineAverage,
              baselineAverage > 0
        else {
            return MetricInsight(
                metric: metric,
                recentAverage: recentAverage,
                baselineAverage: baselineAverage,
                trend: .insufficientData,
                guidance: nil
            )
        }

        let ratio = recentAverage / baselineAverage
        let trend = trend(for: ratio)
        return MetricInsight(
            metric: metric,
            recentAverage: recentAverage,
            baselineAverage: baselineAverage,
            trend: trend,
            guidance: guidance(for: trend)
        )
    }

    // MARK: - Guidance (SPEC §14 #61)

    static func guidance(for trend: Trend) -> String? {
        switch trend {
        case .up:
            "You’re ahead of your usual pace."
        case .down:
            "Gentler week — that still counts."
        case .flat:
            "Right around your usual pace."
        case .insufficientData:
            nil
        }
    }

    // MARK: - Private

    private static func keyPath(for metric: Metric) -> KeyPath<HealthDaySnapshot, Double?> {
        switch metric {
        case .steps: \.stepCount
        case .sleep: \.sleepHours
        case .calories: \.activeEnergyKilocalories
        case .activeHeartRate: \.averageHeartRateBPM
        }
    }

    private static func trend(for ratio: Double) -> Trend {
        let upper = 1.0 + trendRatioThreshold
        let lower = 1.0 - trendRatioThreshold
        if ratio > upper { return .up }
        if ratio < lower { return .down }
        return .flat
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
}
