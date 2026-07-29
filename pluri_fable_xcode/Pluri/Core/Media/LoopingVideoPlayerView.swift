import SwiftUI

/// Chromeless, muted, aspect-filling looping player for a locally cached MP4.
///
/// AVKit's `VideoPlayer` always brings playback chrome and letterboxes to
/// `.resizeAspect`, neither of which works for a 72pt exercise thumbnail — so
/// this drops to `AVPlayerLayer`, the narrow case AGENTS.md allows UIKit for.
/// It replaces the old GIF-decoding `UIImageView` bridge (SPEC §14 #79).
struct LoopingVideoPlayerView: UIViewRepresentable {
    var fileURL: URL
    var isPlaying: Bool

    func makeUIView(context: Context) -> LoopingVideoContainerView {
        let view = LoopingVideoContainerView()
        view.configure(fileURL: fileURL)
        view.setPlaying(isPlaying)
        return view
    }

    func updateUIView(_ uiView: LoopingVideoContainerView, context: Context) {
        uiView.configure(fileURL: fileURL)
        uiView.setPlaying(isPlaying)
    }

    static func dismantleUIView(_ uiView: LoopingVideoContainerView, coordinator: ()) {
        uiView.teardown()
    }
}
