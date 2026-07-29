import SwiftUI

/// Profile screen per SPEC §5.2 (M2-16): plan info, connected apps with the live
/// Apple Health connect control (M5-03), a link to the Notifications page (M3-15),
/// language stub, theme, subscription management, terms, and account actions.
/// Receives the restored state from the caller — missing profile/plan renders
/// honest empty states rather than invented data.
struct ProfileView: View {
    var restored: RestoredUserState?

    @State private var viewModel: ProfileViewModel
    @Environment(ThemeStore.self) private var themeStore
    @Environment(LiveHealthKitService.self) private var healthKitService
    @State private var showsCustomerCenter = false

    init(restored: RestoredUserState?, viewModel: ProfileViewModel) {
        self.restored = restored
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var themeStore = themeStore

        List {
            Section("Your plan") {
                ProfilePlanRows(summary: ProfilePlanSummary.make(from: restored?.plan))
            }

            AppleHealthConnectionSection(
                healthKit: healthKitService,
                headerTitle: "Connected apps"
            )

            Section {
                NavigationLink("Notifications", value: HomeRoute.notifications)
                LabeledContent("Language", value: currentLanguageName)
                Picker("Theme", selection: $themeStore.selection) {
                    ForEach(PluriTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
            } header: {
                Text("Preferences")
            } footer: {
                Text("Language follows your device setting for now.")
            }

            Section("Subscription") {
                Button("Manage subscription") {
                    showsCustomerCenter = true
                }
            }

            Section("Legal") {
                Link("Terms & Conditions", destination: LegalLinks.termsAndConditions)
            }

            ProfileAccountSection(viewModel: viewModel)
        }
        .font(PluriFont.body)
        .scrollContentBackground(.hidden)
        .background(PluriColor.bgCanvas)
        .navigationTitle(navigationTitle)
        .sheet(isPresented: $showsCustomerCenter) {
            PluriCustomerCenterView()
        }
    }

    private var navigationTitle: String {
        if let name = restored?.profile.displayName, !name.isEmpty {
            return name
        }
        return "Profile"
    }

    private var currentLanguageName: String {
        let locale = Locale.current
        guard let code = locale.language.languageCode?.identifier else { return "English" }
        return locale.localizedString(forLanguageCode: code)?.localizedCapitalized ?? code
    }
}

#Preview("No plan") {
    NavigationStack {
        ProfileView(
            restored: nil,
            viewModel: ProfileViewModel(
                authService: MockSupabaseAuthService(isSignedIn: true),
                subscriptionService: MockSubscriptionService(),
                onAccountEnded: {}
            )
        )
    }
    .environment(ThemeStore())
    .environment(LiveHealthKitService())
}
