import Foundation
import Observation
import PhotosUI
import SwiftUI

/// Create Post form logic (M8-07 / SPEC §11): Post gated on title + ≥3 body words;
/// Share Workout requires a local `WorkoutSnapshot`.
@MainActor
@Observable
final class CreateCommunityPostViewModel {
    var title = ""
    var body = ""
    var postType: CommunityPostType = .general
    var pollQuestion = ""
    var pollOptionA = ""
    var pollOptionB = ""
    var includesPoll = false
    var selectedSnapshot: WorkoutSnapshot?
    var availableSnapshots: [WorkoutSnapshot] = []
    var selectedPhotoItem: PhotosPickerItem?
    var selectedImageData: Data?
    var selectedImageContentType = "image/jpeg"
    var selectedImageExtension = "jpg"
    var isSubmitting = false
    var didPost = false
    var errorMessage: String?

    private let client: any CommunityClient
    private let onCreated: (CommunityPost) -> Void

    init(
        client: any CommunityClient,
        availableSnapshots: [WorkoutSnapshot] = [],
        onCreated: @escaping (CommunityPost) -> Void = { _ in }
    ) {
        self.client = client
        self.availableSnapshots = availableSnapshots
        self.onCreated = onCreated
    }

    var bodyWordCount: Int {
        CommunityTextRules.wordCount(in: body)
    }

    var canPost: Bool {
        guard CommunityTextRules.isValidPost(title: title, body: body) else { return false }
        if postType == .shareWorkout {
            return selectedSnapshot != nil
        }
        if includesPoll {
            let question = pollQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
            let a = pollOptionA.trimmingCharacters(in: .whitespacesAndNewlines)
            let b = pollOptionB.trimmingCharacters(in: .whitespacesAndNewlines)
            return !question.isEmpty && !a.isEmpty && !b.isEmpty
        }
        return true
    }

    func loadPhoto() async {
        guard let selectedPhotoItem else {
            selectedImageData = nil
            return
        }
        do {
            if let data = try await selectedPhotoItem.loadTransferable(type: Data.self) {
                selectedImageData = data
                selectedImageContentType = "image/jpeg"
                selectedImageExtension = "jpg"
            }
        } catch {
            errorMessage = "We couldn't load that photo. Try another one."
            selectedImageData = nil
        }
    }

    func submit() async -> Bool {
        guard canPost, !isSubmitting else { return false }
        isSubmitting = true
        didPost = false
        errorMessage = nil
        defer { isSubmitting = false }

        let poll: CreateCommunityPollDraft?
        if includesPoll {
            poll = CreateCommunityPollDraft(
                question: pollQuestion.trimmingCharacters(in: .whitespacesAndNewlines),
                options: [
                    pollOptionA.trimmingCharacters(in: .whitespacesAndNewlines),
                    pollOptionB.trimmingCharacters(in: .whitespacesAndNewlines),
                ]
            )
        } else {
            poll = nil
        }

        let image: CommunityPostImageUpload?
        if let selectedImageData {
            image = CommunityPostImageUpload(
                data: selectedImageData,
                contentType: selectedImageContentType,
                fileExtension: selectedImageExtension
            )
        } else {
            image = nil
        }

        let draft = CreateCommunityPostDraft(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            postType: postType,
            workoutSnapshot: postType == .shareWorkout ? selectedSnapshot : nil,
            poll: poll,
            image: image
        )

        do {
            let post = try await client.createPost(draft)
            didPost = true
            onCreated(post)
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "We couldn't publish that post. Check your connection and try again."
            return false
        }
    }
}

extension CommunityPostType {
    var createTitle: String {
        switch self {
        case .general: "General"
        case .gear: "Gear"
        case .recipe: "Recipe"
        case .shareWorkout: "Share Workout"
        }
    }
}
