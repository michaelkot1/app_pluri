import Foundation

/// Pure, deterministic plan generator (M1-16; focus-first rework M3-19).
///
/// Modeled on `CalorieCalculator`: a `nonisolated enum` of static functions
/// with no `@MainActor`/SwiftData coupling, so it is trivially unit-testable
/// and can later be ported almost verbatim to the `generate-plan` Edge
/// Function (PLAN §1.3). Given the same `(input, catalog, seed)` it always
/// produces the same `GeneratedPlan`.
///
/// Algorithm (SPEC §3.3, PLAN §1.4, SPEC §14 #46/#47):
/// 1. Filter the catalog to weight-training exercises the user can do
///    (equipment match; drop `"Cardio"` — v1 is Workout-only).
/// 2. Derive a weekly **session-focus** split from days/week + experience/goal.
/// 3. For each focus, select majority primary-target movements + 1–2
///    secondary via `targetMuscle`/`secondaryMuscles`, applying graded pain
///    rules. Fall back to Full Body only when earned (2-day split or a
///    too-small primary pool).
/// 4. Repeat those session templates for every week with simple progression
///    and pin them to weekdays/dates for scheduled plans.
///
/// Marked `nonisolated` so it opts out of the project's main-actor default
/// isolation (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
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

    /// Secondary / supporting movements to include per focused session.
    static let secondaryExercisesPerSession = 2

    /// When a focus's graded primary pool has fewer than this many exercises,
    /// the session falls back to an earned Full Body focus (SPEC §14 #46/#49).
    static let smallPoolFullBodyThreshold = 3

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
        guard templates.contains(where: { !$0.exercises.isEmpty }) else {
            throw PlanEngineError.noEligibleExercises
        }

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

    /// Weight-training exercises the user can perform on their equipment.
    /// Injury grading happens later per focus (SPEC §14 #47) — this step only
    /// drops `"Cardio"` (v1 Workout-only) and unmatched equipment. Sorted by
    /// id for a deterministic base ordering before any shuffling.
    static func filteredCatalog(_ catalog: [Exercise], input: PlanInput) -> [Exercise] {
        let selection = EquipmentMatcher.normalizedKeys(for: input.equipment)

        return catalog
            .filter { exercise in
                exercise.bodyPart != "Cardio"
                    && EquipmentMatcher.isAvailable(exercise.equipment, in: selection)
            }
            .sorted { $0.id < $1.id }
    }

    // MARK: Step 2 & 3 — focus-first session templates

    /// One session template: the focus assigned to that training day and the
    /// exercises selected against it.
    struct SessionTemplate: Sendable {
        let focus: SessionFocus
        let exercises: [Exercise]
    }

    /// Builds `sessionsPerWeek` focus-first templates from the weekly split
    /// (SPEC §14 #46). Each session is majority primary-target movements plus
    /// up to `secondaryExercisesPerSession` supporting ones; seed-shuffled
    /// within each pool. Falls back to Full Body when the graded primary pool
    /// is below `smallPoolFullBodyThreshold`.
    static func buildSessionTemplates(
        from eligible: [Exercise],
        input: PlanInput,
        rng: inout SeededGenerator
    ) -> [SessionTemplate] {
        let sessionCount = input.sessionsPerWeek
        let perSession = exercisesPerSession(forDurationMinutes: input.sessionDurationMinutes)
        let split = SessionFocus.split(
            daysPerWeek: sessionCount,
            experience: input.experience,
            goal: input.goal
        )

        var fullBodyToggle = 0
        return (0..<sessionCount).map { sessionIndex in
            let requested = split[sessionIndex % split.count]
            let resolved = resolveFocus(
                requested,
                eligible: eligible,
                injuries: input.injuries,
                fullBodyToggle: &fullBodyToggle
            )
            let exercises = selectExercises(
                for: resolved,
                from: eligible,
                count: perSession,
                injuries: input.injuries,
                rng: &rng
            )
            return SessionTemplate(focus: resolved, exercises: exercises)
        }
    }

    /// Chooses the focus that will actually drive selection: the requested
    /// split focus, or an earned Full Body when the primary pool is too small.
    static func resolveFocus(
        _ requested: SessionFocus,
        eligible: [Exercise],
        injuries: [BodyArea: Int],
        fullBodyToggle: inout Int
    ) -> SessionFocus {
        if requested.isFullBody { return requested }

        let primaryPool = eligible.filter { exercise in
            role(of: exercise, in: requested, injuries: injuries) == .primary
        }
        guard primaryPool.count < smallPoolFullBodyThreshold else { return requested }

        let fallback = fullBodyToggle.isMultiple(of: 2) ? SessionFocus.fullBodyA : SessionFocus.fullBodyB
        fullBodyToggle += 1
        return fallback
    }

    /// Graded role of an exercise inside a focus (exposed for unit tests).
    enum FocusRole: Equatable, Sendable {
        case primary
        case secondary
        case excluded
    }

    /// Graded pain rules (SPEC §14 #47) applied against a focus:
    /// - Pain 1–2: no primary targeting of the injured muscle; secondary OK.
    /// - Pain 3: no primary; secondary only on supported/machine equipment.
    /// - Pain 4–5: hard exclude as primary **and** as secondary involvement.
    static func role(
        of exercise: Exercise,
        in focus: SessionFocus,
        injuries: [BodyArea: Int]
    ) -> FocusRole {
        let primarySet = Set(focus.primaryMuscles)
        let secondarySet = Set(focus.secondaryMuscles)
        let isPrimaryTarget = primarySet.contains(exercise.targetMuscle)
        let isSecondaryTarget = secondarySet.contains(exercise.targetMuscle)
            || exercise.secondaryMuscles.contains(where: { primarySet.contains($0) || secondarySet.contains($0) })

        if isPrimaryTarget {
            if let pain = BodyAreaMuscleMapping.painLevel(for: exercise.targetMuscle, injuries: injuries),
               pain >= 1 {
                return .excluded
            }
            let secondaryPains = exercise.secondaryMuscles.compactMap {
                BodyAreaMuscleMapping.painLevel(for: $0, injuries: injuries)
            }
            // Pain 4–5 on listed secondary muscles: hard-exclude the lift.
            // Pain 3 load-cap applies when the injured muscle is the exercise's
            // own target in a secondary slot (below), not when it merely
            // appears on a healthy primary-target lift (SPEC §14 #47/#49).
            if secondaryPains.contains(where: { $0 >= 4 }) {
                return .excluded
            }
            return .primary
        }

        if isSecondaryTarget {
            let implicatedPain = implicatedSecondaryPain(exercise: exercise, focus: focus, injuries: injuries)
            if let pain = implicatedPain {
                if pain >= 4 { return .excluded }
                if pain == 3 {
                    return BodyAreaMuscleMapping.isSupportedOrMachine(exercise.equipment)
                        ? .secondary
                        : .excluded
                }
                // Pain 1–2: light secondary OK.
                return .secondary
            }
            return .secondary
        }

        // Full Body fallback may also pull from any non-hard-excluded lift.
        if focus.isFullBody {
            if let pain = BodyAreaMuscleMapping.painLevel(for: exercise.targetMuscle, injuries: injuries),
               pain >= 4 {
                return .excluded
            }
            if exercise.secondaryMuscles.contains(where: { muscle in
                (BodyAreaMuscleMapping.painLevel(for: muscle, injuries: injuries) ?? 0) >= 4
            }) {
                return .excluded
            }
            if let pain = BodyAreaMuscleMapping.painLevel(for: exercise.targetMuscle, injuries: injuries),
               pain >= 1 {
                return .secondary
            }
            return .primary
        }

        return .excluded
    }

    private static func implicatedSecondaryPain(
        exercise: Exercise,
        focus: SessionFocus,
        injuries: [BodyArea: Int]
    ) -> Int? {
        var highest: Int?
        let relevant = Set(focus.primaryMuscles).union(focus.secondaryMuscles)
        let muscles = [exercise.targetMuscle] + exercise.secondaryMuscles
        for muscle in muscles where relevant.contains(muscle) {
            if let pain = BodyAreaMuscleMapping.painLevel(for: muscle, injuries: injuries) {
                highest = max(highest ?? pain, pain)
            }
        }
        return highest
    }

    /// Majority primary + up to `secondaryExercisesPerSession` secondary,
    /// seed-shuffled within each pool. Cycles the pool when it is smaller
    /// than needed (same v1 compromise as the old round-robin engine).
    static func selectExercises(
        for focus: SessionFocus,
        from eligible: [Exercise],
        count: Int,
        injuries: [BodyArea: Int],
        rng: inout SeededGenerator
    ) -> [Exercise] {
        var primary = eligible.filter { role(of: $0, in: focus, injuries: injuries) == .primary }
            .shuffled(using: &rng)
        var secondary = eligible.filter { role(of: $0, in: focus, injuries: injuries) == .secondary }
            .shuffled(using: &rng)

        let secondaryCount = min(secondaryExercisesPerSession, max(0, count - 1), secondary.count)
        let primaryCount = count - secondaryCount

        var selected: [Exercise] = []
        selected.append(contentsOf: takeCycling(from: &primary, count: primaryCount))
        selected.append(contentsOf: takeCycling(from: &secondary, count: secondaryCount))

        // If primaries were short, backfill from any non-excluded lifts so the
        // session still fills (small catalogs / heavy injury filters).
        if selected.count < count {
            var backfill = eligible.filter { role(of: $0, in: focus, injuries: injuries) != .excluded }
                .shuffled(using: &rng)
            var existingIDs = Set(selected.map(\.id))
            for exercise in backfill where selected.count < count {
                if existingIDs.insert(exercise.id).inserted {
                    selected.append(exercise)
                }
            }
            if selected.count < count {
                let needed = count - selected.count
                selected.append(contentsOf: takeCycling(from: &backfill, count: needed))
            }
        }

        return Array(selected.prefix(count))
    }

    private static func takeCycling(from pool: inout [Exercise], count: Int) -> [Exercise] {
        guard count > 0, !pool.isEmpty else { return [] }
        return (0..<count).map { pool[$0 % pool.count] }
    }

    // MARK: Step 4 — weeks, progression, scheduling

    static func buildWeek(weekNumber: Int, templates: [SessionTemplate], input: PlanInput) -> PlanWeek {
        let base = baseSetsReps(goal: input.goal)
        let target = progression(base: base, week: weekNumber)
        let calendar = Calendar.current
        let trainingDates = orderedTrainingDates(weekNumber: weekNumber, input: input, calendar: calendar)

        let sessions = templates.enumerated().map { sessionIndex, template in
            // Sessions map onto the week's training-day dates in chronological
            // order (M3-02), so indexInWeek, order, and dates ascend together.
            let slot = sessionIndex < trainingDates.count ? trainingDates[sessionIndex] : nil
            let planned = template.exercises.enumerated().map { order, exercise in
                PlannedExercise(
                    exerciseID: exercise.id,
                    name: exercise.name,
                    bodyPart: exercise.bodyPart,
                    equipment: exercise.equipment,
                    targetMuscle: exercise.targetMuscle,
                    secondaryMuscles: exercise.secondaryMuscles,
                    imageURL: exercise.imageURL,
                    videoURL: exercise.videoURL,
                    order: order,
                    sets: target.sets,
                    reps: target.reps
                )
            }
            return PlannedSession(
                title: template.focus.displayTitle,
                indexInWeek: sessionIndex + 1,
                weekday: slot?.weekday,
                date: slot?.date,
                status: .scheduled,
                workoutType: .weights,
                color: template.focus.colorToken.rawValue,
                focus: template.focus.code,
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
}
