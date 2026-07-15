import SwiftUI

/// Debug screen rendering every design-system token and component (M0-08).
/// Doubles as the M0 exit-criteria "themed placeholder screen".
struct ComponentGalleryView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PluriSpacing.xl) {
                    GallerySupabaseSection()
                    GalleryTypographySection()
                    GalleryColorSection()
                    GalleryComponentSection()
                }
                .padding(PluriSpacing.lg)
            }
            .background(PluriColor.bgCanvas)
            .navigationTitle("Pluri Gallery")
        }
    }
}

struct GallerySectionHeader: View {
    var title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(PluriFont.sectionHeader)
            .foregroundStyle(PluriColor.textPrimary)
    }
}

struct GalleryTypographySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.md) {
            GallerySectionHeader(title: "Typography")
            PluriCard {
                VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                    PluriHeroNumeral(text: "12,408")
                    Text("147 kcal")
                        .font(PluriFont.displayNumeral)
                        .foregroundStyle(PluriColor.textPrimary)
                    Text("Go Gentler")
                        .font(PluriFont.title)
                        .foregroundStyle(PluriColor.textPrimary)
                    Text("Wellness")
                        .font(PluriFont.sectionHeader)
                        .foregroundStyle(PluriColor.textPrimary)
                    Text("Body copy that guides gently and never scolds.")
                        .font(PluriFont.body)
                        .foregroundStyle(PluriColor.textSecondary)
                    Text("Total Distance")
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                    Text("Energy")
                        .font(PluriFont.overline)
                        .textCase(.uppercase)
                        .kerning(1)
                        .foregroundStyle(PluriColor.textTertiary)
                }
            }
        }
    }
}

struct GalleryColorSection: View {
    private let swatches: [(String, Color)] = [
        ("brand/orange", PluriColor.brandOrange),
        ("brand/orange-deep", PluriColor.brandOrangeDeep),
        ("brand/coral-soft", PluriColor.brandCoralSoft),
        ("sunrise/core", PluriColor.sunriseCore),
        ("sunrise/mid", PluriColor.sunriseMid),
        ("sunrise/edge", PluriColor.sunriseEdge),
        ("status/green", PluriColor.statusGreen),
        ("status/green-deep", PluriColor.statusGreenDeep),
        ("status/red-soft", PluriColor.statusRedSoft),
        ("status/blue", PluriColor.statusBlue),
        ("accent/pink", PluriColor.accentPink),
        ("accent/lavender", PluriColor.accentLavender),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.md) {
            GallerySectionHeader(title: "Colors")
            PluriCard {
                VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                    ForEach(swatches, id: \.0) { name, color in
                        HStack(spacing: PluriSpacing.sm) {
                            RoundedRectangle(cornerRadius: PluriRadius.sm)
                                .fill(color)
                                .frame(width: 44, height: 28)
                            Text(name)
                                .font(PluriFont.label)
                                .foregroundStyle(PluriColor.textSecondary)
                        }
                    }
                    HStack(spacing: PluriSpacing.xs) {
                        ForEach(PluriColor.zones.indices, id: \.self) { index in
                            RoundedRectangle(cornerRadius: PluriRadius.sm)
                                .fill(PluriColor.zones[index])
                                .frame(height: 28)
                        }
                    }
                    Text("Heart-rate zones 0–5")
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                }
            }
            RoundedRectangle(cornerRadius: PluriRadius.lg)
                .fill(PluriColor.sunriseGradient)
                .frame(height: 120)
                .overlay {
                    Text("Sunrise Glow")
                        .font(PluriFont.title)
                        .foregroundStyle(PluriColor.brandOrangeDeep)
                }
        }
    }
}

struct GalleryComponentSection: View {
    @State private var fitnessType = "Workout"
    @State private var progress = 0.35
    @State private var showSheet = false

    private let fitnessOptions = ["Workout", "Cardio", "Flexibility"]

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.md) {
            GallerySectionHeader(title: "Components")

            PluriProgressBar(value: progress)

            HStack(spacing: PluriSpacing.sm) {
                ForEach(fitnessOptions, id: \.self) { option in
                    PluriChip(
                        title: LocalizedStringKey(option),
                        isSelected: fitnessType == option,
                        isEnabled: option == "Workout"
                    ) {
                        fitnessType = option
                    }
                }
            }

            Button("Primary Action") {
                progress = progress >= 1 ? 0.1 : progress + 0.25
            }
            .buttonStyle(.pluriPrimary)

            Button("Secondary Action") {
                showSheet = true
            }
            .buttonStyle(.pluriSecondary)
        }
        .pluriBottomSheet(isPresented: $showSheet) {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                Text("Bottom Sheet")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)
                Text("Elevation-2 sheet with rounded top corners and a drag indicator.")
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
                Spacer()
            }
            .padding(PluriSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("Light") {
    ComponentGalleryView()
}

#Preview("Dark") {
    ComponentGalleryView()
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XL") {
    ComponentGalleryView()
        .environment(\.dynamicTypeSize, .accessibility2)
}
