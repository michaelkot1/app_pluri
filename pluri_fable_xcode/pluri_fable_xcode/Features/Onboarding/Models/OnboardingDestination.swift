import Foundation

/// Every pushable screen in the onboarding flow, in flow order. Splash isn't
/// included — it's the `NavigationStack`'s root content, shown whenever the
/// router's path is empty.
enum OnboardingDestination: Int, CaseIterable, Hashable, Sendable {
    case name
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
    static let totalProgressSteps = 14

    /// 1-based position in the full flow (name = 1, Q1 = 2, ... Q13 = 14).
    /// `nil` for the plan-generation screen, which shows no progress bar.
    var stepNumber: Int? {
        self == .planGeneration ? nil : rawValue + 1
    }

    /// SPEC §3.1: the progress bar is hidden on name entry, appears at Q1
    /// already showing name's completed step, and fills forward from there.
    var showsProgressBar: Bool {
        self != .name && self != .planGeneration
    }

    var progress: Double? {
        guard let stepNumber else { return nil }
        return Double(stepNumber) / Double(Self.totalProgressSteps)
    }

    var next: OnboardingDestination? {
        OnboardingDestination(rawValue: rawValue + 1)
    }
}
