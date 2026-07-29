import SwiftUI

/// Compact exercise card on the Workout Screen (M4-07 / M4-10 / SPEC §8):
/// media, name, equipment, muscles, sets × reps; when the session is live,
/// a compact inline Log (and optional duration timer) expands without crowding.
struct WorkoutExerciseCardView: View {
    var exercise: PlannedExercise
    /// Resolved mirrored-video URL (`PlannedExercise.videoURL` ?? catalog).
    /// Defaults to the planned exercise's own URL when omitted.
    var videoURL: URL? = nil
    var showsInlineLog: Bool = false
    var usesImperialUnits: Bool = false
    var loggedSetCount: Int = 0
    var action: () -> Void
    var onLogSet: ((Int, Double?) -> Void)?
    var onLogDuration: ((Int) -> Void)?

    @State private var repsText = ""
    @State private var weightText = ""
    @State private var weightErrorMessage: String?
    @State private var cardTimerSeconds = 0
    @State private var isCardTimerRunning = false
    @State private var cardTimerTask: Task<Void, Never>?
    @State private var logPulse = false
    @FocusState private var focusedField: LogField?

    private enum LogField: Hashable {
        case reps
        case weight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Button(action: action) {
                PluriCard {
                    HStack(alignment: .top, spacing: PluriSpacing.md) {
                        CachedExerciseMediaView(videoURL: videoURL ?? exercise.videoURL)
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
        .onChange(of: weightText) { _, newValue in
            let filtered = WorkoutWeightInput.filtered(newValue)
            if filtered != newValue {
                weightText = filtered
            }
            if WorkoutWeightInput.canLog(filtered) {
                weightErrorMessage = nil
            }
        }
        .onDisappear {
            stopCardTimer()
        }
        .sensoryFeedback(.success, trigger: logPulse)
        // Only the focused card contributes a keyboard accessory. Every mounted
        // card registering one made any keyboard (including Ask Pluri's) thrash
        // the main thread while a workout was open (SPEC §14 #76).
        .toolbar {
            if focusedField != nil {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
    }

    private var inlineLogControls: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            HStack(spacing: PluriSpacing.sm) {
                compactNumberField(title: "Reps", text: $repsText, field: .reps)
                compactDecimalField(title: weightUnitLabel, text: $weightText, field: .weight)
                Button("Log") {
                    confirmLog()
                }
                .buttonStyle(.pluriPrimary)
                .frame(maxWidth: 96)
                .disabled(!canConfirmLog)
            }

            if let weightErrorMessage {
                Text(weightErrorMessage)
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.statusRedSoft)
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

    private var canConfirmLog: Bool {
        WorkoutWeightInput.canLog(weightText)
    }

    private func compactNumberField(
        title: String,
        text: Binding<String>,
        field: LogField
    ) -> some View {
        compactField(title: title, text: text, isDecimal: false, field: field)
    }

    private func compactDecimalField(
        title: String,
        text: Binding<String>,
        field: LogField
    ) -> some View {
        compactField(title: title, text: text, isDecimal: true, field: field)
    }

    private func compactField(
        title: String,
        text: Binding<String>,
        isDecimal: Bool,
        field: LogField
    ) -> some View {
        VStack(alignment: .leading, spacing: PluriSpacing.xs) {
            Text(title)
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
            TextField(title, text: text)
                .keyboardType(isDecimal ? .decimalPad : .numberPad)
                .focused($focusedField, equals: field)
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
        switch WorkoutWeightInput.parse(weightText) {
        case .invalid:
            weightErrorMessage = "Enter a valid weight, or leave it blank."
            return
        case .empty:
            weightErrorMessage = nil
            let reps = Int(repsText.trimmingCharacters(in: .whitespacesAndNewlines))
                ?? exercise.reps
            onLogSet?(reps, nil)
            logPulse.toggle()
        case .valid(let weight):
            weightErrorMessage = nil
            let reps = Int(repsText.trimmingCharacters(in: .whitespacesAndNewlines))
                ?? exercise.reps
            onLogSet?(reps, weight)
            logPulse.toggle()
        }
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
