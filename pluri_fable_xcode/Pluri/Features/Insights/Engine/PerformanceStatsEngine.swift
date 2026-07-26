import Foundation

/// Pure per-exercise Performance aggregation for Insights (M5-08 / SPEC §9.1 / §14 #60).
///
/// Modeled on `ScoreEngine`: a `nonisolated enum` of static functions with no
/// `@MainActor` / SwiftData / UI coupling so it is unit-testable. Volume is
/// `Σ(reps × weightKg)` for sets that have both; sets without weight contribute
/// only to sets/reps totals (no invented kilograms).
nonisolated enum PerformanceStatsEngine {
    // MARK: - Inputs

    struct SetLogInput: Sendable, Equatable {
        var exerciseName: String
        var reps: Int?
        var weightKg: Double?
    }

    /// One completed session's set logs. Filter by `endedAt` (completion day).
    struct SessionInput: Sendable, Equatable {
        var id: UUID
        var endedAt: Date
        var setLogs: [SetLogInput]
    }

    // MARK: - Outputs

    struct ExerciseDayPoint: Sendable, Equatable, Identifiable {
        var id: Date { dayStart }
        var dayStart: Date
        var setCount: Int
        var totalReps: Int
        /// Sum of `reps × weightKg` for weighted sets that day; `nil` if none.
        var volumeKg: Double?
    }

    enum Trend: String, Sendable, Equatable {
        case up
        case down
        case flat
        case insufficientData
    }

    struct ExerciseStats: Sendable, Equatable, Identifiable {
        var id: String { exerciseName }
        var exerciseName: String
        var setCount: Int
        var totalReps: Int
        /// Week volume in kg·reps; `nil` when no weighted sets were logged.
        var volumeKg: Double?
        var points: [ExerciseDayPoint]
        var trend: Trend
    }

    struct WeekWindow: Sendable, Equatable {
        /// Inclusive start of the calendar week.
        var start: Date
        /// Exclusive end of the calendar week.
        var end: Date
    }

    // MARK: - Week helpers

    static func weekStart(containing date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }

    static func weekWindow(starting weekStart: Date, calendar: Calendar = .current) -> WeekWindow {
        let start = calendar.startOfDay(for: weekStart)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return WeekWindow(start: start, end: end)
    }

    static func weekWindow(containing date: Date, calendar: Calendar = .current) -> WeekWindow {
        weekWindow(starting: weekStart(containing: date, calendar: calendar), calendar: calendar)
    }

    // MARK: - Aggregation

    /// Aggregates completed sessions into per-exercise stats for the week that
    /// begins at `weekStart`. Sessions outside the window are ignored.
    static func aggregate(
        sessions: [SessionInput],
        weekStart: Date,
        calendar: Calendar = .current
    ) -> [ExerciseStats] {
        let window = weekWindow(starting: weekStart, calendar: calendar)
        let inWindow = sessions.filter { session in
            session.endedAt >= window.start && session.endedAt < window.end
        }

        var buckets: [String: [DayAccumulator]] = [:]

        for session in inWindow {
            let day = calendar.startOfDay(for: session.endedAt)
            for log in session.setLogs {
                let name = log.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }

                var dayBuckets = buckets[name] ?? []
                if let index = dayBuckets.firstIndex(where: { $0.dayStart == day }) {
                    dayBuckets[index].add(log)
                } else {
                    var accumulator = DayAccumulator(dayStart: day)
                    accumulator.add(log)
                    dayBuckets.append(accumulator)
                }
                buckets[name] = dayBuckets
            }
        }

        return buckets.map { name, dayBuckets in
            let sortedDays = dayBuckets.sorted { $0.dayStart < $1.dayStart }
            let points = sortedDays.map { $0.asPoint() }
            let setCount = points.reduce(0) { $0 + $1.setCount }
            let totalReps = points.reduce(0) { $0 + $1.totalReps }
            let volumeParts = points.compactMap(\.volumeKg)
            let volumeKg: Double? = volumeParts.isEmpty ? nil : volumeParts.reduce(0, +)
            return ExerciseStats(
                exerciseName: name,
                setCount: setCount,
                totalReps: totalReps,
                volumeKg: volumeKg,
                points: points,
                trend: trend(for: points)
            )
        }
        .sorted { lhs, rhs in
            let leftVolume = lhs.volumeKg ?? -1
            let rightVolume = rhs.volumeKg ?? -1
            if leftVolume != rightVolume {
                return leftVolume > rightVolume
            }
            if lhs.totalReps != rhs.totalReps {
                return lhs.totalReps > rhs.totalReps
            }
            return lhs.exerciseName.localizedStandardCompare(rhs.exerciseName) == .orderedAscending
        }
    }

    // MARK: - Private

    private struct DayAccumulator {
        var dayStart: Date
        var setCount = 0
        var totalReps = 0
        var volumeKg: Double?

        mutating func add(_ log: SetLogInput) {
            setCount += 1
            let reps = max(0, log.reps ?? 0)
            totalReps += reps
            if let weightKg = log.weightKg, let loggedReps = log.reps, loggedReps > 0 {
                volumeKg = (volumeKg ?? 0) + (Double(loggedReps) * weightKg)
            }
        }

        func asPoint() -> ExerciseDayPoint {
            ExerciseDayPoint(
                dayStart: dayStart,
                setCount: setCount,
                totalReps: totalReps,
                volumeKg: volumeKg
            )
        }
    }

    /// Compares the first and last day points in the week using volume when
    /// available, otherwise total reps. Needs at least two days of data.
    private static func trend(for points: [ExerciseDayPoint]) -> Trend {
        guard points.count >= 2 else { return .insufficientData }
        let first = metric(for: points[0])
        let last = metric(for: points[points.count - 1])
        let delta = last - first
        let threshold = max(abs(first) * 0.05, 1)
        if delta > threshold { return .up }
        if delta < -threshold { return .down }
        return .flat
    }

    private static func metric(for point: ExerciseDayPoint) -> Double {
        if let volumeKg = point.volumeKg {
            return volumeKg
        }
        return Double(point.totalReps)
    }
}
