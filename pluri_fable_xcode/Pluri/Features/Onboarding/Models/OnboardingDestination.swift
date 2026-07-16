import Foundation

/// Every pushable screen in the onboarding flow, in flow order. Splash isn't
/// included — it's the `NavigationStack`'s root content, shown whenever the
/// router's path is empty.
///
/// Auth (`.account`) sits between name and Q1 but is **not** a progress step
/// (SPEC §3.1 / §14 #29) — the bar still counts name + Q1–Q13 only.
enum OnboardingDestination: Int, CaseIterable, Hashable, Sendable {
    case name
    case account
    case q1FitnessType
    case q2Goal
    case q3Experience
    case q4Regularity
    case q5Location
    case q6Equipment
    case q7Injuries
    case q8TrainingDays
    case q9Schedule
    case q10Duration
    case q11AboutYou
    case q12CaloriesAllergies
    case q13StartDate
    case planGeneration

    /// Name entry (step 1) through Q13 (step 14) — SPEC §3.1's "14 steps".
    /// Auth is chrome between name and Q1 and is excluded.
    static let totalProgressSteps = 14

    /// 1-based position in the progress flow (name = 1, Q1 = 2, ... Q13 = 14).
    /// `nil` for auth and plan-generation (no progress bar).
    var stepNumber: Int? {
        switch self {
        case .name:
            1
        case .account, .planGeneration:
            nil
        case .q1FitnessType, .q2Goal, .q3Experience, .q4Regularity, .q5Location,
             .q6Equipment, .q7Injuries, .q8TrainingDays, .q9Schedule, .q10Duration,
             .q11AboutYou, .q12CaloriesAllergies, .q13StartDate:
            // rawValue: name=0, account=1, q1=2 … q13=14 → step == rawValue
            rawValue
        }
    }

    /// SPEC §3.1: hidden on name + auth; appears at Q1 already showing name's
    /// completed step; hidden again on plan generation.
    var showsProgressBar: Bool {
        self != .name && self != .account && self != .planGeneration
    }

    var progress: Double? {
        guard let stepNumber else { return nil }
        return Double(stepNumber) / Double(Self.totalProgressSteps)
    }

    var next: OnboardingDestination? {
        OnboardingDestination(rawValue: rawValue + 1)
    }
}
