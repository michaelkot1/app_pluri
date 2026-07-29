import SwiftUI

/// Shared Apple Health status row + Connect CTA for Connected Apps and Profile
/// (M5-03 / SPEC §14 #57b / #78). Owns its view model so any `List` screen can drop
/// the section in with just the injected reader. Connect presents the system HealthKit
/// sheet and never navigates out of the app. Refreshes when the row appears and when
/// the scene becomes active, so access changed elsewhere shows up on return.
struct AppleHealthConnectionSection: View {
    @State private var viewModel: AppleHealthConnectionViewModel
    private let headerTitle: String

    @Environment(\.scenePhase) private var scenePhase

    init(healthKit: any HealthKitReading, headerTitle: String) {
        _viewModel = State(initialValue: AppleHealthConnectionViewModel(healthKit: healthKit))
        self.headerTitle = headerTitle
    }

    var body: some View {
        Section {
            LabeledContent("Apple Health", value: viewModel.statusLabel)
                .frame(minHeight: 44)
                .accessibilityLabel("Apple Health")
                .accessibilityValue(viewModel.statusLabel)
                // Attached to the row rather than the section so `List` keeps its
                // section structure intact.
                .task { await viewModel.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await viewModel.refresh() }
                }

            if viewModel.showsConnectButton {
                Button {
                    Task { await viewModel.connect() }
                } label: {
                    HStack {
                        Text("Connect")
                        if viewModel.isConnecting {
                            Spacer(minLength: PluriSpacing.sm)
                            ProgressView()
                        }
                    }
                    .frame(minHeight: 44)
                }
                .foregroundStyle(PluriColor.brandOrange)
                .disabled(viewModel.isConnecting)
                .accessibilityHint("Requests Apple Health access for steps, sleep, heart rate, and active energy")
            }
        } header: {
            Text(headerTitle)
        } footer: {
            Text(viewModel.footerText)
        }
    }
}

#if DEBUG
#Preview("Not determined") {
    List {
        AppleHealthConnectionSection(
            healthKit: MockHealthKitReading(authorizationStatus: .notDetermined),
            headerTitle: "Apps"
        )
    }
}

#Preview("Connected") {
    List {
        AppleHealthConnectionSection(
            healthKit: MockHealthKitReading(authorizationStatus: .authorized),
            headerTitle: "Apps"
        )
    }
}

#Preview("Partly connected") {
    List {
        AppleHealthConnectionSection(
            healthKit: MockHealthKitReading(
                authorizationStatus: .authorized,
                todayFixture: HealthDaySnapshot(
                    dayStart: Calendar.current.startOfDay(for: .now),
                    stepCount: 9_446,
                    sleepHours: nil,
                    averageHeartRateBPM: 68,
                    activeEnergyKilocalories: 420
                )
            ),
            headerTitle: "Connected apps"
        )
    }
}

#Preview("Denied") {
    List {
        AppleHealthConnectionSection(
            healthKit: MockHealthKitReading(authorizationStatus: .denied),
            headerTitle: "Connected apps"
        )
    }
}

#Preview("Unavailable") {
    List {
        AppleHealthConnectionSection(
            healthKit: MockHealthKitReading(authorizationStatus: .unavailable),
            headerTitle: "Apps"
        )
    }
}
#endif
