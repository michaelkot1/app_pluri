import SwiftUI

/// Confirm sheet for coach-proposed plan add/remove (M6-09 / SPEC §14 #66c).
/// Plan stays untouched until the user confirms; Cancel dismisses without mutate.
struct AskPluriConfirmChangeSheet: View {
    var summaryLines: [AskPluriPlanActionApplier.SummaryLine]
    /// Runs apply; returns gentle error copy to keep the sheet open, or `nil` on success.
    var onConfirm: () async -> String?
    var onCancel: () -> Void

    @State private var feedback: String?
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                Text("Update your plan?")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                Text("Pluri suggested these changes. Nothing updates until you confirm.")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)

                if let feedback {
                    Text(feedback)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                        .accessibilityLabel(feedback)
                }

                VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                    ForEach(summaryLines) { line in
                        AskPluriConfirmChangeRow(line: line)
                    }
                }

                Button("Confirm changes") {
                    Task { await confirm() }
                }
                .buttonStyle(.pluriPrimary)
                .disabled(isSaving || summaryLines.isEmpty)
                .frame(minHeight: 44)
                .accessibilityHint("Applies the suggested plan changes")

                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.pluriSecondary)
                .disabled(isSaving)
                .frame(minHeight: 44)
                .accessibilityHint("Keeps your plan as it is")
            }
            .padding(PluriSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Confirm plan changes")
    }

    private func confirm() async {
        isSaving = true
        feedback = nil
        let message = await onConfirm()
        isSaving = false
        if let message {
            feedback = message
        }
    }
}

private struct AskPluriConfirmChangeRow: View {
    var line: AskPluriPlanActionApplier.SummaryLine

    var body: some View {
        HStack(alignment: .top, spacing: PluriSpacing.sm) {
            Image(systemName: iconName)
                .foregroundStyle(PluriColor.brandOrange)
                .frame(width: 24, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                Text(line.title)
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textPrimary)
                Text(line.detail)
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(PluriSpacing.md)
        .background(PluriColor.bgMuted, in: .rect(cornerRadius: PluriRadius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.title), \(line.detail)")
    }

    private var iconName: String {
        switch line.kind {
        case .add: "plus.circle.fill"
        case .remove: "minus.circle.fill"
        }
    }
}

#if DEBUG
#Preview("Add") {
    AskPluriConfirmChangeSheet(
        summaryLines: [
            .init(
                id: "1",
                kind: .add,
                title: "Add Pull Day",
                detail: "Jul 28, 2026"
            ),
        ],
        onConfirm: { nil },
        onCancel: {}
    )
}

#Preview("Remove") {
    AskPluriConfirmChangeSheet(
        summaryLines: [
            .init(
                id: "1",
                kind: .remove,
                title: "Remove Push Day",
                detail: "Jul 29, 2026"
            ),
        ],
        onConfirm: { nil },
        onCancel: {}
    )
}

#Preview("Cancel") {
    AskPluriConfirmChangeSheet(
        summaryLines: [
            .init(
                id: "1",
                kind: .add,
                title: "Add Legs",
                detail: "Jul 30, 2026"
            ),
        ],
        onConfirm: { nil },
        onCancel: {}
    )
}

#Preview("Apply error") {
    AskPluriConfirmChangeSheet(
        summaryLines: [
            .init(
                id: "1",
                kind: .add,
                title: "Add Pull Day",
                detail: "Jul 28, 2026"
            ),
        ],
        onConfirm: {
            "That day already has a workout. Pick an empty day, or move the other workout first."
        },
        onCancel: {}
    )
}
#endif
