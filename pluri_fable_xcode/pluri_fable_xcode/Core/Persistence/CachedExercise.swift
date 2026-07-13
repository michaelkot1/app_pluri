import Foundation
import SwiftData

/// SwiftData cache of one `Exercise` from the WorkoutX catalog (M1-03).
///
/// The catalog is rarely-changing, so `ExerciseCatalogStore` serves it from
/// here first and only refreshes from `WorkoutXClient` when stale.
@Model
final class CachedExercise {
    #Unique<CachedExercise>([\.id])

    var id: String = ""
    var name: String = ""
    var bodyPart: String = ""
    var equipment: String = ""
    var targetMuscle: String = ""
    var secondaryMuscles: [String] = []
    var instructions: [String] = []
    var imageURLString: String?
    var videoURLString: String?

    init(exercise: Exercise) {
        id = exercise.id
        update(with: exercise)
    }

    /// Updates every field from a freshly-fetched `Exercise` (used when
    /// upserting during a catalog refresh).
    func update(with exercise: Exercise) {
        name = exercise.name
        bodyPart = exercise.bodyPart
        equipment = exercise.equipment
        targetMuscle = exercise.targetMuscle
        secondaryMuscles = exercise.secondaryMuscles
        instructions = exercise.instructions
        imageURLString = exercise.imageURL?.absoluteString
        videoURLString = exercise.videoURL?.absoluteString
    }

    var asDomainExercise: Exercise {
        Exercise(
            id: id,
            name: name,
            bodyPart: bodyPart,
            equipment: equipment,
            targetMuscle: targetMuscle,
            secondaryMuscles: secondaryMuscles,
            instructions: instructions,
            imageURL: imageURLString.flatMap(URL.init(string:)),
            videoURL: videoURLString.flatMap(URL.init(string:))
        )
    }
}
