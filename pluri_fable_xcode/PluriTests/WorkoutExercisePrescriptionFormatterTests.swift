import Foundation
import Testing
@testable import Pluri

@Suite("WorkoutExercisePrescriptionFormatter")
struct WorkoutExercisePrescriptionFormatterTests {

    @Test("Normal case uses reps..reps+2 and sets as repeat count")
    func normalCase() {
        #expect(
            WorkoutExercisePrescriptionFormatter.phrase(sets: 4, reps: 5)
                == "5–7 reps, repeat 4 times"
        )
    }

    @Test("reps=1 yields 1–3 range")
    func singleRepRange() {
        #expect(
            WorkoutExercisePrescriptionFormatter.phrase(sets: 3, reps: 1)
                == "1–3 reps, repeat 3 times"
        )
    }

    @Test("sets=1 uses singular time")
    func singleSet() {
        #expect(
            WorkoutExercisePrescriptionFormatter.phrase(sets: 1, reps: 10)
                == "10–12 reps, repeat 1 time"
        )
    }

    @Test("Large numbers format without special casing")
    func largeNumbers() {
        #expect(
            WorkoutExercisePrescriptionFormatter.phrase(sets: 12, reps: 50)
                == "50–52 reps, repeat 12 times"
        )
    }
}
