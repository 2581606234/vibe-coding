import SwiftUI
import VibePMCore

struct TaskCollectionView: View {
    let title: String
    let subtitle: String
    let accent: Color
    let headerSystemImage: String
    let tasks: [ProjectTask]
    let supportsProjectViews: Bool
    @Binding var viewMode: TaskViewMode
    @Binding var priorityFilter: TaskPriority?
    @Binding var statusFilter: TaskStatus?
    let onAdd: () -> Void
    let onEdit: (ProjectTask) -> Void
    let onToggleCompletion: (ProjectTask) -> Void
    let onMove: (ProjectTask, TaskStatus) -> Void
    let onEditProject: (() -> Void)?
    let onArchiveProject: (() -> Void)?

    private var orderedTasks: [ProjectTask] {
        TaskHierarchy.parentFirst(tasks)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            collectionHeader

            if tasks.isEmpty {
                emptyState
            } else if supportsProjectViews && viewMode == .board {
                TaskBoardView(
                    tasks: tasks,
                    accent: accent,
                    onEdit: onEdit,
                    onMove: onMove
                )
            } else if supportsProjectViews && viewMode == .gantt {
                GanttView(
                    tasks: tasks,
                    accent: accent,
                    onEdit: onEdit
                )
            } else {
                taskList
            }
        }
        .background(VibeTheme.canvas)
        .toolbar {
            ToolbarItemGroup {
                if let onEditProject, let onArchiveProject {
                    Menu {
                        Button(L10n.text("Edit Project"), systemImage: "pencil", action: onEditProject)
                        Button(L10n.text("Archive Project"), systemImage: "archivebox", action: onArchiveProject)
                    } label: {
                        Label(L10n.text("Project actions"), systemImage: "ellipsis.circle")
                    }
                }

                Button(action: onAdd) {
                    Label(L10n.text("New Task"), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }

    private var collectionHeader: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(accent.gradient)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: headerSystemImage)
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

                if supportsProjectViews {
                    Picker(L10n.text("View"), selection: $viewMode) {
                        ForEach(TaskViewMode.allCases, id: \.self) { mode in
                            Label(L10n.text(mode.title), systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 238)
                    .labelsHidden()
                }
            }

            HStack(spacing: 10) {
                filterMenu
                if priorityFilter != nil || statusFilter != nil {
                    Button(L10n.text("Clear Filters"), systemImage: "xmark.circle") {
                        priorityFilter = nil
                        statusFilter = nil
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    private var filterMenu: some View {
        Menu {
            Picker(L10n.text("Priority"), selection: $priorityFilter) {
                Text(L10n.text("Any Priority")).tag(TaskPriority?.none)
                ForEach(TaskPriority.allCases.filter { $0 != .none }, id: \.self) { priority in
                    Text(L10n.text(priority.title)).tag(Optional(priority))
                }
            }

            Picker(L10n.text("Status"), selection: $statusFilter) {
                Text(L10n.text("Any Status")).tag(TaskStatus?.none)
                ForEach(TaskStatus.allCases, id: \.self) { status in
                    Text(L10n.text(status.title)).tag(Optional(status))
                }
            }
        } label: {
            Label(
                L10n.text(priorityFilter == nil && statusFilter == nil ? "Filter" : "Filtered"),
                systemImage: "line.3.horizontal.decrease.circle"
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(orderedTasks) { task in
                    TaskRowView(
                        task: task,
                        accent: accent,
                        isSubtask: task.parentTaskID != nil,
                        onEdit: { onEdit(task) },
                        onToggleCompletion: { onToggleCompletion(task) },
                        onMove: { onMove(task, $0) }
                    )
                    .padding(.leading, task.parentTaskID == nil ? 0 : 30)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
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
                Text(L10n.text("Nothing here yet"))
                    .font(.title3.weight(.semibold))
                Text(L10n.text("Capture the next concrete action when you are ready."))
                    .foregroundStyle(.secondary)
            }

            Button(L10n.text("Create a Task"), action: onAdd)
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
    let isSubtask: Bool
    let onEdit: () -> Void
    let onToggleCompletion: () -> Void
    let onMove: (TaskStatus) -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 13) {
            if isSubtask {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel(L10n.text("Subtask"))
            }

            Button(action: onToggleCompletion) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.status == .done ? accent : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text(task.status == .done ? "Reopen Task" : "Complete Task"))

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

            Menu {
                ForEach(TaskStatus.allCases, id: \.self) { status in
                    Button(L10n.text(status.title)) {
                        onMove(status)
                    }
                    .disabled(status == task.status)
                }
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(task.status == .done ? Color.green : accent)
                        .frame(width: 6, height: 6)
                    Text(L10n.text(task.status.title))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(task.status == .done ? .green : accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background((task.status == .done ? Color.green : accent).opacity(0.09), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke((task.status == .done ? Color.green : accent).opacity(0.14), lineWidth: 1)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            if isHovering {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(L10n.text("Edit Task"))
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
                Label(L10n.text(task.priority.title), systemImage: "flag.fill")
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
