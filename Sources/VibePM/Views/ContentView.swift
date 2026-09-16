import SwiftData
import SwiftUI
import VibePMCore

private enum SidebarSelection: Hashable {
    case inbox
    case today
    case project(UUID)
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @Query(sort: \ProjectTask.createdAt, order: .reverse) private var tasks: [ProjectTask]

    @State private var selection: SidebarSelection? = .inbox

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
                onAdd: addTask,
                onToggleCompletion: toggleCompletion
            )
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

    private func addTask() {
        let projectID: UUID?
        if case let .project(id) = selection {
            projectID = id
        } else {
            projectID = nil
        }

        let task = ProjectTask(title: "New Task", projectID: projectID)
        if selection == .today {
            task.scheduledFor = .now
        }
        modelContext.insert(task)
    }

    private func toggleCompletion(_ task: ProjectTask) {
        if task.status == .done {
            task.reopen()
        } else {
            task.markDone()
        }
    }
}

