import SwiftUI

/// The reusable Calendar page (M3-13 / SPEC §5.4), reached from Home's
/// calendar button and from Plan as "Rearrange Workouts" (§6) — it stays in
/// whichever stack opened it. Week-by-week layout: every dated workout on
/// its day, add-workout affordances on empty days, the week's flexible pool
/// labeled honestly ("Anytime this week", SPEC §14 #37), and button/sheet
/// move + add flows with optimistic updates and gentle rollback feedback.
struct CalendarView: View {
    /// "Calendar" from Home, "Rearrange Workouts" from Plan.
    var title: String

    @Environment(PlanStore.self) private var planStore

    @State private var viewModel = CalendarViewModel()
    @State private var activeSheet: CalendarSheet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                switch planStore.loadState {
                case .loading:
                    CalendarLoadingIndicator()
                case .failed:
                    HomeMessageCard(
                        title: "We couldn't load your plan",
                        message: "Check your connection and relaunch — your plan is safe on your account."
                    )
                case .empty:
                    HomeMessageCard(
                        title: "No active plan yet",
                        message: "We couldn't find an active plan on your account, so there's nothing to arrange here."
                    )
                case .ready:
                    if let plan = planStore.plan {
                        CalendarWeekContent(plan: plan, viewModel: viewModel) { sheet in
                            activeSheet = sheet
                        }
                    }
                }
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .background(PluriColor.bgCanvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: CalendarSheet) -> some View {
        if let plan = planStore.plan {
            switch sheet {
            case .move(let session):
                CalendarDayPickerSheet(
                    workoutTitle: session.title,
                    range: planWindow(for: plan),
                    initialDate: session.date ?? planStore.today,
                    confirmTitle: session.date == nil ? "Assign to this day" : "Move here",
                    onConfirm: { date in await moveWorkout(session, to: date) }
                )
            case .add(let date):
                CalendarSourcePickerSheet(
                    date: date,
                    sources: plan.weeks.flatMap(\.sessions),
                    onConfirm: { sourceID in await addWorkout(cloning: sourceID, on: date) }
                )
            }
        }
    }

    private func planWindow(for plan: GeneratedPlan) -> ClosedRange<Date> {
        let start = plan.startDate
        let end = max(plan.endDate, start)
        return start...end
    }

    /// Optimistic move via the store; a failure already rolled the plan
    /// back, so we only translate the error into gentle sheet feedback.
    private func moveWorkout(_ session: PlannedSession, to date: Date) async -> String? {
        do {
            try await planStore.moveWorkout(id: session.id, to: date)
            return nil
        } catch {
            return PlanChangeErrorMessage.message(for: error)
        }
    }

    /// Optimistic clone-add via the store (SPEC §14 #38), same gentle
    /// feedback contract as `moveWorkout`.
    private func addWorkout(cloning sourceID: UUID, on date: Date) async -> String? {
        do {
            try await planStore.addWorkout(cloning: sourceID, on: date)
            return nil
        } catch {
            return PlanChangeErrorMessage.message(for: error)
        }
    }
}

/// The move/add flows presented from the Calendar page.
enum CalendarSheet: Identifiable {
    /// Move a dated workout — or assign a flexible one — to a day.
    case move(PlannedSession)
    /// Add a cloned workout onto an empty day.
    case add(Date)

    var id: String {
        switch self {
        case .move(let session): "move-\(session.id.uuidString)"
        case .add(let date): "add-\(date.timeIntervalSinceReferenceDate)"
        }
    }
}

/// Week header + day cards + flexible pool for the ready state.
private struct CalendarWeekContent: View {
    var plan: GeneratedPlan
    var viewModel: CalendarViewModel
    var onAction: (CalendarSheet) -> Void

    @Environment(PlanStore.self) private var planStore

    var body: some View {
        let today = planStore.today
        let weekNumber = viewModel.resolvedWeekNumber(plan: plan, today: today)
        let weekDays = viewModel.days(ofWeek: weekNumber, in: plan)

        CalendarWeekHeader(
            weekNumber: weekNumber,
            rangeLabel: viewModel.weekRangeLabel(forWeek: weekNumber, in: plan),
            canShowPrevious: viewModel.canShowPreviousWeek(plan: plan, today: today),
            canShowNext: viewModel.canShowNextWeek(plan: plan, today: today),
            onPrevious: { viewModel.showPreviousWeek(plan: plan, today: today) },
            onNext: { viewModel.showNextWeek(plan: plan, today: today) }
        )

        ForEach(weekDays, id: \.self) { day in
            CalendarDayCard(
                day: day,
                isToday: Calendar.current.isDate(day, inSameDayAs: today),
                sessions: planStore.sessions(on: day),
                onMove: { session in onAction(.move(session)) },
                onAdd: { onAction(.add(day)) }
            )
        }

        let pool = weekDays.first.map { planStore.flexibleWeeklyPool(containing: $0) } ?? []
        if !pool.isEmpty {
            CalendarFlexiblePoolCard(sessions: pool) { session in
                onAction(.move(session))
            }
        }
    }
}

/// "Week N · Jul 20 – Jul 26" with previous/next week navigation.
private struct CalendarWeekHeader: View {
    var weekNumber: Int
    var rangeLabel: String
    var canShowPrevious: Bool
    var canShowNext: Bool
    var onPrevious: () -> Void
    var onNext: () -> Void

