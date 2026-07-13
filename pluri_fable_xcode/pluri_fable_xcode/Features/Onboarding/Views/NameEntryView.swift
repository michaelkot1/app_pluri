import SwiftUI

/// Name entry (M1-06) — "What should we call you?" No progress bar yet
/// (SPEC §3.1: it appears starting at Q1).
struct NameEntryView: View {
    @Bindable var answers: OnboardingAnswers
    var onContinue: () -> Void

    private var trimmedName: String {
        answers.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        OnboardingScaffold(
            title: "What should we call you?",
            subtitle: "We'll use this to keep things personal.",
            isContinueEnabled: !trimmedName.isEmpty,
            onContinue: onContinue
        ) {
            TextField("Your name", text: $answers.name)
                .font(PluriFont.body)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(PluriSpacing.md)
                .frame(minHeight: 44)
                .background(PluriColor.bgSurface, in: .rect(cornerRadius: PluriRadius.md))
                .submitLabel(.done)
                .onSubmit {
                    if !trimmedName.isEmpty { onContinue() }
                }
        }
    }
}

#Preview {
    NavigationStack {
        NameEntryView(answers: OnboardingAnswers(), onContinue: {})
    }
}
