import SwiftUI

/// Environment injection for Community networking (M8-05). Default mock for
/// previews/tests; live client wired in `AppRootView`.
private struct CommunityClientKey: EnvironmentKey {
    static let defaultValue: any CommunityClient = MockCommunityClient()
}

extension EnvironmentValues {
    var communityClient: any CommunityClient {
        get { self[CommunityClientKey.self] }
        set { self[CommunityClientKey.self] = newValue }
    }
}
