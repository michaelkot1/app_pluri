import Foundation

/// Pure mappers between onboarding/plan domain types and Supabase row DTOs (M2-13).
nonisolated enum OnboardingSyncMapper {
    /// Maps in-memory answers to a profiles upsert row. Requires goal / experience /
    /// regularity / location (Q2–Q5) — flush only runs after a complete questionnaire.
    @MainActor
    static func profileRow(userID: UUID, answers: OnboardingAnswers) throws -> ProfileUpsertRow {
        guard let goal = answers.goal,
              let experience = answers.experience,
              let regularity = answers.regularity,
              let location = answers.location
        else {
            throw PluriSyncError.incompleteAnswers
        }

        let days = Array(answers.trainingDays)
            .sorted { $0.rawValue < $1.rawValue }
            .map(DatabaseCodeMappings.weekdayCode)
        let clampedDaysPerWeek = min(6, max(2, answers.trainingDays.count))

        let injuries = answers.injuries
            .map { InjuryJSON(area: $0.key.rawValue, pain: $0.value) }
            .sorted { $0.area.localizedStandardCompare($1.area) == .orderedAscending }

        return ProfileUpsertRow(
            id: userID,
            displayName: answers.name.trimmingCharacters(in: .whitespacesAndNewlines),
            goal: DatabaseCodeMappings.goalCode(goal),
            trainingExperience: DatabaseCodeMappings.experienceCode(experience),
            trainingRegularity: DatabaseCodeMappings.regularityCode(regularity),
            workoutLocation: DatabaseCodeMappings.locationCode(location),
            injuries: injuries,
            daysPerWeek: clampedDaysPerWeek,
            workoutDays: days,
            scheduleType: DatabaseCodeMappings.scheduleTypeCode(answers.scheduleType),
            programWeeks: answers.planLengthWeeks,
            sessionMinutes: answers.sessionDuration.rawValue,
            age: answers.age,
            gender: answers.gender.map(DatabaseCodeMappings.genderCode),
            heightCm: answers.heightCM,
            weightKg: answers.weightKG,
            startDate: DatabaseCodeMappings.dateString(answers.resolvedStartDate),
            onboardingCompleted: true,
            units: "metric",
            maintenanceCalories: answers.maintenanceCalories,
            allergies: answers.allergies.sorted(),
            equipment: answers.equipment.sorted()
        )
    }

    static func planTree(userID: UUID, plan: GeneratedPlan) -> PlanTreeInsert {
        let planRow = planRow(userID: userID, plan: plan)

        var workouts: [PlanWorkoutInsertRow] = []
        var exercises: [WorkoutExerciseInsertRow] = []

        for week in plan.weeks {
            for session in week.sessions {
                workouts.append(workoutRow(for: session, planID: plan.id, weekNumber: week.number))
                exercises.append(contentsOf: exerciseRows(for: session))
            }
        }

        return PlanTreeInsert(plan: planRow, workouts: workouts, exercises: exercises)
    }

    /// Maps a plan's own metadata to its `plans` row (M3-03: name, status,
    /// and end date come from the domain instead of being reinvented).
    static func planRow(userID: UUID, plan: GeneratedPlan) -> PlanInsertRow {
        PlanInsertRow(
            id: plan.id,
            userId: userID,
            goal: DatabaseCodeMappings.goalCode(plan.goal),
            name: plan.name ?? plan.goal.rawValue,
            startDate: DatabaseCodeMappings.dateString(plan.startDate),
            endDate: DatabaseCodeMappings.dateString(plan.endDate),
            weeks: plan.weekCount,
            scheduleType: DatabaseCodeMappings.scheduleTypeCode(plan.scheduleType),
            status: plan.status.rawValue
        )
    }

    /// Maps one session to its `plan_workouts` row. M3-03: status / type /
    /// color / order / duration are carried by the domain model, so flush and
    /// the M3-05 mutation services write exactly what hydrate reads back.
    static func workoutRow(for session: PlannedSession, planID: UUID, weekNumber: Int) -> PlanWorkoutInsertRow {
        PlanWorkoutInsertRow(
            id: session.id,
            planId: planID,
            weekNumber: weekNumber,
            scheduledDate: session.date.map(DatabaseCodeMappings.dateString),
            scheduledDay: session.weekday.map(DatabaseCodeMappings.weekdayCode),
            name: session.title,
            workoutType: session.workoutType.rawValue,
            color: session.color,
            focus: session.focus?.rawValue,
            durationMinutes: PlannedSession.clampedDuration(session.durationMinutes),
            status: session.status.rawValue,
            orderIndex: session.orderIndex
        )
    }

    /// Maps a local workout session to a `workout_sessions` upsert row (M4-03).
    /// Excludes local-only pause / per-exercise note fields (SPEC §14 #51).
    @MainActor
    static func sessionRow(for session: WorkoutSessionRecord) -> WorkoutSessionUpsertRow {
        WorkoutSessionUpsertRow(
            id: session.id,
            userId: session.userId,
            planWorkoutId: session.planWorkoutId,
            activityType: session.activityType,
            startedAt: DatabaseCodeMappings.timestampString(session.startedAt),
            endedAt: session.endedAt.map(DatabaseCodeMappings.timestampString),
            durationSeconds: session.durationSeconds,
            distanceMeters: session.distanceMeters,
            notes: session.notes,
            syncedToHealth: session.syncedToHealth,
            isManualLog: session.isManualLog,
            createdAt: DatabaseCodeMappings.timestampString(session.createdAt),
            updatedAt: DatabaseCodeMappings.timestampString(session.updatedAt)
        )
    }

    /// Maps a local set log to a `set_logs` upsert row (M4-03).
    @MainActor
    static func setLogRow(for setLog: SetLogRecord, sessionId: UUID) -> SetLogUpsertRow {
        SetLogUpsertRow(
            id: setLog.id,
            sessionId: sessionId,
            workoutExerciseId: setLog.workoutExerciseId,
            exerciseName: setLog.exerciseName,
            setNumber: setLog.setNumber,
            reps: setLog.reps,
            weightKg: setLog.weightKg,
            durationSeconds: setLog.durationSeconds,
            createdAt: DatabaseCodeMappings.timestampString(setLog.createdAt)
        )
    }

    /// Maps a local favorite to a `recipe_favorites` upsert row (M7-07).
    @MainActor
    static func recipeFavoriteRow(for record: RecipeFavoriteRecord) -> RecipeFavoriteUpsertRow {
        RecipeFavoriteUpsertRow(
            id: record.id,
            userId: record.userId,
            mealdbRecipeId: record.mealdbRecipeId,
            cachedTitle: record.cachedTitle,
            cachedThumbURL: record.cachedThumbURL,
            createdAt: DatabaseCodeMappings.timestampString(record.createdAt)
        )
    }

    /// Maps a local food log to a `food_logs` upsert row (M7-11).
    @MainActor
    static func foodLogRow(for record: FoodLogRecord) -> FoodLogUpsertRow {
        FoodLogUpsertRow(
            id: record.id,
            userId: record.userId,
            foodName: record.foodName,
            serving: record.serving,
            calories: record.calories,
            macros: FoodLogMacrosJSON.decode(from: record.macrosJSON),
            meal: record.meal,
            loggedDate: DatabaseCodeMappings.dateString(record.loggedDate),
            mealdbRecipeId: record.mealdbRecipeId,
            nutritionFoodId: record.nutritionFoodId,
            createdAt: DatabaseCodeMappings.timestampString(record.createdAt)
        )
    }

    /// Maps a plan's editable metadata to the Manage Plan `plans` update row
    /// (M3-14 / §6.2). All fields are filled so the row is also usable as the
    /// complete `plan_update` object of the `replace_remaining_plan` RPC.
    static func planSettingsUpdate(for plan: GeneratedPlan) -> PlanSettingsUpdateRow {
        PlanSettingsUpdateRow(
            goal: DatabaseCodeMappings.goalCode(plan.goal),
            name: plan.name ?? plan.goal.rawValue,
            startDate: DatabaseCodeMappings.dateString(plan.startDate),
            endDate: DatabaseCodeMappings.dateString(plan.endDate),
            weeks: plan.weekCount,
            scheduleType: DatabaseCodeMappings.scheduleTypeCode(plan.scheduleType),
            status: plan.status.rawValue
        )
    }

    /// Maps the profile fields Manage Plan edits (goal, dates/length,
    /// training days, session duration, units — §6.2) to a `profiles`
    /// update row (M3-14).
    static func profileSettingsUpdate(for profile: RestoredProfile) -> ProfileSettingsUpdateRow {
        let days = profile.trainingDays
            .sorted { $0.rawValue < $1.rawValue }
            .map(DatabaseCodeMappings.weekdayCode)
        return ProfileSettingsUpdateRow(
            goal: profile.goal.map(DatabaseCodeMappings.goalCode),
            daysPerWeek: min(6, max(2, profile.trainingDays.count)),
            workoutDays: days,
            scheduleType: DatabaseCodeMappings.scheduleTypeCode(profile.scheduleType),
            programWeeks: profile.planLengthWeeks,
            sessionMinutes: profile.sessionDuration.rawValue,
            startDate: profile.startDate.map(DatabaseCodeMappings.dateString),
            units: profile.units
        )
    }

    /// Maps a session's exercises to their `workout_exercises` rows.
    static func exerciseRows(for session: PlannedSession) -> [WorkoutExerciseInsertRow] {
        session.exercises.map { exercise in
            WorkoutExerciseInsertRow(
                id: exercise.id,
                planWorkoutId: session.id,
                workoutxExerciseId: exercise.exerciseID,
                cachedMetadata: ExerciseCachedMetadata(
                    name: exercise.name,
                    bodyPart: exercise.bodyPart,
                    equipment: exercise.equipment,
                    targetMuscle: exercise.targetMuscle,
                    secondaryMuscles: exercise.secondaryMuscles,
                    imageURL: exercise.imageURL?.absoluteString
                ),
                targetSets: exercise.sets,
                targetReps: String(exercise.reps),
                targetDurationSeconds: nil,
                orderIndex: exercise.order
            )
        }
    }

    /// Reverse-maps a fetched profile row into fields usable to hydrate onboarding-ish state.
    static func hydrateProfile(from row: ProfileUpsertRow) -> RestoredProfile {
        RestoredProfile(
            displayName: row.displayName,
            goal: DatabaseCodeMappings.goal(from: row.goal),
            experience: DatabaseCodeMappings.experience(from: row.trainingExperience),
            regularity: DatabaseCodeMappings.regularity(from: row.trainingRegularity),
            location: DatabaseCodeMappings.location(from: row.workoutLocation),
            injuries: Dictionary(
                uniqueKeysWithValues: row.injuries.compactMap { injury in
                    guard let area = BodyArea(rawValue: injury.area) else { return nil }
                    return (area, injury.pain)
                }
            ),
            trainingDays: Set(row.workoutDays.compactMap(DatabaseCodeMappings.weekday)),
            scheduleType: DatabaseCodeMappings.scheduleType(from: row.scheduleType) ?? .scheduled,
            planLengthWeeks: row.programWeeks,
            sessionDuration: SessionDuration(rawValue: row.sessionMinutes) ?? .oneHour,
            age: row.age,
            gender: row.gender.flatMap(DatabaseCodeMappings.gender),
            heightCM: row.heightCm,
            weightKG: row.weightKg,
            allergies: Set(row.allergies),
            equipment: Set(row.equipment),
            startDate: DatabaseCodeMappings.date(from: row.startDate),
            maintenanceCalories: row.maintenanceCalories,
            units: row.units,
            onboardingCompleted: row.onboardingCompleted
        )
    }

    /// Rebuilds a `GeneratedPlan` from persisted plan tree rows (M2-15).
    /// M3-03: workout status / type / color / order / duration and the plan's
    /// name, status, end date, and full week count survive the round-trip.
    /// The seed isn't persisted by the schema, so restored plans carry `0`.
    static func hydratePlan(
        plan: PlanInsertRow,
        workouts: [PlanWorkoutInsertRow],
        exercises: [WorkoutExerciseInsertRow]
    ) -> GeneratedPlan? {
        guard let goal = DatabaseCodeMappings.goal(from: plan.goal),
              let scheduleType = DatabaseCodeMappings.scheduleType(from: plan.scheduleType),
              let startDate = DatabaseCodeMappings.date(from: plan.startDate)
        else {
            return nil
        }

        let exercisesByWorkout = Dictionary(grouping: exercises, by: \.planWorkoutId)
        let workoutsByWeek = Dictionary(grouping: workouts, by: \.weekNumber)

        // Preserve the declared week count even when trailing weeks have no
        // workouts yet, so trackers ("Weeks Completed 1/6") stay honest.
        let lastWeekNumber = max(plan.weeks, workoutsByWeek.keys.max() ?? 0)
        guard lastWeekNumber >= 1 else { return nil }

        let weeks: [PlanWeek] = (1...lastWeekNumber).map { weekNumber in
            let weekWorkouts = (workoutsByWeek[weekNumber] ?? [])
                .sorted { $0.orderIndex < $1.orderIndex }
            let sessions: [PlannedSession] = weekWorkouts.enumerated().map { index, workout in
                let plannedExercises = (exercisesByWorkout[workout.id] ?? [])
                    .sorted { $0.orderIndex < $1.orderIndex }
                    .map { row in
                        PlannedExercise(
                            id: row.id,
                            exerciseID: row.workoutxExerciseId,
                            name: row.cachedMetadata.name,
                            bodyPart: row.cachedMetadata.bodyPart,
                            equipment: row.cachedMetadata.equipment,
                            targetMuscle: row.cachedMetadata.targetMuscle,
                            secondaryMuscles: row.cachedMetadata.secondaryMuscles,
                            imageURL: row.cachedMetadata.imageURL.flatMap(URL.init(string:)),
                            order: row.orderIndex,
                            sets: row.targetSets ?? 3,
                            reps: Int(row.targetReps ?? "10") ?? 10
                        )
                    }
                return PlannedSession(
                    id: workout.id,
                    title: workout.name,
                    indexInWeek: index + 1,
                    weekday: workout.scheduledDay.flatMap(DatabaseCodeMappings.weekday),
                    date: workout.scheduledDate.flatMap(DatabaseCodeMappings.date),
                    status: WorkoutStatus(rawValue: workout.status) ?? .scheduled,
                    workoutType: WorkoutType(rawValue: workout.workoutType) ?? .weights,
                    color: workout.color,
                    focus: workout.focus.flatMap(SessionFocusCode.init(rawValue:)),
                    orderIndex: workout.orderIndex,
                    durationMinutes: workout.durationMinutes,
                    exercises: plannedExercises
                )
            }
            return PlanWeek(id: UUID(), number: weekNumber, sessions: sessions)
        }

        return GeneratedPlan(
            id: plan.id,
            goal: goal,
            scheduleType: scheduleType,
            sessionDurationMinutes: workouts.first?.durationMinutes ?? 60,
            startDate: startDate,
            weeks: weeks,
            seed: 0,
            name: plan.name,
            status: PlanStatus(rawValue: plan.status) ?? .active,
            endDate: DatabaseCodeMappings.date(from: plan.endDate)
        )
    }
}

/// Hydrated profile fields after remote restore (M2-15). Not a full Main shell.
nonisolated struct RestoredProfile: Sendable, Equatable {
    var displayName: String
    var goal: Goal?
    var experience: ExperienceLevel?
    var regularity: RegularityLevel?
    var location: WorkoutLocation?
    var injuries: [BodyArea: Int]
    var trainingDays: Set<Weekday>
    var scheduleType: ScheduleType
    var planLengthWeeks: Int
    var sessionDuration: SessionDuration
    var age: Int?
    var gender: Gender?
    var heightCM: Double?
    var weightKG: Double?
    var allergies: Set<String>
    var equipment: Set<String>
    var startDate: Date?
    var maintenanceCalories: Int?
    var units: String
    var onboardingCompleted: Bool
}

nonisolated struct RestoredUserState: Sendable, Equatable {
    var profile: RestoredProfile
    var plan: GeneratedPlan?
}
