import Foundation
import Observation

/// Manage Plan editing state (M3-14 / SPEC §6.2): goal, start date, plan
/// length / end date, training days, session duration, and units — kept out
/// of the view so the date/length rules, change detection, validation, and
/// the edited-profile / engine-input builders are unit-testable.
///
/// Date rule (SPEC §14): **start date + plan length (weeks) are primary; the
/// end date is derived** (`start + weeks × 7 − 1`). Editing the end date
/// recomputes the length in whole weeks from the start, clamped to the
/// supported 3–12 range, so the three fields can never disagree.
@MainActor
@Observable
final class ManagePlanViewModel {
    /// SPEC §3.2 Q9 plan-length range.
    static let supportedWeeks = 3...12
    /// SPEC §3.2 Q8 training-day range.
    static let supportedTrainingDays = 2...6

    // MARK: - Editable state

    var goal: Goal?
    private(set) var startDate: Date
    private(set) var planLengthWeeks: Int
    var trainingDays: Set<Weekday>
    var sessionDuration: SessionDuration
    /// Display preference only — canonical storage stays metric (SPEC §3.2 Q11).
    var usesImperialUnits: Bool

    // MARK: - Originals

    /// The profile at edit start; non-editable engine inputs (experience,
    /// equipment, injuries) come from here.
    private let originalProfile: RestoredProfile
    private let originalPlan: GeneratedPlan
    private let calendar: Calendar

    init(profile: RestoredProfile, plan: GeneratedPlan, calendar: Calendar = .current) {
        self.originalProfile = profile
        self.originalPlan = plan
        self.calendar = calendar

        goal = plan.goal
        startDate = calendar.startOfDay(for: plan.startDate)
        // Deliberately unclamped at init: the current plan's length only
        // snaps into the supported 3–12 range once the user edits it, so an
        // untouched form never reports phantom changes.
        planLengthWeeks = plan.weekCount
        trainingDays = profile.trainingDays
        sessionDuration = profile.sessionDuration
        usesImperialUnits = profile.units == "imperial"
    }

    // MARK: - Dates & length

    /// Derived end date: the last day of the final week.
    var endDate: Date {
        calendar.date(byAdding: .day, value: planLengthWeeks * 7 - 1, to: startDate) ?? startDate
    }

    /// The earliest/latest end dates the supported plan lengths allow, for
    /// bounding the end-date picker.
    var endDateRange: ClosedRange<Date> {
        let earliest = calendar.date(
            byAdding: .day,
            value: Self.supportedWeeks.lowerBound * 7 - 1,
            to: startDate
        ) ?? startDate
        let latest = calendar.date(
            byAdding: .day,
            value: Self.supportedWeeks.upperBound * 7 - 1,
            to: startDate
        ) ?? startDate
        return earliest...max(latest, earliest)
    }

    func updateStartDate(_ date: Date) {
        startDate = calendar.startOfDay(for: date)
    }

    func updatePlanLength(weeks: Int) {
        planLengthWeeks = min(
            max(weeks, Self.supportedWeeks.lowerBound),
            Self.supportedWeeks.upperBound
        )
    }

    /// End-date edits recompute the plan length in whole weeks from the
    /// start (rounded to the nearest week, clamped to 3–12); the end date
    /// then re-derives from the clamped length.
    func updateEndDate(_ date: Date) {
        let end = calendar.startOfDay(for: date)
        let days = (calendar.dateComponents([.day], from: startDate, to: end).day ?? 0) + 1
        let weeks = Int((Double(days) / 7).rounded())
        updatePlanLength(weeks: weeks)
    }

    // MARK: - Training days

    func toggleTrainingDay(_ day: Weekday) {
        if trainingDays.contains(day) {
            trainingDays.remove(day)
        } else {
            trainingDays.insert(day)
        }
    }

    // MARK: - Units

    var units: String { usesImperialUnits ? "imperial" : "metric" }

    // MARK: - Change detection

    /// Edits that require regenerating the remaining plan (SPEC §6.2).
    var hasPlanAffectingChanges: Bool {
        goal != originalPlan.goal
            || startDate != calendar.startOfDay(for: originalPlan.startDate)
            || planLengthWeeks != originalPlan.weekCount
            || trainingDays != originalProfile.trainingDays
            || sessionDuration != originalProfile.sessionDuration
    }

    /// Any edit at all — units alone persists without regeneration.
    var hasChanges: Bool {
        hasPlanAffectingChanges || units != originalProfile.units
    }

    // MARK: - Validation

    /// A gentle blocker when a regenerating save can't proceed, else `nil`.
    /// Units-only saves skip this — they don't touch the engine.
    var regenerationValidationMessage: String? {
        if goal == nil {
            return "Pick a goal so we know what to aim for."
        }
        if !Self.supportedTrainingDays.contains(trainingDays.count) {
            return "Choose between 2 and 6 training days."
        }
        if originalProfile.experience == nil {
            return "We couldn't find your training experience on your profile, so we can't rebuild the plan just yet."
        }
        if originalProfile.equipment.isEmpty {
            return "We couldn't find your equipment list on your profile, so we can't rebuild the plan just yet."
        }
        return nil
    }

    // MARK: - Builders

    /// The profile with this editor's changes applied — everything not
    /// editable here passes through unchanged.
    func editedProfile() -> RestoredProfile {
        var profile = originalProfile
        profile.goal = goal ?? profile.goal
        profile.trainingDays = trainingDays
        profile.planLengthWeeks = planLengthWeeks
        profile.sessionDuration = sessionDuration
        profile.startDate = startDate
        profile.units = units
        return profile
    }

    /// The engine input for regeneration: edited settings plus the
    /// non-editable profile fields the engine requires. `nil` when
    /// `regenerationValidationMessage` would block the save.
    func planInput() -> PlanInput? {
        guard let goal,
              let experience = originalProfile.experience,
              !originalProfile.equipment.isEmpty,
              Self.supportedTrainingDays.contains(trainingDays.count)
        else {
            return nil
        }
        return PlanInput(
            goal: goal,
            experience: experience,
            regularity: originalProfile.regularity,
            equipment: originalProfile.equipment,
            injuries: originalProfile.injuries,
            trainingDays: Array(trainingDays),
            scheduleType: originalProfile.scheduleType,
            planLengthWeeks: planLengthWeeks,
            sessionDurationMinutes: sessionDuration.rawValue,
            startDate: startDate
        )
    }
}
