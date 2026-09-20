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
    @Binding var sortOption: TaskSortOption
    let onAdd: () -> Void
    let onEdit: (ProjectTask) -> Void
    let onToggleCompletion: (ProjectTask) -> Void
    let onMove: (ProjectTask, TaskStatus) -> Void
    let onDelete: (Set<UUID>) -> Void
    let onEditProject: (() -> Void)?
    let onArchiveProject: (() -> Void)?
    let onDeleteProject: (() -> Void)?
    let onImportProjectTasks: (() -> Void)?
    let onExportProject: (() -> Void)?
    let onExportProjectTemplate: (() -> Void)?

    @State private var isSelecting = false
    @State private var selectedTaskIDs: Set<UUID> = []
    @State private var pendingDeletionIDs: Set<UUID> = []
    @State private var pendingTaskName: String?
    @State private var showsDeleteConfirmation = false

    private var orderedTasks: [ProjectTask] {
        TaskSorter.parentFirst(tasks, by: sortOption)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            collectionHeader

            if tasks.isEmpty {
                emptyState
            } else if supportsProjectViews && viewMode == .board {
                TaskBoardView(
                    tasks: orderedTasks,
                    accent: accent,
                    isSelecting: isSelecting,
                    selectedTaskIDs: selectedTaskIDs,
                    onToggleSelection: toggleSelection,
                    onEdit: onEdit,
                    onMove: onMove,
                    onDelete: requestDelete
                )
            } else if supportsProjectViews && viewMode == .gantt {
                GanttView(
                    tasks: orderedTasks,
                    accent: accent,
                    isSelecting: isSelecting,
                    selectedTaskIDs: selectedTaskIDs,
                    onToggleSelection: toggleSelection,
                    onEdit: onEdit,
                    onDelete: requestDelete
                )
            } else {
                taskList
            }
        }
        .background(VibeTheme.canvas)
        .alert(deleteConfirmationTitle, isPresented: $showsDeleteConfirmation) {
            Button(L10n.text("Cancel"), role: .cancel) {}
            Button(L10n.text("Move to Trash"), role: .destructive, action: confirmDeletion)
        } message: {
            Text(deleteConfirmationMessage)
        }
        .onChange(of: tasks.map(\.id)) {
            selectedTaskIDs.formIntersection(Set(tasks.map(\.id)))
            if tasks.isEmpty { endSelection() }
        }
        .toolbar {
            ToolbarItemGroup {
                if !tasks.isEmpty {
                    Button(action: toggleSelectionMode) {
                        Label(
                            L10n.text(isSelecting ? "Done Selecting" : "Select Tasks"),
                            systemImage: isSelecting ? "checkmark.circle.fill" : "checkmark.circle"
                        )
                    }
                }

                if isSelecting && !selectedTaskIDs.isEmpty {
                    Button(role: .destructive, action: requestBulkDelete) {
                        Label(
                            L10n.format("Move %d Tasks to Trash", arguments: [selectedTaskIDs.count]),
                            systemImage: "trash"
                        )
                    }
                    .tint(.red)
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

                Button(action: onAdd) {
                    Label(L10n.text("New Task"), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .fixedSize()

                if supportsProjectViews {
                    projectActionsMenu

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
                sortMenu
                if priorityFilter != nil || statusFilter != nil {
                    Button(L10n.text("Clear Filters"), systemImage: "xmark.circle") {
                        priorityFilter = nil
                        statusFilter = nil
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }

                if isSelecting {
                    Divider().frame(height: 18)
                    Text(L10n.format("%d selected", arguments: [selectedTaskIDs.count]))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(selectedTaskIDs.isEmpty ? .secondary : accent)

                    Button(L10n.text(allVisibleTasksSelected ? "Deselect All" : "Select All")) {
                        if allVisibleTasksSelected {
                            selectedTaskIDs.removeAll()
                        } else {
                            selectedTaskIDs = Set(tasks.map(\.id))
                        }
                    }
                    .buttonStyle(.borderless)

                    if !selectedTaskIDs.isEmpty {
                        Button(L10n.text("Move to Trash"), systemImage: "trash", role: .destructive) {
                            requestBulkDelete()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var projectActionsMenu: some View {
        if let onEditProject,
           let onArchiveProject,
           let onDeleteProject,
           let onImportProjectTasks,
           let onExportProject,
           let onExportProjectTemplate {
            Menu {
                Button(L10n.text("Import Tasks…"), systemImage: "square.and.arrow.down", action: onImportProjectTasks)
                Button(L10n.text("Export Project…"), systemImage: "square.and.arrow.up", action: onExportProject)
                Button(L10n.text("Download Template…"), systemImage: "arrow.down.doc", action: onExportProjectTemplate)
                Divider()
                Button(L10n.text("Edit Project"), systemImage: "pencil", action: onEditProject)
                Button(L10n.text("Archive Project"), systemImage: "archivebox", action: onArchiveProject)
                Divider()
                Button(
                    L10n.text("Move to Trash"),
                    systemImage: "trash",
                    role: .destructive,
                    action: onDeleteProject
                )
            } label: {
                Label(L10n.text("Project actions"), systemImage: "ellipsis.circle")
            }
            .buttonStyle(.bordered)
            .fixedSize()
        }
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

    private var sortMenu: some View {
        Menu {
            Picker(L10n.text("Sort Tasks"), selection: $sortOption) {
                ForEach(TaskSortOption.allCases, id: \.self) { option in
                    Text(L10n.text(option.title)).tag(option)
                }
            }
        } label: {
            Label(L10n.text(sortOption.title), systemImage: "arrow.up.arrow.down.circle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(L10n.text("Sort Tasks"))
    }

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(orderedTasks) { task in
                    TaskRowView(
                        task: task,
                        accent: accent,
                        isSubtask: task.parentTaskID != nil,
                        isSelecting: isSelecting,
                        isSelected: selectedTaskIDs.contains(task.id),
                        onToggleSelection: { toggleSelection(task) },
                        onEdit: { onEdit(task) },
                        onToggleCompletion: { onToggleCompletion(task) },
                        onMove: { onMove(task, $0) },
                        onDelete: { requestDelete(task) }
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

    private var allVisibleTasksSelected: Bool {
        !tasks.isEmpty && Set(tasks.map(\.id)).isSubset(of: selectedTaskIDs)
    }

    private var deleteConfirmationTitle: String {
        if let pendingTaskName {
            return L10n.format("Move \"%@\" to Trash?", arguments: [pendingTaskName])
        }
        return L10n.format("Move %d Tasks to Trash?", arguments: [pendingDeletionIDs.count])
    }

    private var deleteConfirmationMessage: String {
        if pendingTaskName != nil {
            return L10n.text("This Task and its Subtasks can be restored from Trash for 30 days.")
        }
        return L10n.text("The selected Tasks and their Subtasks can be restored from Trash for 30 days.")
    }

    private func toggleSelectionMode() {
        if isSelecting {
            endSelection()
        } else {
            isSelecting = true
            selectedTaskIDs = Set(tasks.map(\.id))
        }
    }

    private func endSelection() {
        isSelecting = false
        selectedTaskIDs.removeAll()
    }

    private func toggleSelection(_ task: ProjectTask) {
        if selectedTaskIDs.contains(task.id) {
            selectedTaskIDs.remove(task.id)
        } else {
            selectedTaskIDs.insert(task.id)
        }
    }

    private func requestDelete(_ task: ProjectTask) {
        pendingDeletionIDs = [task.id]
        pendingTaskName = task.title
        showsDeleteConfirmation = true
    }

    private func requestBulkDelete() {
        guard !selectedTaskIDs.isEmpty else { return }
        pendingDeletionIDs = selectedTaskIDs
        pendingTaskName = nil
        showsDeleteConfirmation = true
    }

    private func confirmDeletion() {
        onDelete(pendingDeletionIDs)
        pendingDeletionIDs.removeAll()
        pendingTaskName = nil
        endSelection()
    }
}

private struct TaskRowView: View {
    let task: ProjectTask
    let accent: Color
    let isSubtask: Bool
    let isSelecting: Bool
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onEdit: () -> Void
    let onToggleCompletion: () -> Void
    let onMove: (TaskStatus) -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 13) {
            if isSubtask {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel(L10n.text("Subtask"))
            }

            if isSelecting {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? accent : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text(isSelected ? "Deselect Task" : "Select Task"))
            } else {
                Button(action: onToggleCompletion) {
                    Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(task.status == .done ? accent : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text(task.status == .done ? "Reopen Task" : "Complete Task"))
            }

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
            .onTapGesture(perform: isSelecting ? onToggleSelection : onEdit)

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

            if isHovering && !isSelecting {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(L10n.text("Edit Task"))
                .transition(.opacity)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .accessibilityLabel(L10n.text("Delete Task"))
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
        .contextMenu {
            Button(L10n.text("Edit Task"), systemImage: "pencil", action: onEdit)
            Divider()
            Button(L10n.text("Delete Task"), systemImage: "trash", role: .destructive, action: onDelete)
        }
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
