import SwiftUI

/// Q5 (M1-10) — workout location, single-select. Selecting a location
/// auto-selects that location's default equipment subset for Q6
/// (`EquipmentCatalog.defaultSelection`); the user can still edit freely
/// on the next screen. Defaults to `.commercialGym`.
struct Q5LocationView: View {
    @Bindable var answers: OnboardingAnswers
    var progress: Double?
    var onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            title: "Where do you work out?",
            onContinue: onContinue
        ) {
            OnboardingSelectRowList(
                items: WorkoutLocation.allCases,
                isSelected: { answers.location == $0 },
                label: \.title,
                action: { location in
                    answers.location = location
                    answers.equipment = EquipmentCatalog.defaultSelection(for: location)
                }
            )
        }
    }
}

#Preview {
    NavigationStack {
        Q5LocationView(answers: OnboardingAnswers(), progress: 6.0 / 14, onContinue: {})
    }
}
