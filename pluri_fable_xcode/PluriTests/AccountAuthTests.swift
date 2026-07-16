import Testing
import Foundation
@testable import Pluri

@Suite("AccountAuthValidator")
struct AccountAuthValidatorTests {
    @Test("Accepts a normal email")
    func validEmail() {
        #expect(AccountAuthValidator.isValidEmail("alex@example.com"))
        #expect(AccountAuthValidator.isValidEmail("  alex@example.com  "))
    }

    @Test("Rejects malformed emails")
    func invalidEmails() {
        #expect(!AccountAuthValidator.isValidEmail(""))
        #expect(!AccountAuthValidator.isValidEmail("alex"))
        #expect(!AccountAuthValidator.isValidEmail("alex@"))
        #expect(!AccountAuthValidator.isValidEmail("@example.com"))
        #expect(!AccountAuthValidator.isValidEmail("alex@example"))
    }

    @Test("Password requires minimum length")
    func passwordLength() {
        #expect(!AccountAuthValidator.isValidPassword("12345"))
        #expect(AccountAuthValidator.isValidPassword("123456"))
    }

    @Test("canSubmit requires both valid email and password")
    func canSubmit() {
        #expect(AccountAuthValidator.canSubmit(email: "a@b.co", password: "secret1"))
        #expect(!AccountAuthValidator.canSubmit(email: "nope", password: "secret1"))
        #expect(!AccountAuthValidator.canSubmit(email: "a@b.co", password: "short"))
    }
}

