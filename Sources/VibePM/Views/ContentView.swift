import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import VibePMCore

private enum SidebarSelection: Hashable {
    case inbox
    case today
    case project(UUID)
    case archive
    case trash
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
    @State private var persistenceErrorMessage: String?
    @State private var showsPersistenceError = false
    @State private var undoBatchID: UUID?
    @State private var undoMessage = ""
    @State private var undoToken: UUID?
    @State private var isImportingProjectWorkbook = false
    @State private var projectImportTargetID: UUID?
    @State private var pendingProjectWorkbookImport: PendingProjectWorkbookImport?
    @AppStorage("remindersEnabled") private var remindersEnabled = false
    @AppStorage(TaskSortOption.userDefaultsKey) private var taskSortRawValue = TaskSortOption.createdNewest.rawValue
    @AppStorage("lastAutomaticRecoveryPointAt") private var lastAutomaticRecoveryPointAt = 0.0

    private var activeProjects: [Project] {
        projects.filter { $0.deletedAt == nil && !$0.isArchived }
    }

    private var archivedProjects: [Project] {
        projects.filter { $0.deletedAt == nil && $0.isArchived }
    }

    private var availableTasks: [ProjectTask] {
        tasks.filter { $0.deletedAt == nil }
    }

    private var trashedProjects: [Project] {
        projects.filter { $0.deletedAt != nil }
    }

    private var trashTaskGroups: [TrashTaskGroup] {
        let deletedProjectIDs = Set(trashedProjects.map(\.id))
        let independentTasks = tasks.filter { task in
            task.deletedAt != nil && !(task.projectID.map { deletedProjectIDs.contains($0) } ?? false)
        }
        return TrashTaskGroup.make(from: independentTasks)
    }

