import Foundation

/// Bundled Explore Spaces directory entries (M8-10 / SPEC §14 #72f) — browse-only stub.
struct CommunitySpace: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let kind: Kind
    let locationLabel: String
    let detail: String

    enum Kind: String, Sendable {
        case race
        case runningGroup

        var title: String {
            switch self {
            case .race: "Upcoming race"
            case .runningGroup: "Running group"
            }
        }
    }

    /// Static nearby-ish directory for v1 Discover. Join/manage = v2.
    static let bundledDirectory: [CommunitySpace] = [
        CommunitySpace(
            id: "space-bay-half",
            name: "Bay Bridge Half Marathon",
            kind: .race,
            locationLabel: "San Francisco Bay Area",
            detail: "October · scenic bridge course · browse only in v1"
        ),
        CommunitySpace(
            id: "space-coastal-10k",
            name: "Coastal Trail 10K",
            kind: .race,
            locationLabel: "Pacifica",
            detail: "Rolling coastal hills · registration opens soon"
        ),
        CommunitySpace(
            id: "space-sunrise-crew",
            name: "Sunrise Embarcadero Crew",
            kind: .runningGroup,
            locationLabel: "Embarcadero, SF",
            detail: "Easy miles before work · Wed & Sat mornings"
        ),
        CommunitySpace(
            id: "space-weeknight-track",
            name: "Weeknight Track Club",
            kind: .runningGroup,
            locationLabel: "Kezar Stadium",
            detail: "Intervals and tempo · all paces welcome"
        ),
    ]
}
