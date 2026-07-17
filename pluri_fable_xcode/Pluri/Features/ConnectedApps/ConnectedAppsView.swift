import SwiftUI

/// Connected Apps shell (M3-12 / SPEC §6): current Apple Health and device
/// status, display-only until the M5 HealthKit integration — an honest shell
/// with no pretend connect buttons, matching Profile's Apple Health row.
struct ConnectedAppsView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Apple Health", value: "Not connected")
            } header: {
                Text("Apps")
            } footer: {
                Text("Apple Health connects when Insights arrive in a future update.")
            }

            Section {
                Text("No devices connected")
                    .foregroundStyle(PluriColor.textSecondary)
            } header: {
                Text("Devices")
            } footer: {
                Text("Adding your watch or other Bluetooth devices arrives in a future update.")
            }
        }
        .font(PluriFont.body)
        .scrollContentBackground(.hidden)
        .background(PluriColor.bgCanvas)
        .navigationTitle("Connected Apps")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ConnectedAppsView()
    }
}
