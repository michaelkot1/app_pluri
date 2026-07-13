import Foundation

/// Q2 — SPEC §3.2 / §14 decision #2 ("Goal question added").
enum Goal: String, CaseIterable, Identifiable, Sendable {
    case buildMuscle = "Build muscle"
    case getStronger = "Get stronger"
    case loseFatToneUp = "Lose fat / tone up"
    case generalFitness = "General fitness & consistency"

    var id: Self { self }
    var title: String { rawValue }
}
