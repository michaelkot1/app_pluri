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

        func session(
            focus: SessionFocus,
            dayOffset: Int,
            status: WorkoutStatus,
            index: Int
        ) -> PlannedSession {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: start) ?? start
            return PlannedSession(
                title: focus.displayTitle,
                indexInWeek: index,
                weekday: Weekday(rawValue: calendar.component(.weekday, from: date)),
                date: date,
                status: status,
                workoutType: .weights,
                color: focus.colorToken.rawValue,
                focus: focus.code,
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
                    session(focus: .push, dayOffset: 0, status: .completed, index: 1),
                    session(focus: .lower, dayOffset: 2, status: .scheduled, index: 2),
                    session(focus: .pull, dayOffset: 4, status: .scheduled, index: 3),
                ]),
                PlanWeek(number: 2, sessions: [
                    session(focus: .push, dayOffset: 7, status: .scheduled, index: 1),
                    session(focus: .lower, dayOffset: 9, status: .scheduled, index: 2),
                    session(focus: .pull, dayOffset: 11, status: .scheduled, index: 3),
                ]),
            ],
            seed: 1
        )
    }

    private static var flexiblePlan: GeneratedPlan {
        func undatedSession(
            focus: SessionFocus,
            index: Int,
            orderIndex: Int,
            status: WorkoutStatus = .scheduled
        ) -> PlannedSession {
            PlannedSession(
                title: focus.displayTitle,
                indexInWeek: index,
                weekday: nil,
                date: nil,
                status: status,
                workoutType: .weights,
                color: focus.colorToken.rawValue,
                focus: focus.code,
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
                    undatedSession(focus: .fullBodyA, index: 1, orderIndex: 0, status: .completed),
                    undatedSession(focus: .fullBodyB, index: 2, orderIndex: 1),
                ]),
                PlanWeek(number: 2, sessions: [
                    undatedSession(focus: .fullBodyA, index: 1, orderIndex: 2),
                    undatedSession(focus: .fullBodyB, index: 2, orderIndex: 3),
                ]),
            ],
            seed: 2
        )
    }
}
#endif
