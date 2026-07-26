import Foundation
import Testing
@testable import Pluri

/// M5-10 — Health averages, baseline trends, and kind guidance.
@Suite("HealthInsightsEngine")
struct HealthInsightsEngineTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// Fixed "today" — 2025-07-26 12:00 UTC.
    private var asOf: Date {
        Date(timeIntervalSince1970: 1_753_531_200)
    }

    private var asOfDay: Date {
        calendar.startOfDay(for: asOf)
    }

    private func day(_ offsetFromAsOf: Int) -> Date {
        calendar.date(byAdding: .day, value: offsetFromAsOf, to: asOfDay) ?? asOfDay
    }

    private func snapshot(
        offset: Int,
        steps: Double? = nil,
        sleep: Double? = nil,
        hr: Double? = nil,
        calories: Double? = nil
    ) -> HealthDaySnapshot {
        HealthDaySnapshot(
            dayStart: day(offset),
            stepCount: steps,
            sleepHours: sleep,
            averageHeartRateBPM: hr,
            activeEnergyKilocalories: calories
        )
    }

    /// Baseline days (−37…−8) + recent (−6…0) with controllable recent steps.
    private func history(
        baselineSteps: Double = 8_000,
        recentSteps: Double = 8_000,
        includeHR: Bool = true
    ) -> [HealthDaySnapshot] {
        var days: [HealthDaySnapshot] = []
        for offset in -37 ... -8 {
            days.append(
                snapshot(
                    offset: offset,
                    steps: baselineSteps,
                    sleep: 7.0,
                    hr: includeHR ? 70 : nil,
                    calories: 400
                )
            )
        }
        for offset in -6 ... 0 {
            days.append(
                snapshot(
                    offset: offset,
                    steps: recentSteps,
                    sleep: 7.0,
                    hr: includeHR ? 70 : nil,
                    calories: 400
                )
            )
        }
        return days
    }

    @Test("Empty history yields insufficient data and no guidance")
    func emptyHistory() {
        let insight = HealthInsightsEngine.insight(
            for: .steps,
            history: [],
            asOf: asOf,
            calendar: calendar
        )
        #expect(insight.trend == .insufficientData)
        #expect(insight.guidance == nil)
        #expect(insight.recentAverage == nil)
        #expect(insight.baselineAverage == nil)
    }

    @Test("Insufficient baseline samples stay insufficient")
    func insufficientBaseline() {
        let history = [
            snapshot(offset: -1, steps: 9_000),
            snapshot(offset: 0, steps: 9_000),
        ]
        let insight = HealthInsightsEngine.insight(
            for: .steps,
            history: history,
            asOf: asOf,
            calendar: calendar
        )
        #expect(insight.trend == .insufficientData)
        #expect(insight.recentAverage == 9_000)
        #expect(insight.guidance == nil)
    }

    @Test("Above-baseline steps trend up with kind guidance")
    func stepsTrendUp() {
        let insight = HealthInsightsEngine.insight(
            for: .steps,
            history: history(baselineSteps: 8_000, recentSteps: 10_000),
            asOf: asOf,
            calendar: calendar
        )
        #expect(insight.trend == .up)
        #expect(insight.recentAverage == 10_000)
        #expect(insight.baselineAverage == 8_000)
        #expect(insight.guidance == "You’re ahead of your usual pace.")
    }

    @Test("Below-baseline steps trend down without scolding")
    func stepsTrendDown() {
        let insight = HealthInsightsEngine.insight(
            for: .steps,
            history: history(baselineSteps: 8_000, recentSteps: 6_000),
            asOf: asOf,
            calendar: calendar
        )
        #expect(insight.trend == .down)
        #expect(insight.guidance == "Gentler week — that still counts.")
    }

    @Test("Near-baseline steps trend flat")
    func stepsTrendFlat() {
        let insight = HealthInsightsEngine.insight(
            for: .steps,
            history: history(baselineSteps: 8_000, recentSteps: 8_100),
            asOf: asOf,
            calendar: calendar
        )
        #expect(insight.trend == .flat)
        #expect(insight.guidance == "Right around your usual pace.")
    }

    @Test("insights() includes HR and calories metrics")
    func includesHRAndCalories() {
        let all = HealthInsightsEngine.insights(
            history: history(),
            asOf: asOf,
            calendar: calendar
        )
        let metrics = all.map(\.metric)
        #expect(metrics == [.steps, .sleep, .calories, .activeHeartRate])
        #expect(all.first(where: { $0.metric == .activeHeartRate })?.trend == .flat)
        #expect(all.first(where: { $0.metric == .calories })?.trend == .flat)
    }

    @Test("Guidance copy matches trend cases")
    func guidanceCopy() {
        #expect(
            HealthInsightsEngine.guidance(for: .up)
                == "You’re ahead of your usual pace."
        )
        #expect(
            HealthInsightsEngine.guidance(for: .down)
                == "Gentler week — that still counts."
        )
        #expect(
            HealthInsightsEngine.guidance(for: .flat)
                == "Right around your usual pace."
        )
        #expect(HealthInsightsEngine.guidance(for: .insufficientData) == nil)
    }
}
