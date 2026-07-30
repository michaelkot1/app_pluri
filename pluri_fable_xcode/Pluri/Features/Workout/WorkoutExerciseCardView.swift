import SwiftUI

/// Live-workout exercise card: cushioned resting state + expandable Log drawer.
///
/// Resting shows media, name, equipment, prescription, Log CTA, and growing
/// logged-set rows. Tapping Log expands an animated drawer (weight slider + reps,
/// or bodyweight stopwatch). After a successful log the drawer collapses.
struct WorkoutExerciseCardView: View {
    var exercise: PlannedExercise
    /// Resolved mirrored-video URL (`PlannedExercise.videoURL` ?? catalog).
    var videoURL: URL? = nil
    var showsInlineLog: Bool = false
    var usesImperialUnits: Bool = false
    var loggedSets: [LoggedSetSummary] = []
    /// Last weight for this exercise in the session (display units), for slider seed.
    var lastLoggedWeightDisplay: Double? = nil
    var action: () -> Void
    var onLogSet: ((Int, Double?) -> Void)?
    var onLogDuration: ((Int) -> Void)?

    @State private var isLoggingExpanded = false
    @State private var weightValue: Double = 0
    @State private var repsValue: Int = 0
    @State private var isEditingWeightText = false
    @State private var weightText = ""
    @State private var weightErrorMessage: String?
    @State private var cardTimerSeconds = 0
    @State private var isCardTimerRunning = false
    @State private var cardTimerTask: Task<Void, Never>?
    @State private var logPulse = false
    @FocusState private var isWeightFieldFocused: Bool

    private var prescription: String {
        WorkoutExercisePrescriptionFormatter.phrase(sets: exercise.sets, reps: exercise.reps)
    }

    private var usesDurationLogging: Bool {
        ExerciseWeightRange.usesDurationLogging(
            equipment: exercise.equipment,
            targetMuscle: exercise.targetMuscle,
            name: exercise.name
        )
    }

    private var weightRange: ExerciseWeightRange {
        let base = ExerciseWeightRange.resolve(
            equipment: exercise.equipment,
            targetMuscle: exercise.targetMuscle,
            name: exercise.name,
            usesImperial: usesImperialUnits
        )
        if let lastLoggedWeightDisplay {
            return base.widening(toContain: lastLoggedWeightDisplay)
        }
        return base
    }

    private var weightUnitLabel: String {
        usesImperialUnits ? "lb" : "kg"
    }

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                headerButton

                if showsInlineLog {
                    loggedSetsSection

                    if isLoggingExpanded {
                        loggingDrawer
                            .transition(
                                .opacity.combined(with: .move(edge: .top))
                            )
                    } else {
                        Button("Log", systemImage: "plus.circle.fill") {
                            openLoggingDrawer()
                        }
                        .buttonStyle(.pluriPrimary)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Log set for \(exercise.name)")
                        .accessibilityHint(
                            usesDurationLogging
                                ? "Opens a timer to log duration"
                                : "Opens weight and reps controls"
                        )
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isLoggingExpanded)
        .animation(.easeInOut(duration: 0.22), value: loggedSets.count)
        .onAppear {
            if repsValue == 0 {
                repsValue = max(1, exercise.reps)
            }
        }
        .onDisappear {
            stopCardTimer()
        }
        .sensoryFeedback(.success, trigger: logPulse)
        .sensoryFeedback(.selection, trigger: weightValue)
        .toolbar {
            if isWeightFieldFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        commitTypedWeight()
                        isWeightFieldFocused = false
                        isEditingWeightText = false
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerButton: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: PluriSpacing.md) {
                CachedExerciseMediaView(videoURL: videoURL ?? exercise.videoURL)
                    .frame(width: 72, height: 72)
                    .clipShape(.rect(cornerRadius: PluriRadius.md))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                    Text(exercise.name)
                        .font(PluriFont.body)
                        .bold()
                        .foregroundStyle(PluriColor.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(exercise.equipment)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)

                    Text(prescription)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textTertiary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Shows exercise details and notes")
    }

    private var accessibilityLabel: String {
        var label = "\(exercise.name), \(exercise.equipment), \(prescription)"
        if !loggedSets.isEmpty {
            label += ", logged \(loggedSets.count) sets"
        }
        return label
    }

    // MARK: - Logged history

    @ViewBuilder
    private var loggedSetsSection: some View {
        if !loggedSets.isEmpty {
            VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                ForEach(loggedSets) { set in
                    Text(set.displayLine(usesImperial: usesImperialUnits))
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.brandOrange)
                        .accessibilityLabel(set.displayLine(usesImperial: usesImperialUnits))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, PluriSpacing.xs)
        }
    }

