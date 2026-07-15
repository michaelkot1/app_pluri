import RevenueCat
import RevenueCatUI
import SwiftUI

/// RevenueCatUI paywall hosting the dashboard-designed Paywall (M2-09 / M2-10).
/// App Review must-haves (restore, terms, trial disclosure) come from the RC
/// Paywall editor template when the owner enables them.
struct PluriPaywallView: View {
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(\.dismiss) private var dismiss

    var onUnlocked: (() -> Void)?

    @State private var isRestoring = false
    @State private var showFallback = false
    @State private var fallbackMessage: String?

    var body: some View {
        Group {
            if showFallback {
                fallbackContent
            } else {
                PaywallView(displayCloseButton: true)
                    .onPurchaseCompleted { customerInfo in
                        handleEntitled(customerInfo)
                    }
                    .onRestoreCompleted { customerInfo in
                        handleEntitled(customerInfo)
                    }
            }
        }
        .background(PluriColor.bgCanvas)
        .task {
            await subscriptionService.refresh()
            if subscriptionService.offerings?.current == nil {
                showFallback = true
                fallbackMessage = subscriptionService.lastError?.userFacingMessage
                    ?? PluriSubscriptionError.offeringsUnavailable.userFacingMessage
            }
        }
    }

    private var fallbackContent: some View {
        VStack(spacing: PluriSpacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.circle")
                .font(.largeTitle)
                .foregroundStyle(PluriColor.brandOrange)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: PluriSpacing.sm) {
                Text("Couldn’t load the paywall")
                    .font(PluriFont.title)
                    .foregroundStyle(PluriColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(fallbackMessage ?? PluriSubscriptionError.offeringsUnavailable.userFacingMessage)
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, PluriSpacing.lg)

            Spacer()

            Button("Try again") {
                Task {
                    await subscriptionService.refresh()
                    if subscriptionService.offerings?.current == nil {
                        fallbackMessage = subscriptionService.lastError?.userFacingMessage
                            ?? PluriSubscriptionError.offeringsUnavailable.userFacingMessage
                        showFallback = true
                    } else {
                        fallbackMessage = nil
                        showFallback = false
                    }
                }
            }
            .buttonStyle(.pluriPrimary)
            .disabled(subscriptionService.isLoading)

            Button("Restore purchases") {
                Task { await restoreFromFallback() }
            }
            .buttonStyle(.pluriSecondary)
            .disabled(isRestoring || subscriptionService.isLoading)

            Button("Close", action: { dismiss() })
                .buttonStyle(.pluriSecondary)
        }
        .padding(.horizontal, PluriSpacing.lg)
        .padding(.bottom, PluriSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PluriColor.bgCanvas)
    }

    private func handleEntitled(_ customerInfo: CustomerInfo) {
        subscriptionService.applyCustomerInfo(customerInfo)
        if customerInfo.entitlements[PluriSubscription.entitlementID]?.isActive == true {
            onUnlocked?()
            dismiss()
        }
    }

    private func restoreFromFallback() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await subscriptionService.restore()
            if subscriptionService.isPluriProActive {
                onUnlocked?()
                dismiss()
            } else {
                fallbackMessage = "No active Pluri Pro subscription found to restore."
            }
        } catch let error as PluriSubscriptionError {
            fallbackMessage = error.userFacingMessage
        } catch {
            fallbackMessage = error.localizedDescription
        }
    }
}

#Preview {
    PluriPaywallView()
        .environment(SubscriptionService(configurePurchases: false))
}
