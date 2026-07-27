import SwiftUI

/// Ask Pluri chat sheet (M6-06 / SPEC §10): message list, composer, busy/offline/error.
struct AskPluriChatView: View {
    var currentPlanWorkoutId: String?

    @Environment(\.askPluriClient) private var askPluriClient
    @Environment(\.askPluriHistoryLoader) private var historyLoader
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AskPluriViewModel?
    @State private var scrollPosition = ScrollPosition(idType: String.self)

    var body: some View {
        Group {
            if let viewModel {
                AskPluriChatContent(
                    viewModel: viewModel,
                    scrollPosition: $scrollPosition,
                    onDismiss: { dismiss() }
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PluriColor.bgSurface)
            }
        }
        .task {
            ensureViewModel()
            await viewModel?.onAppear()
        }
        .onDisappear {
            viewModel?.tearDown()
        }
    }

    private func ensureViewModel() {
        guard viewModel == nil else { return }
        viewModel = AskPluriViewModel(
            currentPlanWorkoutId: currentPlanWorkoutId,
            client: askPluriClient,
            historyLoader: historyLoader
        )
    }
}

// MARK: - Content

private struct AskPluriChatContent: View {
    @Bindable var viewModel: AskPluriViewModel
    @Binding var scrollPosition: ScrollPosition
    var onDismiss: () -> Void

    @Environment(PlanStore.self) private var planStore

    var body: some View {
        VStack(spacing: 0) {
            AskPluriChatHeader(onDismiss: onDismiss)

            if let status = viewModel.statusMessage {
                AskPluriStatusBanner(
                    message: status,
                    onDismiss: { viewModel.dismissStatus() }
                )
            }

            AskPluriMessageList(
                viewModel: viewModel,
                scrollPosition: $scrollPosition
            )

            AskPluriComposer(
                draft: $viewModel.draft,
                canSend: viewModel.canSend,
                isBusy: viewModel.isBusy,
                onSend: {
                    Task { await viewModel.send() }
                }
            )
        }
        .background(PluriColor.bgSurface)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ask Pluri chat")
        .pluriBottomSheet(
            isPresented: Binding(
                get: { viewModel.showsConfirmSheet },
                set: { isPresented in
                    if !isPresented {
                        viewModel.cancelPendingActions()
                    }
                }
            ),
            detents: [.medium, .large]
        ) {
            AskPluriConfirmChangeSheet(
                summaryLines: AskPluriPlanActionApplier.summaryLines(
                    for: viewModel.pendingActions,
                    plan: planStore.plan
                ),
                onConfirm: {
                    await viewModel.confirmPendingActions(using: planStore)
                },
                onCancel: {
                    viewModel.cancelPendingActions()
                }
            )
        }
    }
}

private struct AskPluriChatHeader: View {
    var onDismiss: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                Text("Ask Pluri")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)
                Text("Your kind training coach")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)
            }
            Spacer(minLength: PluriSpacing.sm)
            Button("Done") {
                onDismiss()
            }
            .font(PluriFont.label)
            .foregroundStyle(PluriColor.brandOrange)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Done")
            .accessibilityHint("Closes Ask Pluri")
        }
        .padding(.horizontal, PluriSpacing.lg)
        .padding(.top, PluriSpacing.lg)
        .padding(.bottom, PluriSpacing.sm)
    }
}

private struct AskPluriMessageList: View {
    var viewModel: AskPluriViewModel
    @Binding var scrollPosition: ScrollPosition

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: PluriSpacing.md) {
                if viewModel.isLoadingHistory && viewModel.messages.isEmpty {
                    ProgressView("Loading chat…")
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PluriSpacing.xl)
                        .accessibilityLabel("Loading chat history")
                } else if viewModel.showsEmptyState {
                    AskPluriEmptyState()
                }

                ForEach(viewModel.messages) { message in
                    AskPluriMessageBubble(message: message)
                        .id(message.id)
                }

                if viewModel.isBusy {
                    AskPluriBusyRow()
                }
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.md)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollPosition($scrollPosition)
        .defaultScrollAnchor(.bottom)
        .onChange(of: viewModel.messages.count) { _, _ in
            if let lastID = viewModel.messages.last?.id {
                withAnimation {
                    scrollPosition.scrollTo(id: lastID)
                }
            }
        }
        .onChange(of: viewModel.isBusy) { _, isBusy in
            if isBusy, let lastID = viewModel.messages.last?.id {
                withAnimation {
                    scrollPosition.scrollTo(id: lastID)
                }
            }
        }
    }
}

