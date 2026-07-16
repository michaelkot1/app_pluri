import SwiftUI

/// 6-digit email OTP confirmation after sign-up when Supabase leaves session nil (M2-11 OTP UX).
struct EmailOTPConfirmationView: View {
    @Bindable var viewModel: AccountAuthViewModel
    var onVerified: (AccountAuthSuccessRoute) -> Void

    var body: some View {
        VStack(spacing: PluriSpacing.lg) {
            ScrollView {
                VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                    VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                        Text(viewModel.title)
                            .font(PluriFont.title)
                            .foregroundStyle(PluriColor.textPrimary)
                        Text(viewModel.subtitle)
                            .font(PluriFont.body)
                            .foregroundStyle(PluriColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("6-digit code", text: $viewModel.otpCode)
                        .font(PluriFont.title)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .padding(PluriSpacing.md)
                        .frame(minHeight: 56)
                        .background(PluriColor.bgSurface, in: .rect(cornerRadius: PluriRadius.md))
                        .accessibilityLabel("Confirmation code")

                    if let validationMessage = viewModel.validationMessage {
                        Text(validationMessage)
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.statusRedSoft)
                    }

                    if let authError = viewModel.authError {
                        Text(authError.userFacingMessage)
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.statusRedSoft)
                    }

                    if let resendConfirmationMessage = viewModel.resendConfirmationMessage {
                        Text(resendConfirmationMessage)
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.textSecondary)
                    }

                    Button("Confirm code") {
                        Task {
                            guard let route = await viewModel.submitOTP() else { return }
                            onVerified(route)
                        }
                    }
                    .buttonStyle(.pluriPrimary)
                    .disabled(!viewModel.canSubmitOTP || viewModel.isLoading)

                    Button("Resend code") {
                        Task { await viewModel.resendOTP() }
                    }
                    .font(PluriFont.body)
                    .bold()
                    .foregroundStyle(PluriColor.brandOrange)
                    .disabled(viewModel.isLoading)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)

                    Button("Use a different email") {
                        viewModel.returnToCredentials()
                    }
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
                    .disabled(viewModel.isLoading)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                }
                .padding(.top, PluriSpacing.sm)
                .padding(.bottom, PluriSpacing.lg)
            }
            .scrollIndicators(.hidden)

            if viewModel.isLoading {
                ProgressView()
                    .padding(.bottom, PluriSpacing.sm)
            }
        }
        .padding(.horizontal, PluriSpacing.lg)
        .padding(.top, PluriSpacing.md)
        .padding(.bottom, PluriSpacing.md)
        .background(PluriColor.bgCanvas)
    }
}
