import Foundation

/// Shared plan state for the Main tabs (M3-04): one `@Observable` source of
/// truth for the restored profile + active plan, with the derived day / week
/// / completion data Home, Plan, and Calendar all consume — so they observe
/// the same store instead of copying a one-shot `RestoredUserState?` value.
///
/// Owned by `AppRootView` as `@State` and configured from
/// `AppRouter.restoredState` when the app enters the Main phase. Mutations
/// (M3-05) apply optimistically: the local plan updates first, the
/// authenticated service persists, and a failure rolls the local plan back
/// before rethrowing so UI can surface the error gently.
@MainActor
@Observable
final class PlanStore {
    /// Explicit content states for the Main tabs (M3-04).
    enum LoadState: Equatable {
        /// Not configured yet (router still resolving).
        case loading
        /// Restore produced no usable state — the router admitted the user via
        /// the offline completion hint, but there is no content to show
        /// (SPEC §14 #40).
        case failed
        /// Profile restored but no active plan.
        case empty
        /// Profile + plan available.
        case ready
    }

    /// Completion tally for a week or the whole plan ("Weeks Completed 1/6",
    /// checkmarks on week cards).
    struct CompletionStats: Equatable, Sendable {
        var completed = 0
        var skipped = 0
        var scheduled = 0

        var total: Int { completed + skipped + scheduled }
        /// A bucket counts as done when nothing scheduled remains (and it has
        /// at least one workout).
        var isFullyFinished: Bool { total > 0 && scheduled == 0 }
    }

    private(set) var loadState: LoadState = .loading
    private(set) var profile: RestoredProfile?
    private(set) var plan: GeneratedPlan?

    private let mutationService: any PlanMutationServicing
    /// Reconciles workout reminders after a successful remote plan change
    /// (M3-13 hook; the real service is M3-15). Deliberately non-throwing —
    /// a reminder problem never rolls back a persisted plan change.
    private let reminderReconciler: any WorkoutReminderReconciling
    private let calendar: Calendar

    /// Injectable clock so "today"-derived helpers are testable.
    var now: () -> Date = { .now }

    init(
        mutationService: any PlanMutationServicing,
        reminderReconciler: any WorkoutReminderReconciling = NoopWorkoutReminderReconciler(),
        calendar: Calendar = .current
    ) {
        self.mutationService = mutationService
        self.reminderReconciler = reminderReconciler
        self.calendar = calendar
    }

    // MARK: - Lifecycle

    /// Configures the store when the app enters the Main phase. `nil` means
    /// the launch restore failed (the router admitted the user via the local
    /// completion hint), which the store surfaces as `.failed` rather than
    /// pretending the account is empty (SPEC §14 #40).
    func configure(from restored: RestoredUserState?) {
        guard let restored else {
            profile = nil
            plan = nil
            loadState = .failed
            return
        }
        profile = restored.profile
        plan = restored.plan
        loadState = restored.plan == nil ? .empty : .ready
    }

    /// Back to a blank slate (sign-out / delete account reroute).
    func reset() {
        profile = nil
        plan = nil
        loadState = .loading
    }

    // MARK: - Derived: days & weeks

    /// Start of the current day per the injectable clock.
    var today: Date { calendar.startOfDay(for: now()) }

    /// The 1-based plan week containing `date`, or `nil` outside the plan.
    func weekNumber(containing date: Date) -> Int? {
        guard let plan else { return nil }
        return PlanMutator.weekNumber(containing: date, in: plan, calendar: calendar)
    }

    /// The plan week containing today, if the plan is in progress.
    var currentWeek: PlanWeek? {
        guard let plan, let number = weekNumber(containing: now()) else { return nil }
        return plan.weeks.first { $0.number == number }
    }

    /// Dated workouts grouped by start-of-day. Undated (flexible) workouts
    /// are deliberately absent — they live in `flexibleWeeklyPool` instead
    /// (SPEC §14 #37).
    var sessionsByDay: [Date: [PlannedSession]] {
        guard let plan else { return [:] }
        return Dictionary(
            grouping: plan.weeks.flatMap(\.sessions).filter { $0.date != nil },
            by: { calendar.startOfDay(for: $0.date ?? .distantPast) }
        )
    }

