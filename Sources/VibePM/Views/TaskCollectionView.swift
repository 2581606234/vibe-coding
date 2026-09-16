import SwiftUI
import VibePMCore

struct TaskCollectionView: View {
    let title: String
    let tasks: [ProjectTask]
    let onAdd: () -> Void
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

                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                                .strikethrough(task.status == .done)
                            if task.priority != .none {
                                Text(task.priority.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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