    private var selectedProject: Project? {
        guard case let .project(id) = selection else { return nil }
        return activeProjects.first { $0.id == id }
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
        .sheet(item: $pendingProjectWorkbookImport) { pending in
            ProjectImportPreviewView(
                projectName: pending.project.name,
                preview: pending.preview,
                onCancel: { pendingProjectWorkbookImport = nil },
                onImport: { confirmProjectWorkbookImport(pending) }
            )
        }
        .fileImporter(
            isPresented: $isImportingProjectWorkbook,
            allowedContentTypes: [.vibePMExcel],
            allowsMultipleSelection: false,
            onCompletion: importProjectWorkbook
        )
        .alert(item: $projectDestructiveRequest, content: projectDestructiveAlert)
        .alert("VibePM", isPresented: $showsPersistenceError) {
            Button(L10n.text("OK"), role: .cancel) {}
        } message: {
            Text(persistenceErrorMessage ?? L10n.text("Unable to save changes."))
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: L10n.text("Search Tasks"))
        .tint(VibeTheme.accent)
        .safeAreaInset(edge: .bottom) {
            if undoBatchID != nil {
                undoBar
            }
        }
        .task {
            performLaunchMaintenance()
        }
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

                sidebarRow(
                    title: L10n.text("Trash"),
                    systemImage: "trash.fill",
                    count: trashedProjects.count + trashTaskGroups.count,
                    color: .secondary
                )
                .tag(SidebarSelection.trash)
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
        } else if selection == .trash {
            TrashView(
                projects: trashedProjects,
                taskGroups: trashTaskGroups,
                taskCount: { project in tasks.count { $0.projectID == project.id } },
                onRestore: restoreDeletionBatch,
                onPermanentlyDeleteProject: permanentlyDeleteProject,
                onPermanentlyDeleteTaskGroup: permanentlyDeleteTaskGroup,
                onEmptyTrash: emptyTrash
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
                activeProjects: activeProjects,
                allActiveTasks: availableTasks,
                onApplyBulk: applyBulkAction,
                onEditProject: selectedProject.map { project in
                    { presentProjectEditor(project) }
                },
                onArchiveProject: selectedProject.map { project in
                    { requestArchiveProject(project) }
                },
                onDeleteProject: selectedProject.map { project in
                    { requestDeleteProject(project) }
                },
                onImportProjectTasks: selectedProject.map { project in
                    { presentProjectWorkbookImport(project) }
                },
                onExportProject: selectedProject.map { project in
                    { exportProjectWorkbook(project) }
                },
                onExportProjectTemplate: selectedProject.map { project in
                    { exportProjectTemplate(project) }
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
        case .trash:
            L10n.text("Trash")
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
        case .trash:
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
        case .trash: "trash.fill"
        default: "checklist"
        }
    }

    private var filteredTasks: [ProjectTask] {
        let scopedTasks: [ProjectTask]

        switch selection {
        case .inbox, .none:
            scopedTasks = availableTasks.filter { $0.projectID == nil }
        case .today:
            let calendar = Calendar.current
            scopedTasks = availableTasks.filter { task in
                guard task.status != .done else { return false }
                return task.scheduledFor.map(calendar.isDateInToday) == true
                    || task.dueAt.map(calendar.isDateInToday) == true
            }
        case let .project(id):
            scopedTasks = availableTasks.filter { $0.projectID == id }
        case .archive, .trash:
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
        availableTasks.count { $0.projectID == nil && $0.parentTaskID == nil && $0.status != .done }
    }

    private var todayTaskCount: Int {
        let calendar = Calendar.current
        return availableTasks.count { task in
            guard task.status != .done else { return false }
            return task.scheduledFor.map(calendar.isDateInToday) == true
                || task.dueAt.map(calendar.isDateInToday) == true
        }
    }

    private func taskCount(for project: Project) -> Int {
        availableTasks.count { $0.projectID == project.id && $0.status != .done }
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
        persistChanges {
            selection = .inbox
        }
    }

    private func restoreProject(_ project: Project) {
        project.restore()
        persistChanges {
            selection = .project(project.id)
        }
    }

    private func deleteProject(_ project: Project) {
        let batchID = TrashManager.moveProject(project, tasks: tasks)
        persistChanges {
            selection = .inbox
            showUndo(
                batchID: batchID,
                message: L10n.format("Moved \"%@\" to Trash.", arguments: [project.name])
            )
            refreshReminders()
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
                title: Text(L10n.format("Move \"%@\" to Trash?", arguments: [project.name])),
                message: Text(L10n.text("The Project and its Tasks can be restored from Trash for 30 days.")),
                primaryButton: .destructive(Text(L10n.text("Move to Trash"))) {
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
                return persistChanges {
                    selection = .project(project.id)
                }
            }
        case let .edit(project):
            ProjectEditorView(
                heading: L10n.text("Edit Project"),
                draft: ProjectDraft(project: project)
            ) { draft in
                draft.apply(to: project)
                return persistChanges()
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
                return persistChanges {
                    taskEditorRequest = nil
                    refreshReminders()
                }
            }
        case let .edit(task):
            TaskEditorView(
                heading: L10n.text("Edit Task"),
                draft: TaskDraft(task: task),
                projects: activeProjects,
                parentTasks: parentTaskCandidates(excluding: task.id)
            ) { draft in
                normalizedHierarchy(draft).apply(to: task)
                return persistChanges {
                    taskEditorRequest = nil
                    refreshReminders()
                }
            }
        }
    }

    private func parentTaskCandidates(excluding taskID: UUID? = nil) -> [ProjectTask] {
        availableTasks.filter { task in
            task.parentTaskID == nil && task.id != taskID
        }
    }

    private func normalizedHierarchy(_ draft: TaskDraft) -> TaskDraft {
        var draft = draft
        if let parentTaskID = draft.parentTaskID,
           let parent = availableTasks.first(where: { $0.id == parentTaskID }) {
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
        persistChanges {
            refreshReminders()
        }
    }

    private func moveTask(_ task: ProjectTask, to status: TaskStatus) {
        task.move(to: status)
        persistChanges {
            refreshReminders()
        }
    }

    private func deleteTasks(_ selectedIDs: Set<UUID>) {
        let batchID = TrashManager.moveTasks(selectedIDs: selectedIDs, in: tasks)
        let movedCount = tasks.count { $0.deletionBatchID == batchID }
        persistChanges {
            showUndo(
                batchID: batchID,
                message: L10n.format("Moved %d Tasks to Trash.", arguments: [movedCount])
            )
            refreshReminders()
        }
    }

    private func applyBulkAction(_ selectedIDs: Set<UUID>, _ action: TaskBulkAction) -> Bool {
        if case let .project(projectID) = action.destination,
           !activeProjects.contains(where: { $0.id == projectID }) {
            persistenceErrorMessage = L10n.text("Selected destination is no longer active.")
            showsPersistenceError = true
            return false
        }
        let preview = action.preview(selectedIDs: selectedIDs, tasks: availableTasks)
        guard preview.canApply else { return false }

        do {
            let store = try RecoveryPointStore.applicationSupport()
            _ = try store.create(
                backup: VibePMBackup(projects: projects, tasks: tasks),
                kind: .preBulk
            )
            action.apply(selectedIDs: selectedIDs, tasks: availableTasks)
            return persistChanges {
                refreshReminders()
            }
        } catch {
            persistenceErrorMessage = L10n.format(
                "Unable to save changes: %@",
                arguments: [error.localizedDescription]
            )
            showsPersistenceError = true
            return false
        }
    }

    private func presentProjectWorkbookImport(_ project: Project) {
        projectImportTargetID = project.id
        isImportingProjectWorkbook = true
    }

    private func exportProjectWorkbook(_ project: Project) {
        do {
            let workbook = ProjectExcelWorkbook(project: project, tasks: availableTasks)
            let date = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
            try saveProjectExcel(
                workbook.encoded(project: project),
                filename: "VibePM-\(safeFilename(project.name))-\(date)",
                message: L10n.text("Project workbook exported successfully.")
            )
        } catch {
            showMessage(L10n.format("Export failed: %@", arguments: [error.localizedDescription]))
        }
    }

    private func exportProjectTemplate(_ project: Project) {
        do {
            let language = L10n.selectedLanguage()
            try saveProjectExcel(
                ProjectExcelWorkbook.templateData(project: project, language: language),
                filename: language.resolved() == .simplifiedChinese
                    ? "VibePM-\(safeFilename(project.name))-任务导入模板"
                    : "VibePM-\(safeFilename(project.name))-Task-Import-Template",
                message: L10n.text("Project import template saved successfully.")
            )
        } catch {
            showMessage(L10n.format("Export failed: %@", arguments: [error.localizedDescription]))
        }
    }

    private func saveProjectExcel(_ data: Data, filename: String, message: String) throws {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.vibePMExcel]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(filename).xlsx"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try data.write(to: url, options: .atomic)
        showMessage(message)
    }

    private func importProjectWorkbook(_ result: Result<[URL], Error>) {
        defer { projectImportTargetID = nil }
        do {
            guard let projectID = projectImportTargetID,
                  let project = activeProjects.first(where: { $0.id == projectID }),
                  let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            let workbook = try ProjectExcelWorkbook.decoded(from: Data(contentsOf: url))
            pendingProjectWorkbookImport = PendingProjectWorkbookImport(
                project: project,
                workbook: workbook,
                preview: ProjectWorkbookImportPreview(
                    workbook: workbook,
                    targetProjectID: project.id,
                    existingTasks: tasks
                )
            )
        } catch {
            showMessage(L10n.format("Import failed: %@", arguments: [error.localizedDescription]))
        }
    }

    private func confirmProjectWorkbookImport(_ pending: PendingProjectWorkbookImport) {
        do {
            let store = try RecoveryPointStore.applicationSupport()
            _ = try store.create(
                backup: VibePMBackup(projects: projects, tasks: tasks),
                kind: .preImport
            )
            try pending.workbook.restore(
                into: modelContext,
                targetProjectID: pending.project.id,
                existingTasks: tasks
            )
            pendingProjectWorkbookImport = nil
            showMessage(L10n.format(
                "Imported %d new Tasks and updated %d Tasks in %@.",
                arguments: [pending.preview.creates, pending.preview.updates, pending.project.name]
            ))
            refreshReminders()
        } catch {
            modelContext.rollback()
            pendingProjectWorkbookImport = nil
            showMessage(L10n.format("Import failed: %@", arguments: [error.localizedDescription]))
        }
    }

    private func safeFilename(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }

    private func showMessage(_ message: String) {
        persistenceErrorMessage = message
        showsPersistenceError = true
    }

    private func restoreDeletionBatch(_ batchID: UUID) {
        TrashManager.restore(batchID: batchID, projects: projects, tasks: tasks)
        persistChanges {
            if undoBatchID == batchID {
                undoBatchID = nil
                undoToken = nil
            }
            refreshReminders()
        }
    }

    private func permanentlyDeleteProject(_ project: Project) {
        for task in tasks where task.projectID == project.id {
            modelContext.delete(task)
        }
        modelContext.delete(project)
        persistChanges()
    }

    private func permanentlyDeleteTaskGroup(_ group: TrashTaskGroup) {
        for task in group.tasks {
            modelContext.delete(task)
        }
        persistChanges()
    }

    private func emptyTrash() {
        let taskIDs = TrashManager.permanentDeletionTaskIDs(projects: projects, tasks: tasks)
        for task in tasks where taskIDs.contains(task.id) {
            modelContext.delete(task)
        }
        for project in trashedProjects {
            modelContext.delete(project)
        }
        persistChanges {
            undoBatchID = nil
            undoToken = nil
            refreshReminders()
        }
    }

    @discardableResult
    private func persistChanges(onSuccess: () -> Void = {}) -> Bool {
        do {
            try modelContext.save()
            onSuccess()
            return true
        } catch {
            modelContext.rollback()
            persistenceErrorMessage = L10n.format(
                "Unable to save changes: %@",
                arguments: [error.localizedDescription]
            )
            showsPersistenceError = true
            return false
        }
    }

    private func showUndo(batchID: UUID, message: String) {
        let token = UUID()
        undoBatchID = batchID
        undoMessage = message
        undoToken = token
        Task {
            try? await Task.sleep(for: .seconds(8))
            guard undoToken == token else { return }
            undoBatchID = nil
            undoToken = nil
        }
    }

    private var undoBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "trash")
            Text(undoMessage)
                .lineLimit(1)
            Spacer()
            Button(L10n.text("Undo")) {
                if let undoBatchID {
                    restoreDeletionBatch(undoBatchID)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private func performLaunchMaintenance() {
        let expiredProjectIDs = TrashManager.expiredProjectIDs(in: projects)
        let expiredTaskIDs = TrashManager.expiredTaskIDs(in: tasks)
        for task in tasks where expiredTaskIDs.contains(task.id) || (task.projectID.map { expiredProjectIDs.contains($0) } ?? false) {
            modelContext.delete(task)
        }
        for project in projects where expiredProjectIDs.contains(project.id) {
            modelContext.delete(project)
        }

        if !expiredProjectIDs.isEmpty || !expiredTaskIDs.isEmpty {
            persistChanges()
        }

        do {
            let store = try RecoveryPointStore.applicationSupport()
            let currentProjects = try modelContext.fetch(FetchDescriptor<Project>())
            let currentTasks = try modelContext.fetch(FetchDescriptor<ProjectTask>())
            if let descriptor = try store.createAutomaticIfNeeded(
                backup: VibePMBackup(projects: currentProjects, tasks: currentTasks)
            ) {
                lastAutomaticRecoveryPointAt = descriptor.createdAt.timeIntervalSince1970
            } else if let latest = try store.descriptors().first(where: { $0.kind == .automatic }) {
                lastAutomaticRecoveryPointAt = latest.createdAt.timeIntervalSince1970
            }
        } catch {
            persistenceErrorMessage = L10n.format(
                "Unable to create a recovery point: %@",
                arguments: [error.localizedDescription]
            )
            showsPersistenceError = true
        }
    }

    private func refreshReminders() {
        guard remindersEnabled else { return }
        let active = tasks.filter { $0.deletedAt == nil }
        Task {
            try? await TaskReminderService.schedule(tasks: active)
        }
    }
}

private struct PendingProjectWorkbookImport: Identifiable {
    let id = UUID()
    let project: Project
    let workbook: ProjectExcelWorkbook
    let preview: ProjectWorkbookImportPreview
}

private struct ProjectImportPreviewView: View {
    let projectName: String
    let preview: ProjectWorkbookImportPreview
    let onCancel: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "tablecells")
                    .font(.title2)
                    .foregroundStyle(VibeTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("Project Import Preview"))
                        .font(.title2.bold())
                    Text(L10n.format("Import Tasks into %@.", arguments: [projectName]))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                previewMetric(L10n.text("Create"), preview.creates, color: .green)
                previewMetric(L10n.text("Update"), preview.updates, color: VibeTheme.accent)
                previewMetric(L10n.text("Skip"), preview.skips, color: .secondary)
                previewMetric(L10n.text("Conflict"), preview.conflicts, color: .red)
            }

            if !preview.conflictItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        L10n.text("Resolve conflicts before importing."),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.red)

