import SwiftUI
import VibePMCore

struct TaskCollectionView: View {
    let title: String
    let subtitle: String
    let accent: Color
    let tasks: [ProjectTask]
    let supportsBoard: Bool
    @Binding var viewMode: TaskViewMode
    @Binding var priorityFilter: TaskPriority?
    @Binding var statusFilter: TaskStatus?
    let onAdd: () -> Void
    let onEdit: (ProjectTask) -> Void
    let onToggleCompletion: (ProjectTask) -> Void
    let onMove: (ProjectTask, TaskStatus) -> Void
    let onEditProject: (() -> Void)?
    let onArchiveProject: (() -> Void)?

    private var parentTasks: [ProjectTask] {
        tasks.filter { $0.parentTaskID == nil }
    }

    private var orphanSubtasks: [ProjectTask] {
        let visibleParentIDs = Set(parentTasks.map(\.id))
        return tasks.filter { task in
            guard let parentTaskID = task.parentTaskID else { return false }
            return !visibleParentIDs.contains(parentTaskID)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            collectionHeader

            if tasks.isEmpty {
                emptyState
            } else if supportsBoard && viewMode == .board {
                TaskBoardView(
                    tasks: tasks,
                    accent: accent,
                    onEdit: onEdit,
                    onMove: onMove
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
        VStack(alignment: .leading, spacing: 15) {
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

                if supportsBoard {
                    Picker("View", selection: $viewMode) {
                        ForEach(TaskViewMode.allCases, id: \.self) { mode in
                            Label(mode.title, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .labelsHidden()
                }
            }

            HStack(spacing: 10) {
                filterMenu
                if priorityFilter != nil || statusFilter != nil {
                    Button("Clear Filters", systemImage: "xmark.circle") {
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
            Picker("Priority", selection: $priorityFilter) {
                Text("Any Priority").tag(TaskPriority?.none)
                ForEach(TaskPriority.allCases.filter { $0 != .none }, id: \.self) { priority in
                    Text(priority.title).tag(Optional(priority))
                }
            }

            Picker("Status", selection: $statusFilter) {
                Text("Any Status").tag(TaskStatus?.none)
                ForEach(TaskStatus.allCases, id: \.self) { status in
                    Text(status.title).tag(Optional(status))
                }
            }
        } label: {
            Label(
                priorityFilter == nil && statusFilter == nil ? "Filter" : "Filtered",
                systemImage: "line.3.horizontal.decrease.circle"
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(parentTasks) { task in
                    TaskRowView(
                        task: task,
                        accent: accent,
                        isSubtask: false,
                        onEdit: { onEdit(task) },
                        onToggleCompletion: { onToggleCompletion(task) },
                        onMove: { onMove(task, $0) }
                    )

                    ForEach(subtasks(for: task)) { subtask in
                        TaskRowView(
                            task: subtask,
                            accent: accent,
                            isSubtask: true,
                            onEdit: { onEdit(subtask) },
                            onToggleCompletion: { onToggleCompletion(subtask) },
                            onMove: { onMove(subtask, $0) }
                        )
                        .padding(.leading, 30)
                    }
                }

                ForEach(orphanSubtasks) { subtask in
                    TaskRowView(
                        task: subtask,
                        accent: accent,
                        isSubtask: true,
                        onEdit: { onEdit(subtask) },
                        onToggleCompletion: { onToggleCompletion(subtask) },
                        onMove: { onMove(subtask, $0) }
                    )
                    .padding(.leading, 30)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
    }

    private func subtasks(for task: ProjectTask) -> [ProjectTask] {
        tasks.filter { $0.parentTaskID == task.id }
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
                    .accessibilityLabel("Subtask")
            }

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

            Menu {
                ForEach(TaskStatus.allCases, id: \.self) { status in
                    Button(status.title) {
                        onMove(status)
                    }
                    .disabled(status == task.status)
                }
            } label: {
                Text(task.status.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(task.status == .done ? .green : accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background((task.status == .done ? Color.green : accent).opacity(0.09), in: Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

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
