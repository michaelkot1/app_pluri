import Foundation

/// On-device persistence for the Pluri Score clamp anchor + latest display (M5-05).
/// Used only for the ±3 daily clamp — never uploaded (SPEC §13 / §14 #57/#59).
///
/// - `clampBase` is frozen for the calendar day (previous day's latest, or the
///   first-ever score) so refreshes cannot move more than ±3 from that base.
/// - `latestScore` is always the last displayed clamped value and becomes the
///   next day's clamp source.
nonisolated enum PluriScoreStore {
    private static let scoreKeyPrefix = "pluri.score.value."
    private static let dayKeyPrefix = "pluri.score.dayStart."
    private static let clampBaseKeyPrefix = "pluri.score.clampBase."

    /// Persisted clamp anchor + last display for a user.
    struct Snapshot: Equatable, Sendable {
        /// Score the ±3 clamp uses for `dayStart`.
        var clampBase: Double
        /// Last displayed clamped score (feeds the next day's clamp base).
        var latestScore: Double
        var dayStart: Date

        /// Back-compat alias used by older call sites / tests.
        var score: Double { latestScore }
    }

    static func load(
        userID: String?,
        defaults: UserDefaults = .standard
    ) -> Snapshot? {
        let latestKey = scoreKey(forUserID: userID)
        guard defaults.object(forKey: latestKey) != nil else { return nil }
        let latest = defaults.double(forKey: latestKey)
        guard let day = defaults.object(forKey: dayKey(forUserID: userID)) as? Date else {
            return nil
        }
        let clampKey = clampBaseKey(forUserID: userID)
        let clampBase = defaults.object(forKey: clampKey) != nil
            ? defaults.double(forKey: clampKey)
            : latest
        return Snapshot(clampBase: clampBase, latestScore: latest, dayStart: day)
    }

    static func save(
        clampBase: Double,
        latestScore: Double,
        dayStart: Date,
        userID: String?,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(latestScore, forKey: scoreKey(forUserID: userID))
        defaults.set(clampBase, forKey: clampBaseKey(forUserID: userID))
        defaults.set(dayStart, forKey: dayKey(forUserID: userID))
    }

    /// Convenience for tests / first-score seeding (clamp base == latest).
    static func save(
        score: Double,
        dayStart: Date,
        userID: String?,
        defaults: UserDefaults = .standard
    ) {
        save(
            clampBase: score,
            latestScore: score,
            dayStart: dayStart,
            userID: userID,
            defaults: defaults
        )
    }

    static func clear(userID: String?, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: scoreKey(forUserID: userID))
        defaults.removeObject(forKey: dayKey(forUserID: userID))
        defaults.removeObject(forKey: clampBaseKey(forUserID: userID))
    }

    nonisolated static func scoreKey(forUserID userID: String?) -> String {
        scoreKeyPrefix + (userID ?? "anonymous")
    }

    nonisolated static func dayKey(forUserID userID: String?) -> String {
        dayKeyPrefix + (userID ?? "anonymous")
    }

    nonisolated static func clampBaseKey(forUserID userID: String?) -> String {
        clampBaseKeyPrefix + (userID ?? "anonymous")
    }
}
