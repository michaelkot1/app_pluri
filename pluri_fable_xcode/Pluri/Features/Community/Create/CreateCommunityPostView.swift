import PhotosUI
import SwiftUI

/// Create Post sheet (M8-07 / SPEC §11).
struct CreateCommunityPostView: View {
    @Bindable var viewModel: CreateCommunityPostViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Post type", selection: $viewModel.postType) {
                        ForEach(CommunityPostType.allCases, id: \.self) { type in
                            Text(type.createTitle).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Post") {
                    TextField("Title", text: $viewModel.title)
                        .font(PluriFont.body)
                        .accessibilityLabel("Post title")
                    TextField("Body", text: $viewModel.body, axis: .vertical)
                        .lineLimit(4...10)
                        .font(PluriFont.body)
                        .accessibilityLabel("Post body")
                    Text("\(viewModel.bodyWordCount) words · need \(CommunityTextRules.minimumBodyWordCount)")
                        .font(PluriFont.overline)
                        .foregroundStyle(PluriColor.textTertiary)
                        .accessibilityLabel(
                            "\(viewModel.bodyWordCount) words, need \(CommunityTextRules.minimumBodyWordCount)"
                        )
                }

                if viewModel.postType == .shareWorkout {
                    Section("Workout") {
                        if viewModel.availableSnapshots.isEmpty {
                            Text("Complete a workout first, then share a snapshot from here.")
                                .font(PluriFont.body)
                                .foregroundStyle(PluriColor.textSecondary)
                        } else {
                            Picker("Session", selection: $viewModel.selectedSnapshot) {
                                Text("Choose a workout").tag(Optional<WorkoutSnapshot>.none)
                                ForEach(viewModel.availableSnapshots, id: \.sessionId) { snapshot in
                                    Text(snapshot.title ?? "Workout")
                                        .tag(Optional(snapshot))
                                }
                            }
                        }
                    }
                }

                Section("Optional") {
                    PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                        Label(
                            viewModel.selectedImageData == nil ? "Add photo" : "Change photo",
                            systemImage: "photo"
                        )
                        .frame(minHeight: 44)
                    }
                    .onChange(of: viewModel.selectedPhotoItem) { _, _ in
                        Task { await viewModel.loadPhoto() }
                    }

                    Toggle("Add a poll", isOn: $viewModel.includesPoll)
                        .tint(PluriColor.brandOrange)

                    if viewModel.includesPoll {
                        TextField("Question", text: $viewModel.pollQuestion)
                        TextField("Option A", text: $viewModel.pollOptionA)
                        TextField("Option B", text: $viewModel.pollOptionB)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(PluriFont.body)
                            .foregroundStyle(PluriColor.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PluriColor.bgCanvas)
            .navigationTitle("Create post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task {
                            if await viewModel.submit() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canPost || viewModel.isSubmitting)
                    .bold()
                    .accessibilityHint(
                        viewModel.canPost
                            ? "Publish this Community post"
                            : "Add a title and at least three body words to post"
                    )
                }
            }
        }
    }
}

#Preview("Can post") {
    CreateCommunityPostPreviewHost(canPost: true)
}

#Preview("Can't post") {
    CreateCommunityPostPreviewHost(canPost: false)
}

private struct CreateCommunityPostPreviewHost: View {
    @State private var viewModel: CreateCommunityPostViewModel

    init(canPost: Bool) {
        let vm = CreateCommunityPostViewModel(client: MockCommunityClient(posts: []))
        if canPost {
            vm.title = "Rest day tips"
            vm.body = "one two three"
        } else {
            vm.title = "Almost"
            vm.body = "too short"
        }
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        CreateCommunityPostView(viewModel: viewModel)
    }
}
