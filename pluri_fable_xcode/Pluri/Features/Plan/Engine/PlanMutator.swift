import Foundation

/// Pure, deterministic plan mutations for the Calendar / Manage Plan flows
/// (M3-05): move a workout to a date, add (clone) a workout onto an empty
/// day, and replace the remaining unfinished workouts after regeneration.
///
/// Like `PlanEngine`, this is a `nonisolated enum` of static functions with
/// no persistence coupling, so the `PlanStore` can apply changes
/// optimistically and the same values map onto Supabase rows via
/// `OnboardingSyncMapper`. Each mutation renormalizes `indexInWeek` (per
/// week) and `orderIndex` (global) so order and dates always agree — the
/// invariant M3-02 established for freshly generated plans.
nonisolated enum PlanMutator {
    /// A session together with the plan week it belongs to — what the sync
    /// layer needs to build a `plan_workouts` row.
    struct PlacedSession: Hashable, Sendable {
        let session: PlannedSession
        let weekNumber: Int
    }

    struct MoveResult: Sendable {
        let plan: GeneratedPlan
        /// Every session whose persisted row changed (the moved one plus any
        /// neighbors whose order shifted).
        let changedSessions: [PlacedSession]
    }

    struct AddResult: Sendable {
        let plan: GeneratedPlan
        /// The newly created clone (new IDs, SPEC §14 #38).
        let addedSession: PlacedSession
        /// Pre-existing sessions whose order shifted to make room.
        let reorderedSessions: [PlacedSession]
    }

    struct ReplaceResult: Sendable {
        let plan: GeneratedPlan
        /// Replacement sessions to insert (new IDs, SPEC §14 #39) — these
        /// need workout **and** exercise rows written.
        let insertedSessions: [PlacedSession]
        /// Preserved (completed/skipped) sessions whose workout row changed —
        /// e.g. a shifted `orderIndex` after renormalization. Their exercise
        /// rows and IDs are untouched; only the workout row needs an upsert.
        let updatedPreservedSessions: [PlacedSession]
        /// Old `scheduled` workout IDs to delete after the insert succeeds.
        let deletedWorkoutIDs: [UUID]
    }

    // MARK: - Lookups

    /// The 1-based plan week containing `date`, or `nil` when the date falls
    /// outside the plan's rolling start…end window.
    static func weekNumber(containing date: Date, in plan: GeneratedPlan, calendar: Calendar = .current) -> Int? {
        let start = calendar.startOfDay(for: plan.startDate)
        let target = calendar.startOfDay(for: date)
        guard let days = calendar.dateComponents([.day], from: start, to: target).day,
              days >= 0, days < plan.weekCount * 7
        else {
            return nil
        }
        return days / 7 + 1
    }

    static func session(withID id: UUID, in plan: GeneratedPlan) -> PlannedSession? {
        plan.weeks.flatMap(\.sessions).first { $0.id == id }
    }

    /// Whether any (other) workout already occupies `date` — one workout per
    /// day in v1 (SPEC §14 #38).
    static func hasWorkout(
        on date: Date,
        in plan: GeneratedPlan,
        excluding excludedID: UUID? = nil,
        calendar: Calendar = .current
    ) -> Bool {
        plan.weeks.flatMap(\.sessions).contains { session in
            guard session.id != excludedID, let sessionDate = session.date else { return false }
            return calendar.isDate(sessionDate, inSameDayAs: date)
        }
    }

    // MARK: - Move

    /// Moves a workout to a (conflict-free) date inside the plan window,
    /// assigning its `scheduledDate` + weekday — this is also how a flexible
    /// workout graduates from the weekly pool onto the calendar (SPEC §14 #37).
    /// Only `scheduled` workouts may move — completed/skipped history is
    /// immutable (M3-13).
    static func movingWorkout(
        id: UUID,
        to date: Date,
        in plan: GeneratedPlan,
        calendar: Calendar = .current
    ) throws -> MoveResult {
        guard let existing = session(withID: id, in: plan) else { throw PlanMutationError.workoutNotFound }
        guard existing.status == .scheduled else { throw PlanMutationError.workoutFinished }
        guard let targetWeek = weekNumber(containing: date, in: plan, calendar: calendar) else {
            throw PlanMutationError.dateOutsidePlan
        }
        guard !hasWorkout(on: date, in: plan, excluding: id, calendar: calendar) else {
            throw PlanMutationError.dayOccupied
        }

        let day = calendar.startOfDay(for: date)
        let moved = copy(
            existing,
            weekday: Weekday(rawValue: calendar.component(.weekday, from: day)),
            date: day,
            indexInWeek: existing.indexInWeek,
            orderIndex: existing.orderIndex
        )

        var sessionsByWeek = sessionsByWeek(in: plan)
        for week in sessionsByWeek.keys {
            sessionsByWeek[week]?.removeAll { $0.id == id }
        }
        sessionsByWeek[targetWeek, default: []].append(moved)

        let newPlan = renormalizedPlan(from: plan, sessionsByWeek: sessionsByWeek)
        return MoveResult(
            plan: newPlan,
            changedSessions: changedSessions(from: plan, to: newPlan)
        )
    }

    // MARK: - Add (clone)

    /// Adds a workout to an empty day by cloning an existing plan workout —
    /// same type / color / duration / exercises, new workout + exercise IDs,
    /// `status = scheduled` (SPEC §14 #38).
    static func addingWorkout(
        cloning sourceID: UUID,
        on date: Date,
        in plan: GeneratedPlan,
        calendar: Calendar = .current
    ) throws -> AddResult {
        guard let source = session(withID: sourceID, in: plan) else { throw PlanMutationError.workoutNotFound }
        guard let targetWeek = weekNumber(containing: date, in: plan, calendar: calendar) else {
            throw PlanMutationError.dateOutsidePlan
        }
        guard !hasWorkout(on: date, in: plan, calendar: calendar) else {
            throw PlanMutationError.dayOccupied
        }

        let day = calendar.startOfDay(for: date)
        let clonedExercises = source.exercises.map { exercise in
            PlannedExercise(
                exerciseID: exercise.exerciseID,
                name: exercise.name,
                bodyPart: exercise.bodyPart,
                equipment: exercise.equipment,
                targetMuscle: exercise.targetMuscle,
                secondaryMuscles: exercise.secondaryMuscles,
                imageURL: exercise.imageURL,
                order: exercise.order,
                sets: exercise.sets,
                reps: exercise.reps
            )
        }
        let clone = PlannedSession(
            title: source.title,
            indexInWeek: source.indexInWeek,
            weekday: Weekday(rawValue: calendar.component(.weekday, from: day)),
            date: day,
            status: .scheduled,
            workoutType: source.workoutType,
            color: source.color,
            orderIndex: source.orderIndex,
            durationMinutes: source.durationMinutes,
            exercises: clonedExercises
        )

        var sessionsByWeek = sessionsByWeek(in: plan)
        sessionsByWeek[targetWeek, default: []].append(clone)

        let newPlan = renormalizedPlan(from: plan, sessionsByWeek: sessionsByWeek)
        guard let placedClone = placedSession(withID: clone.id, in: newPlan) else {
            throw PlanMutationError.workoutNotFound
        }
        let reordered = changedSessions(from: plan, to: newPlan)
            .filter { $0.session.id != clone.id }
        return AddResult(plan: newPlan, addedSession: placedClone, reorderedSessions: reordered)
    }

    // MARK: - Replace remaining (Manage Plan regeneration)

    /// Merges a freshly regenerated plan into the current one per SPEC §14
    /// #39: `completed` / `skipped` workouts (and their exercise rows / IDs)
    /// are preserved unchanged in their original weeks; every old `scheduled`
    /// workout is replaced by the regenerated sessions (which carry new IDs
    /// straight from `PlanEngine`). Regenerated sessions that would collide
    /// with a preserved workout's day are dropped (one workout per day).
    static func replacingRemainingWorkouts(
        in plan: GeneratedPlan,
        withRegenerated regenerated: GeneratedPlan,
        calendar: Calendar = .current
    ) -> ReplaceResult {
        let preserved = plan.weeks.flatMap { week in
            week.sessions
                .filter(\.status.isFinished)
                .map { PlacedSession(session: $0, weekNumber: week.number) }
        }
        let preservedDays = Set(
            preserved.compactMap { placed in
                placed.session.date.map { calendar.startOfDay(for: $0) }
            }
        )
        let deletedIDs = plan.weeks
            .flatMap(\.sessions)
            .filter { $0.status == .scheduled }
            .map(\.id)

        var sessionsByWeek: [Int: [PlannedSession]] = [:]
        for placed in preserved {
            sessionsByWeek[placed.weekNumber, default: []].append(placed.session)
        }
        for week in regenerated.weeks {
            for session in week.sessions {
                if let date = session.date, preservedDays.contains(calendar.startOfDay(for: date)) {
                    continue
                }
                sessionsByWeek[week.number, default: []].append(session)
            }
        }

        // Regenerated metadata (new goal / dates / duration / schedule) wins;
        // the plan keeps its identity so remote rows update in place.
        let base = GeneratedPlan(
            id: plan.id,
            goal: regenerated.goal,
            scheduleType: regenerated.scheduleType,
            sessionDurationMinutes: regenerated.sessionDurationMinutes,
            startDate: regenerated.startDate,
            weeks: [],
            seed: regenerated.seed,
            name: plan.name,
            status: plan.status
        )
        let weekCount = max(
            regenerated.weekCount,
            sessionsByWeek.keys.max() ?? 0
        )
        let newPlan = renormalizedPlan(from: base, sessionsByWeek: sessionsByWeek, weekCount: weekCount)

        let preservedIDs = Set(preserved.map(\.session.id))
        let oldByID = Dictionary(uniqueKeysWithValues: preserved.map { ($0.session.id, $0) })
        var inserted: [PlacedSession] = []
        var updatedPreserved: [PlacedSession] = []
        for week in newPlan.weeks {
            for session in week.sessions {
                let placed = PlacedSession(session: session, weekNumber: week.number)
                if preservedIDs.contains(session.id) {
                    if oldByID[session.id] != placed {
                        updatedPreserved.append(placed)
                    }
                } else {
                    inserted.append(placed)
                }
            }
        }
        return ReplaceResult(
            plan: newPlan,
            insertedSessions: inserted,
            updatedPreservedSessions: updatedPreserved,
            deletedWorkoutIDs: deletedIDs
        )
    }

    // MARK: - Private plumbing

    private static func sessionsByWeek(in plan: GeneratedPlan) -> [Int: [PlannedSession]] {
        Dictionary(uniqueKeysWithValues: plan.weeks.map { ($0.number, $0.sessions) })
    }

    private static func placedSession(withID id: UUID, in plan: GeneratedPlan) -> PlacedSession? {
        for week in plan.weeks {
            if let session = week.sessions.first(where: { $0.id == id }) {
                return PlacedSession(session: session, weekNumber: week.number)
            }
        }
        return nil
    }

    /// Rebuilds the plan with each week's sessions sorted chronologically
    /// (dated first, ascending; undated pool after, in prior order), then
    /// renumbers `indexInWeek` per week and `orderIndex` globally so order
    /// and dates agree everywhere.
    private static func renormalizedPlan(
        from plan: GeneratedPlan,
        sessionsByWeek: [Int: [PlannedSession]],
        weekCount: Int? = nil
    ) -> GeneratedPlan {
        let existingWeekIDs = Dictionary(
            uniqueKeysWithValues: plan.weeks.map { ($0.number, $0.id) }
        )
        let lastWeek = weekCount ?? max(plan.weekCount, sessionsByWeek.keys.max() ?? 0)
        var globalOrder = 0

        let weeks: [PlanWeek] = (1...max(lastWeek, 1)).map { weekNumber in
            let ordered = (sessionsByWeek[weekNumber] ?? []).sorted { lhs, rhs in
                switch (lhs.date, rhs.date) {
                case let (lhsDate?, rhsDate?): lhsDate < rhsDate
                case (.some, .none): true
                case (.none, .some): false
                case (.none, .none): lhs.orderIndex < rhs.orderIndex
                }
            }
            let sessions = ordered.enumerated().map { index, session in
                let renumbered = copy(
                    session,
                    weekday: session.weekday,
                    date: session.date,
                    indexInWeek: index + 1,
                    orderIndex: globalOrder + index
                )
                return renumbered
            }
            globalOrder += sessions.count
            return PlanWeek(
                id: existingWeekIDs[weekNumber] ?? UUID(),
                number: weekNumber,
                sessions: sessions
            )
        }

        return GeneratedPlan(
            id: plan.id,
            goal: plan.goal,
            scheduleType: plan.scheduleType,
            sessionDurationMinutes: plan.sessionDurationMinutes,
            startDate: plan.startDate,
            weeks: weeks,
            seed: plan.seed,
            name: plan.name,
            status: plan.status
        )
    }

    /// Sessions whose persisted `plan_workouts` fields differ between the two
    /// plans (new sessions included) — the rows a mutation must write.
    private static func changedSessions(from old: GeneratedPlan, to new: GeneratedPlan) -> [PlacedSession] {
        var oldByID: [UUID: PlacedSession] = [:]
        for week in old.weeks {
            for session in week.sessions {
                oldByID[session.id] = PlacedSession(session: session, weekNumber: week.number)
            }
        }

        var changed: [PlacedSession] = []
        for week in new.weeks {
            for session in week.sessions {
                let placed = PlacedSession(session: session, weekNumber: week.number)
                if oldByID[session.id] != placed {
                    changed.append(placed)
                }
            }
        }
        return changed
    }

    private static func copy(
        _ session: PlannedSession,
        weekday: Weekday?,
        date: Date?,
        indexInWeek: Int,
        orderIndex: Int
    ) -> PlannedSession {
        PlannedSession(
            id: session.id,
            title: session.title,
            indexInWeek: indexInWeek,
            weekday: weekday,
            date: date,
            status: session.status,
            workoutType: session.workoutType,
            color: session.color,
            orderIndex: orderIndex,
            durationMinutes: session.durationMinutes,
            exercises: session.exercises
        )
    }
}
