import SwiftUI

/// Shared chrome for every onboarding question screen: an optional progress
/// bar (M1-07), title/subtitle, scrollable content, and a pinned Continue
/// button. Keeps each `Q*View` focused on just its own inputs.
struct OnboardingScaffold<Content: View>: View {
    var progress: Double?
    var title: String
    var subtitle: String?
    var continueTitle: String = "Continue"
    var isContinueEnabled: Bool = true
    var onContinue: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: PluriSpacing.lg) {
            if let progress {
                PluriProgressBar(value: progress)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                    VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                        Text(title)
                            .font(PluriFont.title)
                            .foregroundStyle(PluriColor.textPrimary)
                        if let subtitle {
                            Text(subtitle)
                                .font(PluriFont.body)
                                .foregroundStyle(PluriColor.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    content
                }
                .padding(.top, PluriSpacing.sm)
                .padding(.bottom, PluriSpacing.lg)
            }
            .scrollIndicators(.hidden)

            Button(continueTitle, action: onContinue)
                .buttonStyle(.pluriPrimary)
                .disabled(!isContinueEnabled)
        }
        .padding(.horizontal, PluriSpacing.lg)
        .padding(.top, PluriSpacing.md)
        .padding(.bottom, PluriSpacing.md)
        .background(PluriColor.bgCanvas)
        .navigationBarTitleDisplayMode(.inline)
    }
}
