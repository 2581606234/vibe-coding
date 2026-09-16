import SwiftUI
import VibePMCore

struct TaskCollectionView: View {
    let title: String
    let tasks: [ProjectTask]
    let onAdd: () -> Void
    let onEdit: (ProjectTask) -> Void
    let onToggleCompletion: (ProjectTask) -> Void

    var body: some View {
        Group {
            if tasks.isEmpty {
                ContentUnavailableView(
                    "No Tasks",
                    systemImage: "checkmark.circle",
                    description: Text("Capture the next concrete action when you are ready.")
                )
            } else {
                List(tasks) { task in
                    HStack(spacing: 12) {
                        Button {
                            onToggleCompletion(task)
                        } label: {
                            Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.status == .done ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(task.status == .done ? "Reopen Task" : "Complete Task")

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .strikethrough(task.status == .done)

                            if !task.taskDescription.isEmpty {
                                Text(task.taskDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            TaskMetadataView(task: task)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onEdit(task)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            Button(action: onAdd) {
                Label("New Task", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: [.command])
        }
    }
}

private struct TaskMetadataView: View {
    let task: ProjectTask

    var body: some View {
        HStack(spacing: 10) {
            if task.priority != .none {
                Label(task.priority.title, systemImage: "flag.fill")
            }

            if let scheduledFor = task.scheduledFor {
                Label(scheduledFor.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
            }

            if let dueAt = task.dueAt {
                Label(dueAt.formatted(date: .abbreviated, time: .omitted), systemImage: "clock")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