    // MARK: - Drawer

    @ViewBuilder
    private var loggingDrawer: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.md) {
            if usesDurationLogging {
                durationLoggingControls
            } else {
                weightLoggingControls
            }

            HStack(spacing: PluriSpacing.sm) {
                Button("Cancel") {
                    collapseLoggingDrawer()
                }
                .buttonStyle(.pluriSecondary)
                .frame(minHeight: 44)
                .accessibilityLabel("Cancel logging")

                Button("Log") {
                    confirmLog()
                }
                .buttonStyle(.pluriPrimary)
                .frame(minHeight: 44)
                .disabled(!canConfirmLog)
                .accessibilityLabel("Confirm log set")
            }
        }
        .padding(.top, PluriSpacing.xs)
    }

    private var durationLoggingControls: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text(WorkoutScreenViewModel.formatElapsed(cardTimerSeconds))
                .font(PluriFont.displayNumeral)
                .foregroundStyle(PluriColor.textPrimary)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .accessibilityLabel(
                    "Exercise timer, \(WorkoutScreenViewModel.formatElapsed(cardTimerSeconds))"
                )

            Button(isCardTimerRunning ? "Stop" : "Start timer", systemImage: isCardTimerRunning ? "pause.fill" : "play.fill") {
                toggleCardTimer()
            }
            .buttonStyle(.pluriSecondary)
            .frame(minHeight: 44)
            .accessibilityLabel(isCardTimerRunning ? "Stop timer" : "Start timer")
        }
    }

    private var weightLoggingControls: some View {
        let range = weightRange
        return VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            weightReadout

            if let caption = range.semanticsCaption {
                Text(caption)
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textTertiary)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: PluriSpacing.sm) {
                nudgeButton(systemImage: "minus", label: "Decrease weight") {
                    nudgeWeight(by: -range.step, range: range)
                }

                Slider(
                    value: Binding(
                        get: { weightValue },
                        set: { weightValue = range.snapped($0) }
                    ),
                    in: range.min...max(range.min, range.max),
                    step: range.step
                )
                .tint(PluriColor.brandOrange)
                .accessibilityLabel("Weight")
                .accessibilityValue(weightAccessibilityValue)

                nudgeButton(systemImage: "plus", label: "Increase weight") {
                    nudgeWeight(by: range.step, range: range)
                }
            }

            repsStepper

            if let weightErrorMessage {
                Text(weightErrorMessage)
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.statusRedSoft)
            }
        }
    }

    @ViewBuilder
    private var weightReadout: some View {
        if isEditingWeightText {
            TextField("Weight", text: $weightText)
                .keyboardType(.decimalPad)
                .focused($isWeightFieldFocused)
                .font(PluriFont.displayNumeral)
                .foregroundStyle(PluriColor.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .onChange(of: weightText) { _, newValue in
                    let filtered = WorkoutWeightInput.filtered(newValue)
                    if filtered != newValue {
                        weightText = filtered
                    }
                }
                .accessibilityLabel("Weight in \(weightUnitLabel)")
        } else {
            Button {
                weightText = formatWeightForField(weightValue)
                isEditingWeightText = true
                isWeightFieldFocused = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: PluriSpacing.xs) {
                    Text(weightValue, format: .number.precision(.fractionLength(0...1)))
                        .font(PluriFont.displayNumeral)
                        .foregroundStyle(PluriColor.textPrimary)
                        .monospacedDigit()
                    Text(weightUnitLabel)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Weight \(weightAccessibilityValue). Double tap to type exact value.")
        }
    }

    private var repsStepper: some View {
        HStack(spacing: PluriSpacing.md) {
            Text("Reps")
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)

            Spacer()

            nudgeButton(systemImage: "minus", label: "Decrease reps") {
                repsValue = max(0, repsValue - 1)
            }

            Text(repsValue, format: .number)
                .font(PluriFont.body)
                .bold()
                .foregroundStyle(PluriColor.textPrimary)
                .monospacedDigit()
                .frame(minWidth: 36)
                .accessibilityLabel("\(repsValue) reps")

            nudgeButton(systemImage: "plus", label: "Increase reps") {
                repsValue += 1
            }
        }
    }

    private func nudgeButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textPrimary)
                .frame(width: 44, height: 44)
                .background(PluriColor.bgMuted, in: .rect(cornerRadius: PluriRadius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Actions

    private var canConfirmLog: Bool {
        if usesDurationLogging {
            return cardTimerSeconds > 0 && !isCardTimerRunning
        }
        return weightValue.isFinite && weightValue >= 0 && repsValue >= 0
    }

    private var weightAccessibilityValue: String {
        let formatted = weightValue.formatted(.number.precision(.fractionLength(0...1)))
        return "\(formatted) \(weightUnitLabel)"
    }

    private func openLoggingDrawer() {
        weightErrorMessage = nil
        isEditingWeightText = false
        repsValue = max(1, exercise.reps)
        if !usesDurationLogging {
            let range = weightRange
            weightValue = range.seeded(withLastLoggedDisplay: lastLoggedWeightDisplay)
        }
        withAnimation(.easeInOut(duration: 0.22)) {
            isLoggingExpanded = true
        }
    }

    private func collapseLoggingDrawer() {
        stopCardTimer()
        isEditingWeightText = false
        isWeightFieldFocused = false
        weightErrorMessage = nil
        withAnimation(.easeInOut(duration: 0.22)) {
            isLoggingExpanded = false
        }
    }

    private func confirmLog() {
        if usesDurationLogging {
            guard cardTimerSeconds > 0 else { return }
            onLogDuration?(cardTimerSeconds)
            logPulse.toggle()
            cardTimerSeconds = 0
            collapseLoggingDrawer()
            return
        }

        if isEditingWeightText {
            commitTypedWeight()
        }

        guard weightValue.isFinite, weightValue >= 0 else {
            weightErrorMessage = "Enter a valid weight."
            return
        }
        weightErrorMessage = nil
        onLogSet?(repsValue, weightValue)
        logPulse.toggle()
        collapseLoggingDrawer()
    }

    private func nudgeWeight(by delta: Double, range: ExerciseWeightRange) {
        weightValue = range.snapped(weightValue + delta)
        isEditingWeightText = false
    }

    private func commitTypedWeight() {
        switch WorkoutWeightInput.parse(weightText) {
        case .empty:
            weightValue = weightRange.snapped(0)
            weightErrorMessage = nil
        case .valid(let value):
            let widened = weightRange.widening(toContain: value)
            weightValue = widened.snapped(value)
            // Allow off-step typed values: prefer the parsed value when finite.
            if value.isFinite, value >= 0 {
                weightValue = min(max(value, widened.min), widened.max)
            }
            weightErrorMessage = nil
        case .invalid:
            weightErrorMessage = "Enter a valid weight, or leave it blank."
        }
        isEditingWeightText = false
        isWeightFieldFocused = false
    }

    private func formatWeightForField(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
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
#Preview("Weight log") {
    ScrollView {
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
                sets: 4,
                reps: 5
            ),
            showsInlineLog: true,
            loggedSets: [
                LoggedSetSummary(setNumber: 1, reps: 5, weightKg: 60),
                LoggedSetSummary(setNumber: 2, reps: 5, weightKg: 62.5),
            ],
            lastLoggedWeightDisplay: 62.5,
            action: {},
            onLogSet: { _, _ in },
            onLogDuration: { _ in }
        )
        .padding()
    }
    .background(PluriColor.bgCanvas)
}

#Preview("Bodyweight timer") {
    WorkoutExerciseCardView(
        exercise: PlannedExercise(
            exerciseID: "0002",
            name: "Push-up",
            bodyPart: "Chest",
            equipment: "Body Weight",
            targetMuscle: "Pectorals",
            secondaryMuscles: [],
            imageURL: nil,
            order: 1,
            sets: 3,
            reps: 12
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
