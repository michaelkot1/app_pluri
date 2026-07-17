import SwiftUI

/// Insights tab placeholder (M3-06): honest "coming later" content that still
/// honors the Home health-tile deep link — the requested section from
/// `MainRouter` is selected and its placeholder card shown. Live insights
/// (HealthKit, charts) are M5+.
struct InsightsPlaceholderView: View {
    @Environment(MainRouter.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                InsightsSectionChips(
                    selected: router.insightsSection,
                    onSelect: { router.insightsSection = $0 }
                )
                InsightsSectionPlaceholderCard(section: router.insightsSection)
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .background(PluriColor.bgCanvas)
        .navigationTitle("Insights")
    }
}

/// Horizontal chip row to switch between placeholder sections.
private struct InsightsSectionChips: View {
    var selected: InsightsSection
    var onSelect: (InsightsSection) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: PluriSpacing.sm) {
                ForEach(InsightsSection.allCases) { section in
                    PluriChip(
                        title: LocalizedStringKey(section.title),
                        isSelected: section == selected
                    ) {
                        onSelect(section)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

/// The gentle "arrives later" card for one Insights section.
private struct InsightsSectionPlaceholderCard: View {
    var section: InsightsSection

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Label {
                    Text(section.title)
                        .font(PluriFont.sectionHeader)
                        .foregroundStyle(PluriColor.textPrimary)
                } icon: {
                    Image(systemName: section.systemImage)
                        .foregroundStyle(PluriColor.brandOrange)
                }
                Text(section.placeholderMessage)
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        InsightsPlaceholderView()
    }
    .environment(MainRouter())
}
