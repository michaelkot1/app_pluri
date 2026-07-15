import SwiftUI

/// Soft shadow levels per design.md §6.
enum PluriElevation {
    case card
    case floating
    case primaryCTA
}

extension View {
    /// Applies one of the design-system elevation shadows.
    func pluriShadow(_ elevation: PluriElevation, tint: Color = .black) -> some View {
        switch elevation {
        case .card:
            // Elevation 1: 0 2px 8px rgba(0,0,0,0.05)
            return shadow(color: tint.opacity(0.05), radius: 8, x: 0, y: 2)
        case .floating:
            // Elevation 2: 0 8px 24px rgba(0,0,0,0.10)
            return shadow(color: tint.opacity(0.10), radius: 24, x: 0, y: 8)
        case .primaryCTA:
            // Elevation 3: subtle tinted glow signaling tappability.
            return shadow(color: tint.opacity(0.35), radius: 12, x: 0, y: 4)
        }
    }
}
