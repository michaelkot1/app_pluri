import SwiftUI

/// 2-column icon + title tile for short icon-led option sets (e.g. Q1 fitness
/// type). Shares the near-black selected language with `OnboardingSelectRow`.
struct OnboardingSelectTile: View {
    var title: String
    var systemImage: String
    var isSelected: Bool
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: PluriSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(.title2, design: .rounded, weight: .medium))
                    .foregroundStyle(foreground)
                Text(title)
                    .font(PluriFont.label)
                    .bold()
                    .foregroundStyle(foreground)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PluriSpacing.lg)
            .padding(.horizontal, PluriSpacing.sm)
            .frame(minHeight: 96)
            .background(background, in: .rect(cornerRadius: PluriRadius.md))
        }
        .disabled(!isEnabled)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(title)
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

/// Two-column grid of `OnboardingSelectTile`s.
struct OnboardingSelectTileGrid<Item: Hashable>: View {
    let items: [Item]
    var isSelected: (Item) -> Bool
    var isEnabled: (Item) -> Bool = { _ in true }
    var title: (Item) -> String
    var systemImage: (Item) -> String
    var action: (Item) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: PluriSpacing.sm),
        GridItem(.flexible(), spacing: PluriSpacing.sm),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: PluriSpacing.sm) {
            ForEach(items, id: \.self) { item in
                OnboardingSelectTile(
                    title: title(item),
                    systemImage: systemImage(item),
                    isSelected: isSelected(item),
                    isEnabled: isEnabled(item),
                    action: { action(item) }
                )
            }
        }
    }
}

#Preview {
    @Previewable @State var selection = FitnessType.workout

    OnboardingSelectTileGrid(
        items: FitnessType.allCases,
        isSelected: { selection == $0 },
        isEnabled: \.isAvailable,
        title: { $0.isAvailable ? $0.title : "\($0.title) · Soon" },
        systemImage: \.systemImage,
        action: { if $0.isAvailable { selection = $0 } }
    )
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
