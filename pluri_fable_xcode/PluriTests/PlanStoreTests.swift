import Foundation
import Testing
@testable import Pluri

/// M3-04 / M3-05 — the shared `PlanStore`: explicit load states, derived
/// day / week / completion data, and optimistic mutations (move / add-clone /
/// replace-remaining) with rollback on service failure, asserted against the
/// row shapes `MockPlanMutationService` records.
@Suite("PlanStore")
@MainActor
struct PlanStoreTests {
    // MARK: - Fixtures

    private let calendar = Calendar.current

    /// A Monday at start-of-day, walked forward from a fixed epoch so the
    /// fixture is deterministic in any time zone.
    private var monday: Date {
        var date = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_752_364_800))
        while calendar.component(.weekday, from: date) != Weekday.monday.rawValue {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return date
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: monday) ?? monday
    }

    private func makeExercise(order: Int) -> PlannedExercise {
        PlannedExercise(
            exerciseID: "00\(order)",
            name: "Exercise \(order)",
            bodyPart: "Back",
            equipment: "Dumbbell",
            targetMuscle: "Lats",
            secondaryMuscles: [],
            imageURL: nil,
            order: order,
            sets: 3,
            reps: 10
        )
    }

    private func makeSession(
        title: String,
        indexInWeek: Int,
        dayOffset: Int?,
        status: WorkoutStatus = .scheduled,
        orderIndex: Int
    ) -> PlannedSession {
        let date = dayOffset.map(day)
        return PlannedSession(
            title: title,
            indexInWeek: indexInWeek,
            weekday: date.flatMap { Weekday(rawValue: calendar.component(.weekday, from: $0)) },
            date: date,
            status: status,
            workoutType: .weights,
            color: nil,
            orderIndex: orderIndex,
            durationMinutes: 45,
            exercises: [makeExercise(order: 0), makeExercise(order: 1)]
        )
    }

    /// Two-week scheduled plan starting Monday: week 1 (Mon/Wed/Fri) is fully
    /// finished (completed / skipped / completed), week 2 is still scheduled.
    private func makeScheduledPlan() -> GeneratedPlan {
        GeneratedPlan(
            goal: .buildMuscle,
            scheduleType: .scheduled,
            sessionDurationMinutes: 45,
            startDate: monday,
            weeks: [
                PlanWeek(number: 1, sessions: [
                    makeSession(title: "W1 Mon", indexInWeek: 1, dayOffset: 0, status: .completed, orderIndex: 0),
                    makeSession(title: "W1 Wed", indexInWeek: 2, dayOffset: 2, status: .skipped, orderIndex: 1),
                    makeSession(title: "W1 Fri", indexInWeek: 3, dayOffset: 4, status: .completed, orderIndex: 2),
                ]),
                PlanWeek(number: 2, sessions: [
                    makeSession(title: "W2 Mon", indexInWeek: 1, dayOffset: 7, orderIndex: 3),
                    makeSession(title: "W2 Wed", indexInWeek: 2, dayOffset: 9, orderIndex: 4),
                    makeSession(title: "W2 Fri", indexInWeek: 3, dayOffset: 11, orderIndex: 5),
                ]),
            ],
            seed: 1
        )
    }

    /// Two-week flexible plan: no session carries a weekday or date.
    private func makeFlexiblePlan() -> GeneratedPlan {
        GeneratedPlan(
            goal: .loseFatToneUp,
            scheduleType: .flexible,
            sessionDurationMinutes: 30,
            startDate: monday,
            weeks: [
                PlanWeek(number: 1, sessions: [
                    makeSession(title: "F1 A", indexInWeek: 1, dayOffset: nil, orderIndex: 0),
                    makeSession(title: "F1 B", indexInWeek: 2, dayOffset: nil, orderIndex: 1),
                ]),
                PlanWeek(number: 2, sessions: [
                    makeSession(title: "F2 A", indexInWeek: 1, dayOffset: nil, orderIndex: 2),
                    makeSession(title: "F2 B", indexInWeek: 2, dayOffset: nil, orderIndex: 3),
                ]),
            ],
            seed: 2
        )
    }

    private func makeProfile() -> RestoredProfile {
        RestoredProfile(
            displayName: "Alex",
            goal: .buildMuscle,
            experience: .oneToSixMonths,
            regularity: .onAndOff,
            location: .commercialGym,
            injuries: [:],
            trainingDays: [.monday, .wednesday, .friday],
            scheduleType: .scheduled,
            planLengthWeeks: 2,
            sessionDuration: .fortyFiveMinutes,
            age: 28,
            gender: .male,
            heightCM: 178,
            weightKG: 75,
            allergies: [],
            equipment: ["Dumbbell"],
            startDate: monday,
            maintenanceCalories: 2400,
            units: "metric",
            onboardingCompleted: true
        )
    }

    private func makeStore(
        plan: GeneratedPlan?,
        service: MockPlanMutationService? = nil,
        reminderReconciler: MockWorkoutReminderReconciler? = nil,
        nowOffsetDays: Int = 8
    ) -> (store: PlanStore, service: MockPlanMutationService) {
        let mutationService = service ?? MockPlanMutationService()
        let store = PlanStore(
            mutationService: mutationService,
            reminderReconciler: reminderReconciler ?? MockWorkoutReminderReconciler(),
            calendar: calendar
        )
        let nowDate = day(nowOffsetDays)
        store.now = { nowDate }
        store.configure(from: RestoredUserState(profile: makeProfile(), plan: plan))
        return (store, mutationService)
    }

    // MARK: - Load states

    @Test("Store starts loading, then maps restored state to explicit states")
    func loadStates() {
        let store = PlanStore(mutationService: MockPlanMutationService(), calendar: calendar)
        #expect(store.loadState == .loading)

        store.configure(from: nil)
        #expect(store.loadState == .failed)
        #expect(store.plan == nil)

        store.configure(from: RestoredUserState(profile: makeProfile(), plan: nil))
        #expect(store.loadState == .empty)
        #expect(store.profile?.displayName == "Alex")

        store.configure(from: RestoredUserState(profile: makeProfile(), plan: makeScheduledPlan()))
        #expect(store.loadState == .ready)
        #expect(store.plan != nil)

        store.reset()
        #expect(store.loadState == .loading)
        #expect(store.plan == nil)
        #expect(store.profile == nil)
    }

    // MARK: - Derived data

    @Test("Sessions group by day and only dated workouts get calendar dots")
    func dayGroupingAndDots() {
        let (store, _) = makeStore(plan: makeScheduledPlan())

        #expect(store.sessionsByDay.count == 6)
        #expect(store.sessions(on: day(0)).map(\.title) == ["W1 Mon"])
        #expect(store.sessions(on: day(1)).isEmpty)
        #expect(store.calendarDotDays == Set([0, 2, 4, 7, 9, 11].map(day)))
    }

    @Test("Today and current week derive from the injected clock")
    func todayAndCurrentWeek() {
        let (store, _) = makeStore(plan: makeScheduledPlan(), nowOffsetDays: 7)

        #expect(store.today == day(7))
        #expect(store.weekNumber(containing: day(7)) == 2)
        #expect(store.currentWeek?.number == 2)
        #expect(store.todaysSessions.map(\.title) == ["W2 Mon"])
        #expect(store.weekNumber(containing: day(-1)) == nil)
        #expect(store.weekNumber(containing: day(14)) == nil)
    }

    @Test("Completion stats count statuses per week and across the plan")
    func completionStats() {
        let (store, _) = makeStore(plan: makeScheduledPlan())

        let week1 = store.completionStats(forWeek: 1)
        #expect(week1.completed == 2)
        #expect(week1.skipped == 1)
        #expect(week1.scheduled == 0)
        #expect(week1.isFullyFinished)

        let week2 = store.completionStats(forWeek: 2)
        #expect(week2.scheduled == 3)
        #expect(!week2.isFullyFinished)

        #expect(store.completedWeekCount == 1)
        #expect(store.overallCompletion.total == 6)
        #expect(store.overallCompletion.completed == 2)
    }

    @Test("Flexible plans expose a weekly pool and no calendar dots (SPEC §14 #37)")
    func flexiblePool() {
        let (store, _) = makeStore(plan: makeFlexiblePlan(), nowOffsetDays: 1)

        #expect(store.calendarDotDays.isEmpty)
        #expect(store.sessionsByDay.isEmpty)
        #expect(store.currentFlexiblePool.map(\.title) == ["F1 A", "F1 B"])
        #expect(store.flexibleWeeklyPool(containing: day(8)).map(\.title) == ["F2 A", "F2 B"])
    }

    // MARK: - Move

    @Test("Moving a workout updates the plan and persists the changed rows")
    func moveWorkoutSucceeds() async throws {
        let plan = makeScheduledPlan()
        let (store, service) = makeStore(plan: plan)
        let moved = plan.weeks[1].sessions[0] // W2 Mon (day 7)

        try await store.moveWorkout(id: moved.id, to: day(8))

        let updated = try #require(store.plan)
        let updatedSession = try #require(PlanMutator.session(withID: moved.id, in: updated))
        #expect(updatedSession.date == day(8))
        #expect(updatedSession.weekday == Weekday(rawValue: calendar.component(.weekday, from: day(8))))

        // Order and dates still agree after the move.
        let orderIndexes = updated.weeks.flatMap { $0.sessions.map(\.orderIndex) }
        #expect(orderIndexes == Array(0..<orderIndexes.count))

        #expect(service.moveCalls.count == 1)
        let call = try #require(service.moveCalls.first)
        #expect(call.planID == plan.id)
        let movedRow = try #require(call.changedWorkouts.first { $0.id == moved.id })
        #expect(movedRow.scheduledDate == DatabaseCodeMappings.dateString(day(8)))
        #expect(movedRow.status == "scheduled")
        #expect(movedRow.weekNumber == 2)
    }

    @Test("Moving assigns a date to a flexible workout (SPEC §14 #37)")
    func moveAssignsDateToFlexibleWorkout() async throws {
        let plan = makeFlexiblePlan()
        let (store, service) = makeStore(plan: plan, nowOffsetDays: 1)
        let pooled = plan.weeks[0].sessions[0]

        try await store.moveWorkout(id: pooled.id, to: day(3))

        let updated = try #require(store.plan)
        let assigned = try #require(PlanMutator.session(withID: pooled.id, in: updated))
        #expect(assigned.date == day(3))
        #expect(store.calendarDotDays == [day(3)])
        #expect(store.currentFlexiblePool.map(\.title) == ["F1 B"])
        #expect(service.moveCalls.count == 1)
    }

    @Test("Moving onto an occupied day is rejected without a service call")
    func moveRejectsOccupiedDay() async throws {
        let plan = makeScheduledPlan()
        let (store, service) = makeStore(plan: plan)
        let moved = plan.weeks[1].sessions[0]

        await #expect(throws: PlanMutationError.dayOccupied) {
            try await store.moveWorkout(id: moved.id, to: day(9)) // W2 Wed already there
        }
        #expect(store.plan == plan)
        #expect(service.moveCalls.isEmpty)
    }

    @Test("Moving outside the plan window is rejected")
    func moveRejectsOutsidePlan() async throws {
        let plan = makeScheduledPlan()
        let (store, service) = makeStore(plan: plan)
        let moved = plan.weeks[1].sessions[0]

        await #expect(throws: PlanMutationError.dateOutsidePlan) {
            try await store.moveWorkout(id: moved.id, to: day(20))
        }
        #expect(store.plan == plan)
        #expect(service.moveCalls.isEmpty)
    }

    @Test("Moving a completed or skipped workout is rejected — history is immutable (M3-13)")
    func moveRejectsFinishedWorkouts() async throws {
        let plan = makeScheduledPlan()
        let (store, service) = makeStore(plan: plan)
        let completed = plan.weeks[0].sessions[0] // W1 Mon, completed
        let skipped = plan.weeks[0].sessions[1] // W1 Wed, skipped

        await #expect(throws: PlanMutationError.workoutFinished) {
            try await store.moveWorkout(id: completed.id, to: day(8))
        }
        await #expect(throws: PlanMutationError.workoutFinished) {
            try await store.moveWorkout(id: skipped.id, to: day(8))
        }
        #expect(store.plan == plan)
        #expect(service.moveCalls.isEmpty)
    }

    @Test("A failed move rolls the local plan back and rethrows")
    func moveRollsBackOnServiceFailure() async throws {
        let plan = makeScheduledPlan()
        let service = MockPlanMutationService()
        service.nextError = .networkUnavailable
        let (store, _) = makeStore(plan: plan, service: service)
        let moved = plan.weeks[1].sessions[0]

        await #expect(throws: PluriSyncError.networkUnavailable) {
            try await store.moveWorkout(id: moved.id, to: day(8))
        }
        #expect(store.plan == plan)
    }

    // MARK: - Add (clone)

    @Test("Adding clones the source workout with new IDs onto an empty day (SPEC §14 #38)")
    func addWorkoutClonesSource() async throws {
        let plan = makeScheduledPlan()
        let (store, service) = makeStore(plan: plan)
        let source = plan.weeks[0].sessions[0] // W1 Mon, completed

        try await store.addWorkout(cloning: source.id, on: day(8))

        let updated = try #require(store.plan)
        #expect(updated.totalSessions == 7)
        let call = try #require(service.addCalls.first)
        #expect(call.planID == plan.id)
        #expect(call.newWorkout.id != source.id)
        #expect(call.newWorkout.name == source.title)
        #expect(call.newWorkout.status == "scheduled")
        #expect(call.newWorkout.durationMinutes == source.durationMinutes)
        #expect(call.newWorkout.scheduledDate == DatabaseCodeMappings.dateString(day(8)))
        #expect(call.newWorkout.weekNumber == 2)

        // Cloned exercises: new row IDs, same catalog exercises.
        #expect(call.newExercises.count == source.exercises.count)
        let sourceExerciseIDs = Set(source.exercises.map(\.id))
        #expect(call.newExercises.allSatisfy { !sourceExerciseIDs.contains($0.id) })
        #expect(call.newExercises.map(\.workoutxExerciseId) == source.exercises.map(\.exerciseID))

        // The source itself is untouched.
        let stillThere = try #require(PlanMutator.session(withID: source.id, in: updated))
        #expect(stillThere.status == .completed)
        #expect(stillThere.date == day(0))
    }

    @Test("Adding onto an occupied day is rejected without a service call")
    func addRejectsOccupiedDay() async throws {
        let plan = makeScheduledPlan()
        let (store, service) = makeStore(plan: plan)
        let source = plan.weeks[0].sessions[0]

        await #expect(throws: PlanMutationError.dayOccupied) {
            try await store.addWorkout(cloning: source.id, on: day(7))
        }
        #expect(store.plan == plan)
        #expect(service.addCalls.isEmpty)
    }

    @Test("A failed add rolls the local plan back and rethrows")
    func addRollsBackOnServiceFailure() async throws {
        let plan = makeScheduledPlan()
        let service = MockPlanMutationService()
        service.nextError = .flushFailed("boom")
        let (store, _) = makeStore(plan: plan, service: service)
        let source = plan.weeks[0].sessions[0]

        await #expect(throws: PluriSyncError.flushFailed("boom")) {
            try await store.addWorkout(cloning: source.id, on: day(8))
        }
        #expect(store.plan == plan)
    }

    // MARK: - Replace remaining (SPEC §14 #39)

    @Test("Replacing preserves completed/skipped history and swaps only scheduled workouts")
    func replaceRemainingPreservesHistory() async throws {
        let plan = makeScheduledPlan()
        let (store, service) = makeStore(plan: plan)
        let preservedIDs = Set(plan.weeks[0].sessions.map(\.id))
        let oldScheduledIDs = Set(plan.weeks[1].sessions.map(\.id))

        // Regenerated plan: same window, new sessions on Tue/Thu of each week.
        let regenerated = GeneratedPlan(
            goal: .buildMuscle,
            scheduleType: .scheduled,
            sessionDurationMinutes: 45,
            startDate: monday,
            weeks: [
                PlanWeek(number: 1, sessions: [
                    makeSession(title: "R1 Tue", indexInWeek: 1, dayOffset: 1, orderIndex: 0),
                    makeSession(title: "R1 Thu", indexInWeek: 2, dayOffset: 3, orderIndex: 1),
                ]),
                PlanWeek(number: 2, sessions: [
                    makeSession(title: "R2 Tue", indexInWeek: 1, dayOffset: 8, orderIndex: 2),
                    makeSession(title: "R2 Thu", indexInWeek: 2, dayOffset: 10, orderIndex: 3),
                ]),
            ],
            seed: 9
        )

        try await store.replaceRemainingWorkouts(withRegenerated: regenerated)

        let updated = try #require(store.plan)
        #expect(updated.id == plan.id)
        let updatedIDs = Set(updated.weeks.flatMap { $0.sessions.map(\.id) })

        // Finished history survives with IDs intact; old scheduled rows are gone.
        #expect(preservedIDs.isSubset(of: updatedIDs))
        #expect(updatedIDs.isDisjoint(with: oldScheduledIDs))

        // Week 1 interleaves history + replacements chronologically.
        #expect(updated.weeks[0].sessions.map(\.title) == ["W1 Mon", "R1 Tue", "W1 Wed", "R1 Thu", "W1 Fri"])
        #expect(updated.weeks[1].sessions.map(\.title) == ["R2 Tue", "R2 Thu"])

        let call = try #require(service.replaceCalls.first)
        #expect(call.planID == plan.id)
        #expect(Set(call.deletingWorkoutIDs) == oldScheduledIDs)
        #expect(call.insertingWorkouts.count == 4)
        #expect(call.insertingWorkouts.allSatisfy { !preservedIDs.contains($0.id) })
        #expect(call.insertingExercises.count == 8)
        // Preserved rows only need an upsert when their order shifted.
        #expect(call.updatingWorkouts.allSatisfy { preservedIDs.contains($0.id) })
    }

    @Test("Replacement workouts colliding with preserved days are dropped")
    func replaceDropsCollisionsWithHistory() async throws {
        let plan = makeScheduledPlan()
        let (store, _) = makeStore(plan: plan)

        let regenerated = GeneratedPlan(
            goal: .buildMuscle,
            scheduleType: .scheduled,
            sessionDurationMinutes: 45,
            startDate: monday,
            weeks: [
                PlanWeek(number: 1, sessions: [
                    // Collides with completed "W1 Mon" — must be dropped.
                    makeSession(title: "R1 Mon", indexInWeek: 1, dayOffset: 0, orderIndex: 0),
                    makeSession(title: "R1 Tue", indexInWeek: 2, dayOffset: 1, orderIndex: 1),
                ]),
                PlanWeek(number: 2, sessions: [
                    makeSession(title: "R2 Tue", indexInWeek: 1, dayOffset: 8, orderIndex: 2),
                ]),
            ],
            seed: 9
        )

        try await store.replaceRemainingWorkouts(withRegenerated: regenerated)

        let updated = try #require(store.plan)
        let titles = updated.weeks.flatMap { $0.sessions.map(\.title) }
        #expect(!titles.contains("R1 Mon"))
        #expect(titles.contains("R1 Tue"))
        #expect(updated.weeks[0].sessions.first?.title == "W1 Mon")
    }

    @Test("A failed replace rolls the local plan back and rethrows")
    func replaceRollsBackOnServiceFailure() async throws {
        let plan = makeScheduledPlan()
        let service = MockPlanMutationService()
        service.nextError = .networkUnavailable
        let (store, _) = makeStore(plan: plan, service: service)

        let regenerated = GeneratedPlan(
            goal: .buildMuscle,
            scheduleType: .scheduled,
            sessionDurationMinutes: 45,
            startDate: monday,
            weeks: [
                PlanWeek(number: 1, sessions: [
                    makeSession(title: "R1 Tue", indexInWeek: 1, dayOffset: 1, orderIndex: 0),
                ]),
            ],
            seed: 9
        )

        await #expect(throws: PluriSyncError.networkUnavailable) {
            try await store.replaceRemainingWorkouts(withRegenerated: regenerated)
        }
        #expect(store.plan == plan)
    }

    // MARK: - Reminder reconciliation hook (M3-13)

    @Test("The reminder hook fires only after a successful remote mutation")
    func reminderHookFiresOnSuccessOnly() async throws {
        let plan = makeScheduledPlan()
        let reconciler = MockWorkoutReminderReconciler()
        let service = MockPlanMutationService()
        let (store, _) = makeStore(plan: plan, service: service, reminderReconciler: reconciler)
        let moved = plan.weeks[1].sessions[0]

        // Validation rejection: no reconcile.
        await #expect(throws: PlanMutationError.dayOccupied) {
            try await store.moveWorkout(id: moved.id, to: day(9))
        }
        #expect(reconciler.reconciledPlans.isEmpty)

        // Remote failure (rolled back): no reconcile.
        service.nextError = .networkUnavailable
        await #expect(throws: PluriSyncError.networkUnavailable) {
            try await store.moveWorkout(id: moved.id, to: day(8))
        }
        #expect(reconciler.reconciledPlans.isEmpty)

        // Success: reconciled with the updated plan.
        try await store.moveWorkout(id: moved.id, to: day(8))
        #expect(reconciler.reconciledPlans.count == 1)
        #expect(reconciler.reconciledPlans.first == store.plan)

        // Add fires the hook too.
        try await store.addWorkout(cloning: moved.id, on: day(10))
        #expect(reconciler.reconciledPlans.count == 2)

        // Replace-remaining fires the hook too (M3-16 thin coverage).
        let regenerated = GeneratedPlan(
            goal: .buildMuscle,
            scheduleType: .scheduled,
            sessionDurationMinutes: 45,
            startDate: monday,
            weeks: [
                PlanWeek(number: 1, sessions: [
                    makeSession(title: "R1 Tue", indexInWeek: 1, dayOffset: 1, orderIndex: 0),
                ]),
                PlanWeek(number: 2, sessions: [
                    makeSession(title: "R2 Tue", indexInWeek: 1, dayOffset: 8, orderIndex: 1),
                ]),
            ],
            seed: 9
        )
        try await store.replaceRemainingWorkouts(withRegenerated: regenerated)
        #expect(reconciler.reconciledPlans.count == 3)
        #expect(reconciler.reconciledPlans.last == store.plan)
    }

    // MARK: - Manage Plan (M3-14)

    /// Regenerated stand-in for a Manage Plan save: one-week plan, Tue/Thu.
    private func makeRegeneratedPlan() -> GeneratedPlan {
        GeneratedPlan(
            goal: .getStronger,
            scheduleType: .scheduled,
            sessionDurationMinutes: 30,
            startDate: monday,
            weeks: [
                PlanWeek(number: 1, sessions: [
                    makeSession(title: "R1 Tue", indexInWeek: 1, dayOffset: 1, orderIndex: 0),
                    makeSession(title: "R1 Thu", indexInWeek: 2, dayOffset: 3, orderIndex: 1),
                ]),
            ],
            seed: 9
        )
    }

    @Test("Manage Plan save merges the regenerated plan, swaps the profile, and calls the atomic RPC path")
    func applyManagePlanSucceeds() async throws {
        let plan = makeScheduledPlan()
        let reconciler = MockWorkoutReminderReconciler()
        let service = MockPlanMutationService()
        let (store, _) = makeStore(plan: plan, service: service, reminderReconciler: reconciler)

        var edited = makeProfile()
        edited.goal = .getStronger
        edited.units = "imperial"
        edited.sessionDuration = .thirtyMinutes

        try await store.applyManagePlan(editedProfile: edited, regenerated: makeRegeneratedPlan())

        // Local plan merged: same identity, regenerated metadata, history kept.
        let updated = try #require(store.plan)
        #expect(updated.id == plan.id)
        #expect(updated.goal == .getStronger)
        let preservedIDs = Set(plan.weeks[0].sessions.map(\.id))
        let updatedIDs = Set(updated.weeks.flatMap { $0.sessions.map(\.id) })
        #expect(preservedIDs.isSubset(of: updatedIDs))

        // Local profile refreshed.
        #expect(store.profile == edited)

        // One atomic call carrying plan + profile settings and the row sets.
        #expect(service.managePlanCalls.count == 1)
        #expect(service.replaceCalls.isEmpty)
        let call = try #require(service.managePlanCalls.first)
        #expect(call.planID == plan.id)
        #expect(call.planUpdate.goal == "build_strength")
        #expect(call.planUpdate.weeks == updated.weekCount)
        #expect(call.profileUpdate.units == "imperial")
        #expect(call.profileUpdate.sessionMinutes == 30)
        #expect(Set(call.deletingWorkoutIDs) == Set(plan.weeks[1].sessions.map(\.id)))
        #expect(call.insertingWorkouts.allSatisfy { !preservedIDs.contains($0.id) })

        // Reminder hook fired once, with the merged plan.
        #expect(reconciler.reconciledPlans == [updated])
    }

    @Test("A failed Manage Plan save rolls back both the plan and the profile")
    func applyManagePlanRollsBackOnFailure() async throws {
        let plan = makeScheduledPlan()
        let reconciler = MockWorkoutReminderReconciler()
        let service = MockPlanMutationService()
        service.nextError = .networkUnavailable
        let (store, _) = makeStore(plan: plan, service: service, reminderReconciler: reconciler)
        let originalProfile = store.profile

        var edited = makeProfile()
        edited.goal = .getStronger

        await #expect(throws: PluriSyncError.networkUnavailable) {
            try await store.applyManagePlan(editedProfile: edited, regenerated: makeRegeneratedPlan())
        }
        #expect(store.plan == plan)
        #expect(store.profile == originalProfile)
        #expect(reconciler.reconciledPlans.isEmpty)
    }

    @Test("A units-only profile update persists and rolls back on failure")
    func updateProfileSettingsOptimism() async throws {
        let plan = makeScheduledPlan()
        let service = MockPlanMutationService()
        let (store, _) = makeStore(plan: plan, service: service)
        let userID = UUID()

        var edited = makeProfile()
        edited.units = "imperial"

        try await store.updateProfileSettings(userID: userID, editedProfile: edited)
        #expect(store.profile?.units == "imperial")
        #expect(service.profileSettingsCalls.count == 1)
        #expect(service.profileSettingsCalls.first?.userID == userID)
        #expect(service.profileSettingsCalls.first?.update.units == "imperial")
        // The plan is untouched by a settings-only save.
        #expect(store.plan == plan)

        var reverted = edited
        reverted.units = "metric"
        service.nextError = .networkUnavailable
        await #expect(throws: PluriSyncError.networkUnavailable) {
            try await store.updateProfileSettings(userID: userID, editedProfile: reverted)
        }
        #expect(store.profile?.units == "imperial")
    }

    @Test("A plan-settings-only update persists and rolls back on failure")
    func updatePlanSettingsOptimism() async throws {
        let plan = makeScheduledPlan()
        let service = MockPlanMutationService()
        let (store, _) = makeStore(plan: plan, service: service)

        let renamed = GeneratedPlan(
            id: plan.id,
            goal: plan.goal,
            scheduleType: plan.scheduleType,
            sessionDurationMinutes: plan.sessionDurationMinutes,
            startDate: plan.startDate,
            weeks: plan.weeks,
            seed: plan.seed,
            name: "Summer block",
            status: plan.status
        )

        try await store.updatePlanSettings(to: renamed)
        #expect(store.plan?.name == "Summer block")
        #expect(service.planSettingsCalls.count == 1)
        #expect(service.planSettingsCalls.first?.update.name == "Summer block")

        service.nextError = .flushFailed("boom")
        await #expect(throws: PluriSyncError.flushFailed("boom")) {
            try await store.updatePlanSettings(to: plan)
        }
        #expect(store.plan?.name == "Summer block")
    }

    // MARK: - Mutations without a plan

    @Test("Mutations without a plan throw noPlan")
    func mutationsWithoutPlanThrow() async throws {
        let store = PlanStore(mutationService: MockPlanMutationService(), calendar: calendar)
        store.configure(from: RestoredUserState(profile: makeProfile(), plan: nil))

        await #expect(throws: PlanMutationError.noPlan) {
            try await store.moveWorkout(id: UUID(), to: day(1))
        }
        await #expect(throws: PlanMutationError.noPlan) {
            try await store.addWorkout(cloning: UUID(), on: day(1))
        }
    }

    // MARK: - Settings write path (M3-05 stubs for Manage Plan)

    @Test("Settings updates reach the mutation service with the expected rows")
    func settingsUpdateCallShapes() async throws {
        let service = MockPlanMutationService()
        let planID = UUID()
        let userID = UUID()

        try await service.updatePlanSettings(
            planID: planID,
            update: PlanSettingsUpdateRow(goal: "build_strength", weeks: 8)
        )
        try await service.updateProfileSettings(
            userID: userID,
            update: ProfileSettingsUpdateRow(
                goal: "build_strength",
                daysPerWeek: 4,
                workoutDays: ["mon", "tue", "thu", "sat"],
                sessionMinutes: 45,
                units: "imperial"
            )
        )

        #expect(service.planSettingsCalls.count == 1)
        #expect(service.planSettingsCalls.first?.planID == planID)
        #expect(service.planSettingsCalls.first?.update.goal == "build_strength")
        #expect(service.planSettingsCalls.first?.update.weeks == 8)
        #expect(service.profileSettingsCalls.count == 1)
        #expect(service.profileSettingsCalls.first?.userID == userID)
        #expect(service.profileSettingsCalls.first?.update.workoutDays == ["mon", "tue", "thu", "sat"])
        #expect(service.profileSettingsCalls.first?.update.units == "imperial")
    }
}
