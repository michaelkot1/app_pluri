import Foundation
import Testing
@testable import Pluri

@Suite("AskPluriViewModel")
@MainActor
struct AskPluriViewModelTests {

    private let workoutID = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
    private let calendar = Calendar.current

    private var monday: Date {
        var date = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_752_364_800))
        while calendar.component(.weekday, from: date) != Weekday.monday.rawValue {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return date
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: monday) ?? monday
    }

    private func makeSession(
        title: String,
        indexInWeek: Int,
        dayOffset: Int,
        status: WorkoutStatus = .scheduled,
        orderIndex: Int
    ) -> PlannedSession {
        let date = day(dayOffset)
        return PlannedSession(
            title: title,
            indexInWeek: indexInWeek,
            weekday: Weekday(rawValue: calendar.component(.weekday, from: date)),
            date: date,
            status: status,
            workoutType: .weights,
            orderIndex: orderIndex,
            durationMinutes: 45,
            exercises: [
                PlannedExercise(
                    exerciseID: "001",
                    name: "Row",
                    bodyPart: "Back",
                    equipment: "Dumbbell",
                    targetMuscle: "Lats",
                    secondaryMuscles: [],
                    imageURL: nil,
                    order: 0,
                    sets: 3,
                    reps: 10
                ),
            ]
        )
    }

    private func makePlanStore() -> (store: PlanStore, service: MockPlanMutationService) {
        let source = makeSession(title: "Pull", indexInWeek: 1, dayOffset: 7, orderIndex: 0)
        let removable = makeSession(title: "Push", indexInWeek: 2, dayOffset: 9, orderIndex: 1)
        let plan = GeneratedPlan(
            goal: .buildMuscle,
            scheduleType: .scheduled,
            sessionDurationMinutes: 45,
            startDate: monday,
            weeks: [
                PlanWeek(number: 1, sessions: []),
                PlanWeek(number: 2, sessions: [source, removable]),
            ],
            seed: 1
        )
        let service = MockPlanMutationService()
        let store = PlanStore(mutationService: service, calendar: calendar)
        store.now = { day(8) }
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
                    planLengthWeeks: 2,
                    sessionDuration: .fortyFiveMinutes,
                    age: 28,
                    gender: .male,
                    heightCM: 178,
                    weightKG: 75,
                    allergies: [],
                    equipment: ["Dumbbell"],
                    startDate: monday,
                    maintenanceCalories: 2400,
                    units: "metric",
                    onboardingCompleted: true
                ),
                plan: plan
            )
        )
        return (store, service)
    }

    @Test("Send appends user and assistant, rounds trip conversation and workout ids")
    func sendAppendsMessagesAndRoundTripsIds() async {
        let client = MockAskPluriClient()
        let reachability = MockNetworkReachability(isOnline: true)
        let viewModel = AskPluriViewModel(
            currentPlanWorkoutId: workoutID,
            client: client,
            historyLoader: MockAskPluriHistoryLoader(),
            reachability: reachability
        )

        viewModel.draft = "How many reps?"
        await viewModel.send()

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[0].role == .user)
        #expect(viewModel.messages[0].content == "How many reps?")
        #expect(viewModel.messages[1].role == .assistant)
        #expect(viewModel.messages[1].content == AskPluriResponse.previewFixture.reply)
        #expect(viewModel.conversationId == AskPluriResponse.previewFixture.conversationId)
        #expect(viewModel.draft.isEmpty)
        #expect(viewModel.isSending == false)
        #expect(client.lastRequest?.message == "How many reps?")
        #expect(client.lastRequest?.currentPlanWorkoutId == workoutID)
        #expect(client.lastRequest?.conversationId == nil)

        viewModel.draft = "And the rest?"
        await viewModel.send()
        #expect(client.lastRequest?.conversationId == AskPluriResponse.previewFixture.conversationId)
        #expect(client.lastRequest?.currentPlanWorkoutId == workoutID)
        #expect(viewModel.messages.count == 4)
    }

    @Test("Offline send keeps draft and shows needs-connection copy")
    func offlineKeepsDraft() async {
        let client = MockAskPluriClient()
        let reachability = MockNetworkReachability(isOnline: false)
        let viewModel = AskPluriViewModel(
            currentPlanWorkoutId: workoutID,
            client: client,
            historyLoader: MockAskPluriHistoryLoader(),
            reachability: reachability
        )

        viewModel.draft = "Am I offline?"
        await viewModel.send()

        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.draft == "Am I offline?")
        #expect(client.lastRequest == nil)
        #expect(viewModel.statusMessage?.localizedStandardContains("connection") == true)
    }

    @Test("Busy error surfaces coach-is-busy copy without a fake reply")
    func busySurfacesKindCopy() async {
        let client = MockAskPluriClient(
            errorToThrow: .busy(AskPluriClientError.defaultBusyMessage)
        )
        let viewModel = AskPluriViewModel(
            currentPlanWorkoutId: workoutID,
            client: client,
            historyLoader: MockAskPluriHistoryLoader(),
            reachability: MockNetworkReachability(isOnline: true)
        )

        viewModel.draft = "Help"
        await viewModel.send()

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].role == .user)
        #expect(viewModel.messages.contains(where: { $0.role == .assistant }) == false)
        #expect(viewModel.statusMessage == AskPluriClientError.defaultBusyMessage)
        #expect(viewModel.lastReceivedActions.isEmpty)
        #expect(viewModel.pendingActions.isEmpty)
    }

    @Test("Unauthorized error surfaces sign-in copy without a fake reply")
    func unauthorizedSurfacesSignInCopy() async {
        let client = MockAskPluriClient(errorToThrow: .unauthorized)
        let viewModel = AskPluriViewModel(
            currentPlanWorkoutId: workoutID,
            client: client,
            historyLoader: MockAskPluriHistoryLoader(),
            reachability: MockNetworkReachability(isOnline: true)
        )

        viewModel.draft = "Help"
        await viewModel.send()

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].role == .user)
        #expect(viewModel.messages.contains(where: { $0.role == .assistant }) == false)
        #expect(viewModel.statusMessage == "Sign in to ask your coach.")
        #expect(viewModel.statusMessage?.localizedStandardContains("JWT") == false)
        #expect(viewModel.statusMessage?.localizedStandardContains("401") == false)
        #expect(viewModel.lastReceivedActions.isEmpty)
        #expect(viewModel.pendingActions.isEmpty)
        #expect(viewModel.isSending == false)
    }

    @Test("Throttled error surfaces coach-is-busy copy without a fake reply")
    func throttledSurfacesKindCopy() async {
        let client = MockAskPluriClient(
            errorToThrow: .throttled(AskPluriClientError.defaultThrottledMessage)
        )
        let viewModel = AskPluriViewModel(
            currentPlanWorkoutId: workoutID,
            client: client,
            historyLoader: MockAskPluriHistoryLoader(),
            reachability: MockNetworkReachability(isOnline: true)
        )

        viewModel.draft = "Help"
        await viewModel.send()

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].role == .user)
        #expect(viewModel.messages.contains(where: { $0.role == .assistant }) == false)
        #expect(viewModel.statusMessage == AskPluriClientError.defaultThrottledMessage)
        #expect(viewModel.statusMessage?.localizedStandardContains("busy") == true)
        #expect(viewModel.statusMessage?.localizedStandardContains("quota") == false)
        #expect(viewModel.statusMessage?.localizedStandardContains("429") == false)
        #expect(viewModel.lastReceivedActions.isEmpty)
        #expect(viewModel.pendingActions.isEmpty)
        #expect(viewModel.isSending == false)
    }

    @Test("History load restores prior turns and conversation id")
    func loadsHistoryOnAppear() async {
        let conversationId = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
        let history = MockAskPluriHistoryLoader(
            snapshot: AskPluriConversationSnapshot(
                conversationId: conversationId,
                messages: [
                    AskPluriChatMessage(role: .user, content: "Earlier question"),
                    AskPluriChatMessage(role: .assistant, content: "Earlier answer"),
                ]
            )
        )
        let viewModel = AskPluriViewModel(
            currentPlanWorkoutId: workoutID,
            client: MockAskPluriClient(),
            historyLoader: history,
            reachability: MockNetworkReachability(isOnline: true)
        )

        await viewModel.onAppear()

        #expect(viewModel.conversationId == conversationId)
        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[0].content == "Earlier question")
    }

    @Test("Decoded actions become a pending confirm proposal without mutating the plan")
    func storesActionsAsPendingWithoutApplying() async throws {
        let (store, service) = makePlanStore()
        let sourceID = try #require(store.plan?.weeks[1].sessions[0].id)
        let client = MockAskPluriClient(
            response: AskPluriResponse(
                reply: "I can add a session.",
                conversationId: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
                actions: [
                    .addWorkout(
                        sourceWorkoutId: sourceID.uuidString,
                        date: DatabaseCodeMappings.dateString(day(11))
                    ),
                ]
            )
        )
        let viewModel = AskPluriViewModel(
            currentPlanWorkoutId: workoutID,
            client: client,
            historyLoader: MockAskPluriHistoryLoader(),
            reachability: MockNetworkReachability(isOnline: true)
        )
        let planBefore = store.plan

        viewModel.draft = "Add a pull day"
        await viewModel.send()

        #expect(viewModel.lastReceivedActions.count == 1)
        #expect(viewModel.pendingActions.count == 1)
        #expect(viewModel.showsConfirmSheet)
        #expect(viewModel.messages.last?.role == .assistant)
        #expect(store.plan == planBefore)
        #expect(service.addCalls.isEmpty)
        #expect(service.removeCalls.isEmpty)
    }

    @Test("Confirm applies add via PlanStore and clears pending")
    func confirmAppliesAdd() async throws {
        let (store, service) = makePlanStore()
        let sourceID = try #require(store.plan?.weeks[1].sessions[0].id)
        let dateString = DatabaseCodeMappings.dateString(day(11))
        let client = MockAskPluriClient(
            response: AskPluriResponse(
                reply: "I can add a session.",
                conversationId: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
                actions: [
                    .addWorkout(sourceWorkoutId: sourceID.uuidString, date: dateString),
                ]
            )
        )
        let viewModel = AskPluriViewModel(
            currentPlanWorkoutId: workoutID,
            client: client,
            historyLoader: MockAskPluriHistoryLoader(),
            reachability: MockNetworkReachability(isOnline: true)
        )

        viewModel.draft = "Add a pull day"
        await viewModel.send()
        let error = await viewModel.confirmPendingActions(using: store)

        #expect(error == nil)
        #expect(viewModel.pendingActions.isEmpty)
        #expect(viewModel.showsConfirmSheet == false)
        #expect(service.addCalls.count == 1)
        #expect(store.plan?.totalSessions == 3)
        #expect(viewModel.messages.last?.role == .system)
        #expect(viewModel.messages.last?.content.localizedStandardContains("Updated") == true)
    }

    @Test("Confirm applies remove via PlanStore")
    func confirmAppliesRemove() async throws {
        let (store, service) = makePlanStore()
        let removableID = try #require(store.plan?.weeks[1].sessions[1].id)
        let client = MockAskPluriClient(
            response: AskPluriResponse(
                reply: "I can drop that session.",
                conversationId: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee",
                actions: [
                    .removeWorkout(planWorkoutId: removableID.uuidString),
                ]
            )
        )
        let viewModel = AskPluriViewModel(
            currentPlanWorkoutId: workoutID,
            client: client,
            historyLoader: MockAskPluriHistoryLoader(),
            reachability: MockNetworkReachability(isOnline: true)
        )

        viewModel.draft = "Remove push"
        await viewModel.send()
        let error = await viewModel.confirmPendingActions(using: store)

        #expect(error == nil)
        #expect(service.removeCalls.count == 1)
        #expect(service.removeCalls.first?.deletingWorkoutIDs == [removableID])
        #expect(PlanMutator.session(withID: removableID, in: try #require(store.plan)) == nil)
        #expect(viewModel.pendingActions.isEmpty)
    }

    @Test("Cancel clears pending and leaves the plan untouched")
    func cancelLeavesPlanUntouched() async throws {
        let (store, service) = makePlanStore()
        let sourceID = try #require(store.plan?.weeks[1].sessions[0].id)
        let planBefore = try #require(store.plan)
        let client = MockAskPluriClient(
            response: AskPluriResponse(
                reply: "I can add a session.",
                conversationId: "ffffffff-ffff-4fff-8fff-ffffffffffff",
                actions: [
                    .addWorkout(
                        sourceWorkoutId: sourceID.uuidString,
                        date: DatabaseCodeMappings.dateString(day(11))
                    ),
                ]
            )
        )
        let viewModel = AskPluriViewModel(
            currentPlanWorkoutId: workoutID,
            client: client,
            historyLoader: MockAskPluriHistoryLoader(),
            reachability: MockNetworkReachability(isOnline: true)
        )

        viewModel.draft = "Add a pull day"
        await viewModel.send()
        viewModel.cancelPendingActions()

        #expect(viewModel.pendingActions.isEmpty)
        #expect(viewModel.showsConfirmSheet == false)
        #expect(store.plan == planBefore)
        #expect(service.addCalls.isEmpty)
        #expect(viewModel.messages.last?.role == .system)
        #expect(viewModel.messages.last?.content.localizedStandardContains("No changes") == true)
    }

    @Test("Confirm surfaces PlanStore failures without clearing pending")
    func confirmSurfacesApplyFailure() async throws {
        let (store, service) = makePlanStore()
        service.nextError = .flushFailed("boom")
        let sourceID = try #require(store.plan?.weeks[1].sessions[0].id)
        let planBefore = try #require(store.plan)
        let client = MockAskPluriClient(
            response: AskPluriResponse(
                reply: "I can add a session.",
                conversationId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
                actions: [
                    .addWorkout(
                        sourceWorkoutId: sourceID.uuidString,
                        date: DatabaseCodeMappings.dateString(day(11))
                    ),
                ]
            )
        )
        let viewModel = AskPluriViewModel(
            currentPlanWorkoutId: workoutID,
            client: client,
            historyLoader: MockAskPluriHistoryLoader(),
            reachability: MockNetworkReachability(isOnline: true)
        )

        viewModel.draft = "Add a pull day"
        await viewModel.send()
        let message = await viewModel.confirmPendingActions(using: store)

        #expect(message != nil)
        #expect(viewModel.pendingActions.count == 1)
        #expect(store.plan == planBefore)
        #expect(viewModel.statusMessage != nil)
    }

    @Test("Invalid action payloads are ignored safely on apply")
    func ignoresInvalidActions() async throws {
        let (store, service) = makePlanStore()
        let planBefore = try #require(store.plan)
        let client = MockAskPluriClient(
            response: AskPluriResponse(
                reply: "Hmm.",
                conversationId: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
                actions: [
                    .addWorkout(sourceWorkoutId: "not-a-uuid", date: "2026-07-28"),
                    .removeWorkout(planWorkoutId: "also-bad"),
                    .addWorkout(sourceWorkoutId: UUID().uuidString, date: "not-a-date"),
                ]
            )
        )
        let viewModel = AskPluriViewModel(
            currentPlanWorkoutId: workoutID,
            client: client,
            historyLoader: MockAskPluriHistoryLoader(),
            reachability: MockNetworkReachability(isOnline: true)
        )
        viewModel.draft = "Do something weird"
        await viewModel.send()
        let error = await viewModel.confirmPendingActions(using: store)

        #expect(error == nil)
        #expect(viewModel.pendingActions.isEmpty)
        #expect(store.plan == planBefore)
        #expect(service.addCalls.isEmpty)
        #expect(service.removeCalls.isEmpty)
    }
}