private struct AskPluriEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text("Ask anything about this workout")
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)
            Text("Form tips, how hard to push, or what to change next — Pluri answers using your plan and past sessions. Plan changes always ask for your OK first.")
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, PluriSpacing.md)
        .accessibilityElement(children: .combine)
    }
}

private struct AskPluriBusyRow: View {
    var body: some View {
        HStack(spacing: PluriSpacing.sm) {
            ProgressView()
                .controlSize(.small)
            Text("Pluri is thinking…")
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
        }
        .padding(.vertical, PluriSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pluri is thinking")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct AskPluriStatusBanner: View {
    var message: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: PluriSpacing.sm) {
            Text(message)
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Dismiss", systemImage: "xmark") {
                onDismiss()
            }
            .labelStyle(.iconOnly)
            .font(PluriFont.label)
            .foregroundStyle(PluriColor.textSecondary)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Dismiss status message")
        }
        .padding(.horizontal, PluriSpacing.md)
        .padding(.vertical, PluriSpacing.sm)
        .background(PluriColor.bgMuted, in: .rect(cornerRadius: PluriRadius.md))
        .padding(.horizontal, PluriSpacing.lg)
        .padding(.bottom, PluriSpacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message)
    }
}

private struct AskPluriMessageBubble: View {
    var message: AskPluriChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: PluriSpacing.xl)
            }
            Text(message.content)
                .font(PluriFont.body)
                .foregroundStyle(textColor)
                .padding(.horizontal, PluriSpacing.md)
                .padding(.vertical, PluriSpacing.sm)
                .background(background, in: .rect(cornerRadius: PluriRadius.lg))
            if message.role != .user {
                Spacer(minLength: PluriSpacing.xl)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var background: Color {
        switch message.role {
        case .user: PluriColor.brandOrange
        case .assistant, .system: PluriColor.bgMuted
        }
    }

    private var textColor: Color {
        switch message.role {
        case .user: .white
        case .assistant, .system: PluriColor.textPrimary
        }
    }

    private var accessibilityLabel: String {
        switch message.role {
        case .user: "You said: \(message.content)"
        case .assistant: "Pluri said: \(message.content)"
        case .system: "System: \(message.content)"
        }
    }
}

private struct AskPluriComposer: View {
    @Binding var draft: String
    var canSend: Bool
    var isBusy: Bool
    var onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: PluriSpacing.sm) {
            TextField("Ask about your workout…", text: $draft, axis: .vertical)
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textPrimary)
                .lineLimit(1...5)
                .padding(.horizontal, PluriSpacing.md)
                .padding(.vertical, PluriSpacing.sm)
                .frame(minHeight: 44)
                .background(PluriColor.bgMuted, in: .rect(cornerRadius: PluriRadius.lg))
                .disabled(isBusy)
                .accessibilityLabel("Message")
                .accessibilityHint("Type a question for your coach")

            Button("Send", systemImage: "arrow.up.circle.fill") {
                onSend()
            }
            .labelStyle(.iconOnly)
            .font(.title2)
            .foregroundStyle(canSend ? PluriColor.brandOrange : PluriColor.textTertiary)
            .frame(minWidth: 44, minHeight: 44)
            .disabled(!canSend)
            .accessibilityLabel("Send")
            .accessibilityHint("Sends your message to Pluri")
        }
        .padding(.horizontal, PluriSpacing.lg)
        .padding(.vertical, PluriSpacing.md)
        .background(PluriColor.bgSurface)
    }
}

