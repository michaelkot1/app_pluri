import SwiftUI

/// The floating Record Workout action button (M3-09 / SPEC §5), pinned above
/// the tab bar with the floating elevation and brand styling.
struct HomeRecordWorkoutButton: View {
    var action: () -> Void

    var body: some View {
        Button("Record Workout", systemImage: "plus", action: action)
            .font(PluriFont.label)
            .bold()
            .foregroundStyle(.white)
            .padding(.horizontal, PluriSpacing.lg)
            .frame(minHeight: 56)
            .background(PluriColor.brandOrange, in: .capsule)
            .pluriShadow(.floating, tint: PluriColor.brandOrange)
    }
}

#Preview {
    HomeRecordWorkoutButton(action: {})
        .padding(PluriSpacing.lg)
        .background(PluriColor.bgCanvas)
}
