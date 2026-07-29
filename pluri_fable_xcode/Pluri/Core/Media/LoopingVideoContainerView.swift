import AVFoundation
import UIKit

/// Hosts an `AVPlayerLayer` that loops one local file muted, aspect-filled, and
/// without playback chrome. Driven by `LoopingVideoPlayerView`.
///
/// `AVPlayerLooper` needs an `AVQueuePlayer`, and both must stay alive for the
/// loop to keep running — hence a view that owns them rather than a value type.
final class LoopingVideoContainerView: UIView {
    private let queuePlayer = AVQueuePlayer()
    private let playerLayer = AVPlayerLayer()
    private var looper: AVPlayerLooper?
    private var currentFileURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)

        // Exercise media is decoration inside a Button-backed card; it must
        // never intercept the tap that opens the detail sheet.
        isUserInteractionEnabled = false

        queuePlayer.isMuted = true
        queuePlayer.preventsDisplaySleepDuringVideoPlayback = false
        playerLayer.player = queuePlayer
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        preconditionFailure("LoopingVideoContainerView is created in code only")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    /// Points the loop at `fileURL`, rebuilding the looper only when the source
    /// actually changed so a redraw can't restart playback from frame zero.
    func configure(fileURL: URL) {
        guard currentFileURL != fileURL else { return }
        currentFileURL = fileURL

        looper?.disableLooping()
        queuePlayer.removeAllItems()
        looper = AVPlayerLooper(player: queuePlayer, templateItem: AVPlayerItem(url: fileURL))
    }

    func setPlaying(_ isPlaying: Bool) {
        if isPlaying {
            queuePlayer.play()
        } else {
            queuePlayer.pause()
        }
    }

    /// Releases the loop when the SwiftUI view goes away, so a scrolled-off
    /// card stops decoding immediately instead of at the next ARC sweep.
    func teardown() {
        queuePlayer.pause()
        looper?.disableLooping()
        looper = nil
        queuePlayer.removeAllItems()
        currentFileURL = nil
    }
}
