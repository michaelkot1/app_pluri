import CryptoKit
import Foundation

/// Disk cache for exercise GIF/image assets under `URL.cachesDirectory`
/// (M4-08 / SPEC §13). Offline sessions can still show previously seen media.
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
