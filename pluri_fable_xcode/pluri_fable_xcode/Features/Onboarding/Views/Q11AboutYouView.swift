import SwiftUI

/// Q11 (M1-13) — age, gender, height, weight. Units follow the user's
/// locale (imperial for `.us`, metric otherwise) but are always stored
/// canonically in metric on `OnboardingAnswers` via `Measurement` conversion.
struct Q11AboutYouView: View {
    @Bindable var answers: OnboardingAnswers
    var progress: Double?
    var onContinue: () -> Void

    private static let defaultAge = 25
    private static let defaultHeightCM = 170.0
    private static let defaultWeightKG = 70.0

    private var usesImperialUnits: Bool {
        Locale.current.measurementSystem == .us
    }

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            title: "About you",
            subtitle: "This helps us tailor your plan and maintenance calories.",
            isContinueEnabled: answers.gender != nil,
            onContinue: onContinue
        ) {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                OnboardingNumberField(title: "Age", unit: "years", value: ageBinding)

                VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                    Text("Gender")
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                    PluriChipGrid(
                        items: Gender.allCases,
                        isSelected: { answers.gender == $0 },
                        label: \.title,
                        action: { answers.gender = $0 }
                    )
                }

                if usesImperialUnits {
                    HStack(spacing: PluriSpacing.md) {
                        heightFeetPicker
                        heightInchesPicker
                    }
                    OnboardingNumberField(title: "Weight", unit: "lb", value: weightLBBinding)
                } else {
                    OnboardingNumberField(title: "Height", unit: "cm", value: heightCMBinding)
                    OnboardingNumberField(title: "Weight", unit: "kg", value: weightKGBinding)
                }
            }
        }
        .onAppear(perform: seedDefaultsIfNeeded)
    }

    private var heightFeetPicker: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.xs) {
            Text("Height (ft)")
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
            Picker("Feet", selection: heightFeetBinding) {
                ForEach(3...7, id: \.self) { feet in
                    Text("\(feet) ft").tag(feet)
                }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PluriSpacing.md)
            .background(PluriColor.bgSurface, in: .rect(cornerRadius: PluriRadius.md))
        }
    }

    private var heightInchesPicker: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.xs) {
            Text("Height (in)")
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
            Picker("Inches", selection: heightInchesBinding) {
                ForEach(0...11, id: \.self) { inches in
                    Text("\(inches) in").tag(inches)
                }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PluriSpacing.md)
            .background(PluriColor.bgSurface, in: .rect(cornerRadius: PluriRadius.md))
        }
    }

    private func seedDefaultsIfNeeded() {
        if answers.age == nil { answers.age = Self.defaultAge }
        if answers.heightCM == nil { answers.heightCM = Self.defaultHeightCM }
        if answers.weightKG == nil { answers.weightKG = Self.defaultWeightKG }
    }

    private var ageBinding: Binding<Double> {
        Binding(
            get: { Double(answers.age ?? Self.defaultAge) },
            set: { answers.age = Int($0.rounded()) }
        )
    }

    private var heightCMBinding: Binding<Double> {
        Binding(
            get: { answers.heightCM ?? Self.defaultHeightCM },
            set: { answers.heightCM = $0 }
        )
    }

    private var weightKGBinding: Binding<Double> {
        Binding(
            get: { answers.weightKG ?? Self.defaultWeightKG },
            set: { answers.weightKG = $0 }
        )
    }

    private var weightLBBinding: Binding<Double> {
        Binding(
            get: {
                let kg = answers.weightKG ?? Self.defaultWeightKG
                return Measurement(value: kg, unit: UnitMass.kilograms).converted(to: .pounds).value
            },
            set: { newLB in
                answers.weightKG = Measurement(value: newLB, unit: UnitMass.pounds).converted(to: .kilograms).value
            }
        )
    }

    private var totalHeightInches: Double {
        let cm = answers.heightCM ?? Self.defaultHeightCM
        return Measurement(value: cm, unit: UnitLength.centimeters).converted(to: .inches).value
    }

    private var heightFeetBinding: Binding<Int> {
        Binding(
            get: { Int(totalHeightInches / 12) },
            set: { newFeet in setHeightFromImperial(feet: newFeet, inches: Int(totalHeightInches.rounded()) % 12) }
        )
    }

    private var heightInchesBinding: Binding<Int> {
        Binding(
            get: { Int(totalHeightInches.rounded()) % 12 },
            set: { newInches in setHeightFromImperial(feet: Int(totalHeightInches / 12), inches: newInches) }
        )
    }

    private func setHeightFromImperial(feet: Int, inches: Int) {
        let totalInches = Double(feet * 12 + inches)
        answers.heightCM = Measurement(value: totalInches, unit: UnitLength.inches).converted(to: .centimeters).value
    }
}

#Preview {
    NavigationStack {
        Q11AboutYouView(answers: OnboardingAnswers(), progress: 12.0 / 14, onContinue: {})
    }
}
