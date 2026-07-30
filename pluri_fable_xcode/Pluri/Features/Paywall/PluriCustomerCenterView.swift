import RevenueCat
import RevenueCatUI
import SwiftUI

/// Thin RevenueCatUI Customer Center wrapper for Profile (M2-16).
/// Present from Profile when that screen is built; safe to sheet today.
struct PluriCustomerCenterView: View {
    var body: some View {
        // CustomerCenterView traps in Release when Purchases was never configured.
        if Purchases.isConfigured {
            CustomerCenterView()
        } else {
            ContentUnavailableView(
                "Subscriptions unavailable",
                systemImage: "creditcard.trianglebadge.exclamationmark",
                description: Text(PluriSubscriptionError.configurationMissing.userFacingMessage)
            )
        }
    }
}

#if DEBUG
#Preview {
    PluriCustomerCenterView()
}
#endif
