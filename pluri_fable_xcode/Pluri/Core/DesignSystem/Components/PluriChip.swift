import SwiftUI

/// Selectable chip for questionnaire options, allergies, equipment, etc.
/// Selected chips fill with brand orange; unselected sit on the muted surface.
/// Supports a disabled "coming soon" state for v2 options.
struct PluriChip: View {
    var title: LocalizedStringKey
    var isSelected: Bool
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PluriFont.label)
                .foregroundStyle(foreground)
                .padding(.horizontal, PluriSpacing.md)
                .frame(minHeight: 44)
                .background(background, in: .capsule)
                .overlay {
                    if !isSelected {
                        Capsule().strokeBorder(PluriColor.lineDivider, lineWidth: 1)
                    }
                }
        }
        .disabled(!isEnabled)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foreground: Color {
        if !isEnabled { return PluriColor.textTertiary }
        return isSelected ? .white : PluriColor.textPrimary
    }

    private var background: Color {
        if !isEnabled { return PluriColor.bgMuted }
        return isSelected ? PluriColor.brandOrange : PluriColor.bgSurface
    }
}

#Preview {
    @Previewable @State var selection = "Workout"

    let options = ["Workout", "Cardio", "Flexibility"]
    return HStack(spacing: PluriSpacing.sm) {
        ForEach(options, id: \.self) { option in
            PluriChip(
                title: LocalizedStringKey(option),
                isSelected: selection == option,
                isEnabled: option == "Workout"
            ) {
                selection = option
            }
        }
    }
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
