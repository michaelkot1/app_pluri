import SwiftUI

/// Brand moment (M1-05): the sunrise-glow radial gradient behind the
/// wordmark, per design.md's "Ambient Glow" elevation and sunrise tokens.
/// Advances automatically after a brief pause; tappable to skip the wait.
struct SplashView: View {
    var onFinished: () -> Void

    /// Wordmark size anchored to `.largeTitle` so it scales with Dynamic
    /// Type (same approach as `PluriHeroNumeral`).
    @ScaledMetric(relativeTo: .largeTitle) private var wordmarkSize: CGFloat = 56

    var body: some View {
        Button(action: onFinished) {
            ZStack {
                PluriColor.bgCanvas.ignoresSafeArea()

                Circle()
                    .fill(PluriColor.sunriseGradient)
                    .frame(width: 320, height: 320)

                VStack(spacing: PluriSpacing.sm) {
                    Text("Pluri")
                        .font(.system(size: wordmarkSize, weight: .bold, design: .rounded))
                        .foregroundStyle(PluriColor.brandOrangeDeep)
                    Text("Your gentle fitness coach")
                        .font(PluriFont.body)
                        .foregroundStyle(PluriColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Pluri — tap to continue"))
        .task {
            try? await Task.sleep(for: .seconds(1.6))
            // If the user already tapped through, this task is cancelled by
            // the push; don't fire again and stomp the navigation path.
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
