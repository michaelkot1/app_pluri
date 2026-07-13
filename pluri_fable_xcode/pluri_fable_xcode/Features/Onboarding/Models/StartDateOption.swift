import Foundation

/// Q13 — "When do you want to start?" (SPEC §3.2).
enum StartDateOption: String, CaseIterable, Identifiable, Sendable {
    case today = "Today"
    case tomorrow = "Tomorrow"
    case custom = "Choose a date"

    var id: Self { self }
    var title: String { rawValue }
}