    /// Workouts scheduled on a specific day (calendar day views).
    func sessions(on date: Date) -> [PlannedSession] {
        sessionsByDay[calendar.startOfDay(for: date)] ?? []
    }

    /// Today's scheduled workouts (Home / Record Workout).
    var todaysSessions: [PlannedSession] { sessions(on: now()) }

    /// Days that get a calendar dot — only workouts with a concrete
    /// `scheduledDate` (SPEC §14 #37).
    var calendarDotDays: Set<Date> { Set(sessionsByDay.keys) }

    /// The undated flexible workouts of the plan week containing `date` —
    /// rendered as a weekly pool / checklist, never as fake calendar slots
    /// (SPEC §14 #37).
    func flexibleWeeklyPool(containing date: Date) -> [PlannedSession] {
        guard let plan, let number = PlanMutator.weekNumber(containing: date, in: plan, calendar: calendar),
              let week = plan.weeks.first(where: { $0.number == number })
        else {
            return []
        }
        return week.sessions.filter { $0.date == nil }
    }

    /// This plan week's undated pool (convenience for Home / Plan).
    var currentFlexiblePool: [PlannedSession] { flexibleWeeklyPool(containing: now()) }

    // MARK: - Derived: completion

    /// Completion tally for one week.
    func completionStats(forWeek number: Int) -> CompletionStats {
        stats(for: plan?.weeks.first { $0.number == number }?.sessions ?? [])
    }

    /// Completion tally across the whole plan.
    var overallCompletion: CompletionStats {
        stats(for: plan?.weeks.flatMap(\.sessions) ?? [])
    }

    /// Fully finished weeks, for the "Weeks Completed 1/6" tracker (SPEC §6).
    var completedWeekCount: Int {
        guard let plan else { return 0 }
        return plan.weeks.count { stats(for: $0.sessions).isFullyFinished }
    }

    private func stats(for sessions: [PlannedSession]) -> CompletionStats {
        var result = CompletionStats()
        for session in sessions {
            switch session.status {
            case .completed: result.completed += 1
            case .skipped: result.skipped += 1
            case .scheduled: result.scheduled += 1
            }
        }
        return result
    }

    // MARK: - Mutations (M3-05, optimistic with rollback)

    /// Moves a workout to a date: applies locally, persists via the authed
    /// service, and rolls back + rethrows on failure.
    func moveWorkout(id: UUID, to date: Date) async throws {
        guard let plan else { throw PlanMutationError.noPlan }
        let snapshot = plan
        let result = try PlanMutator.movingWorkout(id: id, to: date, in: plan, calendar: calendar)

        applyPlan(result.plan)
        do {
            try await mutationService.moveWorkout(
                planID: plan.id,
                changedWorkouts: result.changedSessions.map(workoutRow)
            )
        } catch {
            applyPlan(snapshot)
            throw error
        }
        await reconcileReminders()
    }

    /// Adds a workout to an empty day by cloning `sourceID` (SPEC §14 #38):
    /// applies locally, persists, rolls back + rethrows on failure.
    func addWorkout(cloning sourceID: UUID, on date: Date) async throws {
        guard let plan else { throw PlanMutationError.noPlan }
        let snapshot = plan
        let result = try PlanMutator.addingWorkout(cloning: sourceID, on: date, in: plan, calendar: calendar)

        applyPlan(result.plan)
        do {
            try await mutationService.addWorkout(
                planID: plan.id,
                newWorkout: workoutRow(for: result.addedSession),
                newExercises: OnboardingSyncMapper.exerciseRows(for: result.addedSession.session),
                reorderedWorkouts: result.reorderedSessions.map(workoutRow)
            )
        } catch {
            applyPlan(snapshot)
            throw error
        }
        await reconcileReminders()
    }

