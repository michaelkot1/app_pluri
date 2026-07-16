import Foundation

/// Legal destinations linked from Profile (SPEC §5.2).
enum LegalLinks {
    /// Apple's standard EULA — interim Terms & Conditions until Pluri hosts
    /// its own terms page (SPEC §14 #35; open question in §15).
    static let termsAndConditions = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
