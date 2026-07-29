import SwiftUI

/// Resolves a pushed `CommunityRoute` to its destination view (M8-05 / M8-08).
struct CommunityRouteDestinationView: View {
    var route: CommunityRoute

    var body: some View {
        switch route {
        case .search:
            CommunitySearchView()
        case .calendar:
            CalendarView(title: "Calendar")
        }
    }
}