    /// Replaces the remaining unfinished workouts with a regenerated plan,
    /// preserving completed/skipped history (SPEC §14 #39): applies locally,
    /// persists insert-then-delete, rolls back + rethrows on failure.
    func replaceRemainingWorkouts(withRegenerated regenerated: GeneratedPlan) async throws {
        guard let plan else { throw PlanMutationError.noPlan }
        let snapshot = plan
        let result = PlanMutator.replacingRemainingWorkouts(
            in: plan,
            withRegenerated: regenerated,
            calendar: calendar
        )

        applyPlan(result.plan)
        do {
            let exercises = result.insertedSessions.flatMap {
                OnboardingSyncMapper.exerciseRows(for: $0.session)
            }
            try await mutationService.replaceRemainingWorkouts(
                planID: plan.id,
                insertingWorkouts: result.insertedSessions.map(workoutRow),
                insertingExercises: exercises,
                updatingWorkouts: result.updatedPreservedSessions.map(workoutRow),
                deletingWorkoutIDs: result.deletedWorkoutIDs
            )
        } catch {
            applyPlan(snapshot)
            throw error
        }
        await reconcileReminders()
    }

    // MARK: - Manage Plan (M3-14)

    /// Applies a full Manage Plan save: merges the regenerated plan into the
    /// current one (preserving completed/skipped history, SPEC §14 #39),
    /// swaps the local plan + profile optimistically, and persists plan
    /// settings + profile settings + the workout replacement **atomically**
    /// via the `replace_remaining_plan` RPC. A failure rolls both back.
    func applyManagePlan(editedProfile: RestoredProfile, regenerated: GeneratedPlan) async throws {
        guard let plan else { throw PlanMutationError.noPlan }
        let planSnapshot = plan
        let profileSnapshot = profile
        let result = PlanMutator.replacingRemainingWorkouts(
            in: plan,
            withRegenerated: regenerated,
            calendar: calendar
        )

        applyPlan(result.plan)
        profile = editedProfile
        do {
            let exercises = result.insertedSessions.flatMap {
                OnboardingSyncMapper.exerciseRows(for: $0.session)
            }
            try await mutationService.applyManagePlan(
                planID: plan.id,
                planUpdate: OnboardingSyncMapper.planSettingsUpdate(for: result.plan),
                profileUpdate: OnboardingSyncMapper.profileSettingsUpdate(for: editedProfile),
                insertingWorkouts: result.insertedSessions.map(workoutRow),
                insertingExercises: exercises,
                updatingWorkouts: result.updatedPreservedSessions.map(workoutRow),
                deletingWorkoutIDs: result.deletedWorkoutIDs
            )
        } catch {
            applyPlan(planSnapshot)
            profile = profileSnapshot
            throw error
        }
        await reconcileReminders()
    }

    /// Persists profile settings edits that don't need regeneration (e.g. a
    /// units change): swaps the local profile optimistically, persists via
    /// the authed service, and rolls back + rethrows on failure.
    func updateProfileSettings(userID: UUID, editedProfile: RestoredProfile) async throws {
        let snapshot = profile
        profile = editedProfile
        do {
            try await mutationService.updateProfileSettings(
                userID: userID,
                update: OnboardingSyncMapper.profileSettingsUpdate(for: editedProfile)
            )
        } catch {
            profile = snapshot
            throw error
        }
    }

    /// Persists plan metadata edits alone (no workout regeneration): swaps
    /// the local plan optimistically and rolls back + rethrows on failure.
    func updatePlanSettings(to updatedPlan: GeneratedPlan) async throws {
        guard let plan else { throw PlanMutationError.noPlan }
        let snapshot = plan
        applyPlan(updatedPlan)
        do {
            try await mutationService.updatePlanSettings(
                planID: plan.id,
                update: OnboardingSyncMapper.planSettingsUpdate(for: updatedPlan)
            )
        } catch {
            applyPlan(snapshot)
            throw error
        }
    }

    // MARK: - Private

    private func applyPlan(_ newPlan: GeneratedPlan) {
        plan = newPlan
        loadState = .ready
    }

    /// Fires the reminder hook after a successful remote write. Never
    /// throws — reminder trouble must not undo a persisted plan change.
    private func reconcileReminders() async {
        guard let plan else { return }
        await reminderReconciler.reconcileReminders(for: plan)
    }

    private func workoutRow(for placed: PlanMutator.PlacedSession) -> PlanWorkoutInsertRow {
        OnboardingSyncMapper.workoutRow(
            for: placed.session,
            planID: plan?.id ?? UUID(),
            weekNumber: placed.weekNumber
        )
    }
}