@Suite("AccountAuthViewModel")
struct AccountAuthViewModelTests {
    init() {
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: PluriSubscription.debugBypassPaywallKey)
        #endif
    }

    @Test("Sign-up success continues onboarding and links RevenueCat")
    @MainActor
    func signUpContinuesOnboarding() async {
        let auth = MockSupabaseAuthService()
        let subscriptions = MockSubscriptionService(isPluriProActive: false)
        let viewModel = AccountAuthViewModel(authService: auth, subscriptionService: subscriptions)
        viewModel.email = "new@example.com"
        viewModel.password = "secret1"

        let route = await viewModel.submitEmailPassword()

        #expect(route == .continueOnboarding)
        #expect(auth.isSignedIn)
        #expect(viewModel.authError == nil)
        #expect(subscriptions.lastLoggedInAppUserID == auth.mockAppUserID)
    }

    @Test("Sign-in without entitlement continues onboarding")
    @MainActor
    func signInWithoutEntitlementContinues() async {
        let auth = MockSupabaseAuthService()
        let subscriptions = MockSubscriptionService(isPluriProActive: false)
        let viewModel = AccountAuthViewModel(authService: auth, subscriptionService: subscriptions)
        viewModel.mode = .signIn
        viewModel.email = "back@example.com"
        viewModel.password = "secret1"

        let route = await viewModel.submitEmailPassword()

        #expect(route == .continueOnboarding)
        #expect(auth.isSignedIn)
    }

    @Test("Sign-in with entitlement routes to welcome-back stub")
    @MainActor
    func signInEntitledWelcomeBack() async {
        let auth = MockSupabaseAuthService()
        let subscriptions = MockSubscriptionService(isPluriProActive: true)
        let viewModel = AccountAuthViewModel(authService: auth, subscriptionService: subscriptions)
        viewModel.mode = .signIn
        viewModel.email = "pro@example.com"
        viewModel.password = "secret1"

        let route = await viewModel.submitEmailPassword()

        #expect(route == .welcomeBackEntitled)
    }

    @Test("Auth failure surfaces PluriAuthError")
    @MainActor
    func authFailureSurfacesError() async {
        let auth = MockSupabaseAuthService()
        auth.nextAuthError = .invalidCredentials
        let subscriptions = MockSubscriptionService()
        let viewModel = AccountAuthViewModel(authService: auth, subscriptionService: subscriptions)
        viewModel.mode = .signIn
        viewModel.email = "bad@example.com"
        viewModel.password = "secret1"

        let route = await viewModel.submitEmailPassword()

        #expect(route == nil)
        #expect(viewModel.authError == .invalidCredentials)
        #expect(!auth.isSignedIn)
    }

    @Test("Invalid email sets validation message without calling auth")
    @MainActor
    func invalidEmailValidation() async {
        let auth = MockSupabaseAuthService()
        let subscriptions = MockSubscriptionService()
        let viewModel = AccountAuthViewModel(authService: auth, subscriptionService: subscriptions)
        viewModel.email = "not-an-email"
        viewModel.password = "secret1"

        let route = await viewModel.submitEmailPassword()

        #expect(route == nil)
        #expect(viewModel.validationMessage != nil)
        #expect(!auth.isSignedIn)
    }

    @Test("Sign-up without session routes to email OTP step")
    @MainActor
    func signUpPendingConfirmation() async {
        let auth = MockSupabaseAuthService()
        auth.signUpLeavesSignedOut = true
        let subscriptions = MockSubscriptionService()
        let viewModel = AccountAuthViewModel(authService: auth, subscriptionService: subscriptions)
        viewModel.email = "pending@example.com"
        viewModel.password = "secret1"

        let route = await viewModel.submitEmailPassword()

        #expect(route == nil)
        #expect(viewModel.step == .emailOTP)
        #expect(!auth.isSignedIn)
        #expect(viewModel.validationMessage == nil)
    }

    @Test("OTP verify continues onboarding and links RevenueCat")
    @MainActor
    func otpVerifyContinuesOnboarding() async {
        let auth = MockSupabaseAuthService()
        auth.signUpLeavesSignedOut = true
        let subscriptions = MockSubscriptionService(isPluriProActive: false)
        let viewModel = AccountAuthViewModel(authService: auth, subscriptionService: subscriptions)
        viewModel.email = "pending@example.com"
        viewModel.password = "secret1"

        _ = await viewModel.submitEmailPassword()
        viewModel.otpCode = "123456"
        let route = await viewModel.submitOTP()

        #expect(route == .continueOnboarding)
        #expect(auth.isSignedIn)
        #expect(auth.verifyOTPCallCount == 1)
        #expect(subscriptions.lastLoggedInAppUserID == auth.mockAppUserID)
    }

    @Test("Invalid OTP surfaces error")
    @MainActor
    func invalidOTPSurfacesError() async {
        let auth = MockSupabaseAuthService()
        let viewModel = AccountAuthViewModel(authService: auth, subscriptionService: MockSubscriptionService())
        viewModel.step = .emailOTP
        viewModel.email = "pending@example.com"
        viewModel.otpCode = "000000"

        let route = await viewModel.submitOTP()

        #expect(route == nil)
        #expect(viewModel.authError == .invalidOTP)
        #expect(!auth.isSignedIn)
    }

    @Test("Resend OTP calls auth service")
    @MainActor
    func resendOTP() async {
        let auth = MockSupabaseAuthService()
        let viewModel = AccountAuthViewModel(authService: auth, subscriptionService: MockSubscriptionService())
        viewModel.step = .emailOTP
        viewModel.email = "pending@example.com"

        await viewModel.resendOTP()

        #expect(auth.resendOTPCallCount == 1)
        #expect(auth.lastResendEmail == "pending@example.com")
        #expect(viewModel.resendConfirmationMessage != nil)
    }

    @Test("OTP validator accepts six digits")
    func otpValidation() {
        #expect(AccountAuthValidator.isValidOTP("123456"))
        #expect(AccountAuthValidator.isValidOTP("12 34 56"))
        #expect(!AccountAuthValidator.isValidOTP("12345"))
        #expect(!AccountAuthValidator.isValidOTP("abcdef"))
    }

    @Test("Apple success without entitlement continues onboarding")
    @MainActor
    func appleContinuesOnboarding() async {
        let auth = MockSupabaseAuthService()
        let subscriptions = MockSubscriptionService(isPluriProActive: false)
        let viewModel = AccountAuthViewModel(authService: auth, subscriptionService: subscriptions)

        let route = await viewModel.completeAppleSignIn(idToken: "token", nonce: "nonce")

        #expect(route == .continueOnboarding)
        #expect(auth.isSignedIn)
    }

    @Test("Toggle flips between sign-up and sign-in")
    @MainActor
    func toggleMode() {
        let viewModel = AccountAuthViewModel(
            authService: MockSupabaseAuthService(),
            subscriptionService: MockSubscriptionService()
        )
        #expect(viewModel.mode == .signUp)
        viewModel.toggleMode()
        #expect(viewModel.mode == .signIn)
        viewModel.toggleMode()
        #expect(viewModel.mode == .signUp)
    }
}

@Suite("OnboardingDestination auth chrome")
struct OnboardingDestinationAuthTests {
    @Test("Auth is not a progress step; Q1 stays at 2/14")
    func authExcludedFromProgress() {
        #expect(OnboardingDestination.totalProgressSteps == 14)
        #expect(OnboardingDestination.name.stepNumber == 1)
        #expect(OnboardingDestination.account.stepNumber == nil)
        #expect(OnboardingDestination.account.showsProgressBar == false)
        #expect(OnboardingDestination.q1FitnessType.stepNumber == 2)
        #expect(OnboardingDestination.q1FitnessType.showsProgressBar == true)
        #expect(OnboardingDestination.name.next == .account)
        #expect(OnboardingDestination.account.next == .q1FitnessType)
        #expect(OnboardingDestination.q13StartDate.stepNumber == 14)
    }
}
