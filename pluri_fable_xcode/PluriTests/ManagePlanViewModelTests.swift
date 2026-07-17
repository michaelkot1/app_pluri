import Foundation
import Testing
@testable import Pluri

/// M3-14 — Manage Plan editing rules: the start + length → end-date
/// derivation (end-date edits recompute whole weeks, clamped 3–12), change
/// detection, regeneration validation, and the edited-profile / engine-input
/// builders.
@Suite("ManagePlanViewModel")
@MainActor
struct ManagePlanViewModelTests {
    private let calendar = Calendar.current

    /// A Monday at start-of-day, walked forward from a fixed epoch so the
    /// fixture is deterministic in any time zone.
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

    private func makeProfile(
        experience: ExperienceLevel? = .oneToSixMonths,
        equipment: Set<String> = ["Dumbbell"]
    ) -> RestoredProfile {
        RestoredProfile(
            displayName: "Alex",
            goal: .buildMuscle,
            experience: experience,
            regularity: .onAndOff,
            location: .commercialGym,
            injuries: [.back: 3],
            trainingDays: [.monday, .wednesday, .friday],
            scheduleType: .scheduled,
            planLengthWeeks: 6,
            sessionDuration: .oneHour,
            age: 28,
            gender: .male,
            heightCM: 178,
            weightKG: 75,
            allergies: [],
            equipment: equipment,
            startDate: monday,
            maintenanceCalories: 2400,
            units: "metric",
            onboardingCompleted: true
        )
    }

    private func makePlan(weeks: Int = 6) -> GeneratedPlan {
        GeneratedPlan(
            goal: .buildMuscle,
            scheduleType: .scheduled,
            sessionDurationMinutes: 60,
            startDate: monday,
            weeks: (1...weeks).map { PlanWeek(number: $0, sessions: []) },
            seed: 1
        )
    }

    private func makeViewModel(
        profile: RestoredProfile? = nil,
        plan: GeneratedPlan? = nil
    ) -> ManagePlanViewModel {
        ManagePlanViewModel(
            profile: profile ?? makeProfile(),
            plan: plan ?? makePlan(),
            calendar: calendar
        )
    }

    // MARK: - Dates & length

    @Test("End date derives from start date + plan length")
    func endDateDerivation() {
        let viewModel = makeViewModel()

        #expect(viewModel.startDate == monday)
        #expect(viewModel.planLengthWeeks == 6)
        #expect(viewModel.endDate == day(6 * 7 - 1))

        viewModel.updateStartDate(day(7))
        #expect(viewModel.endDate == day(7 + 6 * 7 - 1))

        viewModel.updatePlanLength(weeks: 4)
        #expect(viewModel.planLengthWeeks == 4)
        #expect(viewModel.endDate == day(7 + 4 * 7 - 1))
    }

    @Test("Editing the end date recomputes whole weeks from the start, clamped to 3–12")
    func endDateEditsRecomputeLength() {
        let viewModel = makeViewModel()

        // Exactly 4 weeks.
        viewModel.updateEndDate(day(4 * 7 - 1))
        #expect(viewModel.planLengthWeeks == 4)
        #expect(viewModel.endDate == day(4 * 7 - 1))

        // Partial weeks round to the nearest whole week (31 days ≈ 4 weeks).
        viewModel.updateEndDate(day(30))
        #expect(viewModel.planLengthWeeks == 4)
        #expect(viewModel.endDate == day(4 * 7 - 1))

        // Below the minimum clamps to 3 weeks; the end date re-derives.
        viewModel.updateEndDate(day(3))
        #expect(viewModel.planLengthWeeks == 3)
        #expect(viewModel.endDate == day(3 * 7 - 1))

        // Above the maximum clamps to 12 weeks.
        viewModel.updateEndDate(day(200))
        #expect(viewModel.planLengthWeeks == 12)
        #expect(viewModel.endDate == day(12 * 7 - 1))
    }

    @Test("Plan length edits clamp to the supported 3–12 range")
    func planLengthClamping() {
        let viewModel = makeViewModel()

        viewModel.updatePlanLength(weeks: 1)
        #expect(viewModel.planLengthWeeks == 3)

        viewModel.updatePlanLength(weeks: 40)
        #expect(viewModel.planLengthWeeks == 12)
    }

    // MARK: - Change detection

