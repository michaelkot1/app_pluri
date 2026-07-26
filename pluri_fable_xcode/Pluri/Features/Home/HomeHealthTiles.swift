import SwiftUI

/// "Today's Health" live tiles (M5-04 / SPEC §5): steps, sleep, and active
/// heart rate from on-device HealthKit. Empty / unauthorized states stay
/// honest (SPEC §14 #57c). Tapping deep-links into Insights.
struct HomeHealthTiles: View {
    var metrics: HomeHealthTileMetrics
    var onOpen: (InsightsSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text("Today's Health")
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)

            HStack(spacing: PluriSpacing.sm) {
                HomeHealthTile(section: .steps, value: metrics.stepsValue, onOpen: onOpen)
                HomeHealthTile(section: .sleep, value: metrics.sleepValue, onOpen: onOpen)
                HomeHealthTile(
                    section: .activeHeartRate,
                    value: metrics.heartRateValue,
                    onOpen: onOpen
                )
            }
        }
    }
}

/// One health tile; tapping jumps to that Insights section.
private struct HomeHealthTile: View {
    var section: InsightsSection
    var value: String
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
                Text(value)
                    .font(PluriFont.overline)
                    .foregroundStyle(PluriColor.textTertiary)
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(PluriSpacing.md)
            .background(PluriColor.bgSurface, in: .rect(cornerRadius: PluriRadius.md))
            .pluriShadow(.card)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(section.title), \(value)")
        .accessibilityHint("Opens \(section.title) in Insights")
    }
}

#Preview("Populated") {
    HomeHealthTiles(
        metrics: HomeHealthTileMetrics(
            stepsValue: "8,432",
            sleepValue: "7.3 hr",
            heartRateValue: "68 BPM",
            isEmptyPlaceholder: false
        ),
        onOpen: { _ in }
    )
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}

#Preview("Authorized empty") {
    HomeHealthTiles(metrics: .empty, onOpen: { _ in })
        .padding(PluriSpacing.lg)
        .background(PluriColor.bgCanvas)
}

#Preview("Enable Health") {
    HomeHealthTiles(
        metrics: HomeHealthTileMetrics(
            stepsValue: "Enable Health",
            sleepValue: "Enable Health",
            heartRateValue: "Enable Health",
            isEmptyPlaceholder: true
        ),
        onOpen: { _ in }
    )
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}

#Preview("Denied") {
    HomeHealthTiles(
        metrics: HomeHealthTileMetrics(
            stepsValue: "Enable Health",
            sleepValue: "Enable Health",
            heartRateValue: "Enable Health",
            isEmptyPlaceholder: true
        ),
        onOpen: { _ in }
    )
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}

#Preview("Unavailable") {
    HomeHealthTiles(
        metrics: HomeHealthTileMetrics(
            stepsValue: "Not available",
            sleepValue: "Not available",
            heartRateValue: "Not available",
            isEmptyPlaceholder: true
        ),
        onOpen: { _ in }
    )
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
