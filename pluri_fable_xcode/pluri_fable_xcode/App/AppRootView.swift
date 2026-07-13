import SwiftUI

/// Root of the app. During M0 this shows the component gallery;
/// later milestones replace it with the Splash → Onboarding → Main router.
struct AppRootView: View {
    var body: some View {
        ComponentGalleryView()
    }
}

#Preview {
    AppRootView()
}
