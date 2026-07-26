import ImageIO
import SwiftUI
import UIKit

/// Loads exercise image/GIF via `ExerciseMediaCache`, so offline sessions still
/// show previously seen assets (M4-08). Animates multi-frame GIFs when present.
struct CachedExerciseMediaView: View {
    var remoteURL: URL?
    var cache: ExerciseMediaCache = .shared

    @State private var image: UIImage?
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            PluriColor.bgMuted
            if let image {
                AnimatedExerciseImageView(image: image)
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
            image = Self.makeImage(from: data)
            if image == nil {
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

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.image = image
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = image
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
