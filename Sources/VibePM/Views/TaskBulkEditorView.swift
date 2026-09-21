import SwiftUI
import VibePMCore

struct TaskBulkEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let selectedIDs: Set<UUID>
    let tasks: [ProjectTask]
    let projects: [Project]
    let onApply: (TaskBulkAction) -> Bool

    @State private var action = TaskBulkAction()

    private var preview: TaskBulkPreview {
        action.preview(selectedIDs: selectedIDs, tasks: tasks)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundStyle(VibeTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("Edit Selected Tasks"))
                        .font(.title2.bold())
                    Text(L10n.format("%d selected", arguments: [preview.selectedCount]))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(24)

            Divider()

            Form {
                Section(L10n.text("Change only the fields you choose")) {
                    Picker(L10n.text("Status"), selection: $action.status) {
                        Text(L10n.text("Keep current")).tag(TaskStatus?.none)
                        ForEach(TaskStatus.allCases, id: \.self) { status in
                            Text(L10n.text(status.title)).tag(Optional(status))
                        }
                    }

                    Picker(L10n.text("Priority"), selection: $action.priority) {
                        Text(L10n.text("Keep current")).tag(TaskPriority?.none)
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(L10n.text(priority.title)).tag(Optional(priority))
                        }
                    }

                    Picker(L10n.text("Move to"), selection: $action.destination) {
                        Text(L10n.text("Keep current")).tag(BulkProjectDestination.keepCurrent)
                        Text(L10n.text("Inbox")).tag(BulkProjectDestination.inbox)
                        ForEach(projects) { project in
                            Text(project.name).tag(BulkProjectDestination.project(project.id))
                        }
                    }
                }

                Section(L10n.text("Preview")) {
                    LabeledContent(L10n.text("Tasks to change"), value: preview.changedCount.formatted())
                    if action.destination != .keepCurrent {
                        LabeledContent(L10n.text("Tasks to move"), value: preview.movedCount.formatted())
                        LabeledContent(L10n.text("Additional Subtasks"), value: preview.additionallyMovedCount.formatted())
                        Text(L10n.text("Moving a Task also moves its Subtasks. A Subtask moved without its parent becomes a top-level Task."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button(L10n.text("Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L10n.text("Apply Changes")) {
                    if onApply(action) { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!preview.canApply)
            }
            .padding(18)
        }
        .frame(width: 580, height: 470)
    }
}
