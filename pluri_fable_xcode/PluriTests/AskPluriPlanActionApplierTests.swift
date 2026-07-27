import Foundation
import Testing
@testable import Pluri

@Suite("AskPluriPlanActionApplier")
@MainActor
struct AskPluriPlanActionApplierTests {

    private let calendar = Calendar.current

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

    private func makeSession(
        title: String,
        indexInWeek: Int,
        dayOffset: Int,
        orderIndex: Int
    ) -> PlannedSession {
        let date = day(dayOffset)
        return PlannedSession(
            title: title,
            indexInWeek: indexInWeek,
            weekday: Weekday(rawValue: calendar.component(.weekday, from: date)),
            date: date,
            status: .scheduled,
            workoutType: .weights,
            orderIndex: orderIndex,
            durationMinutes: 45,
            exercises: [
                PlannedExercise(
                    exerciseID: "001",
                    name: "Row",
                    bodyPart: "Back",
                    equipment: "Dumbbell",
                    targetMuscle: "Lats",
                    secondaryMuscles: [],
                    imageURL: nil,
                    order: 0,
                    sets: 3,
                    reps: 10
                ),
            ]
        )
    }

    private func makePlanStore() -> (store: PlanStore, service: MockPlanMutationService) {
        let source = makeSession(title: "Pull", indexInWeek: 1, dayOffset: 7, orderIndex: 0)
        let removable = makeSession(title: "Push", indexInWeek: 2, dayOffset: 9, orderIndex: 1)
        let plan = GeneratedPlan(
            goal: .buildMuscle,
            scheduleType: .scheduled,
            sessionDurationMinutes: 45,
            startDate: monday,
            weeks: [
                PlanWeek(number: 1, sessions: []),
                PlanWeek(number: 2, sessions: [source, removable]),
            ],
            seed: 1
        )
        let service = MockPlanMutationService()
        let store = PlanStore(mutationService: service, calendar: calendar)
        store.now = { day(8) }
        store.configure(
            from: RestoredUserState(
                profile: RestoredProfile(
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
                ),
                plan: plan
            )
        )
        return (store, service)
    }

    @Test("summaryLines builds add/remove rows and omits invalid actions")
    func summaryLinesBuildsValidRows() throws {
        let (store, _) = makePlanStore()
        let sourceID = try #require(store.plan?.weeks[1].sessions[0].id)
        let removableID = try #require(store.plan?.weeks[1].sessions[1].id)
        let dateString = DatabaseCodeMappings.dateString(day(11))

        let lines = AskPluriPlanActionApplier.summaryLines(
            for: [
                .addWorkout(sourceWorkoutId: sourceID.uuidString, date: dateString),
                .removeWorkout(planWorkoutId: removableID.uuidString),
                .addWorkout(sourceWorkoutId: "not-a-uuid", date: dateString),
                .removeWorkout(planWorkoutId: "also-bad"),
            ],
            plan: store.plan,
            calendar: calendar
        )

        #expect(lines.count == 2)
        #expect(lines[0].kind == .add)
        #expect(lines[0].title.localizedStandardContains("Pull"))
        #expect(lines[1].kind == .remove)
        #expect(lines[1].title.localizedStandardContains("Push"))
    }

    @Test("multi-action apply stops on first error; later actions do not run")
    func applyStopsOnFirstError() async throws {
        let (store, service) = makePlanStore()
        let sourceID = try #require(store.plan?.weeks[1].sessions[0].id)
        let removableID = try #require(store.plan?.weeks[1].sessions[1].id)
        let planBefore = try #require(store.plan)

        service.nextError = .flushFailed("boom")
        await #expect(throws: PluriSyncError.flushFailed("boom")) {
            try await AskPluriPlanActionApplier.apply(
                [
                    .removeWorkout(planWorkoutId: removableID.uuidString),
                    .addWorkout(
                        sourceWorkoutId: sourceID.uuidString,
                        date: DatabaseCodeMappings.dateString(day(11))
                    ),
                ],
                to: store,
                calendar: calendar
            )
        }

        #expect(store.plan == planBefore)
        #expect(service.removeCalls.isEmpty)
        #expect(service.addCalls.isEmpty)
        #expect(PlanMutator.session(withID: removableID, in: try #require(store.plan)) != nil)
    }
}
