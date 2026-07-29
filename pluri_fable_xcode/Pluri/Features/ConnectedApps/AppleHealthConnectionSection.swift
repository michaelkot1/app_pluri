import SwiftUI

/// Shared Apple Health status row + Connect CTA for Connected Apps and Profile
/// (M5-03 / SPEC §14 #57b). Refresh on appear and when the scene becomes active.
struct AppleHealthConnectionSection: View {
    @Bindable var viewModel: AppleHealthConnectionViewModel
    var headerTitle: String

    var body: some View {
        Section {
            LabeledContent("Apple Health", value: viewModel.statusLabel)

            if viewModel.showsConnectButton {
                Button {
                    Task { await viewModel.connect() }
                } label: {
                    if viewModel.isConnecting {
                        ProgressView()
                    } else {
                        Text("Connect")
                    }
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
            viewModel: AppleHealthConnectionViewModel(
                healthKit: MockHealthKitReading(authorizationStatus: .notDetermined)
            ),
            headerTitle: "Apps"
        )
    }
}

#Preview("Connected") {
    List {
        AppleHealthConnectionSection(
            viewModel: AppleHealthConnectionViewModel(
                healthKit: MockHealthKitReading(authorizationStatus: .authorized)
            ),
            headerTitle: "Apps"
        )
    }
}

#Preview("Denied") {
    List {
        AppleHealthConnectionSection(
            viewModel: AppleHealthConnectionViewModel(
                healthKit: MockHealthKitReading(authorizationStatus: .denied)
            ),
            headerTitle: "Connected apps"
        )
    }
}

#Preview("Unavailable") {
    List {
        AppleHealthConnectionSection(
            viewModel: AppleHealthConnectionViewModel(
                healthKit: MockHealthKitReading(authorizationStatus: .unavailable)
            ),
            headerTitle: "Apps"
        )
    }
}
#endif
