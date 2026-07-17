import SwiftUI

/// Lightweight month header above the calendar strip (M3-07 / SPEC §14 #41):
/// month name + completion fraction among the month's dated workouts.
struct HomeMonthHeader: View {
    var summary: HomeMonthSummary

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(summary.title)
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)
            Spacer(minLength: PluriSpacing.md)
            if let completionText = summary.completionText {
                Text(completionText)
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: PluriSpacing.md) {
        HomeMonthHeader(summary: HomeMonthSummary(title: "July 2026", completedCount: 3, totalCount: 8))
        HomeMonthHeader(summary: HomeMonthSummary(title: "August 2026", completedCount: 0, totalCount: 0))
    }
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
