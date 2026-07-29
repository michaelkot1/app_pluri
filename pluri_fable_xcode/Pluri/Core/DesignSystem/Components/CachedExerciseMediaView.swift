import SwiftUI

/// Plays an exercise's mirrored MP4 loop, caching it on disk via
/// `ExerciseMediaCache` so offline sessions still show previously seen media
/// (M4-08 / SPEC §14 #79).
///
/// Exercises the mirror job hasn't covered yet have no `videoURL`, and show the
/// same honest placeholder as a failed load — never a broken frame.
struct CachedExerciseMediaView: View {
    var videoURL: URL?
    var cache: ExerciseMediaCache = .shared

    @Environment(\.exerciseMediaAnimationEnabled) private var animationEnabled

    @State private var localFileURL: URL?
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            PluriColor.bgMuted
            if let localFileURL {
                LoopingVideoPlayerView(fileURL: localFileURL, isPlaying: animationEnabled)
            } else if loadFailed || videoURL == nil {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textTertiary)
                    .accessibilityHidden(true)
            } else {
                ProgressView()
                    .tint(PluriColor.brandOrange)
            }
        }
        .clipped()
        .task(id: videoURL?.absoluteString) {
            await load()
        }
    }

    private func load() async {
        localFileURL = nil
        loadFailed = false
        guard let videoURL else {
            loadFailed = true
            return
        }

        do {
            localFileURL = try await cache.localFileURL(byCaching: videoURL)
        } catch {
            loadFailed = true
        }
    }
}

#if DEBUG
#Preview {
    CachedExerciseMediaView(videoURL: nil)
        .frame(width: 88, height: 88)
        .clipShape(.rect(cornerRadius: PluriRadius.md))
        .padding()
        .background(PluriColor.bgCanvas)
}
#endif
