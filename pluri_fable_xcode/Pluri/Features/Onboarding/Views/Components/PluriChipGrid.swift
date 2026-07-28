import SwiftUI

/// A wrapping grid of `PluriChip`s — used for dense multi-select lists
/// (Q6 equipment, Q7 body areas, Q8 weekdays, Q12 allergies). Text
/// single-select screens use `OnboardingSelectRowList` / tiles instead.
struct PluriChipGrid<Item: Hashable>: View {
    let items: [Item]
    var isSelected: (Item) -> Bool
    var isEnabled: (Item) -> Bool = { _ in true }
    var label: (Item) -> String
    var action: (Item) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 110), spacing: PluriSpacing.sm)],
            alignment: .leading,
            spacing: PluriSpacing.sm
        ) {
            ForEach(items, id: \.self) { item in
                PluriChip(
                    title: LocalizedStringKey(label(item)),
                    isSelected: isSelected(item),
                    isEnabled: isEnabled(item)
                ) {
                    action(item)
                }
            }
        }
    }
}
