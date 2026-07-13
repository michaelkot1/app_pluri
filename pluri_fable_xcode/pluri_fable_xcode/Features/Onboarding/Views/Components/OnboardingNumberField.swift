import SwiftUI

/// A labeled numeric input with an optional trailing unit (Q11/Q12) —
/// binds directly to a `Double` via the modern `FormatStyle` `TextField`
/// initializer rather than string formatting.
struct OnboardingNumberField: View {
    var title: String
    var unit: String?
    @Binding var value: Double
    var fractionLength: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.xs) {
            Text(title)
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)

            HStack(spacing: PluriSpacing.xs) {
                TextField(title, value: $value, format: .number.precision(.fractionLength(fractionLength)))
                    .keyboardType(.decimalPad)
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textPrimary)

                if let unit {
                    Text(unit)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textTertiary)
                }
            }
            .padding(PluriSpacing.md)
            .frame(minHeight: 44)
            .background(PluriColor.bgSurface, in: .rect(cornerRadius: PluriRadius.md))
        }
    }
}

#Preview {
    @Previewable @State var value = 170.0
    return OnboardingNumberField(title: "Height", unit: "cm", value: $value)
        .padding()
        .background(PluriColor.bgCanvas)
}
