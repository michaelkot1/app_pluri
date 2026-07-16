import SwiftUI

/// "Your plan" rows for Profile (SPEC §5.2): goal, dates, schedule — or an
/// honest empty state when no active plan was restored.
struct ProfilePlanRows: View {
    var summary: ProfilePlanSummary?

    var body: some View {
        if let summary {
            LabeledContent("Goal", value: summary.goalTitle)
            LabeledContent("Dates", value: summary.dateRangeText)
            LabeledContent("Schedule", value: summary.scheduleText)
        } else {
            Text("No active plan yet")
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textSecondary)
        }
    }
}

#Preview {
    List {
        Section("With plan") {
            ProfilePlanRows(
                summary: ProfilePlanSummary(
                    goalTitle: "Build muscle",
                    dateRangeText: "Jul 20 – Sep 13, 2026",
                    scheduleText: "Scheduled · 3 workouts / week · 45 min"
                )
            )
        }
        Section("Without plan") {
            ProfilePlanRows(summary: nil)
        }
    }
}
