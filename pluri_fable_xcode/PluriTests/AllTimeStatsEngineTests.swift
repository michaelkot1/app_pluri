import Foundation
import Testing
@testable import Pluri

/// M5-09 — all-time strength totals from completed sessions / set logs.
@Suite("AllTimeStatsEngine")
struct AllTimeStatsEngineTests {
    private func session(
        id: UUID = UUID(),
        durationSeconds: Int?,
        sets: [(Int?, Double?)]
    ) -> AllTimeStatsEngine.SessionInput {
        AllTimeStatsEngine.SessionInput(
            id: id,
            durationSeconds: durationSeconds,
            setLogs: sets.map { reps, weight in
                AllTimeStatsEngine.SetLogInput(reps: reps, weightKg: weight)
            }
        )
    }

    @Test("Empty sessions yield empty stats")
    func emptySessions() {
        let stats = AllTimeStatsEngine.aggregate(sessions: [])
        #expect(stats == .empty)
        #expect(stats.isEmpty)
    }

    @Test("Aggregates workouts, sets, reps, volume, and duration")
    func aggregatesTotals() {
        let sessions = [
            session(durationSeconds: 600, sets: [
                (8, 60),
                (8, 60),
            ]),
            session(durationSeconds: 900, sets: [
                (5, 100),
                (10, nil),
            ]),
        ]
        let stats = AllTimeStatsEngine.aggregate(sessions: sessions)
        let expectedVolume = 960.0 + 500.0

        #expect(stats.workoutCount == 2)
        #expect(stats.totalSets == 4)
        #expect(stats.totalReps == 31)
        #expect(stats.totalVolumeKg == expectedVolume)
        #expect(stats.totalDurationSeconds == 1_500)
        #expect(!stats.isEmpty)
    }

    @Test("Bodyweight-only sets leave volume nil")
    func bodyweightOmitsVolume() {
        let stats = AllTimeStatsEngine.aggregate(
            sessions: [session(durationSeconds: 300, sets: [(12, nil), (10, nil)])]
        )
        #expect(stats.workoutCount == 1)
        #expect(stats.totalSets == 2)
        #expect(stats.totalReps == 22)
        #expect(stats.totalVolumeKg == nil)
        #expect(stats.totalDurationSeconds == 300)
    }

    @Test("Nil duration contributes zero seconds")
    func nilDurationCountsAsZero() {
        let stats = AllTimeStatsEngine.aggregate(
            sessions: [
                session(durationSeconds: nil, sets: [(5, 40)]),
                session(durationSeconds: 120, sets: [(5, 40)]),
            ]
        )
        #expect(stats.totalDurationSeconds == 120)
        #expect(stats.totalVolumeKg == 400)
    }

    @Test("Plan + manual completed sessions both count in all-time (M5-12 / M5-15)")
    func includesManualSessionsWhenProvided() {
        // Engine is source-agnostic; repo `fetchAllCompletedSessions` supplies
        // both plan-linked and `isManualLog` rows (SPEC §9.3 / §14 #57e / #62).
        // Duration-only manual Workout (no sets) still increments workout count
        // and total time — same path Insights All-Time uses after "+".
        let planLinked = session(durationSeconds: 600, sets: [(8, 50)])
        let manualDurationOnly = session(durationSeconds: 1_200, sets: [])
        let stats = AllTimeStatsEngine.aggregate(sessions: [planLinked, manualDurationOnly])

        #expect(stats.workoutCount == 2)
        #expect(stats.totalSets == 1)
        #expect(stats.totalReps == 8)
        #expect(stats.totalDurationSeconds == 1_800)
        #expect(stats.totalVolumeKg == 400)
        #expect(!stats.isEmpty)
    }
}