    var body: some View {
        HStack(spacing: PluriSpacing.sm) {
            Button("Previous week", systemImage: "chevron.left", action: onPrevious)
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(!canShowPrevious)

            Spacer()

            VStack(spacing: PluriSpacing.xs) {
                Text("Week \(weekNumber)")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)
                Text(rangeLabel)
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)
            }

            Spacer()

            Button("Next week", systemImage: "chevron.right", action: onNext)
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(!canShowNext)
        }
        .foregroundStyle(PluriColor.brandOrange)
        .accessibilityElement(children: .contain)
    }
}

/// One day of the visible week: date column plus either the day's workouts
/// (with a Move affordance for scheduled ones) or an add-workout affordance.
private struct CalendarDayCard: View {
    var day: Date
    var isToday: Bool
    var sessions: [PlannedSession]
    var onMove: (PlannedSession) -> Void
    var onAdd: () -> Void

    var body: some View {
        PluriCard {
            HStack(alignment: .center, spacing: PluriSpacing.md) {
                CalendarDayColumn(day: day, isToday: isToday)

                if sessions.isEmpty {
                    Text("Rest day")
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textTertiary)

                    Spacer(minLength: PluriSpacing.sm)

                    Button("Add workout", systemImage: "plus.circle", action: onAdd)
                        .labelStyle(.iconOnly)
                        .font(PluriFont.sectionHeader)
                        .foregroundStyle(PluriColor.brandOrange)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Add workout on \(day.formatted(date: .abbreviated, time: .omitted))")
                } else {
                    VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                        ForEach(sessions) { session in
                            CalendarSessionLine(session: session) {
                                onMove(session)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The leading date column: weekday abbreviation + day numeral, tinted
/// when the day is today.
private struct CalendarDayColumn: View {
    var day: Date
    var isToday: Bool

    var body: some View {
        VStack(spacing: PluriSpacing.xs) {
            Text(day, format: .dateTime.weekday(.abbreviated))
                .font(PluriFont.overline)
                .textCase(.uppercase)
                .foregroundStyle(isToday ? PluriColor.brandOrange : PluriColor.textSecondary)
            Text(day, format: .dateTime.day())
                .font(PluriFont.metricValue)
                .monospacedDigit()
                .foregroundStyle(isToday ? PluriColor.brandOrange : PluriColor.textPrimary)
        }
        .frame(minWidth: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted) + (isToday ? ", today" : ""))
    }
}

/// One workout on a day: color bar, title, type + duration, status mark,
/// and a Move affordance while it's still scheduled (history stays put).
private struct CalendarSessionLine: View {
    var session: PlannedSession
    var onMove: () -> Void

    /// Planned session length, matching Home/Plan duration formatting.
    private var durationText: String {
        Duration.seconds(session.durationMinutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    var body: some View {
        HStack(spacing: PluriSpacing.sm) {
            RoundedRectangle(cornerRadius: PluriRadius.sm)
                .fill(WorkoutColorResolver.token(for: session).color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                Text(session.title)
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textPrimary)
                    .lineLimit(2)
                Text("\(session.workoutType.title) · \(durationText)")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)
            }

            Spacer(minLength: PluriSpacing.sm)

            switch session.status {
            case .scheduled:
                Button("Move \(session.title)", systemImage: "arrow.up.arrow.down", action: onMove)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(PluriColor.brandOrange)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityHint("Moves this workout to another day")
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(PluriColor.statusGreen)
                    .accessibilityLabel("Completed")
            case .skipped:
                Image(systemName: "arrow.uturn.forward.circle")
                    .foregroundStyle(PluriColor.textTertiary)
                    .accessibilityLabel("Skipped")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The selected week's undated flexible workouts (SPEC §14 #37): shown as a
/// pool, never as fake calendar slots, each with an assign affordance.
private struct CalendarFlexiblePoolCard: View {
    var sessions: [PlannedSession]
    var onAssign: (PlannedSession) -> Void

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text("Anytime this week")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                Text("These workouts aren't pinned to a day yet — do them whenever works, or give one a day.")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)

                ForEach(sessions) { session in
                    HStack(spacing: PluriSpacing.sm) {
                        RoundedRectangle(cornerRadius: PluriRadius.sm)
                            .fill(WorkoutColorResolver.token(for: session).color)
                            .frame(width: 4)

                        Text(session.title)
                            .font(PluriFont.body)
                            .foregroundStyle(PluriColor.textPrimary)
                            .lineLimit(2)

                        Spacer(minLength: PluriSpacing.sm)

                        Button("Assign \(session.title) to a day", systemImage: "calendar.badge.plus") {
                            onAssign(session)
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(PluriColor.brandOrange)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityHint("Pins this workout to a day this week")
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Centered spinner while the router is still resolving plan content.
private struct CalendarLoadingIndicator: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView("Loading your plan…")
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
            Spacer()
        }
        .padding(.vertical, PluriSpacing.xl)
    }
}

#Preview("Ready") {
    NavigationStack {
        CalendarView(title: "Calendar")
    }
    .environment(HomePreviewData.readyStore())
}

#Preview("Empty") {
    NavigationStack {
        CalendarView(title: "Rearrange Workouts")
    }
    .environment(HomePreviewData.emptyStore())
}

#Preview("Failed") {
    NavigationStack {
        CalendarView(title: "Calendar")
    }
    .environment(HomePreviewData.failedStore())
}
