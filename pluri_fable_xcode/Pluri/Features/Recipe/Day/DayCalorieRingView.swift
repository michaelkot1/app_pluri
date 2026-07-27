import SwiftUI

/// Day calorie ring — eaten vs maintenance in `statusBlue` (SPEC §14 #67h).
struct DayCalorieRingView: View {
    var progress: DayCalorieProgress

    var body: some View {
        HStack(spacing: PluriSpacing.md) {
            ZStack {
                Circle()
                    .stroke(PluriColor.bgMuted, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress.fraction)
                    .stroke(
                        PluriColor.statusBlue,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text(progress.eatenCalories, format: .number)
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.statusBlue)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(.horizontal, PluriSpacing.sm)
            }
            .frame(width: 72, height: 72)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                Text("Calories today")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)
                Text(subtitle)
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(PluriSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PluriColor.bgMuted, in: .rect(cornerRadius: PluriRadius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var subtitle: String {
        if let maintenance = progress.maintenanceCalories, maintenance > 0 {
            return "\(progress.eatenCalories.formatted()) of \(maintenance.formatted()) maintenance kcal"
        }
        return "\(progress.eatenCalories.formatted()) kcal logged"
    }

    private var accessibilityLabel: String {
        if let maintenance = progress.maintenanceCalories, maintenance > 0 {
            return "Calories today, \(progress.eatenCalories) of \(maintenance) maintenance kilocalories"
        }
        return "Calories today, \(progress.eatenCalories) kilocalories logged"
    }
}

#Preview("Under maintenance") {
    DayCalorieRingView(
        progress: DayCalorieProgress(eatenCalories: 1_200, maintenanceCalories: 2_000)
    )
    .padding()
    .background(PluriColor.bgCanvas)
}

#Preview("At maintenance") {
    DayCalorieRingView(
        progress: DayCalorieProgress(eatenCalories: 2_000, maintenanceCalories: 2_000)
    )
    .padding()
    .background(PluriColor.bgCanvas)
}

#Preview("Over maintenance") {
    DayCalorieRingView(
        progress: DayCalorieProgress(eatenCalories: 2_600, maintenanceCalories: 2_000)
    )
    .padding()
    .background(PluriColor.bgCanvas)
}

#Preview("No maintenance") {
    DayCalorieRingView(
        progress: DayCalorieProgress(eatenCalories: 450, maintenanceCalories: nil)
    )
    .padding()
    .background(PluriColor.bgCanvas)
}
