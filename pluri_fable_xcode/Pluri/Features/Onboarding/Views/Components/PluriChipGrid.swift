import SwiftUI

/// A wrapping grid of `PluriChip`s — used for both single-select (Q1–Q4,
/// Q10, Q13) and multi-select (Q6, Q7, Q12) questions, since a plain `HStack`
/// would overflow for longer option lists (Q6 has 34 equipment items).
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
