import SwiftUI

/// Connected Apps page (M3-12 / M5-03 / SPEC §6): live Apple Health connection
/// status with the real system prompt, and an honest Devices stub — no pretend
/// Bluetooth. Shares its Apple Health section with Profile.
struct ConnectedAppsView: View {
    @Environment(LiveHealthKitService.self) private var healthKitService

    var body: some View {
        List {
            AppleHealthConnectionSection(
                healthKit: healthKitService,
                headerTitle: "Apps"
            )

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
    .environment(LiveHealthKitService())
}
