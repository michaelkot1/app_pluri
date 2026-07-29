import SwiftUI

/// Soft in-app Apple Health prompt on the Plan page when access is still
/// undecided or denied (SPEC §14 Plan HealthKit nudge). Uses the system
/// HealthKit sheet via `AppleHealthConnectionViewModel` — never a push.
struct PlanHealthKitNudgeBanner: View {
    @Bindable var connectionViewModel: AppleHealthConnectionViewModel
    @Bindable var nudgeController: PlanHealthKitNudgeController
    var onOpenConnectedApps: () -> Void

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                        Text(title)
                            .font(PluriFont.sectionHeader)
                            .foregroundStyle(PluriColor.textPrimary)
                        Text(message)
                            .font(PluriFont.body)
                            .foregroundStyle(PluriColor.textSecondary)
                    }
                    Spacer(minLength: PluriSpacing.sm)
                    Button("Dismiss", systemImage: "xmark") {
                        nudgeController.dismissForSession()
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(PluriColor.textTertiary)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Dismiss")
                }

                HStack(spacing: PluriSpacing.sm) {
                    if connectionViewModel.showsConnectButton {
                        Button {
                            Task { await connectionViewModel.connect() }
                        } label: {
                            if connectionViewModel.isConnecting {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Connect Apple Health")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PluriColor.brandOrange)
                        .disabled(connectionViewModel.isConnecting)
                    } else {
                        Button("Connected Apps") {
                            onOpenConnectedApps()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PluriColor.brandOrange)
                    }

                    Button("Don't ask again") {
                        nudgeController.setDontAskAgain()
                    }
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)
                    .frame(minHeight: 44)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        switch connectionViewModel.authorizationStatus {
        case .denied:
            "Apple Health is off"
        default:
            "Connect Apple Health"
        }
    }

    private var message: String {
        switch connectionViewModel.authorizationStatus {
        case .denied:
            "Access is turned off in iOS Settings. You can turn it on there whenever you're ready — or open Connected Apps for status."
        default:
            "Show Today's Health on Home and Insights. Samples stay on this device."
        }
    }
}

#if DEBUG
#Preview("Not determined") {
    PlanHealthKitNudgeBanner(
        connectionViewModel: AppleHealthConnectionViewModel(
            healthKit: MockHealthKitReading(authorizationStatus: .notDetermined)
        ),
        nudgeController: PlanHealthKitNudgeController(
            defaults: UserDefaults(suiteName: "pluri.previews.planHealthNudge") ?? .standard
        ),
        onOpenConnectedApps: {}
    )
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}

#Preview("Denied") {
    PlanHealthKitNudgeBanner(
        connectionViewModel: AppleHealthConnectionViewModel(
            healthKit: MockHealthKitReading(authorizationStatus: .denied)
        ),
        nudgeController: PlanHealthKitNudgeController(
            defaults: UserDefaults(suiteName: "pluri.previews.planHealthNudge.denied") ?? .standard
        ),
        onOpenConnectedApps: {}
    )
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
#endif
