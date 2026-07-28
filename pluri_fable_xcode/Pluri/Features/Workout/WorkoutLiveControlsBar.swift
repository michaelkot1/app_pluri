import SwiftUI

/// Floating bottom controls for the live Workout Screen (SPEC §8 / §14 #77).
/// Pre-start: Start alone. Running: Pause/Stop alone. Paused: Resume + Hold to Finish.
struct WorkoutLiveControlsBar: View {
    var showsLiveControls: Bool
    var isPaused: Bool
    var holdProgress: Double
    var onStart: () -> Void
    var onPauseOrStop: () -> Void
    var onResume: () -> Void
    var onHoldChanged: () -> Void
    var onHoldEnded: () -> Void

    var body: some View {
        VStack(spacing: PluriSpacing.sm) {
            if showsLiveControls {
                if isPaused {
                    Button("Resume", action: onResume)
                        .buttonStyle(.pluriPrimary)
                        .accessibilityHint("Resumes the workout timer")

                    holdToFinishButton
                } else {
                    Button("Pause/Stop", action: onPauseOrStop)
                        .buttonStyle(.pluriSecondary)
                        .accessibilityHint("Pauses the workout. Hold to Finish appears next.")
                }
            } else {
                Button("Start", action: onStart)
                    .buttonStyle(.pluriPrimary)
                    .accessibilityHint("Starts the live workout timer")
            }
        }
        .padding(.horizontal, PluriSpacing.lg)
        .padding(.bottom, PluriSpacing.md)
    }

    private var holdToFinishButton: some View {
        Text("Hold to Finish")
            .font(PluriFont.label)
            .foregroundStyle(PluriColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(PluriColor.bgMuted, in: .rect(cornerRadius: PluriRadius.xl))
            .overlay {
                GeometryReader { geo in
                    PluriColor.brandOrange.opacity(0.35)
                        .frame(width: geo.size.width * holdProgress)
                        .clipShape(.rect(cornerRadius: PluriRadius.xl))
                }
                .allowsHitTesting(false)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onHoldChanged() }
                    .onEnded { _ in onHoldEnded() }
            )
            .accessibilityLabel("Hold to finish workout")
            .accessibilityHint("Press and hold to open the workout summary")
            .accessibilityAddTraits(.isButton)
    }
}

#if DEBUG
#Preview("Pre-start") {
    WorkoutLiveControlsBar(
        showsLiveControls: false,
        isPaused: false,
        holdProgress: 0,
        onStart: {},
        onPauseOrStop: {},
        onResume: {},
        onHoldChanged: {},
        onHoldEnded: {}
    )
    .padding(.top, PluriSpacing.xxl)
    .background(PluriColor.bgCanvas)
}

#Preview("Running") {
    WorkoutLiveControlsBar(
        showsLiveControls: true,
        isPaused: false,
        holdProgress: 0,
        onStart: {},
        onPauseOrStop: {},
        onResume: {},
        onHoldChanged: {},
        onHoldEnded: {}
    )
    .padding(.top, PluriSpacing.xxl)
    .background(PluriColor.bgCanvas)
}

#Preview("Paused expanded") {
    WorkoutLiveControlsBar(
        showsLiveControls: true,
        isPaused: true,
        holdProgress: 0.4,
        onStart: {},
        onPauseOrStop: {},
        onResume: {},
        onHoldChanged: {},
        onHoldEnded: {}
    )
    .padding(.top, PluriSpacing.xxl)
    .background(PluriColor.bgCanvas)
}
#endif
