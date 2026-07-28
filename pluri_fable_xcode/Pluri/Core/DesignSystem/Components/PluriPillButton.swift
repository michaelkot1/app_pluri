import SwiftUI

/// Pill-shaped button style per design.md — radius/xl, 44pt+ minimum height.
/// Primary carries brand orange with a tinted CTA shadow when enabled; when
/// disabled it softens to a peach/coral tint (Strava-like questionnaire CTA).
/// Secondary is a quiet muted surface.
struct PluriPillButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
    }

    var variant: Variant = .primary

    func makeBody(configuration: Configuration) -> some View {
        PluriPillButtonLabel(configuration: configuration, variant: variant)
    }
}

private struct PluriPillButtonLabel: View {
    let configuration: ButtonStyleConfiguration
    let variant: PluriPillButtonStyle.Variant
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(PluriFont.label)
            .bold()
            .foregroundStyle(foreground)
            .padding(.horizontal, PluriSpacing.lg)
            .frame(minHeight: 52)
            .frame(maxWidth: .infinity)
            .background(background, in: .rect(cornerRadius: PluriRadius.xl))
            .pluriShadow(
                variant == .primary && isEnabled ? .primaryCTA : .card,
                tint: variant == .primary && isEnabled ? PluriColor.brandOrange : .black
            )
            .opacity(configuration.isPressed && isEnabled ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch variant {
        case .primary:
            isEnabled ? .white : .white.opacity(0.85)
        case .secondary:
            PluriColor.textPrimary
        }
    }

    private var background: Color {
        switch variant {
        case .primary:
            if !isEnabled {
                // Soft peach disabled CTA — brand orange reserved for the enabled state.
                PluriColor.brandCoralSoft.opacity(0.55)
            } else if configuration.isPressed {
                PluriColor.brandOrangeDeep
            } else {
                PluriColor.brandOrange
            }
        case .secondary:
            PluriColor.bgMuted
        }
    }
}

extension ButtonStyle where Self == PluriPillButtonStyle {
    static var pluriPrimary: PluriPillButtonStyle { PluriPillButtonStyle(variant: .primary) }
    static var pluriSecondary: PluriPillButtonStyle { PluriPillButtonStyle(variant: .secondary) }
}

#Preview {
    VStack(spacing: PluriSpacing.md) {
        Button("Start Workout") {}
            .buttonStyle(.pluriPrimary)
        Button("Continue") {}
            .buttonStyle(.pluriPrimary)
            .disabled(true)
        Button("Maybe Later") {}
            .buttonStyle(.pluriSecondary)
    }
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
