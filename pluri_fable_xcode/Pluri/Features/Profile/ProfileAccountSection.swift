import SwiftUI

/// Sign out / delete account rows with destructive confirmation and gentle
/// error surfacing (M2-17, SPEC §2 / §5.2).
struct ProfileAccountSection: View {
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        Section {
            Button {
                Task { await viewModel.signOut() }
            } label: {
                HStack {
                    Text("Sign out")
                    if viewModel.activeAction == .signOut {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isBusy)

            Button(role: .destructive) {
                viewModel.requestDeleteAccount()
            } label: {
                HStack {
                    Text("Delete account")
                    if viewModel.activeAction == .deleteAccount {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isBusy)
        } header: {
            Text("Account")
        } footer: {
            if let lastError = viewModel.lastError {
                Text(lastError.userFacingMessage)
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.statusRedSoft)
            }
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $viewModel.isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) {
                Task { await viewModel.confirmDeleteAccount() }
            }
            Button("Keep my account", role: .cancel) {
                viewModel.cancelDeleteAccount()
            }
        } message: {
            Text("This permanently deletes your plan, workout history, and profile from Pluri. It can’t be undone.")
        }
    }
}

#Preview {
    List {
        ProfileAccountSection(
            viewModel: ProfileViewModel(
                authService: MockSupabaseAuthService(isSignedIn: true),
                subscriptionService: MockSubscriptionService(),
                onAccountEnded: {}
            )
        )
    }
}
