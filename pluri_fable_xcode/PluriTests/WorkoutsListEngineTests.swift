import Foundation
import Testing
@testable import Pluri

/// M5-11 — Workouts tab month grouping, totals, day filter, description resolve.
@Suite("WorkoutsListEngine")
struct WorkoutsListEngineTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func session(
        id: UUID = UUID(),
        startedAt: Date,
        durationSeconds: Int = 600,
        distanceMeters: Double? = nil,
        activityType: String = "workout",
        isManualLog: Bool = false,
        planWorkoutId: UUID? = nil,
        description: String = "Session",
        sets: [(String, Int, Int?)] = []
    ) -> WorkoutsListEngine.SessionInput {
        WorkoutsListEngine.SessionInput(
            id: id,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
            activityType: activityType,
            isManualLog: isManualLog,
            planWorkoutId: planWorkoutId,
            description: description,
            setLogs: sets.map { name, setNumber, reps in
                WorkoutsListEngine.SetLogInput(
                    id: UUID(),
                    exerciseName: name,
                    setNumber: setNumber,
                    reps: reps,
                    weightKg: nil,
                    durationSeconds: nil
                )
            }
        )
    }

    @Test("Groups by month of startedAt and sorts newest first")
    func groupsByMonthOfStartedAt() {
        // 2026-07-15 and 2026-06-10 UTC
        let july = Date(timeIntervalSince1970: 1_784_073_600)
        let june = Date(timeIntervalSince1970: 1_781_395_200)
        let julyLater = july.addingTimeInterval(3_600)

        let groups = WorkoutsListEngine.groupByMonth(
            sessions: [
                session(startedAt: june, description: "June"),
                session(startedAt: july, description: "July A"),
                session(startedAt: julyLater, description: "July B"),
            ],
            calendar: calendar
        )

        #expect(groups.count == 2)
        #expect(groups[0].workoutCount == 2)
        #expect(groups[0].workouts.map(\.description) == ["July B", "July A"])
        #expect(groups[1].workoutCount == 1)
        #expect(groups[1].workouts.first?.description == "June")
    }

    @Test("Monthly totals include optional distance sum")
    func monthlyDistanceTotals() {
        let day = Date(timeIntervalSince1970: 1_784_073_600)
        let groups = WorkoutsListEngine.groupByMonth(
            sessions: [
                session(startedAt: day, distanceMeters: 1_000, activityType: "cardio"),
                session(
                    startedAt: day.addingTimeInterval(3_600),
                    distanceMeters: 2_500,
                    activityType: "cardio"
                ),
                session(startedAt: day.addingTimeInterval(7_200), distanceMeters: nil),
            ],
            calendar: calendar
        )

        #expect(groups.count == 1)
        #expect(groups[0].workoutCount == 3)
        #expect(groups[0].totalDistanceMeters == 3_500)
    }

    @Test("Day filter keeps only sessions on that startedAt day")
    func dayFilter() {
        let dayA = Date(timeIntervalSince1970: 1_784_073_600) // 2026-07-15
        let dayB = dayA.addingTimeInterval(86_400)
        let groups = WorkoutsListEngine.groupByMonth(
            sessions: [
                session(startedAt: dayA, description: "A"),
                session(startedAt: dayB, description: "B"),
            ],
            calendar: calendar,
            dayFilter: dayA
        )

        #expect(groups.count == 1)
        #expect(groups[0].workoutCount == 1)
        #expect(groups[0].workouts.first?.description == "A")
    }

    @Test("Card totals reps and groups set logs per exercise")
    func cardAggregatesSets() {
        let day = Date(timeIntervalSince1970: 1_784_073_600)
        let groups = WorkoutsListEngine.groupByMonth(
            sessions: [
                session(
                    startedAt: day,
                    sets: [
                        ("Squat", 1, 8),
                        ("Squat", 2, 8),
                        ("Bench", 1, 10),
                    ]
                ),
            ],
            calendar: calendar
        )

        let card = groups.first?.workouts.first
        #expect(card?.totalReps == 26)
        #expect(card?.exercises.count == 2)
        #expect(card?.exercises.first { $0.exerciseName == "Squat" }?.sets.count == 2)
    }

    @Test("resolveDescription prefers plan title, then notes, then activity label")
    func resolveDescription() {
        #expect(
            WorkoutsListEngine.resolveDescription(
                planTitle: "Push Day",
                notes: "ignored",
                activityType: "workout"
            ) == "Push Day"
        )
        #expect(
            WorkoutsListEngine.resolveDescription(
                planTitle: nil,
                notes: " Easy jog ",
                activityType: "cardio"
            ) == "Easy jog"
        )
        #expect(
            WorkoutsListEngine.resolveDescription(
                planTitle: nil,
                notes: nil,
                activityType: "flexibility"
            ) == "Flexibility"
        )
    }

    @Test("Empty input yields empty groups")
    func emptyInput() {
        #expect(WorkoutsListEngine.groupByMonth(sessions: [], calendar: calendar).isEmpty)
    }

    @Test("Manual activity sessions appear in month groups (M5-12 / M5-15)")
    func includesManualActivities() {
        let day = Date(timeIntervalSince1970: 1_784_073_600) // 2026-07-15
        let groups = WorkoutsListEngine.groupByMonth(
            sessions: [
                session(
                    startedAt: day,
                    isManualLog: false,
                    description: "Plan Push"
                ),
                session(
                    startedAt: day.addingTimeInterval(3_600),
                    activityType: "cardio",
                    isManualLog: true,
                    description: "Easy jog"
                ),
            ],
            calendar: calendar
        )

        #expect(groups.count == 1)
        #expect(groups[0].workoutCount == 2)
        let manuals = groups[0].workouts.filter(\.isManualLog)
        #expect(manuals.count == 1)
        #expect(manuals.first?.description == "Easy jog")
        #expect(groups[0].workouts.contains { !$0.isManualLog && $0.description == "Plan Push" })
    }

    @Test("Cards preserve planWorkoutId separately from session-log id (M5-17)")
    func cardsPreservePlanWorkoutId() {
        let day = Date(timeIntervalSince1970: 1_784_073_600)
        let sessionLogID = UUID()
        let planWorkoutID = UUID()
        let groups = WorkoutsListEngine.groupByMonth(
            sessions: [
                session(
                    id: sessionLogID,
                    startedAt: day,
                    isManualLog: false,
                    planWorkoutId: planWorkoutID,
                    description: "Plan Push"
                ),
                session(
                    startedAt: day.addingTimeInterval(3_600),
                    activityType: "cardio",
                    isManualLog: true,
                    planWorkoutId: nil,
                    description: "Easy jog"
                ),
            ],
            calendar: calendar
        )

        let planCard = groups[0].workouts.first { $0.description == "Plan Push" }
        let manualCard = groups[0].workouts.first { $0.description == "Easy jog" }
        #expect(planCard?.id == sessionLogID)
        #expect(planCard?.planWorkoutId == planWorkoutID)
        #expect(planCard?.id != planCard?.planWorkoutId)
        #expect(manualCard?.planWorkoutId == nil)
        #expect(manualCard?.isManualLog == true)
    }
}