#if DEBUG
@MainActor
private enum AskPluriChatPreviewSupport {
    static func planStore() -> PlanStore {
        let start = Calendar.current.startOfDay(for: .now)
        let source = PlannedSession(
            title: "Pull Day",
            indexInWeek: 1,
            weekday: .monday,
            date: start,
            status: .scheduled,
            workoutType: .weights,
            color: nil,
            focus: .pull,
            orderIndex: 0,
            durationMinutes: 45,
            exercises: []
        )
        let plan = GeneratedPlan(
            goal: .buildMuscle,
            scheduleType: .scheduled,
            sessionDurationMinutes: 45,
            startDate: start,
            weeks: [PlanWeek(number: 1, sessions: [source])],
            seed: 1
        )
        let store = PlanStore(mutationService: MockPlanMutationService())
        store.configure(
            from: RestoredUserState(
                profile: RestoredProfile(
                    displayName: "Alex",
                    goal: .buildMuscle,
                    experience: .oneToSixMonths,
                    regularity: .onAndOff,
                    location: .commercialGym,
                    injuries: [:],
                    trainingDays: [.monday, .wednesday, .friday],
                    scheduleType: .scheduled,
                    planLengthWeeks: 1,
                    sessionDuration: .fortyFiveMinutes,
                    age: 28,
                    gender: .male,
                    heightCM: 178,
                    weightKG: 75,
                    allergies: [],
                    equipment: [],
                    startDate: start,
                    maintenanceCalories: 2400,
                    units: "metric",
                    onboardingCompleted: true
                ),
                plan: plan
            )
        )
        return store
    }
}

#Preview("Empty") {
    AskPluriChatView(currentPlanWorkoutId: UUID().uuidString)
        .environment(\.askPluriClient, MockAskPluriClient())
        .environment(\.askPluriHistoryLoader, MockAskPluriHistoryLoader())
        .environment(AskPluriChatPreviewSupport.planStore())
}

#Preview("Populated") {
    let conversationId = "00000000-0000-4000-8000-000000000001"
    let history = MockAskPluriHistoryLoader(
        snapshot: AskPluriConversationSnapshot(
            conversationId: conversationId,
            messages: [
                AskPluriChatMessage(
                    role: .user,
                    content: "How hard should the next set feel?"
                ),
                AskPluriChatMessage(
                    role: .assistant,
                    content: AskPluriResponse.previewFixture.reply
                ),
            ]
        )
    )
    return AskPluriChatView(currentPlanWorkoutId: UUID().uuidString)
        .environment(\.askPluriClient, MockAskPluriClient())
        .environment(\.askPluriHistoryLoader, history)
        .environment(AskPluriChatPreviewSupport.planStore())
}

#Preview("Busy") {
    // Force `isSending` so the busy row is visible without waiting on a delay
    // (M6-13 — same honesty as M5-16 status-forced previews).
    @Previewable @State var scrollPosition = ScrollPosition(idType: String.self)
    let viewModel = AskPluriViewModel(
        currentPlanWorkoutId: UUID().uuidString,
        client: MockAskPluriClient(delay: .seconds(60)),
        historyLoader: MockAskPluriHistoryLoader(),
        reachability: MockNetworkReachability(isOnline: true)
    )
    viewModel.prepareBusyPreviewState()
    return AskPluriChatContent(
        viewModel: viewModel,
        scrollPosition: $scrollPosition,
        onDismiss: {}
    )
    .environment(AskPluriChatPreviewSupport.planStore())
}

#Preview("Offline / error") {
    AskPluriChatView(currentPlanWorkoutId: UUID().uuidString)
        .environment(
            \.askPluriClient,
            MockAskPluriClient(errorToThrow: .transport(""))
        )
        .environment(
            \.askPluriHistoryLoader,
            MockAskPluriHistoryLoader(
                errorToThrow: .transport(
                    "Ask Pluri needs a connection. Check your network and try again."
                )
            )
        )
        .environment(AskPluriChatPreviewSupport.planStore())
}

#Preview("Confirm add") {
    AskPluriConfirmChangeSheet(
        summaryLines: [
            .init(id: "a", kind: .add, title: "Add Pull Day", detail: "Jul 28, 2026"),
        ],
        onConfirm: { nil },
        onCancel: {}
    )
}

#Preview("Confirm remove") {
    AskPluriConfirmChangeSheet(
        summaryLines: [
            .init(id: "r", kind: .remove, title: "Remove Push Day", detail: "Jul 29, 2026"),
        ],
        onConfirm: { nil },
        onCancel: {}
    )
}
#endif
