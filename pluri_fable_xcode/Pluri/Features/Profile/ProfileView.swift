import SwiftUI

/// Profile screen per SPEC §5.2 (M2-16): plan info, connected apps, notification
/// / language stubs, theme, subscription management, terms, and account actions.
/// Receives the restored state from the caller — missing profile/plan renders
/// honest empty states rather than invented data.
struct ProfileView: View {
    var restored: RestoredUserState?

    @State private var viewModel: ProfileViewModel
    @Environment(ThemeStore.self) private var themeStore
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

            Section {
                LabeledContent("Apple Health", value: "Not connected")
            } header: {
                Text("Connected apps")
            } footer: {
                Text("Apple Health connects when Insights arrive.")
            }

            Section {
                LabeledContent("Notifications", value: "Coming soon")
                LabeledContent("Language", value: currentLanguageName)
                Picker("Theme", selection: $themeStore.selection) {
                    ForEach(PluriTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
            } header: {
                Text("Preferences")
            } footer: {
                Text("Notification settings arrive in a later update. Language follows your device setting for now.")
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
}
