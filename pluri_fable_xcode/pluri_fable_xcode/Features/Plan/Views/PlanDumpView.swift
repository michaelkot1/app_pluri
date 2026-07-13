#if DEBUG
import SwiftUI

/// DEBUG-only full plan dump for the M1 exit check ("real generated plan
/// visible in a debug plan-dump view"). Lists every week → session → exercise
/// with its set/rep targets, equipment, and body part. Not shipped in release
/// builds.
struct PlanDumpView: View {
    var plan: GeneratedPlan

    var body: some View {
        List {
            Section("Plan") {
                LabeledContent("Goal", value: plan.goal.title)
                LabeledContent("Schedule", value: plan.scheduleType.title)
                LabeledContent("Weeks", value: "\(plan.weekCount)")
                LabeledContent("Sessions / week", value: "\(plan.sessionsPerWeek)")
                LabeledContent("Session length", value: "\(plan.sessionDurationMinutes) min")
                LabeledContent("Total workouts", value: "\(plan.totalSessions)")
                LabeledContent("Seed", value: "\(plan.seed)")
                LabeledContent("Start", value: plan.startDate.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("End", value: plan.endDate.formatted(date: .abbreviated, time: .omitted))
            }

            ForEach(plan.weeks) { week in
                Section("Week \(week.number)") {
                    ForEach(week.sessions) { session in
                        PlanDumpSessionRow(session: session)
                    }
                }
            }
        }
        .navigationTitle("Plan Dump")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One session's rows inside `PlanDumpView`.
private struct PlanDumpSessionRow: View {
    var session: PlannedSession

    private var subtitle: String {
        var parts: [String] = ["Workout \(session.indexInWeek)"]
        if let weekday = session.weekday { parts.append(weekday.shortTitle) }
        if let date = session.date {
            parts.append(date.formatted(date: .abbreviated, time: .omitted))
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        DisclosureGroup {
            ForEach(session.exercises) { exercise in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(exercise.order + 1). \(exercise.name)  —  \(exercise.setsRepsSummary)")
                        .font(.callout)
                    Text("\(exercise.bodyPart) · \(exercise.equipment) · \(exercise.targetMuscle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
#endif
