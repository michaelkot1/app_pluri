import SwiftUI

/// "Today's Health" placeholder tiles (M3-08 / SPEC §5): steps, sleep, and
/// active heart rate. No HealthKit reads — live tiles are M5 — so each tile
/// honestly shows "No data yet" and deep-links into its Insights section.
struct HomeHealthTiles: View {
    var onOpen: (InsightsSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text("Today's Health")
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)

            HStack(spacing: PluriSpacing.sm) {
                HomeHealthTile(section: .steps, onOpen: onOpen)
                HomeHealthTile(section: .sleep, onOpen: onOpen)
                HomeHealthTile(section: .activeHeartRate, onOpen: onOpen)
            }
        }
    }
}

/// One placeholder health tile; tapping jumps to that Insights section.
private struct HomeHealthTile: View {
    var section: InsightsSection
    var onOpen: (InsightsSection) -> Void

    var body: some View {
        Button {
            onOpen(section)
        } label: {
            VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                Image(systemName: section.systemImage)
                    .font(PluriFont.metricValue)
                    .foregroundStyle(PluriColor.brandOrange)
                Text(section.title)
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textPrimary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                Text("No data yet")
                    .font(PluriFont.overline)
                    .foregroundStyle(PluriColor.textTertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(PluriSpacing.md)
            .background(PluriColor.bgSurface, in: .rect(cornerRadius: PluriRadius.md))
            .pluriShadow(.card)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(section.title), no data yet")
        .accessibilityHint("Opens \(section.title) in Insights")
    }
}

#Preview {
    HomeHealthTiles(onOpen: { _ in })
        .padding(PluriSpacing.lg)
        .background(PluriColor.bgCanvas)
}
