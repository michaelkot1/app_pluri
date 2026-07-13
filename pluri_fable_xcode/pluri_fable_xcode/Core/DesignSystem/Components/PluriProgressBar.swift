import SwiftUI

/// A soft capsule progress bar (used by the onboarding questionnaire, plan
/// progress, and similar). Animates value changes gently.
struct PluriProgressBar: View {
    /// Progress in 0...1.
    var value: Double
    var tint = PluriColor.brandOrange

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(PluriColor.bgMuted)
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 8)
        .animation(.easeInOut(duration: 0.35), value: value)
        .accessibilityElement()
        .accessibilityLabel(Text("Progress"))
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}

#Preview {
    VStack(spacing: PluriSpacing.lg) {
        PluriProgressBar(value: 0.07)
        PluriProgressBar(value: 0.5)
        PluriProgressBar(value: 0.9, tint: PluriColor.statusGreen)
    }
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
