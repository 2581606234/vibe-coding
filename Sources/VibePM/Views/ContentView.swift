import SwiftData
import SwiftUI
import VibePMCore

private enum SidebarSelection: Hashable {
    case inbox
    case today
    case project(UUID)
}

private struct TaskEditorRequest: Identifiable {
    enum Mode {
        case create(projectID: UUID?, scheduledFor: Date?)
        case edit(ProjectTask)
    }

    let id = UUID()
    let mode: Mode
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @Query(sort: \ProjectTask.createdAt, order: .reverse) private var tasks: [ProjectTask]

    @State private var selection: SidebarSelection? = .inbox
    @State private var taskEditorRequest: TaskEditorRequest?

    private var activeProjects: [Project] {
        projects.filter { !$0.isArchived }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Focus") {
                    Label("Inbox", systemImage: "tray")
                        .tag(SidebarSelection.inbox)
                    Label("Today", systemImage: "sun.max")
                        .tag(SidebarSelection.today)
                }

                Section("Projects") {
                    ForEach(activeProjects) { project in
                        Label(project.name, systemImage: "folder")
                            .tag(SidebarSelection.project(project.id))
                    }
                }
            }
            .navigationTitle("VibePM")
            .toolbar {
                Button(action: addProject) {
                    Label("New Project", systemImage: "folder.badge.plus")
                }
            }
        } detail: {
            TaskCollectionView(
                title: detailTitle,
                tasks: filteredTasks,
                onAdd: presentNewTask,
                onEdit: presentTaskEditor,
                onToggleCompletion: toggleCompletion
            )
        }
        .sheet(item: $taskEditorRequest) { request in
            taskEditor(for: request)
        }
    }

    private var detailTitle: String {
        switch selection {
        case .inbox, .none:
            return "Inbox"
        case .today:
            return "Today"
        case let .project(id):
            return projects.first(where: { $0.id == id })?.name ?? "Project"
        }
    }

    private var filteredTasks: [ProjectTask] {
        switch selection {
        case .inbox, .none:
            return tasks.filter { $0.projectID == nil && $0.parentTaskID == nil }
        case .today:
            let calendar = Calendar.current
            return tasks.filter { task in
                guard task.status != .done else { return false }
                return task.scheduledFor.map(calendar.isDateInToday) == true
                    || task.dueAt.map(calendar.isDateInToday) == true
            }
        case let .project(id):
            return tasks.filter { $0.projectID == id && $0.parentTaskID == nil }
        }
    }

    private func addProject() {
        let project = Project(name: "New Project")
        modelContext.insert(project)
        selection = .project(project.id)
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
                heading: "New Task",
                draft: TaskDraft(
                    projectID: projectID,
                    scheduledFor: scheduledFor
                ),
                projects: activeProjects
            ) { draft in
                modelContext.insert(draft.makeTask())
            }
        case let .edit(task):
            TaskEditorView(
                heading: "Edit Task",
                draft: TaskDraft(task: task),
                projects: activeProjects
            ) { draft in
                draft.apply(to: task)
            }
        }
    }

    private func toggleCompletion(_ task: ProjectTask) {
        if task.status == .done {
            task.reopen()
        } else {
            task.markDone()
        }
    }
}
