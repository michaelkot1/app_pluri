import SwiftUI

/// The "Generating your plan…" progress state (M1-18 / SPEC §3.3): a warm
/// sunrise glow with a slowly rotating ring and gently cycling status copy, so
/// the wait feels deliberate and calm rather than like a spinner.
struct PlanGeneratingProgressView: View {
    var userName: String

    @State private var isAnimating = false
    @State private var messageIndex = 0

    /// Cycles every couple of seconds while generating.
    private let messages = [
        "Choosing exercises for your equipment…",
        "Balancing your muscle groups…",
        "Spreading workouts across your weeks…",
        "Adding a little progression each week…",
    ]

    private var trimmedName: String {
        userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var title: String {
        trimmedName.isEmpty ? "Building your plan" : "Building your plan, \(trimmedName)"
    }

    var body: some View {
        VStack(spacing: PluriSpacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(PluriColor.sunriseGradient)
                    .frame(width: 200, height: 200)
                    .scaleEffect(isAnimating ? 1.05 : 0.92)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isAnimating)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(PluriColor.brandOrange, style: .init(lineWidth: 6, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1.6).repeatForever(autoreverses: false), value: isAnimating)

                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(PluriColor.brandOrangeDeep)
            }

            VStack(spacing: PluriSpacing.sm) {
                Text(title)
                    .font(PluriFont.title)
                    .foregroundStyle(PluriColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(messages[messageIndex])
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                    .id(messageIndex)
            }
            .padding(.horizontal, PluriSpacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PluriColor.bgCanvas)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title). \(messages[messageIndex])"))
        .task {
            isAnimating = true
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut) {
                    messageIndex = (messageIndex + 1) % messages.count
                }
            }
        }
    }
}

#Preview {
    PlanGeneratingProgressView(userName: "Alex")
}
