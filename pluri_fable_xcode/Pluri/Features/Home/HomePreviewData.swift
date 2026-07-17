#if DEBUG
import Foundation

/// Preview-only `PlanStore` fixtures for the Home / Plan / Calendar states
/// (M3-07 / M3-17): ready (scheduled), flexible, empty (no plan), and failed restore.
@MainActor
enum HomePreviewData {
    static func readyStore() -> PlanStore {
        let store = PlanStore(mutationService: MockPlanMutationService())
        store.configure(from: RestoredUserState(profile: profile(scheduleType: .scheduled), plan: plan))
        return store
    }

    /// Flexible-plan persona (SPEC §14 #37): undated weekly pool — Home shows
    /// no calendar dots; Plan / Calendar label workouts "Anytime this week".
    static func flexibleStore() -> PlanStore {
        let store = PlanStore(mutationService: MockPlanMutationService())
        store.configure(
            from: RestoredUserState(
                profile: profile(scheduleType: .flexible),
                plan: flexiblePlan
            )
        )
        return store
    }

    static func emptyStore() -> PlanStore {
        let store = PlanStore(mutationService: MockPlanMutationService())
        store.configure(from: RestoredUserState(profile: profile(scheduleType: .scheduled), plan: nil))
        return store
    }

    static func failedStore() -> PlanStore {
        let store = PlanStore(mutationService: MockPlanMutationService())
        store.configure(from: nil)
        return store
    }

    // MARK: - Fixtures

    private static func profile(scheduleType: ScheduleType) -> RestoredProfile {
        RestoredProfile(
            displayName: "Alex",
            goal: .buildMuscle,
            experience: .oneToSixMonths,
            regularity: .onAndOff,
            location: .commercialGym,
            injuries: [:],
            trainingDays: [.monday, .wednesday, .friday],
            scheduleType: scheduleType,
            planLengthWeeks: 2,
            sessionDuration: .fortyFiveMinutes,
            age: 28,
            gender: .male,
            heightCM: 178,
            weightKG: 75,
            allergies: [],
            equipment: ["Dumbbell"],
            startDate: weekStart,
            maintenanceCalories: 2400,
            units: "metric",
            onboardingCompleted: true
        )
    }

    /// Monday of the current week, so "today" always falls inside the plan.
    private static var weekStart: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday - Weekday.monday.rawValue + 7) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
    }

    private static var plan: GeneratedPlan {
        let calendar = Calendar.current
        let start = weekStart

        func session(title: String, dayOffset: Int, status: WorkoutStatus, index: Int) -> PlannedSession {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: start) ?? start
            return PlannedSession(
                title: title,
                indexInWeek: index,
                weekday: Weekday(rawValue: calendar.component(.weekday, from: date)),
                date: date,
                status: status,
                workoutType: .weights,
                orderIndex: dayOffset,
                durationMinutes: 45,
                exercises: [
                    PlannedExercise(
                        exerciseID: "0001",
                        name: "Dumbbell Bench Press",
                        bodyPart: "Chest",
                        equipment: "Dumbbell",
                        targetMuscle: "Pectorals",
                        secondaryMuscles: [],
                        imageURL: nil,
                        order: 0,
                        sets: 3,
                        reps: 10
                    ),
                ]
            )
        }

        return GeneratedPlan(
            goal: .buildMuscle,
            scheduleType: .scheduled,
            sessionDurationMinutes: 45,
            startDate: start,
            weeks: [
                PlanWeek(number: 1, sessions: [
                    session(title: "Upper Body Push", dayOffset: 0, status: .completed, index: 1),
                    session(title: "Lower Body", dayOffset: 2, status: .scheduled, index: 2),
                    session(title: "Upper Body Pull", dayOffset: 4, status: .scheduled, index: 3),
                ]),
                PlanWeek(number: 2, sessions: [
                    session(title: "Upper Body Push", dayOffset: 7, status: .scheduled, index: 1),
                    session(title: "Lower Body", dayOffset: 9, status: .scheduled, index: 2),
                    session(title: "Upper Body Pull", dayOffset: 11, status: .scheduled, index: 3),
                ]),
            ],
            seed: 1
        )
    }

    private static var flexiblePlan: GeneratedPlan {
        func undatedSession(title: String, index: Int, orderIndex: Int, status: WorkoutStatus = .scheduled) -> PlannedSession {
            PlannedSession(
                title: title,
                indexInWeek: index,
                weekday: nil,
                date: nil,
                status: status,
                workoutType: .weights,
                orderIndex: orderIndex,
                durationMinutes: 30,
                exercises: [
                    PlannedExercise(
                        exerciseID: "0001",
                        name: "Bodyweight Squat",
                        bodyPart: "Legs",
                        equipment: "Body Weight",
                        targetMuscle: "Quadriceps",
                        secondaryMuscles: [],
                        imageURL: nil,
                        order: 0,
                        sets: 3,
                        reps: 12
                    ),
                ]
            )
        }

        return GeneratedPlan(
            goal: .loseFatToneUp,
            scheduleType: .flexible,
            sessionDurationMinutes: 30,
            startDate: weekStart,
            weeks: [
                PlanWeek(number: 1, sessions: [
                    undatedSession(title: "Full Body A", index: 1, orderIndex: 0, status: .completed),
                    undatedSession(title: "Full Body B", index: 2, orderIndex: 1),
                ]),
                PlanWeek(number: 2, sessions: [
                    undatedSession(title: "Full Body A", index: 1, orderIndex: 2),
                    undatedSession(title: "Full Body B", index: 2, orderIndex: 3),
                ]),
            ],
            seed: 2
        )
    }
}
#endif
