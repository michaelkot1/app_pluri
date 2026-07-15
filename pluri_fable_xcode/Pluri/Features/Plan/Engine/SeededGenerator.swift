import Foundation

/// A small, fully deterministic `RandomNumberGenerator` (SplitMix64) so
/// `PlanEngine` output is reproducible from a seed (PLAN §1.4 — "deterministic
/// given a seed, so it's testable").
///
/// SplitMix64 is chosen over the system RNG because the latter is
/// non-deterministic, and over `GKMersenneTwister` to avoid pulling in
/// GameplayKit for six lines of arithmetic.
///
/// `nonisolated` so the off-main-actor `PlanEngine` can use it under the
/// project's main-actor default isolation.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid the all-zero state, which weakens the first few outputs.
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
