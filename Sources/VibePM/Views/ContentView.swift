import SwiftData
import SwiftUI
import VibePMCore

private enum SidebarSelection: Hashable {
    case inbox
    case today
    case project(UUID)
    case archive
}

private struct TaskEditorRequest: Identifiable {
    enum Mode {
        case create(projectID: UUID?, scheduledFor: Date?)
        case edit(ProjectTask)
    }

    let id = UUID()
    let mode: Mode
}

private struct ProjectEditorRequest: Identifiable {
    enum Mode {
        case create
        case edit(Project)
    }

    let id = UUID()
    let mode: Mode
}

private enum ProjectDestructiveRequest: Identifiable {
    case archive(Project)
    case delete(Project)

    var project: Project {
        switch self {
        case let .archive(project), let .delete(project): project
        }
    }

    var id: String {
        switch self {
        case let .archive(project): "archive-\(project.id)"
        case let .delete(project): "delete-\(project.id)"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @Query(sort: \ProjectTask.createdAt, order: .reverse) private var tasks: [ProjectTask]

    @State private var selection: SidebarSelection? = .inbox
    @State private var taskEditorRequest: TaskEditorRequest?
    @State private var projectEditorRequest: ProjectEditorRequest?
    @State private var projectDestructiveRequest: ProjectDestructiveRequest?
    @State private var searchText = ""
    @State private var priorityFilter: TaskPriority?
    @State private var statusFilter: TaskStatus?
    @State private var taskViewMode: TaskViewMode = .list
    @AppStorage("remindersEnabled") private var remindersEnabled = false
    @AppStorage(TaskSortOption.userDefaultsKey) private var taskSortRawValue = TaskSortOption.createdNewest.rawValue

    private var activeProjects: [Project] {
        projects.filter { !$0.isArchived }
    }

    private var archivedProjects: [Project] {
        projects.filter(\.isArchived)
    }

    private var selectedProject: Project? {
        guard case let .project(id) = selection else { return nil }
        return projects.first { $0.id == id }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(item: $taskEditorRequest, onDismiss: { taskEditorRequest = nil }) { request in
            taskEditor(for: request)
        }
        .sheet(item: $projectEditorRequest) { request in
            projectEditor(for: request)
        }
        .alert(item: $projectDestructiveRequest, content: projectDestructiveAlert)
        .searchable(text: $searchText, placement: .toolbar, prompt: L10n.text("Search Tasks"))
        .tint(VibeTheme.accent)
    }

    private var sidebar: some View {
        List(selection: $selection) {
            BrandHeader()
                .listRowInsets(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 12))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            Section(L10n.text("Focus")) {
                sidebarRow(
                    title: L10n.text("Inbox"),
                    systemImage: "tray.fill",
                    count: inboxTaskCount,
                    color: .blue
                )
                .tag(SidebarSelection.inbox)

                sidebarRow(
                    title: L10n.text("Today"),
                    systemImage: "sun.max.fill",
                    count: todayTaskCount,
                    color: .orange
                )
                .tag(SidebarSelection.today)
            }

            Section(L10n.text("Projects")) {
                ForEach(activeProjects) { project in
                    ProjectSidebarRow(
                        project: project,
                        taskCount: taskCount(for: project),
                        onEdit: { presentProjectEditor(project) },
                        onArchive: { requestArchiveProject(project) },
                        onDelete: { requestDeleteProject(project) }
                    )
                    .tag(SidebarSelection.project(project.id))
                }

                Button(action: presentNewProject) {
                    Label(L10n.text("New Project"), systemImage: "plus")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Section {
                sidebarRow(
                    title: L10n.text("Archive"),
                    systemImage: "archivebox.fill",
                    count: archivedProjects.count,
                    color: .secondary
                )
                .tag(SidebarSelection.archive)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 300)
    }

    @ViewBuilder
    private var detail: some View {
        if selection == .archive {
            ProjectArchiveView(
                projects: archivedProjects,
                taskCount: taskCount,
                onRestore: restoreProject,
                onDelete: requestDeleteProject
            )
        } else {
            TaskCollectionView(
                title: detailTitle,
                subtitle: detailSubtitle,
                accent: detailAccent,
                headerSystemImage: detailSystemImage,
                tasks: filteredTasks,
                supportsProjectViews: selectedProject != nil,
                viewMode: $taskViewMode,
                priorityFilter: $priorityFilter,
                statusFilter: $statusFilter,
                sortOption: taskSortBinding,
                onAdd: presentNewTask,
                onEdit: presentTaskEditor,
                onToggleCompletion: toggleCompletion,
                onMove: moveTask,
                onDelete: deleteTasks,
                onEditProject: selectedProject.map { project in
                    { presentProjectEditor(project) }
                },
                onArchiveProject: selectedProject.map { project in
                    { requestArchiveProject(project) }
                },
                onDeleteProject: selectedProject.map { project in
                    { requestDeleteProject(project) }
                }
            )
        }
    }

    private var detailTitle: String {
        switch selection {
        case .inbox, .none:
            L10n.text("Inbox")
        case .today:
            L10n.text("Today")
        case let .project(id):
            projects.first(where: { $0.id == id })?.name ?? L10n.text("Project")
        case .archive:
            L10n.text("Archive")
        }
    }

    private var taskSortBinding: Binding<TaskSortOption> {
        Binding(
            get: { TaskSortOption(rawValue: taskSortRawValue) ?? .createdNewest },
            set: { taskSortRawValue = $0.rawValue }
        )
    }

    private var detailSubtitle: String {
        switch selection {
        case .inbox, .none:
            L10n.text("Capture now. Organize when you are ready.")
        case .today:
            L10n.text("A calm view of what needs your attention.")
        case .project:
            selectedProject?.projectDescription.isEmpty == false
                ? selectedProject?.projectDescription ?? ""
                : L10n.text("Move this Project toward its outcome.")
        case .archive:
            ""
        }
    }

    private var detailAccent: Color {
        selectedProject?.accent.color ?? VibeTheme.accent
    }

    private var detailSystemImage: String {
        switch selection {
        case .today: "sun.max.fill"
        case .project: "folder.fill"
        default: "checklist"
        }
    }

    private var filteredTasks: [ProjectTask] {
        let scopedTasks: [ProjectTask]

        switch selection {
        case .inbox, .none:
            scopedTasks = tasks.filter { $0.projectID == nil }
        case .today:
            let calendar = Calendar.current
            scopedTasks = tasks.filter { task in
                guard task.status != .done else { return false }
                return task.scheduledFor.map(calendar.isDateInToday) == true
                    || task.dueAt.map(calendar.isDateInToday) == true
            }
        case let .project(id):
            scopedTasks = tasks.filter { $0.projectID == id }
        case .archive:
            return []
        }

        let filter = TaskFilter(
            searchText: searchText,
            priority: priorityFilter,
            status: statusFilter
        )
        return filter.isActive ? scopedTasks.filter(filter.matches) : scopedTasks
    }

    private var inboxTaskCount: Int {
        tasks.count { $0.projectID == nil && $0.parentTaskID == nil && $0.status != .done }
    }

    private var todayTaskCount: Int {
        let calendar = Calendar.current
        return tasks.count { task in
            guard task.status != .done else { return false }
            return task.scheduledFor.map(calendar.isDateInToday) == true
                || task.dueAt.map(calendar.isDateInToday) == true
        }
    }

    private func taskCount(for project: Project) -> Int {
        tasks.count { $0.projectID == project.id && $0.status != .done }
    }

    private func sidebarRow(
        title: String,
        systemImage: String,
        count: Int,
        color: Color
    ) -> some View {
        HStack {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
            }
            Spacer()
            CountBadge(count: count)
        }
    }

    private func presentNewProject() {
        projectEditorRequest = ProjectEditorRequest(mode: .create)
    }

    private func presentProjectEditor(_ project: Project) {
        projectEditorRequest = ProjectEditorRequest(mode: .edit(project))
    }

    private func requestArchiveProject(_ project: Project) {
        projectDestructiveRequest = .archive(project)
    }

    private func requestDeleteProject(_ project: Project) {
        projectDestructiveRequest = .delete(project)
    }

    private func archiveProject(_ project: Project) {
        project.archive()
        try? modelContext.save()
        selection = .inbox
    }

    private func restoreProject(_ project: Project) {
        project.restore()
        try? modelContext.save()
        selection = .project(project.id)
    }

    private func deleteProject(_ project: Project) {
        let deletionTaskIDs = ProjectDeletion.taskIDs(for: project.id, in: tasks)
        let remainingTasks = tasks.filter { !deletionTaskIDs.contains($0.id) }

        for task in tasks where deletionTaskIDs.contains(task.id) {
            modelContext.delete(task)
        }
        modelContext.delete(project)
        try? modelContext.save()
        selection = .inbox

        if remindersEnabled {
            Task {
                try? await TaskReminderService.schedule(tasks: remainingTasks)
            }
        }
    }

    private func projectDestructiveAlert(for request: ProjectDestructiveRequest) -> Alert {
        switch request {
        case let .archive(project):
            Alert(
                title: Text(L10n.format("Archive \"%@\"?", arguments: [project.name])),
                message: Text(L10n.text("The Project and its Tasks will move to Archive. You can restore them later.")),
                primaryButton: .default(Text(L10n.text("Archive Project"))) {
                    archiveProject(project)
                },
                secondaryButton: .cancel(Text(L10n.text("Cancel")))
            )
        case let .delete(project):
            Alert(
                title: Text(L10n.format("Delete \"%@\"?", arguments: [project.name])),
                message: Text(L10n.text("The Project and all of its Tasks and Subtasks will be permanently deleted. This cannot be undone.")),
                primaryButton: .destructive(Text(L10n.text("Delete Project"))) {
                    deleteProject(project)
                },
                secondaryButton: .cancel(Text(L10n.text("Cancel")))
            )
        }
    }

    @ViewBuilder
    private func projectEditor(for request: ProjectEditorRequest) -> some View {
        switch request.mode {
        case .create:
            ProjectEditorView(
                heading: L10n.text("New Project"),
                draft: ProjectDraft()
            ) { draft in
                let project = draft.makeProject()
                modelContext.insert(project)
                selection = .project(project.id)
            }
        case let .edit(project):
            ProjectEditorView(
                heading: L10n.text("Edit Project"),
                draft: ProjectDraft(project: project)
            ) { draft in
                draft.apply(to: project)
            }
        }
    }

    private func presentNewTask() {
        let projectID: UUID?
        if case let .project(id) = selection {
            projectID = id
        } else {
            projectID = nil
        }

        taskEditorRequest = TaskEditorRequest(
            mode: .create(
                projectID: projectID,
                scheduledFor: selection == .today ? .now : nil
            )
        )
    }

    private func presentTaskEditor(_ task: ProjectTask) {
        taskEditorRequest = TaskEditorRequest(mode: .edit(task))
    }

    @ViewBuilder
    private func taskEditor(for request: TaskEditorRequest) -> some View {
        switch request.mode {
        case let .create(projectID, scheduledFor):
            TaskEditorView(
                heading: L10n.text("New Task"),
                draft: TaskDraft(
                    projectID: projectID,
                    scheduledFor: scheduledFor
                ),
                projects: activeProjects,
                parentTasks: parentTaskCandidates()
            ) { draft in
                modelContext.insert(normalizedHierarchy(draft).makeTask())
                taskEditorRequest = nil
            }
        case let .edit(task):
            TaskEditorView(
                heading: L10n.text("Edit Task"),
                draft: TaskDraft(task: task),
                projects: activeProjects,
                parentTasks: parentTaskCandidates(excluding: task.id)
            ) { draft in
                normalizedHierarchy(draft).apply(to: task)
                taskEditorRequest = nil
            }
        }
    }

    private func parentTaskCandidates(excluding taskID: UUID? = nil) -> [ProjectTask] {
        tasks.filter { task in
            task.parentTaskID == nil && task.id != taskID
        }
    }

    private func normalizedHierarchy(_ draft: TaskDraft) -> TaskDraft {
        var draft = draft
        if let parentTaskID = draft.parentTaskID,
           let parent = tasks.first(where: { $0.id == parentTaskID }) {
            draft.projectID = parent.projectID
        }
        return draft
    }

    private func toggleCompletion(_ task: ProjectTask) {
        if task.status == .done {
            task.reopen()
        } else {
            task.markDone()
        }
    }

    private func moveTask(_ task: ProjectTask, to status: TaskStatus) {
        task.move(to: status)
    }

    private func deleteTasks(_ selectedIDs: Set<UUID>) {
        let deletionIDs = TaskHierarchy.deletionIDs(selectedIDs: selectedIDs, in: tasks)
        let remainingTasks = tasks.filter { !deletionIDs.contains($0.id) }

        for task in tasks where deletionIDs.contains(task.id) {
            modelContext.delete(task)
        }
        try? modelContext.save()

        if remindersEnabled {
            Task {
                try? await TaskReminderService.schedule(tasks: remainingTasks)
            }
        }
    }
}

private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(VibeTheme.brandGradient)
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                .shadow(color: VibeTheme.accent.opacity(0.24), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text("VibePM")
                    .font(.headline)
                Text(L10n.text("Make progress feel lighter"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

private struct ProjectSidebarRow: View {
    let project: Project
    let taskCount: Int
    let onEdit: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(project.accent.color.gradient)
                .frame(width: 10, height: 10)
                .shadow(color: project.accent.color.opacity(0.25), radius: 3)
            Text(project.name)
                .lineLimit(1)
            Spacer()
            CountBadge(count: taskCount)
        }
        .contextMenu {
            Button(L10n.text("Edit Project"), systemImage: "pencil", action: onEdit)
            Button(L10n.text("Archive Project"), systemImage: "archivebox", action: onArchive)
            Divider()
            Button(L10n.text("Delete Project"), systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}
