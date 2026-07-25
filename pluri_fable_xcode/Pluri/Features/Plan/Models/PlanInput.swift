import Foundation

/// A plain, `Sendable` snapshot of the onboarding answers the `PlanEngine`
/// needs (M1-16). `OnboardingAnswers` is `@MainActor`/`@Observable`, so the
/// engine — which runs off the main actor and must be deterministic — takes
/// this value copy instead of the live container.
nonisolated struct PlanInput: Hashable, Sendable {
    let goal: Goal
    let experience: ExperienceLevel
    let regularity: RegularityLevel?

    /// User-selected equipment (Q6), in the SPEC punctuation. Matched against
    /// catalog `equipment` via `EquipmentMatcher` normalization (SPEC §14).
    let equipment: Set<String>

    /// Injured body areas → pain level (Q7). Graded by pain via
    /// `BodyAreaMuscleMapping` (SPEC §14 #47) — not coarse body-part drops.
    let injuries: [BodyArea: Int]

    /// Chosen training weekdays (Q8), sorted for deterministic scheduling.
    let trainingDays: [Weekday]

    let scheduleType: ScheduleType
    let planLengthWeeks: Int
    let sessionDurationMinutes: Int
    let startDate: Date

    /// Sessions to build per week — the number of chosen training days,
    /// clamped to the SPEC §3.2 Q8 range (2–6).
    var sessionsPerWeek: Int {
        min(max(trainingDays.count, 2), 6)
    }

    /// A stable seed derived from the answers (SPEC §14): the same answers
    /// always regenerate the same plan, so re-running generation doesn't
    /// surprise the user with a different plan. `Hasher` is deliberately
    /// avoided — it's randomized per process, so it wouldn't be stable across
    /// launches. This is a plain FNV-1a over a canonical description.
    var deterministicSeed: UInt64 {
        let startDay = Int(startDate.timeIntervalSince1970 / 86_400)
        // Pain levels are part of the seed so graded injury rules (#47) stay
        // deterministic across regenerations with the same answers (#49).
        let injuryCanonical = injuries
            .map { "\($0.key.rawValue):\($0.value)" }
            .sorted()
            .joined(separator: ",")
        let canonical = [
            goal.rawValue,
            experience.rawValue,
            equipment.sorted().joined(separator: ","),
            injuryCanonical,
            trainingDays.map { String($0.rawValue) }.joined(separator: ","),
            scheduleType.rawValue,
            String(planLengthWeeks),
            String(sessionDurationMinutes),
            String(startDay),
        ].joined(separator: "|")

        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in canonical.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    init(
        goal: Goal,
        experience: ExperienceLevel,
        regularity: RegularityLevel?,
        equipment: Set<String>,
        injuries: [BodyArea: Int],
        trainingDays: [Weekday],
        scheduleType: ScheduleType,
        planLengthWeeks: Int,
        sessionDurationMinutes: Int,
        startDate: Date
    ) {
        self.goal = goal
        self.experience = experience
        self.regularity = regularity
        self.equipment = equipment
        self.injuries = injuries
        self.trainingDays = trainingDays.sorted { $0.rawValue < $1.rawValue }
        self.scheduleType = scheduleType
        self.planLengthWeeks = planLengthWeeks
        self.sessionDurationMinutes = sessionDurationMinutes
        self.startDate = startDate
    }
}

@MainActor
extension PlanInput {
    /// Builds an engine input snapshot from the live onboarding container,
    /// filling sensible defaults for anything Q2/Q3 left unset (both are
    /// single-select screens with a Continue gate, so in practice they're
    /// always answered by the time plan generation runs).
    init(answers: OnboardingAnswers) {
        self.init(
            goal: answers.goal ?? .generalFitness,
            experience: answers.experience ?? .notYet,
            regularity: answers.regularity,
            equipment: answers.equipment,
            injuries: answers.injuries,
            trainingDays: Array(answers.trainingDays),
            scheduleType: answers.scheduleType,
            planLengthWeeks: answers.planLengthWeeks,
            sessionDurationMinutes: answers.sessionDuration.rawValue,
            startDate: answers.resolvedStartDate
        )
    }
}
