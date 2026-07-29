import CryptoKit
import Foundation

/// Disk cache for exercise media under `URL.cachesDirectory` (M4-08 / SPEC §13).
/// Offline sessions can still show previously seen media. Since SPEC §14 #79 the
/// payload is a mirrored MP4 loop rather than a WorkoutX GIF, so callers mostly
/// want `localFileURL(byCaching:)` — `AVPlayer` plays straight off disk.
actor ExerciseMediaCache {
    private let rootDirectory: URL
    private let downloader: any ExerciseMediaDownloading
    private let fileManager: FileManager

    /// Process-wide default used by `CachedExerciseMediaView`.
    static let shared = ExerciseMediaCache()

    init(
        rootDirectory: URL = URL.cachesDirectory.appending(path: "ExerciseMedia", directoryHint: .isDirectory),
        downloader: any ExerciseMediaDownloading = URLSessionExerciseMediaDownloader(),
        fileManager: FileManager = .default
    ) {
        self.rootDirectory = rootDirectory
        self.downloader = downloader
        self.fileManager = fileManager
    }

    /// Returns cached bytes, fetching and writing on miss.
    func data(for remoteURL: URL) async throws -> Data {
        let fileURL = localFileURL(for: remoteURL)
        if let cached = try? Data(contentsOf: fileURL), !cached.isEmpty {
            return cached
        }

        let downloaded = try await downloader.download(remoteURL)
        try ensureRootDirectory()
        try downloaded.write(to: fileURL, options: .atomic)
        return downloaded
    }

    /// On-disk location of the media, downloading it first if needed. Handing
    /// `AVPlayer` a file URL keeps the bytes out of memory and means a cached
    /// exercise plays with no network at all.
    func localFileURL(byCaching remoteURL: URL) async throws -> URL {
        let fileURL = localFileURL(for: remoteURL)
        if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path(percentEncoded: false)),
           let size = attributes[.size] as? Int,
           size > 0 {
            return fileURL
        }

        let downloaded = try await downloader.download(remoteURL)
        try ensureRootDirectory()
        try downloaded.write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// Whether a completed file already exists on disk (tests + diagnostics).
    func hasCachedFile(for remoteURL: URL) -> Bool {
        fileManager.fileExists(atPath: localFileURL(for: remoteURL).path(percentEncoded: false))
    }

    func localFileURL(for remoteURL: URL) -> URL {
        let digest = SHA256.hash(data: Data(remoteURL.absoluteString.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let ext = remoteURL.pathExtension.isEmpty ? "bin" : remoteURL.pathExtension
        return rootDirectory.appending(path: "\(hex).\(ext)")
    }

    private func ensureRootDirectory() throws {
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }
}
