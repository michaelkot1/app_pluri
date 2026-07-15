import Foundation

/// Q7 injury areas — the WorkoutX `bodyPart` taxonomy (see
/// `Core/Networking/WorkoutX/README.md`), minus `"Cardio"`.
///
/// Decision (SPEC §14): WorkoutX's `bodyPart` list includes `"Cardio"`, but
/// that isn't a physical area someone can report pain in, so it's excluded
/// from the injury question. The remaining 9 values are used as-is since
/// `PlanEngine` (M1-16+) will exclude exercises by matching this same field.
enum BodyArea: String, CaseIterable, Identifiable, Sendable {
    case back = "Back"
    case chest = "Chest"
    case lowerArms = "Lower Arms"
    case lowerLegs = "Lower Legs"
    case neck = "Neck"
    case shoulders = "Shoulders"
    case upperArms = "Upper Arms"
    case upperLegs = "Upper Legs"
    case waist = "Waist"

    var id: Self { self }
    var title: String { rawValue }
}