                    ForEach(preview.conflictItems.prefix(6)) { item in
                        Text("• \(item.taskTitle): \(conflictText(item.reason))")
                            .font(.callout)
                    }
                    if preview.conflictItems.count > 6 {
                        Text(L10n.format(
                            "And %d more conflicts.",
                            arguments: [preview.conflictItems.count - 6]
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            Text(L10n.text("A recovery point will be created automatically before import."))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button(L10n.text("Cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(L10n.text("Import"), action: onImport)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!preview.canImport)
            }
        }
        .padding(24)
        .frame(width: 600)
    }

    private func previewMetric(_ title: String, _ value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.formatted())
                .font(.title2.bold())
                .foregroundStyle(color)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    private func conflictText(_ reason: ProjectWorkbookConflict.Reason) -> String {
        switch reason {
        case .identifierOutsideProject:
            L10n.text("Task ID belongs to Inbox or another Project.")
        case .identifierInTrash:
            L10n.text("Task ID belongs to an item in Trash.")
        case .parentOutsideProject:
            L10n.text("Parent Task is not in this Project or workbook.")
        case .invalidParent:
            L10n.text("A Task cannot be its own Parent Task.")
        case .parentCycle:
            L10n.text("Parent Task relationships contain a cycle.")
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
            Button(L10n.text("Move to Trash"), systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}
