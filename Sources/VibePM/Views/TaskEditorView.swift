import SwiftUI
import VibePMCore

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let heading: String
    let projects: [Project]
    let onSave: (TaskDraft) -> Void

    @State private var draft: TaskDraft

    init(
        heading: String,
        draft: TaskDraft,
        projects: [Project],
        onSave: @escaping (TaskDraft) -> Void
    ) {
        self.heading = heading
        self.projects = projects
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(heading)
                    .font(.title2.weight(.semibold))
                Spacer()
            }
            .padding()

            Divider()

            Form {
                TextField("Title", text: $draft.title)
                    .textFieldStyle(.roundedBorder)

                TextField("Description", text: $draft.taskDescription, axis: .vertical)
                    .lineLimit(3...6)

                Picker("Priority", selection: $draft.priority) {
                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                        Text(priority.title).tag(priority)
                    }
                }

                Picker("Project", selection: $draft.projectID) {
                    Text("Inbox").tag(UUID?.none)
                    ForEach(projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }

                OptionalDateField(
                    title: "Schedule",
                    date: $draft.scheduledFor
                )

                OptionalDateField(
                    title: "Due date",
                    date: $draft.dueAt
                )
            }
            .formStyle(.grouped)

            Divider()

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
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.canSave)
            }
            .padding()
        }
        .frame(width: 520, height: 520)
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

