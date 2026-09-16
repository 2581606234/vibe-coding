import SwiftUI
import VibePMCore

struct TaskCollectionView: View {
    let title: String
    let subtitle: String
    let accent: Color
    let tasks: [ProjectTask]
    let onAdd: () -> Void
    let onEdit: (ProjectTask) -> Void
    let onToggleCompletion: (ProjectTask) -> Void
    let onEditProject: (() -> Void)?
    let onArchiveProject: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            collectionHeader

            if tasks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(tasks) { task in
                            TaskRowView(
                                task: task,
                                accent: accent,
                                onEdit: { onEdit(task) },
                                onToggleCompletion: { onToggleCompletion(task) }
                            )
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(VibeTheme.canvas)
        .toolbar {
            ToolbarItemGroup {
                if let onEditProject, let onArchiveProject {
                    Menu {
                        Button("Edit Project", systemImage: "pencil", action: onEditProject)
                        Button("Archive Project", systemImage: "archivebox", action: onArchiveProject)
                    } label: {
                        Label("Project actions", systemImage: "ellipsis.circle")
                    }
                }

                Button(action: onAdd) {
                    Label("New Task", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }

    private var collectionHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(accent.gradient)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: title == "Today" ? "sun.max.fill" : "checklist")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: accent.opacity(0.24), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 9) {
                    Text(title)
                        .font(.largeTitle.bold())
                    CountBadge(count: tasks.count)
                }
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.10))
                    .frame(width: 84, height: 84)
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(spacing: 5) {
                Text("Nothing here yet")
                    .font(.title3.weight(.semibold))
                Text("Capture the next concrete action when you are ready.")
                    .foregroundStyle(.secondary)
            }

            Button("Create a Task", action: onAdd)
                .buttonStyle(.borderedProminent)
                .tint(accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
}

private struct TaskRowView: View {
    let task: ProjectTask
    let accent: Color
    let onEdit: () -> Void
    let onToggleCompletion: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 13) {
            Button(action: onToggleCompletion) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.status == .done ? accent : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.status == .done ? "Reopen Task" : "Complete Task")

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.body.weight(.medium))
                    .strikethrough(task.status == .done)
                    .foregroundStyle(task.status == .done ? .secondary : .primary)

                if !task.taskDescription.isEmpty {
                    Text(task.taskDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                TaskMetadataView(task: task)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

            Spacer(minLength: 12)

            if isHovering {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Edit Task")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .vibeCard()
        .overlay(alignment: .leading) {
            Capsule()
                .fill(task.priority == .none ? accent.opacity(0.22) : task.priority.color)
                .frame(width: 3)
                .padding(.vertical, 11)
        }
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovering)
    }
}

private struct TaskMetadataView: View {
    let task: ProjectTask

    var body: some View {
        HStack(spacing: 10) {
            if task.priority != .none {
                Label(task.priority.title, systemImage: "flag.fill")
                    .foregroundStyle(task.priority.color)
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