    @Test("An untouched form reports no changes")
    func noPhantomChanges() {
        let viewModel = makeViewModel()

        #expect(!viewModel.hasChanges)
        #expect(!viewModel.hasPlanAffectingChanges)
    }

    @Test("A units-only edit is a change that doesn't require regeneration")
    func unitsOnlyChange() {
        let viewModel = makeViewModel()

        viewModel.usesImperialUnits = true

        #expect(viewModel.hasChanges)
        #expect(!viewModel.hasPlanAffectingChanges)
        #expect(viewModel.units == "imperial")
        #expect(viewModel.editedProfile().units == "imperial")
    }

    @Test("Goal, dates, days, and duration edits require regeneration")
    func planAffectingChanges() {
        let goalEdit = makeViewModel()
        goalEdit.goal = .getStronger
        #expect(goalEdit.hasPlanAffectingChanges)

        let startEdit = makeViewModel()
        startEdit.updateStartDate(day(7))
        #expect(startEdit.hasPlanAffectingChanges)

        let lengthEdit = makeViewModel()
        lengthEdit.updatePlanLength(weeks: 8)
        #expect(lengthEdit.hasPlanAffectingChanges)

        let daysEdit = makeViewModel()
        daysEdit.toggleTrainingDay(.tuesday)
        #expect(daysEdit.hasPlanAffectingChanges)

        let durationEdit = makeViewModel()
        durationEdit.sessionDuration = .thirtyMinutes
        #expect(durationEdit.hasPlanAffectingChanges)
    }

    // MARK: - Validation

    @Test("Regeneration validation catches missing goal, bad day counts, and missing engine inputs")
    func regenerationValidation() {
        let valid = makeViewModel()
        #expect(valid.regenerationValidationMessage == nil)
        #expect(valid.planInput() != nil)

        let noGoal = makeViewModel()
        noGoal.goal = nil
        #expect(noGoal.regenerationValidationMessage != nil)
        #expect(noGoal.planInput() == nil)

        let tooFewDays = makeViewModel()
        tooFewDays.trainingDays = [.monday]
        #expect(tooFewDays.regenerationValidationMessage != nil)
        #expect(tooFewDays.planInput() == nil)

        let noExperience = makeViewModel(profile: makeProfile(experience: nil))
        #expect(noExperience.regenerationValidationMessage != nil)
        #expect(noExperience.planInput() == nil)

        let noEquipment = makeViewModel(profile: makeProfile(equipment: []))
        #expect(noEquipment.regenerationValidationMessage != nil)
        #expect(noEquipment.planInput() == nil)
    }

    // MARK: - Builders

    @Test("The edited profile carries the edits and passes everything else through")
    func editedProfileBuilder() {
        let viewModel = makeViewModel()
        viewModel.goal = .getStronger
        viewModel.updateStartDate(day(7))
        viewModel.updatePlanLength(weeks: 4)
        viewModel.toggleTrainingDay(.tuesday)
        viewModel.sessionDuration = .fortyFiveMinutes
        viewModel.usesImperialUnits = true

        let edited = viewModel.editedProfile()
        #expect(edited.goal == .getStronger)
        #expect(edited.startDate == day(7))
        #expect(edited.planLengthWeeks == 4)
        #expect(edited.trainingDays == [.monday, .tuesday, .wednesday, .friday])
        #expect(edited.sessionDuration == .fortyFiveMinutes)
        #expect(edited.units == "imperial")

        // Untouched fields pass through.
        #expect(edited.experience == .oneToSixMonths)
        #expect(edited.equipment == ["Dumbbell"])
        #expect(edited.injuries == [.back: 3])
        #expect(edited.displayName == "Alex")
    }

    @Test("The engine input combines the edits with the profile's non-editable answers")
    func planInputBuilder() throws {
        let viewModel = makeViewModel()
        viewModel.goal = .getStronger
        viewModel.updatePlanLength(weeks: 4)
        viewModel.sessionDuration = .thirtyMinutes

        let input = try #require(viewModel.planInput())
        #expect(input.goal == .getStronger)
        #expect(input.experience == .oneToSixMonths)
        #expect(input.equipment == ["Dumbbell"])
        #expect(input.injuries == [.back: 3])
        #expect(input.trainingDays == [.monday, .wednesday, .friday])
        #expect(input.scheduleType == .scheduled)
        #expect(input.planLengthWeeks == 4)
        #expect(input.sessionDurationMinutes == 30)
        #expect(input.startDate == monday)
    }
}
