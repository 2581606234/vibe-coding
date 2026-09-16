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
                Section("Task details") {
                    TextField("Title", text: $draft.title)
                        .textFieldStyle(.roundedBorder)

                    TextField("Description", text: $draft.taskDescription, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Organization") {
                    Picker("Status", selection: $draft.status) {
                        ForEach(TaskStatus.allCases, id: \.self) { status in
                            Text(status.title).tag(status)
                        }
                    }

                    Picker("Priority", selection: $draft.priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Label(priority.title, systemImage: "flag.fill")
                                .foregroundStyle(priority.color)
                                .tag(priority)
                        }
                    }

                    Picker("Project", selection: $draft.projectID) {
                        Label("Inbox", systemImage: "tray").tag(UUID?.none)
                        ForEach(projects) { project in
                            Label(project.name, systemImage: "folder.fill")
                                .tag(Optional(project.id))
                        }
                    }

                    Picker("Parent Task", selection: $draft.parentTaskID) {
                        Text("None").tag(UUID?.none)
                        ForEach(eligibleParentTasks) { task in
                            Text(task.title).tag(Optional(task.id))
                        }
                    }
                }

                Section("Planning") {
                    OptionalDateField(
                        title: "Schedule",
                        date: $draft.scheduledFor
                    )

                    OptionalDateField(
                        title: "Due date",
                        date: $draft.dueAt
                    )
                }
            }
            .formStyle(.grouped)

            Divider()
            editorActions
        }
        .frame(width: 520, height: 560)
        .onChange(of: draft.projectID) {
            if let parentTaskID = draft.parentTaskID,
               !eligibleParentTasks.contains(where: { $0.id == parentTaskID }) {
                draft.parentTaskID = nil
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
                Text("Make the next action clear and achievable.")
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
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
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

    private var isEnabled: Binding<Bool> {
        Binding(
            get: { date != nil },
            set: { enabled in
                date = enabled ? (date ?? .now) : nil
            }
        )
    }

    private var selectedDate: Binding<Date> {
        Binding(
            get: { date ?? .now },
            set: { date = $0 }
        )
    }

    var body: some View {
        LabeledContent(title) {
            HStack {
                Toggle("", isOn: isEnabled)
                    .labelsHidden()
                if date != nil {
                    DatePicker(
                        "",
                        selection: selectedDate,
                        displayedComponents: [.date]
                    )
                    .labelsHidden()
                }
            }
        }
    }
}
