import SwiftUI

/// Full-width rounded option row for onboarding single-select lists
/// (goals, experience, gender, durations, etc.). Selected state uses the
/// near-black `selection/fill` language — brand orange is reserved for the
/// bottom Continue CTA.
struct OnboardingSelectRow: View {
    var title: String
    var isSelected: Bool
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PluriFont.body)
                .bold()
                .foregroundStyle(foreground)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PluriSpacing.md)
                .frame(minHeight: 52)
                .background(background, in: .rect(cornerRadius: PluriRadius.md))
        }
        .disabled(!isEnabled)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foreground: Color {
        if !isEnabled { return PluriColor.textTertiary }
        return isSelected ? PluriColor.selectionOnFill : PluriColor.textPrimary
    }

    private var background: Color {
        if !isEnabled { return PluriColor.bgMuted }
        return isSelected ? PluriColor.selectionFill : PluriColor.bgMuted
    }
}

/// Vertical stack of `OnboardingSelectRow`s for text option lists.
struct OnboardingSelectRowList<Item: Hashable>: View {
    let items: [Item]
    var isSelected: (Item) -> Bool
    var isEnabled: (Item) -> Bool = { _ in true }
    var label: (Item) -> String
    var action: (Item) -> Void

    var body: some View {
        VStack(spacing: PluriSpacing.sm) {
            ForEach(items, id: \.self) { item in
                OnboardingSelectRow(
                    title: label(item),
                    isSelected: isSelected(item),
                    isEnabled: isEnabled(item),
                    action: { action(item) }
                )
            }
        }
    }
}

#Preview {
    @Previewable @State var selection = Goal.generalFitness

    OnboardingSelectRowList(
        items: Goal.allCases,
        isSelected: { selection == $0 },
        label: \.title,
        action: { selection = $0 }
    )
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
