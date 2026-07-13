import SwiftUI

/// Gallery section that runs the Supabase health check (M0-10) so connectivity
/// can be confirmed from the simulator.
struct GallerySupabaseSection: View {
    @State private var supabase = SupabaseService()

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.md) {
            GallerySectionHeader(title: "Supabase")
            PluriCard {
                HStack(spacing: PluriSpacing.sm) {
                    statusIndicator
                    Text(statusText)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                    Spacer()
                    Button("Check", systemImage: "arrow.clockwise") {
                        Task { await supabase.checkHealth() }
                    }
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.brandOrange)
                }
            }
        }
        .task {
            await supabase.checkHealth()
        }
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
    }

    private var statusColor: Color {
        switch supabase.healthStatus {
        case .unknown, .checking: PluriColor.textTertiary
        case .reachable: PluriColor.statusGreen
        case .unreachable: PluriColor.statusRedSoft
        }
    }

    private var statusText: String {
        switch supabase.healthStatus {
        case .unknown: String(localized: "Not checked")
        case .checking: String(localized: "Checking…")
        case .reachable: String(localized: "Reachable")
        case .unreachable(let message): message
        }
    }
}

#Preview {
    GallerySupabaseSection()
        .padding()
        .background(PluriColor.bgCanvas)
}
