import Foundation

/// Wire-format envelope for `GET /exercises` — see the response shape
/// documented in `Core/Networking/WorkoutX/README.md`.
struct WorkoutXExerciseListEnvelope: Decodable, Sendable {
    let total: Int
    let count: Int
    let data: [WorkoutXExerciseDTO]
}

/// Wire-format representation of a single exercise, decoded from WorkoutX's
/// JSON. Kept separate from the domain `Exercise` model (adapter layer per
/// PLAN §3) — only the fields Pluri actually uses are decoded; WorkoutX also
/// returns `category`, `difficulty`, `mechanic`, `met`, `movement_tags`, etc.,
/// which are ignored here.
struct WorkoutXExerciseDTO: Decodable, Sendable {
    let id: String
    let name: String
    let bodyPart: String
    let equipment: String
    let target: String
    let secondaryMuscles: [String]
    let instructions: [String]
    let gifUrl: String?

    var asDomainExercise: Exercise {
        Exercise(
            id: id,
            name: name,
            bodyPart: bodyPart,
            equipment: equipment,
            targetMuscle: target,
            secondaryMuscles: secondaryMuscles,
            instructions: instructions,
            imageURL: gifUrl.flatMap(URL.init(string:)),
            videoURL: nil
        )
    }
}
