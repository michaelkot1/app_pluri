import SwiftUI

/// Report reason picker (M8-11) — gentle confirmation after selection.
struct CommunityReportSheet: View {
    var onSelect: (CommunityReportReason) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(CommunityReportReason.allCases) { reason in
                        Button(reason.title) {
                            onSelect(reason)
                            dismiss()
                        }
                        .frame(minHeight: 44)
                        .foregroundStyle(PluriColor.textPrimary)
                    }
                } footer: {
                    Text("We'll hide this post for you and review the report when we can.")
                }
            }
            .font(PluriFont.body)
            .scrollContentBackground(.hidden)
            .background(PluriColor.bgCanvas)
            .navigationTitle("Report post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview("Report sheet") {
    CommunityReportSheet { _ in }
}
