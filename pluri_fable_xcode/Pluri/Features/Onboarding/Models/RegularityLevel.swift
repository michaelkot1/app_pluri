import Foundation

/// Q4 — "Do you weight train regularly?" (SPEC §3.2).
enum RegularityLevel: String, CaseIterable, Identifiable, Sendable {
    case never = "I've never done weight training before"
    case onAndOff = "I tend to go on and off"
    case regularly = "I train regularly"
    case comingBack = "I used to — I'm coming back after a long break"

    var id: Self { self }
    var title: String { rawValue }
}
