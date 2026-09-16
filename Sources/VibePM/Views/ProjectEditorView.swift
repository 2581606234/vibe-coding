import SwiftUI
import VibePMCore

struct ProjectEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let heading: String
    let onSave: (ProjectDraft) -> Void

    @State private var draft: ProjectDraft

    init(
        heading: String,
        draft: ProjectDraft,
        onSave: @escaping (ProjectDraft) -> Void
    ) {
        self.heading = heading
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            Divider()

            Form {
                Section("Project details") {
                    TextField("Name", text: $draft.name)
                        .textFieldStyle(.roundedBorder)

                    TextField("Description", text: $draft.projectDescription, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section("Accent") {
                    HStack(spacing: 14) {
                        ForEach(ProjectAccent.allCases, id: \.self) { accent in
                            Button {
                                draft.accent = accent
                            } label: {
                                Circle()
                                    .fill(accent.color.gradient)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if draft.accent == accent {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .overlay {
                                        Circle()
                                            .stroke(.primary.opacity(0.12), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(accent.title)
                            .accessibilityAddTraits(draft.accent == accent ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .formStyle(.grouped)

            Divider()
            editorActions
        }
        .frame(width: 500, height: 430)
    }

    private var editorHeader: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(draft.accent.color.gradient)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(heading)
                    .font(.title2.weight(.semibold))
                Text("Give this Project a clear outcome.")
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
            .tint(draft.accent.color)
            .keyboardShortcut(.defaultAction)
            .disabled(!draft.canSave)
        }
        .padding()
    }
}

