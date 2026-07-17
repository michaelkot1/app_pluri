import SwiftUI
import UserNotifications

/// Notifications page shell (SPEC §5.3, M3-15): a functional upcoming-workout
/// reminders toggle backed by `WorkoutReminderService`, with the community
/// rows (M8) and the late-day reschedule nudge (M4) as honest placeholders.
struct NotificationsView: View {
    @Environment(WorkoutReminderService.self) private var reminderService
    @Environment(PlanStore.self) private var planStore

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
                LabeledContent("Replies to your posts", value: "Coming soon")
                LabeledContent("Clubs & groups", value: "Coming soon")
            } header: {
                Text("Community")
            } footer: {
                Text("Community notifications arrive when Community launches.")
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
        }
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
}

#if DEBUG
#Preview("Reminders off") {
    NavigationStack {
        NotificationsView()
    }
    .environment(WorkoutReminderService.preview())
    .environment(HomePreviewData.readyStore())
}

#Preview("Reminders on") {
    NavigationStack {
        NotificationsView()
    }
    .environment(WorkoutReminderService.preview(status: .authorized, optedIn: true))
    .environment(HomePreviewData.readyStore())
}

#Preview("Permission denied") {
    NavigationStack {
        NotificationsView()
    }
    .environment(WorkoutReminderService.preview(status: .denied))
    .environment(HomePreviewData.readyStore())
}
#endif
