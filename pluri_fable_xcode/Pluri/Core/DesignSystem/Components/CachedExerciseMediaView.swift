import ImageIO
import SwiftUI
import UIKit

/// Loads exercise image/GIF via `ExerciseMediaCache`, so offline sessions still
/// show previously seen assets (M4-08). Animates multi-frame GIFs when present.
struct CachedExerciseMediaView: View {
    var remoteURL: URL?
    var cache: ExerciseMediaCache = .shared

    @Environment(\.exerciseMediaAnimationEnabled) private var animationEnabled

    @State private var image: UIImage?
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            PluriColor.bgMuted
            if let image {
                AnimatedExerciseImageView(image: image, isAnimating: animationEnabled)
                    .scaledToFill()
            } else if loadFailed || remoteURL == nil {
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
        .task(id: remoteURL?.absoluteString) {
            await load()
        }
    }

    private func load() async {
        image = nil
        loadFailed = false
        guard let remoteURL else {
            loadFailed = true
            return
        }

        do {
            let data = try await cache.data(for: remoteURL)
            // GIF frame decode is expensive; keep it off the main actor so a
            // scrolling workout list never stalls on it (SPEC §14 #76).
            let decoded = await Task.detached(priority: .utility) {
                Self.makeImage(from: data)
            }.value
            image = decoded
            if decoded == nil {
                loadFailed = true
            }
        } catch {
            loadFailed = true
        }
    }

    /// Builds a still or animated `UIImage` from cached bytes (GIF-friendly).
    nonisolated static func makeImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else {
            return UIImage(data: data)
        }

        var frames: [UIImage] = []
        var duration: TimeInterval = 0
        frames.reserveCapacity(count)

        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                continue
            }
            frames.append(UIImage(cgImage: cgImage))
            duration += frameDuration(at: index, source: source)
        }

        guard !frames.isEmpty else { return UIImage(data: data) }
        if duration <= 0 {
            duration = Double(frames.count) * 0.1
        }
        return UIImage.animatedImage(with: frames, duration: duration)
    }

    nonisolated private static func frameDuration(at index: Int, source: CGImageSource) -> TimeInterval {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else {
            return 0.1
        }

        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double
        let value = unclamped ?? clamped ?? 0.1
        return value < 0.02 ? 0.1 : value
    }
}

/// Thin UIKit bridge so multi-frame GIF `UIImage`s actually animate.
private struct AnimatedExerciseImageView: UIViewRepresentable {
    var image: UIImage
    var isAnimating: Bool

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        apply(to: view)
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        apply(to: uiView)
    }

    /// Re-assigning an animated `UIImage` restarts its animation from frame
    /// zero, so only touch the view's images when the source actually changed.
    /// Frames go on `animationImages` and the still frame on `image`, which
    /// makes start/stop explicit instead of implicit in the assignment.
    private func apply(to uiView: UIImageView) {
        let frames = image.images
        let stillFrame = frames?.first ?? image
        if uiView.image !== stillFrame {
            uiView.image = stillFrame
            uiView.animationImages = frames
            uiView.animationDuration = image.duration
            uiView.animationRepeatCount = 0
        }

        guard frames != nil else { return }
        if isAnimating {
            if !uiView.isAnimating {
                uiView.startAnimating()
            }
        } else if uiView.isAnimating {
            uiView.stopAnimating()
        }
    }
}

#if DEBUG
#Preview {
    CachedExerciseMediaView(remoteURL: nil)
        .frame(width: 88, height: 88)
        .clipShape(.rect(cornerRadius: PluriRadius.md))
        .padding()
        .background(PluriColor.bgCanvas)
}
#endif
