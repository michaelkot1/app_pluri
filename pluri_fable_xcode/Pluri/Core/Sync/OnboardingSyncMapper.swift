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
        let planRow = PlanInsertRow(
            id: plan.id,
            userId: userID,
            goal: DatabaseCodeMappings.goalCode(plan.goal),
            name: plan.goal.rawValue,
            startDate: DatabaseCodeMappings.dateString(plan.startDate),
            endDate: DatabaseCodeMappings.dateString(plan.endDate),
            weeks: plan.weekCount,
            scheduleType: DatabaseCodeMappings.scheduleTypeCode(plan.scheduleType),
            status: "active"
        )

        var workouts: [PlanWorkoutInsertRow] = []
        var exercises: [WorkoutExerciseInsertRow] = []
        var globalOrder = 0

        for week in plan.weeks {
            for session in week.sessions {
                let workoutID = session.id
                workouts.append(
                    PlanWorkoutInsertRow(
                        id: workoutID,
                        planId: plan.id,
                        weekNumber: week.number,
                        scheduledDate: session.date.map(DatabaseCodeMappings.dateString),
                        scheduledDay: session.weekday.map(DatabaseCodeMappings.weekdayCode),
                        name: session.title,
                        workoutType: "weights",
                        color: nil,
                        durationMinutes: max(10, min(240, session.estimatedMinutes)),
                        status: "scheduled",
                        orderIndex: globalOrder
                    )
                )
                globalOrder += 1

                for exercise in session.exercises {
                    exercises.append(
                        WorkoutExerciseInsertRow(
                            id: exercise.id,
                            planWorkoutId: workoutID,
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
                    )
                }
            }
        }

        return PlanTreeInsert(plan: planRow, workouts: workouts, exercises: exercises)
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

    /// Rebuilds a `GeneratedPlan` from persisted plan tree rows (best-effort for M2-15 stub).
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

        let weeks: [PlanWeek] = workoutsByWeek.keys.sorted().map { weekNumber in
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
            seed: 0
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
