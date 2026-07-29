import Foundation
import Testing
@testable import Pluri

/// M4-08 — disk media cache: miss fetches/writes; second read hits disk.
@Suite("ExerciseMediaCache")
struct ExerciseMediaCacheTests {

    private final class DownloadCounter: @unchecked Sendable {
        var count = 0
    }

    private struct FakeDownloader: ExerciseMediaDownloading {
        let payload: Data
        let counter: DownloadCounter

        func download(_ url: URL) async throws -> Data {
            counter.count += 1
            return payload
        }
    }

    @Test("Miss fetches and writes; second read hits disk without re-download")
    func missThenHit() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "ExerciseMediaCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let remoteURL = URL(string: "https://example.com/exercises/bench.gif")!
        let payload = Data("gif-bytes".utf8)
        let counter = DownloadCounter()
        let cache = ExerciseMediaCache(
            rootDirectory: root,
            downloader: FakeDownloader(payload: payload, counter: counter)
        )

        #expect(await cache.hasCachedFile(for: remoteURL) == false)

        let first = try await cache.data(for: remoteURL)
        #expect(first == payload)
        #expect(counter.count == 1)
        #expect(await cache.hasCachedFile(for: remoteURL))

        let second = try await cache.data(for: remoteURL)
        #expect(second == payload)
        #expect(counter.count == 1)
    }

    @Test("File-URL path downloads once, then replays from disk (SPEC §14 #79)")
    func fileURLMissThenHit() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "ExerciseMediaCacheVideo-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let remoteURL = URL(string: "https://cdn.example/exercise-media/exercises/0031.mp4")!
        let payload = Data("mp4-bytes".utf8)
        let counter = DownloadCounter()
        let cache = ExerciseMediaCache(
            rootDirectory: root,
            downloader: FakeDownloader(payload: payload, counter: counter)
        )

        let first = try await cache.localFileURL(byCaching: remoteURL)
        #expect(first.pathExtension == "mp4")
        #expect(try Data(contentsOf: first) == payload)
        #expect(counter.count == 1)

        // AVPlayer plays straight off this path, so a second request must not
        // hit the network again.
        let second = try await cache.localFileURL(byCaching: remoteURL)
        #expect(second == first)
        #expect(counter.count == 1)
    }

    @Test("Local file URL is stable for the same remote URL")
    func stableFileURL() async {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "ExerciseMediaCacheStable-\(UUID().uuidString)", directoryHint: .isDirectory)
        let cache = ExerciseMediaCache(
            rootDirectory: root,
            downloader: FakeDownloader(payload: Data(), counter: DownloadCounter())
        )
        let remote = URL(string: "https://cdn.example/a/b.gif")!
        let a = await cache.localFileURL(for: remote)
        let b = await cache.localFileURL(for: remote)
        #expect(a == b)
        #expect(a.pathExtension == "gif")
    }
}
