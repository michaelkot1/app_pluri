import SwiftUI

/// One selected injury area with its 1–5 pain-level stepper (Q7, M1-11).
struct InjuryPainRow: View {
    var area: BodyArea
    @Binding var painLevel: Int

    var body: some View {
        PluriCard {
            HStack {
                Text(area.title)
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textPrimary)

                Spacer()

                Text("\(painLevel)/5")
                    .font(PluriFont.metricValue)
                    .foregroundStyle(PluriColor.brandOrange)

                Stepper("Pain level", value: $painLevel, in: 1...5)
                    .labelsHidden()
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(area.title), pain level \(painLevel) of 5"))
    }
}

#Preview {
    @Previewable @State var pain = 3
    return InjuryPainRow(area: .shoulders, painLevel: $pain)
        .padding()
        .background(PluriColor.bgCanvas)
}
