import SwiftUI
import UserNotifications

/// Notifications page (SPEC §5.3, M3-15 / M8-12): upcoming-workout reminders
/// toggle, live Community replies to the user's posts, clubs stub, late-day nudge stub.
struct NotificationsView: View {
    @Environment(WorkoutReminderService.self) private var reminderService
    @Environment(PlanStore.self) private var planStore
    @Environment(\.communityClient) private var communityClient

    @State private var repliesViewModel: CommunityRepliesViewModel?

    var body: some View {
        List {
            Section {
                Toggle("Upcoming workout reminders", isOn: remindersBinding)
                    .tint(PluriColor.brandOrange)
                    .accessibilityHint(workoutsFooter)
            } header: {
                Text("Workouts")
            } footer: {
                Text(workoutsFooter)
            }

            Section {
                communityRepliesContent

                LabeledContent("Clubs & groups", value: "Coming soon")
            } header: {
                Text("Community")
            } footer: {
                Text(communityFooter)
            }

            Section {
                LabeledContent("Late-day reschedule nudge", value: "Coming soon")
            } header: {
                Text("Nudges")
            } footer: {
                Text("If a workout is still unfinished near midnight, Pluri will offer to reschedule it — arriving in a later update.")
            }
        }
        .font(PluriFont.body)
        .scrollContentBackground(.hidden)
        .background(PluriColor.bgCanvas)
        .navigationTitle("Notifications")
        .task {
            await reminderService.refresh()
            ensureRepliesViewModel()
            await repliesViewModel?.load()
        }
    }

    @ViewBuilder
    private var communityRepliesContent: some View {
        if let repliesViewModel {
            switch repliesViewModel.loadState {
            case .idle, .loading:
                ProgressView("Loading replies…")
                    .accessibilityLabel("Loading replies")
            case .offline:
                Text("Replies need a connection. Check your network and try again.")
                    .foregroundStyle(PluriColor.textSecondary)
            case .error(let message):
                Text(message)
                    .foregroundStyle(PluriColor.textSecondary)
            case .empty:
                Text("No replies yet")
                    .foregroundStyle(PluriColor.textSecondary)
            case .loaded:
                ForEach(repliesViewModel.replies) { reply in
                    VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                        Text("\(reply.comment.author.displayName) replied to “\(reply.postTitle)”")
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.textPrimary)
                        Text(reply.comment.body)
                            .font(PluriFont.body)
                            .foregroundStyle(PluriColor.textSecondary)
                            .lineLimit(3)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        } else {
            ProgressView("Loading replies…")
        }
    }

    private var communityFooter: String {
        "Replies to your posts show up here. Club messages arrive when clubs launch. Push delivery is later."
    }

    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { reminderService.isRemindersEnabled },
            set: { newValue in
                let plan = planStore.plan
                Task {
                    await reminderService.setRemindersEnabled(newValue, plan: plan)
                }
            }
        )
    }

    private var workoutsFooter: String {
        if reminderService.isSystemPermissionDenied {
            return "Notifications are turned off for Pluri in iOS Settings. Turn them on there whenever you're ready, then flip this switch again."
        }
        return "A gentle reminder on the morning of each scheduled workout, at 8:00 AM."
    }

    private func ensureRepliesViewModel() {
        if repliesViewModel == nil {
            repliesViewModel = CommunityRepliesViewModel(client: communityClient)
        }
    }
}

#if DEBUG
#Preview("Reminders off") {
    NavigationStack {
        NotificationsView()
    }
    .environment(WorkoutReminderService.preview())
    .environment(HomePreviewData.readyStore())
    .environment(\.communityClient, MockCommunityClient())
}

#Preview("Reminders on") {
    NavigationStack {
        NotificationsView()
    }
    .environment(WorkoutReminderService.preview(status: .authorized, optedIn: true))
    .environment(HomePreviewData.readyStore())
    .environment(\.communityClient, MockCommunityClient())
}

#Preview("Permission denied") {
    NavigationStack {
        NotificationsView()
    }
    .environment(WorkoutReminderService.preview(status: .denied))
    .environment(HomePreviewData.readyStore())
    .environment(\.communityClient, MockCommunityClient())
}
#endif
