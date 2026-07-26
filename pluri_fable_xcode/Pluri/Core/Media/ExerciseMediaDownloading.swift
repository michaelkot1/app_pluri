import Foundation

/// Downloads raw exercise media bytes (GIF/image) for the disk cache (M4-08).
protocol ExerciseMediaDownloading: Sendable {
    func download(_ url: URL) async throws -> Data
}

/// Live `URLSession` downloader used in production.
struct URLSessionExerciseMediaDownloader: ExerciseMediaDownloading {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func download(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ExerciseMediaCacheError.downloadFailed(statusCode: http.statusCode)
        }
        return data
    }
}

enum ExerciseMediaCacheError: Error, Equatable {
    case downloadFailed(statusCode: Int)
}
