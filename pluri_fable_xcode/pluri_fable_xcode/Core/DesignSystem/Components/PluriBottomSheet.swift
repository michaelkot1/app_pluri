import SwiftUI

/// Wrapper for presenting content as a Pluri-styled bottom sheet:
/// rounded top corners (radius/xl), surface background, visible drag indicator,
/// medium/large detents by default.
struct PluriBottomSheet<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    var detents: Set<PresentationDetent> = [.medium, .large]
    @ViewBuilder var sheetContent: SheetContent

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            sheetContent
                .presentationDetents(detents)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(PluriRadius.xl)
                .presentationBackground(PluriColor.bgSurface)
        }
    }
}

extension View {
    /// Presents a Pluri-styled bottom sheet (design.md §6, elevation 2).
    func pluriBottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium, .large],
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        modifier(PluriBottomSheet(isPresented: isPresented, detents: detents, sheetContent: content))
    }
}

#Preview {
    @Previewable @State var showSheet = true

    return Button("Show Sheet") {
        showSheet = true
    }
    .buttonStyle(.pluriPrimary)
    .padding(PluriSpacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(PluriColor.bgCanvas)
    .pluriBottomSheet(isPresented: $showSheet) {
        VStack(alignment: .leading, spacing: PluriSpacing.md) {
            Text("Workout Notes")
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)
            Text("A quick place to jot down how the session felt.")
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textSecondary)
            Spacer()
        }
        .padding(PluriSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
