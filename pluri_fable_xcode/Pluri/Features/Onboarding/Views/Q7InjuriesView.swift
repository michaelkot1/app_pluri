import SwiftUI

/// Q7 (M1-11) — injuries: multi-select body areas, each with a 1–5 pain
/// slider. Selecting an area adds it with a default mid pain level;
/// deselecting removes it. No injuries selected is a valid, common answer.
struct Q7InjuriesView: View {
    @Bindable var answers: OnboardingAnswers
    var progress: Double?
    var onContinue: () -> Void

    private static let defaultPainLevel = 3

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            title: "Any injuries?",
            subtitle: "Select any areas that give you trouble, and how much they bother you. We'll steer your plan around them.",
            onContinue: onContinue
        ) {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                PluriChipGrid(
                    items: BodyArea.allCases,
                    isSelected: { answers.injuries[$0] != nil },
                    label: \.title,
                    action: toggle
                )

                if !answers.injuries.isEmpty {
                    VStack(spacing: PluriSpacing.sm) {
                        ForEach(BodyArea.allCases.filter { answers.injuries[$0] != nil }) { area in
                            InjuryPainRow(area: area, painLevel: painBinding(for: area))
                        }
                    }
                }
            }
        }
    }

    private func toggle(_ area: BodyArea) {
        if answers.injuries[area] != nil {
            answers.injuries.removeValue(forKey: area)
        } else {
            answers.injuries[area] = Self.defaultPainLevel
        }
    }

    private func painBinding(for area: BodyArea) -> Binding<Int> {
        Binding(
            get: { answers.injuries[area] ?? Self.defaultPainLevel },
            set: { answers.injuries[area] = $0 }
        )
    }
}

#Preview {
    NavigationStack {
        Q7InjuriesView(answers: OnboardingAnswers(), progress: 8.0 / 14, onContinue: {})
    }
}
