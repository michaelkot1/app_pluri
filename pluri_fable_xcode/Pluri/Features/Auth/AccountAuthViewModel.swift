import Foundation
import Supabase

/// Sign-up vs sign-in mode for the post-name auth screen (M2-11 / M2-12).
enum AccountAuthMode: Equatable, Sendable {
    case signUp
    case signIn
}

/// Outcome after a successful auth attempt — drives onboarding routing.
enum AccountAuthSuccessRoute: Equatable, Sendable {
    /// New sign-up or incomplete returning user → continue questionnaire at Q1.
    case continueOnboarding
    /// Entitled returning user — the root router reclassifies (restore → Main / locked paywall).
    case welcomeBackEntitled
}

/// Local step within the account auth screen (credentials vs email OTP).
enum AccountAuthStep: Equatable, Sendable {
    case credentials
    case emailOTP
}

/// Screen state for `AccountAuthView` (testable without SwiftUI).
@MainActor
@Observable
final class AccountAuthViewModel {
    var mode: AccountAuthMode = .signUp
    var step: AccountAuthStep = .credentials
    var email = ""
    var password = ""
    var otpCode = ""
    var validationMessage: String?
    var authError: PluriAuthError?
    var resendConfirmationMessage: String?

    private let authService: any SupabaseAuthServicing
    private let subscriptionService: any SubscriptionServicing

    init(
        authService: any SupabaseAuthServicing,
        subscriptionService: any SubscriptionServicing
    ) {
        self.authService = authService
        self.subscriptionService = subscriptionService
    }

    var isLoading: Bool { authService.isLoading }

    var canSubmitEmailPassword: Bool {
        AccountAuthValidator.canSubmit(email: email, password: password)
    }

    var canSubmitOTP: Bool {
        AccountAuthValidator.isValidOTP(otpCode)
    }

    var pendingOTPEmail: String {
        AccountAuthValidator.trimmedEmail(email)
    }

    var title: String {
        switch step {
        case .emailOTP:
            "Check your email"
        case .credentials:
            switch mode {
            case .signUp: "Create your account"
            case .signIn: "Welcome back"
            }
        }
    }

    var subtitle: String {
        switch step {
        case .emailOTP:
            "Enter the 6-digit code we sent to \(pendingOTPEmail)."
        case .credentials:
            switch mode {
            case .signUp:
                "Save your plan and keep everything in sync. Sign in with Apple is quickest."
            case .signIn:
                "Sign in to restore your subscription and plan on this device."
            }
        }
    }

    var emailContinueTitle: String {
        switch mode {
        case .signUp: "Create account"
        case .signIn: "Sign in"
        }
    }

    var modeTogglePrompt: String {
        switch mode {
        case .signUp: "Already have an account?"
        case .signIn: "Need an account?"
        }
    }

    var modeToggleActionTitle: String {
        switch mode {
        case .signUp: "Sign in"
        case .signIn: "Sign up"
        }
    }

    func toggleMode() {
        mode = mode == .signUp ? .signIn : .signUp
        step = .credentials
        otpCode = ""
        validationMessage = nil
        authError = nil
        resendConfirmationMessage = nil
    }

    func returnToCredentials() {
        step = .credentials
        otpCode = ""
        validationMessage = nil
        authError = nil
        resendConfirmationMessage = nil
    }

    func submitEmailPassword() async -> AccountAuthSuccessRoute? {
        validationMessage = nil
        authError = nil
        resendConfirmationMessage = nil

        guard canSubmitEmailPassword else {
            if !AccountAuthValidator.isValidEmail(email) {
                validationMessage = "Enter a valid email address."
            } else if !AccountAuthValidator.isValidPassword(password) {
                validationMessage = "Password must be at least \(AccountAuthValidator.minimumPasswordLength) characters."
            }
            return nil
        }

        let trimmed = AccountAuthValidator.trimmedEmail(email)
        do {
            switch mode {
            case .signUp:
                try await authService.signUp(email: trimmed, password: password)
                guard authService.isSignedIn else {
                    step = .emailOTP
                    otpCode = ""
                    return nil
                }
            case .signIn:
                try await authService.signIn(email: trimmed, password: password)
            }
            await linkRevenueCatIfPossible()
            return successRoute(for: mode)
        } catch let error as PluriAuthError {
            authError = error
            return nil
        } catch {
            authError = .unknown(error.localizedDescription)
            return nil
        }
    }

    func submitOTP() async -> AccountAuthSuccessRoute? {
        validationMessage = nil
        authError = nil
        resendConfirmationMessage = nil

        guard canSubmitOTP else {
            validationMessage = "Enter the 6-digit code from your email."
            return nil
        }

        do {
            try await authService.verifyOTP(
                email: pendingOTPEmail,
                token: AccountAuthValidator.trimmedOTP(otpCode),
                type: .signup
            )
            await linkRevenueCatIfPossible()
            step = .credentials
            return .continueOnboarding
        } catch let error as PluriAuthError {
            authError = error
            return nil
        } catch {
            authError = .unknown(error.localizedDescription)
            return nil
        }
    }

    func resendOTP() async {
        validationMessage = nil
        authError = nil
        resendConfirmationMessage = nil
        do {
            try await authService.resendSignupOTP(email: pendingOTPEmail)
            resendConfirmationMessage = "We sent a new code. Check your inbox."
        } catch let error as PluriAuthError {
            authError = error
        } catch {
            authError = .otpResendFailed(error.localizedDescription)
        }
    }

    func completeAppleSignIn(idToken: String, nonce: String) async -> AccountAuthSuccessRoute? {
        validationMessage = nil
        authError = nil
        do {
            try await authService.signInWithApple(idToken: idToken, nonce: nonce)
            await linkRevenueCatIfPossible()
            // SIWA doesn't distinguish sign-up vs sign-in in the UI; treat like sign-in
            // for entitled restore, otherwise continue onboarding (new or incomplete).
            return successRoute(for: .signIn)
        } catch let error as PluriAuthError {
            authError = error
            return nil
        } catch {
            authError = .unknown(error.localizedDescription)
            return nil
        }
    }

    func applyAppleFailure(_ error: Error) {
        if let auth = error as? PluriAuthError {
            authError = auth
        } else {
            authError = .appleSignInFailed(error.localizedDescription)
        }
    }

    // MARK: - Private

    private func successRoute(for mode: AccountAuthMode) -> AccountAuthSuccessRoute {
        if mode == .signIn, subscriptionService.isPluriProActive {
            return .welcomeBackEntitled
        }
        return .continueOnboarding
    }

    private func linkRevenueCatIfPossible() async {
        guard let userID = authService.appUserID else { return }
        do {
            try await subscriptionService.logIn(appUserID: userID)
        } catch {
            // Non-blocking: auth succeeded; RC alias can retry later (M2-18).
        }
    }
}
