import SwiftUI

/// The Plan page's horizontal row of circular action buttons (M3-10 /
/// SPEC §6): Plan Overview, Rearrange Workouts, Connected Apps, and Manage
/// Plan. All four route to honest placeholders until M3-12/13/14 land.
struct PlanActionButtonsRow: View {
    @Environment(MainRouter.self) private var router

    var body: some View {
        HStack(alignment: .top, spacing: PluriSpacing.sm) {
            PlanActionButton(title: "Plan Overview", systemImage: "info") {
                router.openPlanOverviewStub()
            }
            PlanActionButton(title: "Rearrange Workouts", systemImage: "arrow.up.arrow.down") {
                router.openRearrangeWorkoutsStub()
            }
            PlanActionButton(title: "Connected Apps", systemImage: "applewatch") {
                router.openConnectedAppsStub()
            }
            PlanActionButton(title: "Manage Plan", systemImage: "slider.horizontal.3") {
                router.openManagePlanStub()
            }
        }
    }
}

/// One circular icon button with its label underneath. The circle scales
/// with Dynamic Type and never drops below the 44pt minimum tap target.
private struct PlanActionButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    @ScaledMetric(relativeTo: .title3) private var diameter = 56.0

    var body: some View {
        Button(action: action) {
            VStack(spacing: PluriSpacing.xs) {
                Image(systemName: systemImage)
                    .font(PluriFont.metricValue)
                    .foregroundStyle(PluriColor.brandOrange)
                    .frame(width: max(diameter, 44), height: max(diameter, 44))
                    .background(PluriColor.bgSurface, in: .circle)
                    .pluriShadow(.card)

                Text(title)
                    .font(PluriFont.overline)
                    .foregroundStyle(PluriColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

#Preview {
    PlanActionButtonsRow()
        .padding(PluriSpacing.lg)
        .background(PluriColor.bgCanvas)
        .environment(MainRouter())
}
