import RevenueCatUI
import SwiftUI

/// Thin RevenueCatUI Customer Center wrapper for Profile (M2-16).
/// Present from Profile when that screen is built; safe to sheet today.
struct PluriCustomerCenterView: View {
    var body: some View {
        CustomerCenterView()
    }
}

#Preview {
    PluriCustomerCenterView()
}
