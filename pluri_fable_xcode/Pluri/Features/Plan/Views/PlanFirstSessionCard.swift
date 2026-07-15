import SwiftUI

/// A preview of the plan's first workout (M1-18 teaser): its focus, length,
/// and the first few exercises with their set/rep targets.
struct PlanFirstSessionCard: View {
    var session: PlannedSession

    /// How many exercises to show before a "+N more" summary line.
    private let previewLimit = 4

    private var durationText: String {
        Duration.seconds(session.estimatedMinutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                    Text("First up")
                        .font(PluriFont.overline)
                        .textCase(.uppercase)
                        .kerning(1)
                        .foregroundStyle(PluriColor.textSecondary)
                    Text(session.title)
                        .font(PluriFont.sectionHeader)
                        .foregroundStyle(PluriColor.textPrimary)
                    Text("\(session.exercises.count) exercises · about \(durationText)")
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                }

                VStack(spacing: PluriSpacing.sm) {
                    ForEach(session.exercises.prefix(previewLimit)) { exercise in
                        HStack {
                            Text(exercise.name)
                                .font(PluriFont.body)
                                .foregroundStyle(PluriColor.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: PluriSpacing.md)
                            Text(exercise.setsRepsSummary)
                                .font(PluriFont.label)
                                .foregroundStyle(PluriColor.textSecondary)
                                .monospacedDigit()
                        }
                    }

                    if session.exercises.count > previewLimit {
                        HStack {
                            Text("+ \(session.exercises.count - previewLimit) more")
                                .font(PluriFont.label)
                                .foregroundStyle(PluriColor.textTertiary)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}
