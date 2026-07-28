import SwiftUI

/// Hero timer + live HealthKit slots for the Workout Screen (M4-09/11).
///
/// Kept as its own view so the 1 Hz tick and incoming heart-rate / energy
/// samples invalidate only this subtree instead of the whole screen — the
/// exercise list and its media stay untouched between ticks (SPEC §14 #76).
struct WorkoutTimerMetricsView: View {
    var viewModel: WorkoutScreenViewModel

    var body: some View {
        VStack(spacing: PluriSpacing.md) {
            PluriHeroNumeral(text: viewModel.formattedElapsed)
                .accessibilityLabel(timerAccessibilityLabel)

            HStack(spacing: PluriSpacing.lg) {
                WorkoutMetricSlot(
                    title: "Heart rate",
                    value: viewModel.heartRateDisplay,
                    accessibilityValue: heartRateAccessibility
                )
                WorkoutMetricSlot(
                    title: "Calories",
                    value: viewModel.caloriesDisplay,
                    accessibilityValue: caloriesAccessibility
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PluriSpacing.md)
    }

    private var timerAccessibilityLabel: String {
        let elapsed = viewModel.formattedElapsed
        if viewModel.isRunning {
            return "Workout timer, \(elapsed), running"
        }
        if viewModel.isPaused {
            return "Workout timer, \(elapsed), paused"
        }
        return "Workout timer, \(elapsed)"
    }

    private var heartRateAccessibility: String {
        let value = viewModel.heartRateDisplay
        if value == "—" {
            return "Heart rate, no data yet"
        }
        return "Heart rate, \(value) beats per minute"
    }

    private var caloriesAccessibility: String {
        let value = viewModel.caloriesDisplay
        if value == "—" {
            return "Calories, no data yet"
        }
        return "Calories, \(value) kilocalories"
    }
}

/// Placeholder timer shown before a view model exists.
struct WorkoutTimerMetricsPlaceholderView: View {
    var body: some View {
        VStack(spacing: PluriSpacing.md) {
            PluriHeroNumeral(text: "00:00")
                .accessibilityLabel("Workout timer, 00:00")

            HStack(spacing: PluriSpacing.lg) {
                WorkoutMetricSlot(
                    title: "Heart rate",
                    value: "—",
                    accessibilityValue: "Heart rate, no data yet"
                )
                WorkoutMetricSlot(
                    title: "Calories",
                    value: "—",
                    accessibilityValue: "Calories, no data yet"
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PluriSpacing.md)
    }
}

private struct WorkoutMetricSlot: View {
    var title: String
    var value: String
    var accessibilityValue: String

    var body: some View {
        VStack(spacing: PluriSpacing.xs) {
            Text(value)
                .font(PluriFont.sectionHeader)
                .foregroundStyle(
                    value == "—" ? PluriColor.textTertiary : PluriColor.textPrimary
                )
                .monospacedDigit()
            Text(title)
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityValue)
    }
}
