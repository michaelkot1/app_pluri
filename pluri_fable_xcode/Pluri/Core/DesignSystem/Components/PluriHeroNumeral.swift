import SwiftUI

/// The one focal metric on a screen (design.md §3 "Hero Numeral", ~56–64pt).
/// No built-in iOS text style is this large, so the size is anchored to
/// `.largeTitle` with `@ScaledMetric` to keep Dynamic Type scaling.
struct PluriHeroNumeral: View {
    var text: String
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 60

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(PluriColor.textPrimary)
    }
}

#Preview {
    PluriHeroNumeral(text: "12,408")
        .padding()
        .background(PluriColor.bgCanvas)
}
