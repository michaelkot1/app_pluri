import Foundation

/// Reconciles the Q6 equipment strings (SPEC §3.2 / `EquipmentCatalog`, which
/// use SPEC punctuation) with the WorkoutX catalog's `equipment` values, which
/// differ only cosmetically in casing and punctuation — e.g. SPEC
/// `"Dumbbell + Exercise Ball"` vs the API's `"Dumbbell, Exercise Ball"`, and
/// `"used as Handles for"` vs `"used As Handles For"` (see
/// `Core/Networking/WorkoutX/README.md`).
///
/// Decision (SPEC §14, resolving the TASKS backlog item): rather than maintain
/// a brittle 1:1 mapping table, normalize both sides by lowercasing and
/// stripping every non-alphanumeric character, then compare. This collapses
/// all the observed `+`/`,`/spacing/casing differences to the same key
/// (`"dumbbellexerciseball"`) and degrades gracefully if WorkoutX tweaks
/// punctuation again.
///
/// `nonisolated` so it can be used from the off-main-actor `PlanEngine` under
/// the project's main-actor default isolation.
nonisolated enum EquipmentMatcher {
    /// Canonical comparison key for an equipment string.
    static func normalized(_ equipment: String) -> String {
        equipment.unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map(Character.init)
            .reduce(into: "") { $0.append($1) }
            .lowercased()
    }

    /// The set of normalized keys for a user's equipment selection.
    static func normalizedKeys(for equipment: some Sequence<String>) -> Set<String> {
        Set(equipment.map(normalized))
    }

    /// Whether an exercise's `equipment` is covered by the user's selection.
    static func isAvailable(_ exerciseEquipment: String, in normalizedSelection: Set<String>) -> Bool {
        normalizedSelection.contains(normalized(exerciseEquipment))
    }
}
