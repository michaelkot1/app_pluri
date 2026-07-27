import Foundation
import Observation

/// Ask Pluri chat state (M6-06 / M6-09/10): history, send, busy/offline/error,
/// and confirm-then-apply for EF-returned plan actions via `PlanStore`.
@MainActor
@Observable
final class AskPluriViewModel {
    private(set) var messages: [AskPluriChatMessage] = []
    private(set) var conversationId: String?
    private(set) var isLoadingHistory = false
    private(set) var isSending = false
    private(set) var isApplyingActions = false
    /// Banner for offline / busy / transport / unauthorized / apply failures.
    private(set) var statusMessage: String?
    /// Last actions from a successful reply (decoded; applied only after confirm).
    private(set) var lastReceivedActions: [AskPluriAction] = []
    /// Actions awaiting user confirm — drives the confirm sheet (SPEC §14 #66c).
    private(set) var pendingActions: [AskPluriAction] = []
    var draft = ""

    private let client: any AskPluriClient
    private let historyLoader: any AskPluriHistoryLoading
    private let reachability: any NetworkReachability
    private let currentPlanWorkoutId: String?

    private var didStartReachability = false

    init(
        currentPlanWorkoutId: String?,
        client: any AskPluriClient,
        historyLoader: any AskPluriHistoryLoading = MockAskPluriHistoryLoader(),
        reachability: (any NetworkReachability)? = nil
    ) {
        self.currentPlanWorkoutId = currentPlanWorkoutId
        self.client = client
        self.historyLoader = historyLoader
        self.reachability = reachability ?? PathMonitorReachability()
    }

    var canSend: Bool {
        !isSending
            && !isApplyingActions
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var showsEmptyState: Bool {
        messages.isEmpty && !isLoadingHistory && !isSending
    }

    var isBusy: Bool {
        isSending
    }

    var showsConfirmSheet: Bool {
        !pendingActions.isEmpty
    }

    func onAppear() async {
        startReachabilityIfNeeded()
        refreshOfflineBanner()
        await loadHistory()
    }

    func tearDown() {
        reachability.stop()
        didStartReachability = false
    }

    func loadHistory() async {
        guard !isLoadingHistory else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        refreshOfflineBanner()
        if !reachability.isOnline {
            // Keep any in-memory messages; don't invent history offline.
            return
        }

        do {
            let snapshot = try await historyLoader.loadLatestConversation()
            conversationId = snapshot.conversationId
            messages = snapshot.messages
            if statusMessage == offlineMessage {
                statusMessage = nil
            }
        } catch let error as AskPluriClientError {
            // Soft-fail history: empty chat still lets the user try to send.
            if messages.isEmpty {
                statusMessage = error.errorDescription
            }
        } catch {
            if messages.isEmpty {
                statusMessage = AskPluriClientError.transport("").errorDescription
            }
        }
    }

    func send() async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        startReachabilityIfNeeded()
        refreshOfflineBanner()
        guard reachability.isOnline else {
            // Keep draft in the composer (SPEC §14 #66d).
            statusMessage = offlineMessage
            return
        }

        isSending = true
        statusMessage = nil
        draft = ""

        let userMessage = AskPluriChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)

        do {
            let response = try await client.ask(
                AskPluriRequest(
                    message: trimmed,
                    conversationId: conversationId,
                    currentPlanWorkoutId: currentPlanWorkoutId
                )
            )
            conversationId = response.conversationId
            lastReceivedActions = response.actions
            // Confirm before any PlanStore mutate (SPEC §14 #66c / #66h).
            pendingActions = response.actions
            let assistantId = response.messageIds?.assistant ?? UUID().uuidString
            messages.append(
                AskPluriChatMessage(
                    id: assistantId,
                    role: .assistant,
                    content: response.reply
                )
            )
            if let userId = response.messageIds?.user,
               let index = messages.firstIndex(where: { $0.id == userMessage.id }) {
                messages[index] = AskPluriChatMessage(
                    id: userId,
                    role: .user,
                    content: trimmed,
                    createdAt: userMessage.createdAt
                )
            }
        } catch let error as AskPluriClientError {
            statusMessage = userFacingMessage(for: error)
        } catch {
            statusMessage = AskPluriClientError.transport("").errorDescription
        }

        isSending = false
    }

    /// Applies pending actions via `PlanStore` in order; stops on first failure.
    /// Returns gentle error copy for the confirm sheet, or `nil` on success.
    func confirmPendingActions(using planStore: PlanStore) async -> String? {
        guard !pendingActions.isEmpty, !isApplyingActions else { return nil }
        isApplyingActions = true
        defer { isApplyingActions = false }

        let actions = pendingActions
        do {
            try await AskPluriPlanActionApplier.apply(actions, to: planStore)
            pendingActions = []
            lastReceivedActions = []
            messages.append(
                AskPluriChatMessage(
                    role: .system,
                    content: "Updated your plan."
                )
            )
            return nil
        } catch {
            let message = PlanChangeErrorMessage.message(for: error)
            statusMessage = message
            return message
        }
    }

    /// Dismisses the confirm proposal without mutating the plan (#66c).
    func cancelPendingActions() {
        guard !pendingActions.isEmpty else { return }
        pendingActions = []
        messages.append(
            AskPluriChatMessage(
                role: .system,
                content: "No changes made to your plan."
            )
        )
    }

    func dismissStatus() {
        statusMessage = nil
    }

    // MARK: - Private

    private let offlineMessage =
        "Ask Pluri needs a connection. Check your network and try again."

    private func startReachabilityIfNeeded() {
        guard !didStartReachability else { return }
        reachability.onPathSatisfied = { [weak self] in
            Task { @MainActor in
                self?.refreshOfflineBanner()
            }
        }
        reachability.start()
        didStartReachability = true
    }

    private func refreshOfflineBanner() {
        if !reachability.isOnline {
            statusMessage = offlineMessage
        } else if statusMessage == offlineMessage {
            statusMessage = nil
        }
    }

    private func userFacingMessage(for error: AskPluriClientError) -> String {
        switch error {
        case .busy, .throttled:
            error.errorDescription ?? AskPluriClientError.defaultBusyMessage
        case .transport:
            error.errorDescription ?? offlineMessage
        case .unauthorized, .invalidResponse:
            error.errorDescription
                ?? "Your coach sent back something we didn't expect. Please try again."
        }
    }

    #if DEBUG
    /// Forces the in-flight busy row for Xcode Previews (M6-13).
    func prepareBusyPreviewState(
        userMessage: String = "How hard should the next set feel?"
    ) {
        messages = [AskPluriChatMessage(role: .user, content: userMessage)]
        isSending = true
        statusMessage = nil
    }
    #endif
}
