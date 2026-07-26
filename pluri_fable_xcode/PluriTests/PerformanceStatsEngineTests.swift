import Foundation
import Testing
@testable import Pluri

/// M5-08 — per-exercise Performance aggregation: week window, volume, trends.
@Suite("PerformanceStatsEngine")
struct PerformanceStatsEngineTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2 // Monday
        return calendar
    }

    /// Monday 2025-07-14 00:00 UTC.
    private var weekMonday: Date {
        Date(timeIntervalSince1970: 1_752_451_200)
    }

    private func day(_ offset: Int, hour: Int = 12) -> Date {
        let base = calendar.date(byAdding: .day, value: offset, to: weekMonday) ?? weekMonday
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
    }

    private func session(
        id: UUID = UUID(),
        endedOffset: Int,
        sets: [(String, Int?, Double?)]
    ) -> PerformanceStatsEngine.SessionInput {
        PerformanceStatsEngine.SessionInput(
            id: id,
            endedAt: day(endedOffset),
            setLogs: sets.map { name, reps, weight in
                PerformanceStatsEngine.SetLogInput(
                    exerciseName: name,
                    reps: reps,
                    weightKg: weight
                )
            }
        )
    }

    @Test("Week window is seven days starting at weekOfYear start")
    func weekWindow() {
        let window = PerformanceStatsEngine.weekWindow(
            containing: day(3),
            calendar: calendar
        )
        #expect(window.start == weekMonday)
        #expect(window.end == day(7, hour: 0))
    }

    @Test("Empty sessions yield no exercise stats")
    func emptySessions() {
        let stats = PerformanceStatsEngine.aggregate(
            sessions: [],
            weekStart: weekMonday,
            calendar: calendar
        )
        #expect(stats.isEmpty)
    }

    @Test("Sessions outside the week are ignored")
    func filtersByWeek() {
        let sessions = [
            session(endedOffset: -1, sets: [("Bench", 8, 60)]),
            session(endedOffset: 0, sets: [("Squat", 5, 100)]),
            session(endedOffset: 7, sets: [("Deadlift", 3, 140)]),
        ]
        let stats = PerformanceStatsEngine.aggregate(
            sessions: sessions,
            weekStart: weekMonday,
            calendar: calendar
        )
        #expect(stats.map(\.exerciseName) == ["Squat"])
        #expect(stats[0].setCount == 1)
        #expect(stats[0].totalReps == 5)
        #expect(stats[0].volumeKg == 500)
    }

    @Test("Volume sums reps × weightKg; bodyweight sets omit volume")
    func volumeRules() {
        let sessions = [
            session(endedOffset: 1, sets: [
                ("Push-up", 12, nil),
                ("Push-up", 10, nil),
                ("Row", 8, 40),
                ("Row", 8, 40),
            ]),
        ]
        let stats = PerformanceStatsEngine.aggregate(
            sessions: sessions,
            weekStart: weekMonday,
            calendar: calendar
        )
        let byName = Dictionary(uniqueKeysWithValues: stats.map { ($0.exerciseName, $0) })

        #expect(byName["Push-up"]?.setCount == 2)
        #expect(byName["Push-up"]?.totalReps == 22)
        #expect(byName["Push-up"]?.volumeKg == nil)

        #expect(byName["Row"]?.setCount == 2)
        #expect(byName["Row"]?.totalReps == 16)
        #expect(byName["Row"]?.volumeKg == 640)
    }

    @Test("Day points and upward volume trend across the week")
    func dayPointsAndUpTrend() {
        let sessions = [
            session(endedOffset: 0, sets: [("Bench", 8, 50)]),
            session(endedOffset: 3, sets: [("Bench", 8, 60)]),
        ]
        let stats = PerformanceStatsEngine.aggregate(
            sessions: sessions,
            weekStart: weekMonday,
            calendar: calendar
        )
        #expect(stats.count == 1)
        #expect(stats[0].points.count == 2)
        #expect(stats[0].points[0].volumeKg == 400)
        #expect(stats[0].points[1].volumeKg == 480)
        #expect(stats[0].trend == .up)
        #expect(stats[0].volumeKg == 880)
    }

    @Test("Single day of data yields insufficient trend")
    func insufficientTrend() {
        let sessions = [
            session(endedOffset: 2, sets: [("Curl", 10, 15)]),
        ]
        let stats = PerformanceStatsEngine.aggregate(
            sessions: sessions,
            weekStart: weekMonday,
            calendar: calendar
        )
        #expect(stats[0].trend == .insufficientData)
    }

    @Test("Blank exercise names are skipped")
    func skipsBlankNames() {
        let sessions = [
            session(endedOffset: 1, sets: [
                ("  ", 8, 40),
                ("Press", 8, 40),
            ]),
        ]
        let stats = PerformanceStatsEngine.aggregate(
            sessions: sessions,
            weekStart: weekMonday,
            calendar: calendar
        )
        #expect(stats.map(\.exerciseName) == ["Press"])
    }
}
