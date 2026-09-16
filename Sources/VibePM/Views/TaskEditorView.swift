import SwiftUI
import VibePMCore

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let heading: String
    let projects: [Project]
    let parentTasks: [ProjectTask]
    let onSave: (TaskDraft) -> Void

    @State private var draft: TaskDraft

    init(
        heading: String,
        draft: TaskDraft,
        projects: [Project],
        parentTasks: [ProjectTask],
        onSave: @escaping (TaskDraft) -> Void
    ) {
        self.heading = heading
        self.projects = projects
        self.parentTasks = parentTasks
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            Divider()

            Form {
                Section(L10n.text("Task details")) {
                    TextField(L10n.text("Title"), text: $draft.title)
                        .textFieldStyle(.roundedBorder)

                    TextField(L10n.text("Description"), text: $draft.taskDescription, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section(L10n.text("Planning")) {
                    OptionalDateField(
                        title: L10n.text("Schedule"),
                        date: $draft.scheduledFor
                    )

                    OptionalDateField(
                        title: L10n.text("Due date"),
                        date: $draft.dueAt,
                        minimumDate: draft.scheduledFor
                    )
                }

                Section(L10n.text("Organization")) {
                    Picker(L10n.text("Status"), selection: $draft.status) {
                        ForEach(TaskStatus.allCases, id: \.self) { status in
                            Text(L10n.text(status.title)).tag(status)
                        }
                    }

                    Picker(L10n.text("Priority"), selection: $draft.priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Label(L10n.text(priority.title), systemImage: "flag.fill")
                                .foregroundStyle(priority.color)
                                .tag(priority)
                        }
                    }

                    Picker(L10n.text("Project"), selection: $draft.projectID) {
                        Label(L10n.text("Inbox"), systemImage: "tray").tag(UUID?.none)
                        ForEach(projects) { project in
                            Label(project.name, systemImage: "folder.fill")
                                .tag(Optional(project.id))
                        }
                    }

                    Picker(L10n.text("Parent Task"), selection: $draft.parentTaskID) {
                        Text(L10n.text("None")).tag(UUID?.none)
                        ForEach(eligibleParentTasks) { task in
                            Text(task.title).tag(Optional(task.id))
                        }
                    }
                }

            }
            .formStyle(.grouped)

            Divider()
            editorActions
        }
        .frame(width: 580, height: 560)
        .onChange(of: draft.projectID) {
            if let parentTaskID = draft.parentTaskID,
               !eligibleParentTasks.contains(where: { $0.id == parentTaskID }) {
                draft.parentTaskID = nil
            }
        }
        .onChange(of: draft.scheduledFor) {
            if let scheduledFor = draft.scheduledFor,
               let dueAt = draft.dueAt,
               dueAt < scheduledFor {
                draft.dueAt = scheduledFor
            }
        }
    }

    private var eligibleParentTasks: [ProjectTask] {
        parentTasks.filter { $0.projectID == draft.projectID }
    }

    private var editorHeader: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(VibeTheme.brandGradient)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(heading)
                    .font(.title2.weight(.semibold))
                Text(L10n.text("Make the next action clear and achievable."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private var editorActions: some View {
        HStack {
            Spacer()
            Button(L10n.text("Cancel"), role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button(L10n.text("Save")) {
                onSave(draft)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(VibeTheme.accent)
            .keyboardShortcut(.defaultAction)
            .disabled(!draft.canSave)
        }
        .padding()
    }
}

private struct OptionalDateField: View {
    let title: String
    @Binding var date: Date?
    var minimumDate: Date?

    init(title: String, date: Binding<Date?>, minimumDate: Date? = nil) {
        self.title = title
        _date = date
        self.minimumDate = minimumDate
    }

    private var isEnabled: Binding<Bool> {
        Binding(
            get: { date != nil },
            set: { enabled in
                date = enabled ? (date ?? minimumDate ?? .now) : nil
            }
        )
    }

    private var selectedDate: Binding<Date> {
        Binding(
            get: {
                guard let minimumDate else { return date ?? .now }
                return max(date ?? minimumDate, minimumDate)
            },
            set: { date = $0 }
        )
    }

    var body: some View {
        LabeledContent(title) {
            HStack {
                Toggle("", isOn: isEnabled)
                    .labelsHidden()
                if date != nil {
                    if let minimumDate {
                        DatePicker(
                            "",
                            selection: selectedDate,
                            in: minimumDate...Date.distantFuture,
                            displayedComponents: [.date]
                        )
                        .labelsHidden()
                        .datePickerStyle(.field)
                    } else {
                        DatePicker(
                            "",
                            selection: selectedDate,
                            displayedComponents: [.date]
                        )
                        .labelsHidden()
                        .datePickerStyle(.field)
                    }
                } else {
                    Text(L10n.text("Not set"))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
