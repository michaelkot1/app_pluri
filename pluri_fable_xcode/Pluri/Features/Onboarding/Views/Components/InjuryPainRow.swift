import SwiftUI

/// One selected injury area with a 1–5 pain-level slider (Q7, M1-11).
struct InjuryPainRow: View {
    var area: BodyArea
    @Binding var painLevel: Int

    private var sliderValue: Binding<Double> {
        Binding(
            get: { Double(painLevel) },
            set: { painLevel = Int($0.rounded()) }
        )
    }

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                HStack {
                    Text(area.title)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textPrimary)

                    Spacer()

                    Text("\(painLevel)/5")
                        .font(PluriFont.metricValue)
                        .foregroundStyle(PluriColor.textPrimary)
                        .accessibilityHidden(true)
                }

                Slider(value: sliderValue, in: 1...5, step: 1)
                    .tint(PluriColor.selectionFill)
                    .accessibilityLabel("Pain level for \(area.title)")
                    .accessibilityValue("\(painLevel) of 5")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    @Previewable @State var pain = 3
    return InjuryPainRow(area: .shoulders, painLevel: $pain)
        .padding()
        .background(PluriColor.bgCanvas)
}
