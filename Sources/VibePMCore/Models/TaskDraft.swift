import Foundation

public struct TaskDraft: Equatable, Sendable {
    public var title: String
    public var taskDescription: String
    public var status: TaskStatus
    public var priority: TaskPriority
    public var projectID: UUID?
    public var parentTaskID: UUID?
    public var scheduledFor: Date?
    public var dueAt: Date?

    public init(
        title: String = "",
        taskDescription: String = "",
        status: TaskStatus = .todo,
        priority: TaskPriority = .none,
        projectID: UUID? = nil,
        parentTaskID: UUID? = nil,
        scheduledFor: Date? = nil,
        dueAt: Date? = nil
    ) {
        self.title = title
        self.taskDescription = taskDescription
        self.status = status
        self.priority = priority
        self.projectID = projectID
        self.parentTaskID = parentTaskID
        self.scheduledFor = scheduledFor
        self.dueAt = dueAt
    }

    public init(task: ProjectTask) {
        self.init(
            title: task.title,
            taskDescription: task.taskDescription,
            status: task.status,
            priority: task.priority,
            projectID: task.projectID,
            parentTaskID: task.parentTaskID,
            scheduledFor: task.scheduledFor,
            dueAt: task.dueAt
        )
    }

    public var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var canSave: Bool {
        !normalizedTitle.isEmpty
    }

    public func makeTask(now: Date = .now) -> ProjectTask {
        ProjectTask(
            title: normalizedTitle,
            taskDescription: taskDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status,
            priority: priority,
            projectID: projectID,
            parentTaskID: parentTaskID,
            scheduledFor: scheduledFor,
            dueAt: dueAt,
            createdAt: now,
            updatedAt: now
        )
    }

    public func apply(to task: ProjectTask, now: Date = .now) {
        task.title = normalizedTitle
        task.taskDescription = taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        task.status = status
        task.priority = priority
        task.projectID = projectID
        task.parentTaskID = parentTaskID
        task.scheduledFor = scheduledFor
        task.dueAt = dueAt
        task.updatedAt = now
    }
}
