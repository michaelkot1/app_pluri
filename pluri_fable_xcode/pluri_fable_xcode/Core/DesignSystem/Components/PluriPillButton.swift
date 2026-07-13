import SwiftUI

/// Pill-shaped button style per design.md — radius/xl, 44pt minimum height.
/// Primary carries the brand orange with a tinted CTA shadow; secondary is a
/// quiet muted surface.
struct PluriPillButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
    }

    var variant: Variant = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PluriFont.label)
            .foregroundStyle(foreground)
            .padding(.horizontal, PluriSpacing.lg)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity)
            .background(background(pressed: configuration.isPressed), in: .rect(cornerRadius: PluriRadius.xl))
            .pluriShadow(variant == .primary ? .primaryCTA : .card,
                         tint: variant == .primary ? PluriColor.brandOrange : .black)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch variant {
        case .primary: .white
        case .secondary: PluriColor.textPrimary
        }
    }

    private func background(pressed: Bool) -> Color {
        switch variant {
        case .primary: pressed ? PluriColor.brandOrangeDeep : PluriColor.brandOrange
        case .secondary: PluriColor.bgMuted
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
        Button("Maybe Later") {}
            .buttonStyle(.pluriSecondary)
    }
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
