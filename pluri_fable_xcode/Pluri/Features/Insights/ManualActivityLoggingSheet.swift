import SwiftUI

/// Manual "+" activity wizard (M5-12 / SPEC §9.3): Workout / Cardio /
/// Flexibility → date → start time → duration (+ distance for Cardio).
/// Duration-only for Workout type (no set-entry step). Does not mark plan
/// workouts completed.
struct ManualActivityLoggingSheet: View {
    var usesImperialUnits: Bool
    var onSave: (ManualActivityDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .activityType
    @State private var activityType: ManualActivityType = .workout
    @State private var performedDay: Date = .now
    @State private var startTime: Date = .now
    @State private var durationHoursText = "0"
    @State private var durationMinutesText = "30"
    @State private var distanceText = ""
    @State private var notesText = ""
    @State private var validationMessage: String?

    enum Step: Int, CaseIterable {
        case activityType
        case date
        case startTime
        case duration
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PluriSpacing.md) {
                    Text(stepTitle)
                        .font(PluriFont.sectionHeader)
                        .foregroundStyle(PluriColor.textPrimary)

                    Text(stepSubtitle)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)

                    stepContent

                    if let validationMessage {
                        Text(validationMessage)
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.textSecondary)
                    }

                    Button(primaryButtonTitle) {
                        advanceOrSave()
                    }
                    .buttonStyle(.pluriPrimary)
                    .frame(minHeight: 44)

                    if step != .activityType {
                        Button("Back") {
                            goBack()
                        }
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.brandOrange)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(PluriSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .background(PluriColor.bgSurface)
            .navigationTitle("Log activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(PluriRadius.xl)
        .presentationBackground(PluriColor.bgSurface)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .activityType:
            VStack(spacing: PluriSpacing.sm) {
                ForEach(ManualActivityType.allCases) { type in
                    Button {
                        activityType = type
                    } label: {
                        HStack {
                            Text(type.title)
                                .font(PluriFont.label)
                                .foregroundStyle(PluriColor.textPrimary)
                            Spacer(minLength: 0)
                            if activityType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(PluriColor.brandOrange)
                            }
                        }
                        .padding(PluriSpacing.md)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            PluriColor.bgMuted,
                            in: .rect(cornerRadius: PluriRadius.md)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(activityType == type ? .isSelected : [])
                }
            }
        case .date:
            DatePicker(
                "Date performed",
                selection: $performedDay,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(PluriColor.brandOrange)
        case .startTime:
            DatePicker(
                "Start time",
                selection: $startTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Start time")
        case .duration:
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                HStack(spacing: PluriSpacing.md) {
                    durationField(title: "Hours", text: $durationHoursText)
                    durationField(title: "Minutes", text: $durationMinutesText)
                }
                if activityType == .cardio {
                    VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                        Text(distanceFieldTitle)
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.textSecondary)
                        TextField(distanceFieldTitle, text: $distanceText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(minHeight: 44)
                    }
                }
                VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                    Text("Notes (optional)")
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                    TextField("Notes", text: $notesText, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private func durationField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: PluriSpacing.xs) {
            Text(title)
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
            TextField(title, text: text)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
    }

    private var stepTitle: String {
        switch step {
        case .activityType: "What did you do?"
        case .date: "When?"
        case .startTime: "What time did you start?"
        case .duration: activityType == .cardio ? "How long & how far?" : "How long?"
        }
    }

    private var stepSubtitle: String {
        switch step {
        case .activityType:
            "Choose Workout, Cardio, or Flexibility. This logs an activity — it doesn’t complete a plan workout."
        case .date:
            "Date performed uses the calendar day you actually did it."
        case .startTime:
            "We’ll combine this with the date for your session start."
        case .duration:
            activityType == .cardio
                ? "Duration is required. Distance is optional and stored in meters."
                : "Enter how long you worked out. Set logging isn’t part of this flow."
        }
    }

    private var primaryButtonTitle: String {
        step == .duration ? "Save activity" : "Continue"
    }

    private var distanceFieldTitle: String {
        usesImperialUnits ? "Distance (mi)" : "Distance (km)"
    }

    private func advanceOrSave() {
        validationMessage = nil
        if step != .duration {
            if let next = Step(rawValue: step.rawValue + 1) {
                step = next
            }
            return
        }
        guard let draft = makeDraft() else { return }
        onSave(draft)
        dismiss()
    }

    private func goBack() {
        validationMessage = nil
        if let previous = Step(rawValue: step.rawValue - 1) {
            step = previous
        }
    }

    private func makeDraft() -> ManualActivityDraft? {
        let hours = Int(durationHoursText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let minutes = Int(durationMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let totalSeconds = max(0, hours * 3_600 + minutes * 60)
        guard totalSeconds > 0 else {
            validationMessage = "Enter a duration greater than zero."
            return nil
        }

        var distanceMeters: Double?
        if activityType == .cardio {
            let trimmed = distanceText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                guard let value = Double(trimmed), value >= 0 else {
                    validationMessage = "Enter a valid distance, or leave it blank."
                    return nil
                }
                let unit: UnitLength = usesImperialUnits ? .miles : .kilometers
                distanceMeters = Measurement(value: value, unit: unit)
                    .converted(to: .meters)
                    .value
            }
        }

        let calendar = Calendar.current
        let day = calendar.startOfDay(for: performedDay)
        let time = calendar.dateComponents([.hour, .minute], from: startTime)
        guard let startedAt = calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: 0,
            of: day
        ) else {
            validationMessage = "Couldn't combine that date and time."
            return nil
        }

        let notes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        return ManualActivityDraft(
            activityType: activityType,
            startedAt: startedAt,
            durationSeconds: totalSeconds,
            distanceMeters: distanceMeters,
            notes: notes.isEmpty ? nil : notes
        )
    }
}

// MARK: - Models

enum ManualActivityType: String, CaseIterable, Identifiable, Sendable {
    case workout
    case cardio
    case flexibility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workout: "Workout"
        case .cardio: "Cardio"
        case .flexibility: "Flexibility"
        }
    }

    var storageValue: String { rawValue }
}

struct ManualActivityDraft: Sendable, Equatable {
    var activityType: ManualActivityType
    var startedAt: Date
    var durationSeconds: Int
    var distanceMeters: Double?
    var notes: String?
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ManualActivityLoggingSheet(usesImperialUnits: false) { _ in }
        }
}
