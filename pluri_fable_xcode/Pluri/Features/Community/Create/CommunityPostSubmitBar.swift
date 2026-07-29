import SwiftUI

struct CommunityPostSubmitBar: View {
    @Bindable var viewModel: CreateCommunityPostViewModel
    var onPosted: () -> Void

    var body: some View {
        VStack(spacing: PluriSpacing.sm) {
            if viewModel.didPost {
                Label("Posted", systemImage: "checkmark.circle.fill")
                    .font(PluriFont.label)
                    .bold()
                    .foregroundStyle(PluriColor.statusGreenDeep)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .accessibilityAddTraits(.isStaticText)
            } else {
                Button {
                    Task {
                        if await viewModel.submit() {
                            try? await Task.sleep(for: .milliseconds(700))
                            onPosted()
                        }
                    }
                } label: {
                    HStack(spacing: PluriSpacing.sm) {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(viewModel.isSubmitting ? "Posting…" : "Post")
                    }
                }
                .buttonStyle(.pluriPrimary)
                .disabled(!viewModel.canPost || viewModel.isSubmitting)
                .accessibilityHint(
                    viewModel.canPost
                        ? "Publish this Community post"
                        : "Add a title and at least three body words to post"
                )
            }
        }
        .padding(.horizontal, PluriSpacing.lg)
        .padding(.vertical, PluriSpacing.sm)
        .background(PluriColor.bgSurface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PluriColor.lineDivider)
                .frame(height: 1)
        }
        .animation(.easeInOut, value: viewModel.didPost)
    }
}
