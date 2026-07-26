import Foundation

/// Pure Workouts-tab grouping for Insights (M5-11 / SPEC §9.2 / §14 #56).
///
/// Groups completed sessions (plan-linked **and** manual `isManualLog`) by
/// calendar month of **date performed** = `startOfDay(startedAt)`. Monthly
/// totals = activity count + optional Σ `distanceMeters` when any cardio
/// distance is present. Runner-style all-time distance counts remain v2.
nonisolated enum WorkoutsListEngine {
    // MARK: - Inputs

    struct SetLogInput: Sendable, Equatable, Identifiable {
        var id: UUID
        var exerciseName: String
        var setNumber: Int
        var reps: Int?
        var weightKg: Double?
        var durationSeconds: Int?
    }

    struct SessionInput: Sendable, Equatable, Identifiable {
        var id: UUID
        var startedAt: Date
        var durationSeconds: Int?
        var distanceMeters: Double?
        var activityType: String
        var isManualLog: Bool
        var planWorkoutId: UUID?
        /// Resolved display title (plan workout title, activity label, or notes).
        var description: String
        var setLogs: [SetLogInput]
    }

    // MARK: - Outputs

    struct ExerciseSets: Sendable, Equatable, Identifiable {
        var id: String { exerciseName }
        var exerciseName: String
        var sets: [SetLogInput]
    }

    struct WorkoutCard: Sendable, Equatable, Identifiable {
        /// `WorkoutSessionRecord.id` — card identity only; do **not** pass to
        /// `WorkoutDetailView` (that expects `planWorkoutId` / `PlannedSession.id`).
        var id: UUID
        var description: String
        var startedAt: Date
        var durationSeconds: Int
        var totalReps: Int
        var distanceMeters: Double?
        var activityType: String
        var isManualLog: Bool
        /// When non-nil, Insights opens plan `WorkoutDetailView` with this id.
        var planWorkoutId: UUID?
        var exercises: [ExerciseSets]
    }

    struct MonthGroup: Sendable, Equatable, Identifiable {
        /// First instant of the calendar month.
        var monthStart: Date
        var workoutCount: Int
        /// Sum of session distances when any session has `distanceMeters`; else nil.
        var totalDistanceMeters: Double?
        var workouts: [WorkoutCard]
        var id: Date { monthStart }
    }

    // MARK: - Grouping

    /// Groups sessions by month of `startedAt` (SPEC §14 #56). Newest months /
    /// workouts first. Optional `dayFilter` keeps only sessions whose
    /// `startOfDay(startedAt)` matches (M5-13 day filter).
    static func groupByMonth(
        sessions: [SessionInput],
        calendar: Calendar = .current,
        dayFilter: Date? = nil
    ) -> [MonthGroup] {
        let filtered: [SessionInput]
        if let dayFilter {
            let day = calendar.startOfDay(for: dayFilter)
            filtered = sessions.filter { calendar.startOfDay(for: $0.startedAt) == day }
        } else {
            filtered = sessions
        }

        guard !filtered.isEmpty else { return [] }

        var buckets: [Date: [SessionInput]] = [:]
        for session in filtered {
            let day = calendar.startOfDay(for: session.startedAt)
            let components = calendar.dateComponents([.year, .month], from: day)
            let monthStart = calendar.date(from: components) ?? day
            buckets[monthStart, default: []].append(session)
        }

        return buckets.keys.sorted(by: >).map { monthStart in
            let monthSessions = (buckets[monthStart] ?? [])
                .sorted { $0.startedAt > $1.startedAt }
            let cards = monthSessions.map(makeCard)
            let distances = monthSessions.compactMap(\.distanceMeters)
            let totalDistance: Double? = distances.isEmpty
                ? nil
                : distances.reduce(0, +)
            return MonthGroup(
                monthStart: monthStart,
                workoutCount: cards.count,
                totalDistanceMeters: totalDistance,
                workouts: cards
            )
        }
    }

    // MARK: - Helpers

    static func activityTypeLabel(_ activityType: String) -> String {
        switch activityType {
        case "cardio": "Cardio"
        case "flexibility": "Flexibility"
        default: "Workout"
        }
    }

    /// Plan title wins; else non-empty notes; else activity-type label.
    static func resolveDescription(
        planTitle: String?,
        notes: String?,
        activityType: String
    ) -> String {
        if let planTitle, !planTitle.isEmpty {
            return planTitle
        }
        if let notes {
            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return activityTypeLabel(activityType)
    }

    private static func makeCard(_ session: SessionInput) -> WorkoutCard {
        let sortedLogs = session.setLogs.sorted {
            if $0.exerciseName != $1.exerciseName {
                return $0.exerciseName.localizedStandardCompare($1.exerciseName) == .orderedAscending
            }
            return $0.setNumber < $1.setNumber
        }
        var exercises: [ExerciseSets] = []
        for log in sortedLogs {
            if let index = exercises.firstIndex(where: { $0.exerciseName == log.exerciseName }) {
                exercises[index].sets.append(log)
            } else {
                exercises.append(ExerciseSets(exerciseName: log.exerciseName, sets: [log]))
            }
        }
        let totalReps = session.setLogs.reduce(0) { $0 + max(0, $1.reps ?? 0) }
        return WorkoutCard(
            id: session.id,
            description: session.description,
            startedAt: session.startedAt,
            durationSeconds: max(0, session.durationSeconds ?? 0),
            totalReps: totalReps,
            distanceMeters: session.distanceMeters,
            activityType: session.activityType,
            isManualLog: session.isManualLog,
            planWorkoutId: session.planWorkoutId,
            exercises: exercises
        )
    }
}
