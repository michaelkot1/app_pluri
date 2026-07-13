import SwiftUI

/// Root of the app: Splash → Onboarding (M1). Later milestones extend this
/// into the full Splash → Onboarding → Paywall → Main router (PLAN §1.2).
struct AppRootView: View {
    #if DEBUG
    @State private var showsDebugGallery = false
    #endif

    var body: some View {
        OnboardingRootView()
        #if DEBUG
            .overlay(alignment: .topTrailing) {
                Button("Gallery", systemImage: "paintpalette") {
                    showsDebugGallery = true
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(PluriColor.textTertiary)
                .padding()
            }
            .sheet(isPresented: $showsDebugGallery) {
                ComponentGalleryView()
            }
        #endif
    }
}

#Preview {
    AppRootView()
}
