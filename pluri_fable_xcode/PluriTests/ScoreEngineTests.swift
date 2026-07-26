import Foundation
import Testing
@testable import Pluri

/// M5-05 — Pluri Score math: consistency window, skip/flexible exclusion,
/// HealthKit denied redistribution, streak/decay additives, and ±3 clamp.
@Suite("ScoreEngine")
struct ScoreEngineTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// Fixed Monday so fixtures are stable across time zones.
    private var asOf: Date {
        // 2025-07-14 00:00 UTC — a Monday.
        Date(timeIntervalSince1970: 1_752_451_200)
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: asOf) ?? asOf
    }

    private func session(
        on offset: Int?,
        status: WorkoutStatus = .scheduled
    ) -> PlannedSession {
        PlannedSession(
            title: "Session",
            indexInWeek: 1,
            weekday: offset == nil ? nil : .monday,
            date: offset.map { day($0) },
            status: status,
            durationMinutes: 45,
            exercises: []
        )
    }

    private func snapshot(
        offset: Int,
        steps: Double? = nil,
        sleep: Double? = nil,
        energy: Double? = nil
    ) -> HealthDaySnapshot {
        HealthDaySnapshot(
            dayStart: day(offset),
            stepCount: steps,
            sleepHours: sleep,
            averageHeartRateBPM: nil,
            activeEnergyKilocalories: energy
        )
    }

    // MARK: - Consistency math

    @Test("Perfect completion over the window yields 100 consistency")
    func perfectConsistency() {
        let sessions = [
            session(on: 0, status: .completed),
            session(on: -2, status: .completed),
            session(on: -7, status: .completed),
            session(on: -14, status: .completed),
        ]
        let consistency = ScoreEngine.consistencyComponent(
            sessions: sessions,
            asOfDay: asOf,
            calendar: calendar
        )
        // 100% base + streak bonus, clamped to 100.
        #expect(consistency == 100)
    }

    @Test("Half completed yields ~50 base consistency")
    func halfCompleted() {
        let sessions = [
            session(on: -1, status: .completed),
            session(on: -3, status: .skipped),
            session(on: -5, status: .completed),
            session(on: -10, status: .scheduled),
        ]
        let consistency = ScoreEngine.consistencyComponent(
            sessions: sessions,
            asOfDay: asOf,
            calendar: calendar
        )
        // 2/4 = 50, minus possible decay for recent misses near asOf.
        #expect(consistency >= 45)
        #expect(consistency <= 55)
    }

    @Test("Skipped counts as not completed; flexible date-nil excluded")
    func skipAndFlexibleExclusion() {
        let sessions = [
            session(on: -1, status: .completed),
            session(on: -2, status: .skipped),
            session(on: nil, status: .completed), // flexible — ignore
            session(on: nil, status: .scheduled),
        ]
        let result = ScoreEngine.compute(
            ScoreEngine.Input(
                sessions: sessions,
                healthAuthorized: false,
                asOf: asOf,
                calendar: calendar
            )
        )
        // Dated only: 1/2 = 50, plus streak/decay around asOf.
        #expect(result.usedHealthComponent == false)
        #expect(result.consistencyComponent >= 45)
        #expect(result.consistencyComponent <= 55)
        #expect(result.score == Int(result.rawUnclamped.rounded()))
    }

    @Test("Sessions outside the trailing 28 days are ignored")
    func outsideWindowIgnored() {
        let sessions = [
            session(on: 0, status: .completed),
            session(on: -40, status: .skipped), // outside window
        ]
        let consistency = ScoreEngine.consistencyComponent(
            sessions: sessions,
            asOfDay: asOf,
            calendar: calendar
        )
        // In-window: 1/1 = 100 (+ streak), clamped.
        #expect(consistency == 100)
    }

    @Test("Empty dated window yields 100 consistency (nothing to miss)")
    func emptyWindowIsKind() {
        let consistency = ScoreEngine.consistencyComponent(
            sessions: [session(on: nil, status: .completed)],
            asOfDay: asOf,
            calendar: calendar
        )
        #expect(consistency == 100)
    }

    // MARK: - Health denied / missing

    @Test("Unauthorized health redistributes to 100% consistency")
    func unauthorizedUsesConsistencyOnly() {
        let sessions = [
            session(on: -1, status: .completed),
            session(on: -3, status: .completed),
        ]
        let result = ScoreEngine.compute(
            ScoreEngine.Input(
                sessions: sessions,
                healthHistory: [
                    snapshot(offset: -1, steps: 1_000),
                ],
                healthAuthorized: false,
                asOf: asOf,
                calendar: calendar
            )
        )
        #expect(result.usedHealthComponent == false)
        #expect(result.healthComponent == nil)
        #expect(result.rawUnclamped == result.consistencyComponent)
    }

    @Test("Authorized but insufficient samples also redistributes")
    func insufficientHealthSamples() {
        let sessions = [session(on: 0, status: .completed)]
        let result = ScoreEngine.compute(
            ScoreEngine.Input(
                sessions: sessions,
                healthHistory: [snapshot(offset: 0, steps: 5_000)],
                healthAuthorized: true,
                asOf: asOf,
                calendar: calendar
            )
        )
        #expect(result.usedHealthComponent == false)
    }

    @Test("Authorized health with baseline + recent blends 70/30")
    func healthBlend() {
        var history: [HealthDaySnapshot] = []
        // Baseline days: offsets -37 ... -8 at 10_000 steps / 7h / 400 kcal
        for offset in -37 ... -8 {
            history.append(
                snapshot(offset: offset, steps: 10_000, sleep: 7, energy: 400)
            )
        }
        // Recent: -6 ... 0 slightly above baseline
        for offset in -6 ... 0 {
            history.append(
                snapshot(offset: offset, steps: 12_000, sleep: 7.5, energy: 480)
            )
        }

        let sessions = (0..<4).map { session(on: -$0 * 2, status: .completed) }
        let result = ScoreEngine.compute(
            ScoreEngine.Input(
                sessions: sessions,
                healthHistory: history,
                healthAuthorized: true,
                asOf: asOf,
                calendar: calendar
            )
        )
        #expect(result.usedHealthComponent == true)
        #expect(result.healthComponent != nil)
        // Combined should sit between components.
        if let health = result.healthComponent {
            let expected =
                ScoreEngine.consistencyWeight * result.consistencyComponent
                + ScoreEngine.healthWeight * health
            #expect(abs(result.rawUnclamped - ScoreEngine.clampScore(expected)) < 0.01)
        }
    }

    // MARK: - Daily clamp

    @Test("Daily clamp limits upward jump to +3")
    func clampUpward() {
        let sessions = (0..<8).map { session(on: -$0, status: .completed) }
        let result = ScoreEngine.compute(
            ScoreEngine.Input(
                sessions: sessions,
                healthAuthorized: false,
                previousScore: 50,
                previousScoreDayStart: day(-1),
                asOf: asOf,
                calendar: calendar
            )
        )
        #expect(result.rawUnclamped > 53)
        #expect(result.score == 53)
    }

    @Test("Daily clamp limits downward jump to -3")
    func clampDownward() {
        let sessions = [
            session(on: 0, status: .skipped),
            session(on: -1, status: .skipped),
            session(on: -2, status: .skipped),
            session(on: -3, status: .skipped),
        ]
        let result = ScoreEngine.compute(
            ScoreEngine.Input(
                sessions: sessions,
                healthAuthorized: false,
                previousScore: 80,
                previousScoreDayStart: day(-1),
                asOf: asOf,
                calendar: calendar
            )
        )
        #expect(result.rawUnclamped < 77)
        #expect(result.score == 77)
    }

    @Test("First score has no previous clamp")
    func firstScoreUnclamped() {
        let sessions = [session(on: 0, status: .completed)]
        let result = ScoreEngine.compute(
            ScoreEngine.Input(
                sessions: sessions,
                healthAuthorized: false,
                asOf: asOf,
                calendar: calendar
            )
        )
        #expect(result.score == Int(result.rawUnclamped.rounded()))
        #expect(result.score == 100)
    }

    // MARK: - Health ratio helper

    @Test("Health ratio at baseline maps to the named constant")
    func healthRatioAtBaseline() {
        #expect(ScoreEngine.scoreFromHealthRatio(1.0) == ScoreEngine.healthScoreAtBaseline)
        #expect(ScoreEngine.scoreFromHealthRatio(1.25) == 100)
        #expect(ScoreEngine.scoreFromHealthRatio(0.75) == 40)
    }

    // MARK: - Store

    @Test("PluriScoreStore persists and loads user-scoped score + day")
    func scoreStoreRoundTrip() {
        let suite = "pluri.tests.score.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let userID = "user-abc"
        PluriScoreStore.save(score: 72, dayStart: asOf, userID: userID, defaults: defaults)
        let loaded = PluriScoreStore.load(userID: userID, defaults: defaults)
        #expect(loaded?.latestScore == 72)
        #expect(loaded?.clampBase == 72)
        #expect(loaded?.dayStart == asOf)
        #expect(PluriScoreStore.load(userID: "other", defaults: defaults) == nil)

        PluriScoreStore.save(
            clampBase: 50,
            latestScore: 53,
            dayStart: asOf,
            userID: userID,
            defaults: defaults
        )
        let split = PluriScoreStore.load(userID: userID, defaults: defaults)
        #expect(split?.clampBase == 50)
        #expect(split?.latestScore == 53)
    }
}
