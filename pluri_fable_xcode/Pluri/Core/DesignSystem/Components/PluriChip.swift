import SwiftUI

/// Selectable chip for dense multi-select lists (equipment, allergies, body
/// areas, weekdays). Selected chips use near-black `selection/fill`; brand
/// orange stays on the Continue CTA only. Supports a disabled "coming soon"
/// state for v2 options.
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
                    if !isSelected && isEnabled {
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
        return isSelected ? PluriColor.selectionOnFill : PluriColor.textPrimary
    }

    private var background: Color {
        if !isEnabled { return PluriColor.bgMuted }
        return isSelected ? PluriColor.selectionFill : PluriColor.bgMuted
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
