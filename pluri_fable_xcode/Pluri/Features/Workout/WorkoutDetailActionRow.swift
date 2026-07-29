import SwiftUI

/// Compact icon actions shown below the workout hero.
struct WorkoutDetailActionRow: View {
    let status: WorkoutStatus
    let isUpdatingStatus: Bool
    let statusAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: PluriSpacing.xl) {
            WorkoutDetailIconAction(
                title: "Warm-up\nstretches",
                systemImage: "figure.flexibility",
                isEnabled: false,
                action: {}
            )
            .accessibilityHint("Not available yet")

            WorkoutDetailIconAction(
                title: statusTitle,
                systemImage: statusImage,
                isEnabled: status != .completed && !isUpdatingStatus,
                action: statusAction
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PluriSpacing.md)
        .accessibilityElement(children: .contain)
    }

    private var statusTitle: String {
        switch status {
        case .scheduled: "Skip\nWorkout"
        case .skipped: "Unskip\nWorkout"
        case .completed: "Workout\ncompleted"
        }
    }

    private var statusImage: String {
        switch status {
        case .scheduled: "rectangle"
        case .skipped: "minus"
        case .completed: "checkmark"
        }
    }
}

private struct WorkoutDetailIconAction: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: PluriSpacing.xs) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 52, height: 52)
                    .overlay {
                        Circle()
                            .stroke(PluriColor.textSecondary, lineWidth: 1)
                    }

                Text(title)
                    .font(PluriFont.label)
                    .bold()
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PluriColor.textSecondary)
            }
            .frame(minWidth: 110)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.48)
    }
}
