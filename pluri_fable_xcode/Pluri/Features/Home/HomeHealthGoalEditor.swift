import SwiftUI

/// Explicit editor for one optional Health goal. A baseline-derived suggestion
/// is informational until the user confirms Save.
struct HomeHealthGoalEditor: View {
    var metric: HomeHealthMetricPresentation
    var onSave: (Double) -> Void
    var onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var target: Double?

    init(
        metric: HomeHealthMetricPresentation,
        onSave: @escaping (Double) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.metric = metric
        self.onSave = onSave
        self.onClear = onClear
        _target = State(initialValue: metric.goal)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Daily goal",
                        value: $target,
                        format: .number.precision(.fractionLength(metric.kind == .sleep ? 1 : 0))
                    )
                    .keyboardType(metric.kind == .sleep ? .decimalPad : .numberPad)
                    Text(metric.kind.unitLabel)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                } header: {
                    Text(metric.kind.title)
                }

                if metric.goal == nil, let suggestion = metric.suggestedGoal {
                    Section("Based on your baseline") {
                        Button("Use suggested \(suggestionText(suggestion))") {
                            target = suggestion
                        }
                        Text("This suggestion comes from your own 30-day history. It is not saved until you tap Save.")
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.textSecondary)
                    }
                }

                if metric.goal != nil {
                    Section {
                        Button("Remove goal", role: .destructive) {
                            onClear()
                            dismiss()
                        }
                    } footer: {
                        Text("Without a goal, this card compares today with your own 30-day baseline.")
                    }
                }
            }
            .navigationTitle(metric.goal == nil ? "Set Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let target else { return }
                        onSave(target)
                        dismiss()
                    }
                    .disabled(target.map { !$0.isFinite || $0 <= 0 } ?? true)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func suggestionText(_ value: Double) -> String {
        if metric.kind == .sleep {
            "\(value.formatted(.number.precision(.fractionLength(1)))) \(metric.kind.unitLabel)"
        } else {
            "\(Int(value.rounded()).formatted(.number)) \(metric.kind.unitLabel)"
        }
    }
}
