import SwiftUI

/// Design-system color tokens, mirroring design.md §2 one-to-one.
/// Backed by asset-catalog colorsets (`Assets.xcassets/PluriColors`) so every
/// token carries a dark-mode variant.
enum PluriColor {
    // MARK: Brand

    /// Primary brand color — logo, active tab, primary CTAs, key accents.
    static let brandOrange = Color("BrandOrange")
    /// Pressed/darker orange, on-glow text over warm gradients.
    static let brandOrangeDeep = Color("BrandOrangeDeep")
    /// Softer coral for highlights and secondary accents.
    static let brandCoralSoft = Color("BrandCoralSoft")

    // MARK: Sunrise gradient (hero)

    static let sunriseCore = Color("SunriseCore")
    static let sunriseMid = Color("SunriseMid")
    static let sunriseEdge = Color("SunriseEdge")

    /// The radial hero glow used behind celebratory/focal metrics.
    static let sunriseGradient = RadialGradient(
        colors: [sunriseCore, sunriseMid, sunriseEdge],
        center: .center,
        startRadius: 0,
        endRadius: 220
    )

    // MARK: Status / activity path

    /// "On path" / optimal / rest & active-recovery success.
    static let statusGreen = Color("StatusGreen")
    /// Rest CTA buttons, positive emphasis.
    static let statusGreenDeep = Color("StatusGreenDeep")
    /// "Too high" / overexertion — gentle, not alarming.
    static let statusRedSoft = Color("StatusRedSoft")
    /// Recovery / calorie ring / cool accent.
    static let statusBlue = Color("StatusBlue")

    // MARK: Heart-rate zones

    static let zone0 = Color("Zone0")
    static let zone1 = Color("Zone1")
    static let zone2 = Color("Zone2")
    static let zone3 = Color("Zone3")
    static let zone4 = Color("Zone4")
    static let zone5 = Color("Zone5")

    static let zones: [Color] = [zone0, zone1, zone2, zone3, zone4, zone5]

    // MARK: Accent surfaces

    /// Playful full-bleed card accent.
    static let accentPink = Color("AccentPink")
    /// Cool onboarding / go-gentler background.
    static let accentLavender = Color("AccentLavender")

    // MARK: Neutrals

    /// App background (warm off-white/cream).
    static let bgCanvas = Color("BgCanvas")
    /// Cards, sheets, tab bar.
    static let bgSurface = Color("BgSurface")
    /// Inset rows, secondary chips.
    static let bgMuted = Color("BgMuted")
    /// Headlines, big numerals.
    static let textPrimary = Color("TextPrimary")
    /// Labels, captions, metadata.
    static let textSecondary = Color("TextSecondary")
    /// Disabled, "No Data", axis labels.
    static let textTertiary = Color("TextTertiary")
    /// Hairline separators, chart gridlines.
    static let lineDivider = Color("LineDivider")
}
