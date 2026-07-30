import SwiftData
import SwiftUI

/// Manage Plan (M3-14 / SPEC §6.2): edit goal, start date, plan length /
/// end date, training days, session duration, and units. Saving a
/// plan-affecting change regenerates the remaining plan with `PlanEngine`
/// (completed/skipped history is preserved, SPEC §14 #39) and persists
/// everything atomically via the `replace_remaining_plan` RPC; a units-only
/// change persists without regeneration.
struct ManagePlanView: View {
    @Environment(PlanStore.self) private var planStore

    var body: some View {
        Group {
            if let plan = planStore.plan, let profile = planStore.profile {
                ManagePlanForm(profile: profile, plan: plan)
            } else {
                MissingPlanMessage()
            }
        }
        .background(PluriColor.bgCanvas)
        .navigationTitle("Manage Plan")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Gentle body for the states where there's nothing to manage.
private struct MissingPlanMessage: View {
    @Environment(PlanStore.self) private var planStore

    var body: some View {
        ScrollView {
            HomeMessageCard(
                title: planStore.loadState == .failed ? "We couldn't load your plan" : "No active plan yet",
                message: planStore.loadState == .failed
                    ? "Check your connection and relaunch — your plan is safe on your account."
                    : "We couldn't find an active plan on your account, so there's nothing to manage here."
            )
            .padding(PluriSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }
}

/// The editable form, created once the plan + profile snapshot is known.
private struct ManagePlanForm: View {
    @State private var viewModel: ManagePlanViewModel
    @State private var isSaving = false
    @State private var errorMessage: String?

    @Environment(PlanStore.self) private var planStore
    @Environment(SupabaseAuthService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    init(profile: RestoredProfile, plan: GeneratedPlan) {
        _viewModel = State(initialValue: ManagePlanViewModel(profile: profile, plan: plan))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                ManagePlanGoalCard(viewModel: viewModel)
                ManagePlanDatesCard(viewModel: viewModel)
                ManagePlanTrainingDaysCard(viewModel: viewModel)
                ManagePlanDurationCard(viewModel: viewModel)
                ManagePlanUnitsCard(viewModel: viewModel)

                Text("Saving rebuilds the rest of your plan around these settings. Workouts you've already completed or skipped stay exactly where they are.")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textTertiary)

                if let errorMessage {
                    Text(errorMessage)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                }

                Button(isSaving ? "Saving…" : "Save changes") {
                    Task { await save() }
                }
                .buttonStyle(.pluriPrimary)
                .disabled(!viewModel.hasChanges || isSaving)
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }

    /// Regenerating save for plan-affecting edits; profile-only persistence
    /// for a units-only change. Both roll back locally on remote failure —
    /// we just surface the gentle message here.
    private func save() async {
        errorMessage = nil

        guard viewModel.hasPlanAffectingChanges else {
            await saveUnitsOnly()
            return
        }

        if let message = viewModel.regenerationValidationMessage {
            errorMessage = message
            return
        }
        guard let input = viewModel.planInput() else {
            errorMessage = viewModel.regenerationValidationMessage
            return
        }

        isSaving = true
        defer { isSaving = false }
        do {
            // Catalog reads come from the Supabase-seeded snapshot, matching
            // onboarding generation (SPEC §14 #25).
            let generationService = PlanGenerationService(
                store: ExerciseCatalogStore(
                    modelContext: modelContext,
                    client: SupabaseExerciseCatalogClient()
                )
            )
            let regenerated = try await generationService.generatePlan(for: input)
            try await planStore.applyManagePlan(
                editedProfile: viewModel.editedProfile(),
                regenerated: regenerated
            )
            dismiss()
        } catch {
            errorMessage = PlanChangeErrorMessage.message(for: error)
        }
    }

    private func saveUnitsOnly() async {
        guard let idString = authService.appUserID, let userID = UUID(uuidString: idString) else {
            errorMessage = PlanMutationError.missingUser.userFacingMessage
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await planStore.updateProfileSettings(
                userID: userID,
                editedProfile: viewModel.editedProfile()
            )
            dismiss()
        } catch {
            errorMessage = PlanChangeErrorMessage.message(for: error)
        }
    }
}

/// Goal picker (Q2 options).
private struct ManagePlanGoalCard: View {
    @Bindable var viewModel: ManagePlanViewModel

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text("Goal")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                PluriChipGrid(
                    items: Goal.allCases,
                    isSelected: { viewModel.goal == $0 },
                    label: \.title,
                    action: { viewModel.goal = $0 }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Start date, plan length, and the derived end date (SPEC §14 date rule).
private struct ManagePlanDatesCard: View {
    @Bindable var viewModel: ManagePlanViewModel

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text("Dates & length")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                DatePicker(
                    "Start date",
                    selection: Binding(
                        get: { viewModel.startDate },
                        set: { viewModel.updateStartDate($0) }
                    ),
                    displayedComponents: .date
                )
                .font(PluriFont.body)
                .tint(PluriColor.brandOrange)

                VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                    HStack {
                        Text("Plan length")
                            .font(PluriFont.body)
                            .foregroundStyle(PluriColor.textPrimary)
                        Spacer()
                        Text("\(viewModel.planLengthWeeks) weeks")
                            .font(PluriFont.metricValue)
                            .foregroundStyle(PluriColor.brandOrange)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.planLengthWeeks) },
                            set: { viewModel.updatePlanLength(weeks: Int($0.rounded())) }
                        ),
                        in: Double(ManagePlanViewModel.supportedWeeks.lowerBound)...Double(ManagePlanViewModel.supportedWeeks.upperBound),
                        step: 1
                    )
                    .tint(PluriColor.brandOrange)
                    .accessibilityLabel("Plan length in weeks")
                }

                DatePicker(
                    "End date",
                    selection: Binding(
                        get: { viewModel.endDate },
                        set: { viewModel.updateEndDate($0) }
                    ),
                    in: viewModel.endDateRange,
                    displayedComponents: .date
                )
                .font(PluriFont.body)
                .tint(PluriColor.brandOrange)

                Text("The end date follows your start date and plan length; picking an end date rounds the plan to whole weeks.")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Training-day picker (Q8: 2–6 days).
private struct ManagePlanTrainingDaysCard: View {
    @Bindable var viewModel: ManagePlanViewModel

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text("Training days")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                PluriChipGrid(
                    items: Weekday.displayOrder,
                    isSelected: { viewModel.trainingDays.contains($0) },
                    label: \.shortTitle,
                    action: { viewModel.toggleTrainingDay($0) }
                )

                Text("Pick 2 to 6 days a week.")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Session duration picker (Q10 options).
private struct ManagePlanDurationCard: View {
    @Bindable var viewModel: ManagePlanViewModel

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text("Workout length")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                PluriChipGrid(
                    items: SessionDuration.allCases,
                    isSelected: { viewModel.sessionDuration == $0 },
                    label: \.title,
                    action: { viewModel.sessionDuration = $0 }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Units of measure — a display preference; storage stays metric.
private struct ManagePlanUnitsCard: View {
    @Bindable var viewModel: ManagePlanViewModel

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text("Units")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                PluriChipGrid(
                    items: [false, true],
                    isSelected: { viewModel.usesImperialUnits == $0 },
                    label: { $0 ? "Imperial (lb, ft)" : "Metric (kg, cm)" },
                    action: { viewModel.usesImperialUnits = $0 }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#if DEBUG
#Preview("Ready") {
    NavigationStack {
        ManagePlanView()
    }
    .environment(HomePreviewData.readyStore())
    .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
    .modelContainer(for: [CachedExercise.self, ExerciseCatalogSyncState.self], inMemory: true)
}

#Preview("Empty") {
    NavigationStack {
        ManagePlanView()
    }
    .environment(HomePreviewData.emptyStore())
    .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
    .modelContainer(for: [CachedExercise.self, ExerciseCatalogSyncState.self], inMemory: true)
}
#endif
