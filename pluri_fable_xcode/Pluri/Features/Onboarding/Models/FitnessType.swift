import Foundation

/// Q1 — SPEC §3.2. Only `.workout` is selectable in v1; cardio/flexibility are
/// visible but disabled ("coming soon") per SPEC §1.1.
enum FitnessType: String, CaseIterable, Identifiable, Sendable {
    case workout = "Workout"
    case cardio = "Cardio"
    case flexibility = "Flexibility"

    var id: Self { self }

    var isAvailable: Bool { self == .workout }

    var title: String { rawValue }
}
