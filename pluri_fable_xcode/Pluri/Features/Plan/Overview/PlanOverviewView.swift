import SwiftUI

/// Plan Overview info page (M3-12 / SPEC §6.1): explains what each workout
/// color means, how to read the Pluri Score, and how Ask Pluri will help —
/// soft, educational tone, honest about what isn't live yet.
struct PlanOverviewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                WorkoutColorsCard()
                PluriScoreExplainerCard()
                AskPluriExplainerCard()
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .background(PluriColor.bgCanvas)
        .navigationTitle("Plan Overview")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// What the color bar next to each workout means (SPEC §14 #41 defaults).
private struct WorkoutColorsCard: View {
    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text("Workout colors")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                Text("Every workout carries a small color bar so you can tell workout types apart at a glance.")
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)

                ForEach(WorkoutType.allCases, id: \.self) { type in
                    WorkoutColorLegendRow(type: type)
                }

                Text("Your current plan is all Weights — Cardio and Flexibility plans arrive in a later update.")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// One legend line: color swatch + workout type name.
private struct WorkoutColorLegendRow: View {
    var type: WorkoutType

    var body: some View {
        HStack(spacing: PluriSpacing.sm) {
            RoundedRectangle(cornerRadius: PluriRadius.sm)
                .fill(WorkoutColorResolver.defaultToken(for: type).color)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)

            Text(type.title)
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// How to read the Pluri Score (SPEC §5.1) — no invented formula, and
/// honest that the Home card shows a sample value for now.
private struct PluriScoreExplainerCard: View {
    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text("Your Pluri Score")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                Text("A score out of 100 that reflects how you're doing overall. Consistency is what matters most — showing up for your scheduled workouts and building streaks. Health signals from Apple Health, like steps and sleep, will add a gentle second layer once Insights arrive.")
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)

                Text("The score moves slowly and kindly: it rewards showing up and dips gently rather than punishing a missed day.")
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)

                Text("The score on your Home page is a sample for now — your real Pluri Score arrives with Insights.")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Ask Pluri's future role (SPEC §10) — described honestly as upcoming.
private struct AskPluriExplainerCard: View {
    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text("Talking to Pluri")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                Text("Ask Pluri is your in-app coach: a kind, informative chat that knows your plan and your past workouts. You'll be able to ask about exercises and training, and even ask Pluri to adjust your plan — like adding or removing a workout.")
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)

                Text("Ask Pluri arrives in a later update, right where you work out.")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        PlanOverviewView()
    }
}
