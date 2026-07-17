import Foundation

/// Pure, deterministic v1 plan generator (M1-16).
///
/// Modeled on `CalorieCalculator`: a `nonisolated enum` of static functions
/// with no `@MainActor`/SwiftData coupling, so it is trivially unit-testable
/// (M1-17) and can later be ported almost verbatim to the `generate-plan`
/// Edge Function (PLAN §1.3). Given the same `(input, catalog, seed)` it always
/// produces the same `GeneratedPlan`.
///
/// Algorithm (SPEC §3.3, PLAN §1.4 — kept intentionally simple for v1, with
/// the concrete choices recorded in SPEC §14):
/// 1. Filter the catalog to weight-training exercises the user can do —
///    equipment they selected, excluding any injured body area, excluding the
///    `"Cardio"` body part (v1 is Workout-only, SPEC §1.1).
/// 2. Bucket by body part, seed-shuffle within each bucket, and round-robin
///    across buckets into one balanced pool.
/// 3. Chunk the balanced pool into `sessionsPerWeek` sessions of a size that
///    fits the chosen session duration.
/// 4. Repeat those session templates for every week, applying simple
///    rep-then-set progression, and pin them to weekdays/dates for scheduled
///    plans.
///
/// Marked `nonisolated` so it opts out of the project's main-actor default
/// isolation (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) — the engine must
/// run off the main actor and be callable from tests without hopping actors.
nonisolated enum PlanEngine {
    // MARK: Tunable constants (SPEC §14)

    /// Rough wall-clock minutes budgeted per exercise, including its sets,
    /// inter-set rest, and setup/transition. Drives how many exercises fit in
    /// a session of a given duration.
    static let minutesPerExercise: Double = 8

    /// Minutes budgeted per working set, used only for the session's teaser
    /// `estimatedMinutes` readout.
    static let minutesPerSet: Double = 2

    static let minExercisesPerSession = 3
    static let maxExercisesPerSession = 8

    /// How many exercises fit in a session of `minutes` length, clamped to a
    /// sane range so very short/long picks still yield a coherent workout.
    static func exercisesPerSession(forDurationMinutes minutes: Int) -> Int {
        let raw = Int((Double(minutes) / minutesPerExercise).rounded())
        return min(max(raw, minExercisesPerSession), maxExercisesPerSession)
    }

    // MARK: Entry point

    static func generate(input: PlanInput, catalog: [Exercise], seed: UInt64) throws -> GeneratedPlan {
        guard !catalog.isEmpty else { throw PlanEngineError.emptyCatalog }

        let eligible = filteredCatalog(catalog, input: input)
        guard !eligible.isEmpty else { throw PlanEngineError.noEligibleExercises }

        var rng = SeededGenerator(seed: seed)
        let templates = buildSessionTemplates(from: eligible, input: input, rng: &rng)
        guard templates.contains(where: { !$0.isEmpty }) else { throw PlanEngineError.noEligibleExercises }

        let weekCount = max(input.planLengthWeeks, 1)
        let weeks = (1...weekCount).map { weekNumber in
            buildWeek(weekNumber: weekNumber, templates: templates, input: input)
        }

        return GeneratedPlan(
            goal: input.goal,
            scheduleType: input.scheduleType,
            sessionDurationMinutes: input.sessionDurationMinutes,
            startDate: input.startDate,
            weeks: weeks,
            seed: seed
        )
    }

    // MARK: Step 1 — filtering

    /// Weight-training exercises the user can actually perform: available
    /// equipment (normalized match, SPEC §14), no injured body area (v1
    /// excludes the whole `bodyPart` regardless of pain level, SPEC §14), and
    /// no `"Cardio"` body part (v1 is Workout-only, SPEC §1.1). Sorted by id
    /// for a deterministic base ordering before any shuffling.
    static func filteredCatalog(_ catalog: [Exercise], input: PlanInput) -> [Exercise] {
        let selection = EquipmentMatcher.normalizedKeys(for: input.equipment)
        let injuredParts = Set(input.injuries.keys.map(\.rawValue))

        return catalog
            .filter { exercise in
                exercise.bodyPart != "Cardio"
                    && !injuredParts.contains(exercise.bodyPart)
                    && EquipmentMatcher.isAvailable(exercise.equipment, in: selection)
            }
            .sorted { $0.id < $1.id }
    }

    // MARK: Step 2 & 3 — balanced selection into session templates

    /// Builds `sessionsPerWeek` balanced session templates. Exercises are
    /// grouped by body part, seed-shuffled within each group, then drawn
    /// round-robin across groups into one balanced pool; contiguous chunks of
    /// that pool become sessions, so each session spans varied muscle groups.
    ///
    /// If the eligible pool is smaller than the plan needs (e.g. a very
    /// restricted bodyweight/injury combination), the pool is cycled — some
    /// exercises then recur across the week, which is acceptable for a v1
    /// plan and only happens for unusually small catalogs.
    static func buildSessionTemplates(
        from eligible: [Exercise],
        input: PlanInput,
        rng: inout SeededGenerator
    ) -> [[Exercise]] {
        let sessionCount = input.sessionsPerWeek
        let perSession = exercisesPerSession(forDurationMinutes: input.sessionDurationMinutes)

        let grouped = Dictionary(grouping: eligible, by: \.bodyPart)
        let buckets = grouped.keys.sorted().map { part in
            (grouped[part] ?? []).shuffled(using: &rng)
        }

        var pool: [Exercise] = []
        var moreRemaining = true
        var depth = 0
        while moreRemaining {
            moreRemaining = false
            for bucketIndex in buckets.indices where depth < buckets[bucketIndex].count {
                pool.append(buckets[bucketIndex][depth])
                moreRemaining = true
            }
            depth += 1
        }

        guard !pool.isEmpty else { return [] }

        let needed = sessionCount * perSession
        let selection = (0..<needed).map { pool[$0 % pool.count] }

        return (0..<sessionCount).map { sessionIndex in
            let start = sessionIndex * perSession
            return Array(selection[start..<start + perSession])
        }
    }

    // MARK: Step 4 — weeks, progression, scheduling

    static func buildWeek(weekNumber: Int, templates: [[Exercise]], input: PlanInput) -> PlanWeek {
        let base = baseSetsReps(goal: input.goal)
        let target = progression(base: base, week: weekNumber)
        let calendar = Calendar.current
        let trainingDates = orderedTrainingDates(weekNumber: weekNumber, input: input, calendar: calendar)

        let sessions = templates.enumerated().map { sessionIndex, exercises in
            // Sessions map onto the week's training-day dates in chronological
            // order (M3-02), so indexInWeek, order, and dates ascend together.
            let slot = sessionIndex < trainingDates.count ? trainingDates[sessionIndex] : nil
            let planned = exercises.enumerated().map { order, exercise in
                PlannedExercise(
                    exerciseID: exercise.id,
                    name: exercise.name,
                    bodyPart: exercise.bodyPart,
                    equipment: exercise.equipment,
                    targetMuscle: exercise.targetMuscle,
                    secondaryMuscles: exercise.secondaryMuscles,
                    imageURL: exercise.imageURL,
                    order: order,
                    sets: target.sets,
                    reps: target.reps
                )
            }
            return PlannedSession(
                title: sessionTitle(for: exercises),
                indexInWeek: sessionIndex + 1,
                weekday: slot?.weekday,
                date: slot?.date,
                status: .scheduled,
                workoutType: .weights,
                color: nil,
                orderIndex: (weekNumber - 1) * templates.count + sessionIndex,
                exercises: planned
            )
        }

        return PlanWeek(number: weekNumber, sessions: sessions)
    }

    /// Base sets × reps per goal (SPEC §14): strength = heavy/low-rep,
    /// hypertrophy = moderate, fat-loss/tone = higher-rep, general = moderate.
    static func baseSetsReps(goal: Goal) -> (sets: Int, reps: Int) {
        switch goal {
        case .getStronger: (4, 5)
        case .buildMuscle: (3, 10)
        case .loseFatToneUp: (3, 12)
        case .generalFitness: (3, 10)
        }
    }

    /// Simple linear progression (SPEC §14): +1 rep per week capped at +3,
    /// then an extra set from week 5 onward.
    static func progression(base: (sets: Int, reps: Int), week: Int) -> (sets: Int, reps: Int) {
        let weekIndex = max(week - 1, 0)
        let reps = base.reps + min(weekIndex, 3)
        let sets = base.sets + (weekIndex >= 4 ? 1 : 0)
        return (sets, reps)
    }

    /// The concrete `(weekday, date)` slots for a scheduled plan week, in
    /// **chronological order** within the rolling 7-day window that starts
    /// `weekNumber − 1` weeks after the plan's start date (M3-02).
    ///
    /// Anchoring the scan at the week's start date — rather than mapping
    /// sessions onto Sunday-first-sorted training days — is what keeps
    /// mid-week starts correct: a plan starting Wednesday with Mon/Wed/Fri
    /// yields Wed → Fri → *next* Mon, so "Workout 1" is always the earliest
    /// date. Flexible plans return an empty array (no pinned days, SPEC §3.2
    /// Q9 / §14 #37).
    static func orderedTrainingDates(
        weekNumber: Int,
        input: PlanInput,
        calendar: Calendar
    ) -> [(weekday: Weekday, date: Date)] {
        guard input.scheduleType == .scheduled else { return [] }
        let weekStart = calendar.date(byAdding: .day, value: (weekNumber - 1) * 7, to: input.startDate)
            ?? input.startDate
        let wanted = Set(input.trainingDays.map(\.rawValue))

        var slots: [(weekday: Weekday, date: Date)] = []
        for offset in 0..<7 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
            let component = calendar.component(.weekday, from: candidate)
            if wanted.contains(component), let weekday = Weekday(rawValue: component) {
                slots.append((weekday, candidate))
            }
        }
        return slots
    }

    /// A friendly session title from its body parts: the one or two most
    /// common (tie-broken alphabetically for determinism), or "Full Body" when
    /// it spans four or more.
    static func sessionTitle(for exercises: [Exercise]) -> String {
        let parts = exercises.map(\.bodyPart)
        let distinct = Set(parts)
        guard !distinct.isEmpty else { return "Workout" }
        if distinct.count >= 4 { return "Full Body" }

        let counts = Dictionary(grouping: parts, by: { $0 }).mapValues(\.count)
        let ordered = counts.sorted { lhs, rhs in
            lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key
        }
        return ordered.prefix(2).map(\.key).joined(separator: " & ")
    }
}
