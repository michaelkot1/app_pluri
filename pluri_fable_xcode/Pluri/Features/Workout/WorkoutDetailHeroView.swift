import SwiftUI

/// Runna-inspired workout identity header with a focus-aware color wash.
struct WorkoutDetailHeroView: View {
    let session: PlannedSession

    private var workoutColor: Color {
        WorkoutColorResolver.token(for: session).color
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Wash paints edge-to-edge from the physical top (under status + nav).
            LinearGradient(
                colors: [
                    workoutColor.opacity(0.55),
                    workoutColor.opacity(0.28),
                    workoutColor.opacity(0.10),
                    PluriColor.bgCanvas,
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [workoutColor.opacity(0.62), workoutColor.opacity(0)],
                center: .topLeading,
                startRadius: 0,
                endRadius: 360
            )

            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text(dateLabel)
                    .font(PluriFont.overline)
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .foregroundStyle(PluriColor.textSecondary)

                Text(session.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(PluriColor.textPrimary)

                Text(metaLabel)
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)

                Label(durationLabel, systemImage: "clock")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)
                    .padding(.top, PluriSpacing.sm)
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.top, PluriSpacing.sm)
            .padding(.bottom, PluriSpacing.xl)
            // Keep copy below status/nav chrome while the wash fills behind it.
            .safeAreaPadding(.top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(minHeight: 320)
        .accessibilityElement(children: .combine)
    }

    private var dateLabel: String {
        guard let date = session.date else { return "Anytime this week" }
        return date.formatted(.dateTime.month(.abbreviated).day().year()).uppercased()
    }

    private var metaLabel: String {
        "\(session.workoutType.title) · \(session.exercises.count) exercises"
    }

    private var durationLabel: String {
        Duration.seconds(session.durationMinutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
