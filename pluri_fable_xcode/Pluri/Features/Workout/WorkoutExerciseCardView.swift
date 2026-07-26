import SwiftUI

/// Compact exercise card on the Workout Screen (M4-07 / M4-10 / SPEC §8):
/// media, name, equipment, muscles, sets × reps; when the session is live,
/// a compact inline Log (and optional duration timer) expands without crowding.
struct WorkoutExerciseCardView: View {
    var exercise: PlannedExercise
    var showsInlineLog: Bool = false
    var usesImperialUnits: Bool = false
    var loggedSetCount: Int = 0
    var action: () -> Void
    var onLogSet: ((Int, Double?) -> Void)?
    var onLogDuration: ((Int) -> Void)?

    @State private var repsText = ""
    @State private var weightText = ""
    @State private var cardTimerSeconds = 0
    @State private var isCardTimerRunning = false
    @State private var cardTimerTask: Task<Void, Never>?
    @State private var logPulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Button(action: action) {
                PluriCard {
                    HStack(alignment: .top, spacing: PluriSpacing.md) {
                        CachedExerciseMediaView(remoteURL: exercise.imageURL)
                            .frame(width: 72, height: 72)
                            .clipShape(.rect(cornerRadius: PluriRadius.md))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                            Text(exercise.name)
                                .font(PluriFont.body)
                                .foregroundStyle(PluriColor.textPrimary)
                                .multilineTextAlignment(.leading)

                            Text(exercise.equipment)
                                .font(PluriFont.label)
                                .foregroundStyle(PluriColor.textSecondary)

                            Text(muscleLine)
                                .font(PluriFont.label)
                                .foregroundStyle(PluriColor.textTertiary)
                                .multilineTextAlignment(.leading)

                            Text(exercise.setsRepsSummary)
                                .font(PluriFont.label)
                                .foregroundStyle(PluriColor.textSecondary)
                                .monospacedDigit()

                            if loggedSetCount > 0 {
                                Text("Logged \(loggedSetCount)")
                                    .font(PluriFont.label)
                                    .foregroundStyle(PluriColor.brandOrange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Shows exercise details and notes")

            if showsInlineLog {
                inlineLogControls
            }
        }
        .onAppear {
            if repsText.isEmpty {
                repsText = "\(exercise.reps)"
            }
        }
        .onDisappear {
            stopCardTimer()
        }
        .sensoryFeedback(.success, trigger: logPulse)
    }

    private var inlineLogControls: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            HStack(spacing: PluriSpacing.sm) {
                compactNumberField(title: "Reps", text: $repsText)
                compactDecimalField(title: weightUnitLabel, text: $weightText)
                Button("Log") {
                    confirmLog()
                }
                .buttonStyle(.pluriPrimary)
                .frame(maxWidth: 96)
            }

            HStack(spacing: PluriSpacing.sm) {
                Text(WorkoutScreenViewModel.formatElapsed(cardTimerSeconds))
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)
                    .monospacedDigit()
                    .accessibilityLabel("Exercise timer, \(WorkoutScreenViewModel.formatElapsed(cardTimerSeconds))")

                Button(isCardTimerRunning ? "Stop timer" : "Timer") {
                    toggleCardTimer()
                }
                .buttonStyle(.pluriSecondary)

                if cardTimerSeconds > 0, !isCardTimerRunning {
                    Button("Log time") {
                        onLogDuration?(cardTimerSeconds)
                        logPulse.toggle()
                        cardTimerSeconds = 0
                    }
                    .buttonStyle(.pluriSecondary)
                }
            }
        }
        .padding(.horizontal, PluriSpacing.xs)
    }

    private func compactNumberField(title: String, text: Binding<String>) -> some View {
        compactField(title: title, text: text, isDecimal: false)
    }

    private func compactDecimalField(title: String, text: Binding<String>) -> some View {
        compactField(title: title, text: text, isDecimal: true)
    }

    private func compactField(title: String, text: Binding<String>, isDecimal: Bool) -> some View {
        VStack(alignment: .leading, spacing: PluriSpacing.xs) {
            Text(title)
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
            TextField(title, text: text)
                .keyboardType(isDecimal ? .decimalPad : .numberPad)
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textPrimary)
                .padding(.horizontal, PluriSpacing.sm)
                .padding(.vertical, PluriSpacing.sm)
                .background(PluriColor.bgMuted, in: .rect(cornerRadius: PluriRadius.md))
                .accessibilityLabel(title)
        }
        .frame(maxWidth: .infinity)
    }

    private var weightUnitLabel: String {
        usesImperialUnits ? "lb" : "kg"
    }

    private var muscleLine: String {
        if exercise.secondaryMuscles.isEmpty {
            return exercise.targetMuscle
        }
        let secondary = exercise.secondaryMuscles.joined(separator: ", ")
        return "\(exercise.targetMuscle) · \(secondary)"
    }

    private var accessibilityLabel: String {
        var label = "\(exercise.name), \(exercise.equipment), \(muscleLine), \(exercise.setsRepsSummary)"
        if loggedSetCount > 0 {
            label += ", logged \(loggedSetCount) sets"
        }
        return label
    }

    private func confirmLog() {
        let reps = Int(repsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? exercise.reps
        let trimmedWeight = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        let weight = trimmedWeight.isEmpty ? nil : Double(trimmedWeight)
        onLogSet?(reps, weight)
        logPulse.toggle()
    }

    private func toggleCardTimer() {
        if isCardTimerRunning {
            stopCardTimer()
        } else {
            isCardTimerRunning = true
            cardTimerTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    cardTimerSeconds += 1
                }
            }
        }
    }

    private func stopCardTimer() {
        isCardTimerRunning = false
        cardTimerTask?.cancel()
        cardTimerTask = nil
    }
}

#if DEBUG
#Preview {
    WorkoutExerciseCardView(
        exercise: PlannedExercise(
            exerciseID: "0001",
            name: "Barbell Bench Press",
            bodyPart: "Chest",
            equipment: "Barbell",
            targetMuscle: "Pectorals",
            secondaryMuscles: ["Triceps", "Delts"],
            imageURL: nil,
            order: 0,
            sets: 3,
            reps: 10
        ),
        showsInlineLog: true,
        action: {},
        onLogSet: { _, _ in },
        onLogDuration: { _ in }
    )
    .padding()
    .background(PluriColor.bgCanvas)
}
#endif
