import SwiftUI

/// Environment injection for Ask Pluri networking (M6-05/06).
/// `SupabaseService` itself is not in the environment — only the thin client
/// and history loader the chat UI needs.
private struct AskPluriClientKey: EnvironmentKey {
    static let defaultValue: any AskPluriClient = MockAskPluriClient()
}

private struct AskPluriHistoryLoaderKey: EnvironmentKey {
    static let defaultValue: any AskPluriHistoryLoading = MockAskPluriHistoryLoader()
}

extension EnvironmentValues {
    var askPluriClient: any AskPluriClient {
        get { self[AskPluriClientKey.self] }
        set { self[AskPluriClientKey.self] = newValue }
    }

    var askPluriHistoryLoader: any AskPluriHistoryLoading {
        get { self[AskPluriHistoryLoaderKey.self] }
        set { self[AskPluriHistoryLoaderKey.self] = newValue }
    }
}
