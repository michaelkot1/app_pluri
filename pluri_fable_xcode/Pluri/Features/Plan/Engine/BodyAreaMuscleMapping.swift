import Foundation

/// Maps onboarding `BodyArea` (Q7 coarse WorkoutX body parts) onto WorkoutX
/// `target` / `secondaryMuscles` strings from `/exercises/targetList`
/// (SPEC §14 #46/#47 / M3-18).
///
/// Used by focus selection and graded injury rules so exclusion is muscle-
/// precise rather than whole-`bodyPart` blunt.
nonisolated enum BodyAreaMuscleMapping {
    /// WorkoutX `targetList` muscles associated with each injured body area.
    static func targetMuscles(for area: BodyArea) -> Set<String> {
        switch area {
        case .back:
            ["Lats", "Upper Back", "Traps", "Spine"]
        case .chest:
            ["Pectorals"]
        case .lowerArms:
            ["Forearms"]
        case .lowerLegs:
            ["Calves"]
        case .neck:
            ["Levator Scapulae"]
        case .shoulders:
            ["Delts"]
        case .upperArms:
            ["Biceps", "Triceps"]
        case .upperLegs:
            ["Quads", "Hamstrings", "Glutes", "Abductors", "Adductors"]
        case .waist:
            ["Abs", "Serratus Anterior"]
        }
    }

    /// Union of all WorkoutX muscles implicated by the user's injuries.
    static func muscles(for injuries: [BodyArea: Int]) -> Set<String> {
        Set(injuries.keys.flatMap { targetMuscles(for: $0) })
    }

    /// Highest pain level among injuries that map to `muscle`, or `nil` when
    /// the muscle is not implicated.
    static func painLevel(for muscle: String, injuries: [BodyArea: Int]) -> Int? {
        var highest: Int?
        for (area, pain) in injuries where targetMuscles(for: area).contains(muscle) {
            highest = max(highest ?? pain, pain)
        }
        return highest
    }

    /// Equipment keywords treated as supported / machine variants for pain-3
    /// load-capped secondary involvement (SPEC §14 #49).
    static let supportedEquipmentKeywords: [String] = [
        "machine", "cable", "leverage", "smith", "assisted",
    ]

    static func isSupportedOrMachine(_ equipment: String) -> Bool {
        let normalized = equipment.lowercased()
        return supportedEquipmentKeywords.contains { normalized.contains($0) }
    }
}
