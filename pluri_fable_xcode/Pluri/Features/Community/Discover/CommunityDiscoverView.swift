import SwiftUI

/// Discover hub: Explore Spaces browse stub + Challenges coming-soon (M8-10 / M8-15 thin).
struct CommunityDiscoverView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                spacesSection
                challengesSection
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.md)
        }
        .scrollIndicators(.hidden)
    }

    private var spacesSection: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.md) {
            Text("Explore Spaces")
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("Browse upcoming races and running groups nearby. Joining arrives later.")
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textSecondary)

            ForEach(CommunitySpace.bundledDirectory) { space in
                PluriCard {
                    VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                        Text(space.kind.title)
                            .font(PluriFont.overline)
                            .foregroundStyle(PluriColor.textTertiary)
                            .textCase(.uppercase)
                        Text(space.name)
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.textPrimary)
                        Text(space.locationLabel)
                            .font(PluriFont.body)
                            .foregroundStyle(PluriColor.textSecondary)
                        Text(space.detail)
                            .font(PluriFont.overline)
                            .foregroundStyle(PluriColor.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.md) {
            Text("Challenges")
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            HomeMessageCard(
                title: "Challenges coming soon",
                message: "Joinable challenges and leaderboards are planned for a later update. Explore Spaces above is browse-only for now."
            )
        }
    }
}

#Preview("Spaces and Challenges") {
    NavigationStack {
        CommunityDiscoverView()
    }
    .background(PluriColor.bgCanvas)
}
