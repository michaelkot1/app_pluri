import SwiftUI

struct CommunityPostComposerIntroView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Label("Share with Community", systemImage: "person.3.fill")
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)
            Text("Ask a question, celebrate progress, or help someone on their path.")
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textSecondary)
        }
        .padding(.vertical, PluriSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}
