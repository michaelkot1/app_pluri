import SwiftUI

/// When `false`, cached exercise GIFs hold their first frame instead of
/// animating. Screens set this while a sheet covers them, so N animating
/// `UIImageView`s stop competing for the main thread (SPEC §14 #76).
private struct ExerciseMediaAnimationEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var exerciseMediaAnimationEnabled: Bool {
        get { self[ExerciseMediaAnimationEnabledKey.self] }
        set { self[ExerciseMediaAnimationEnabledKey.self] = newValue }
    }
}
