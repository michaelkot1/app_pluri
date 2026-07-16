import AuthenticationServices
import SwiftUI

/// Post-name auth screen (M2-11 / M2-12): SIWA primary, email/password secondary.
/// Sign-up vs sign-in toggles with “Already have an account?”. Pending email
/// confirmation shows a 6-digit OTP step. On success, either continues to Q1 or
/// shows the welcome-back stub for entitled returning users.
struct AccountAuthView: View {
    @Environment(SupabaseAuthService.self) private var authService
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(SupabaseRemotePlanRestoreService.self) private var restoreService

    var onContinueOnboarding: () -> Void

    @State private var viewModel: AccountAuthViewModel?
    @State private var currentNonce: String?
    @State private var showsWelcomeBack = false

    var body: some View {
        Group {
            if showsWelcomeBack {
                WelcomeBackStubView(restoreService: restoreService)
            } else if let viewModel {
                if viewModel.step == .emailOTP {
                    EmailOTPConfirmationView(viewModel: viewModel, onVerified: apply)
                } else {
                    authContent(viewModel)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PluriColor.bgCanvas)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = AccountAuthViewModel(
                    authService: authService,
                    subscriptionService: subscriptionService
                )
            }
        }
    }

    @ViewBuilder
    private func authContent(_ viewModel: AccountAuthViewModel) -> some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: PluriSpacing.lg) {
            ScrollView {
                VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                    header(viewModel)

                    SignInWithAppleButton(.signIn) { request in
                        let nonce = AppleSignInNonce.randomNonce()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = AppleSignInNonce.sha256(nonce)
                    } onCompletion: { result in
                        Task { await handleAppleResult(result, viewModel: viewModel) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 48)
                    .clipShape(.rect(cornerRadius: PluriRadius.md))
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Sign in with Apple")

                    divider

                    emailFields(viewModel)

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

                    Button(viewModel.emailContinueTitle) {
                        Task { await submitEmail(viewModel) }
                    }
                    .buttonStyle(.pluriPrimary)
                    .disabled(!viewModel.canSubmitEmailPassword || viewModel.isLoading)

                    modeToggle(viewModel)
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
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled()
    }

    private func header(_ viewModel: AccountAuthViewModel) -> some View {
        VStack(alignment: .leading, spacing: PluriSpacing.xs) {
            Text(viewModel.title)
                .font(PluriFont.title)
                .foregroundStyle(PluriColor.textPrimary)
            Text(viewModel.subtitle)
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        HStack(spacing: PluriSpacing.sm) {
            Rectangle()
                .fill(PluriColor.lineDivider)
                .frame(height: 1)
            Text("or")
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textTertiary)
            Rectangle()
                .fill(PluriColor.lineDivider)
                .frame(height: 1)
        }
    }

    private func emailFields(_ viewModel: AccountAuthViewModel) -> some View {
        @Bindable var viewModel = viewModel
        return VStack(spacing: PluriSpacing.sm) {
            TextField("Email", text: $viewModel.email)
                .font(PluriFont.body)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(PluriSpacing.md)
                .frame(minHeight: 44)
                .background(PluriColor.bgSurface, in: .rect(cornerRadius: PluriRadius.md))

            SecureField("Password", text: $viewModel.password)
                .font(PluriFont.body)
                .textContentType(viewModel.mode == .signUp ? .newPassword : .password)
                .padding(PluriSpacing.md)
                .frame(minHeight: 44)
                .background(PluriColor.bgSurface, in: .rect(cornerRadius: PluriRadius.md))
        }
    }

    private func modeToggle(_ viewModel: AccountAuthViewModel) -> some View {
        HStack(spacing: PluriSpacing.xs) {
            Text(viewModel.modeTogglePrompt)
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textSecondary)
            Button(viewModel.modeToggleActionTitle) {
                viewModel.toggleMode()
            }
            .font(PluriFont.body)
            .bold()
            .foregroundStyle(PluriColor.brandOrange)
            .disabled(viewModel.isLoading)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, PluriSpacing.xs)
    }

    private func submitEmail(_ viewModel: AccountAuthViewModel) async {
        guard let route = await viewModel.submitEmailPassword() else { return }
        apply(route)
    }

    private func handleAppleResult(
        _ result: Result<ASAuthorization, Error>,
        viewModel: AccountAuthViewModel
    ) async {
        switch result {
        case .success(let authorization):
            do {
                let idToken = try SignInWithAppleTokenExtractor.identityToken(from: authorization)
                guard let nonce = currentNonce else {
                    viewModel.applyAppleFailure(
                        PluriAuthError.appleSignInFailed("Missing sign-in nonce. Please try again.")
                    )
                    return
                }
                guard let route = await viewModel.completeAppleSignIn(idToken: idToken, nonce: nonce) else {
                    return
                }
                apply(route)
            } catch {
                viewModel.applyAppleFailure(error)
            }
        case .failure(let error):
            // User cancellation is quiet; other failures surface gently.
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                return
            }
            viewModel.applyAppleFailure(error)
        }
    }

    private func apply(_ route: AccountAuthSuccessRoute) {
        switch route {
        case .continueOnboarding:
            onContinueOnboarding()
        case .welcomeBackEntitled:
            showsWelcomeBack = true
        }
    }
}

#Preview {
    NavigationStack {
        AccountAuthView(onContinueOnboarding: {})
            .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
            .environment(SubscriptionService(configurePurchases: false))
            .environment(SupabaseRemotePlanRestoreService(supabaseService: SupabaseService()))
    }
}
