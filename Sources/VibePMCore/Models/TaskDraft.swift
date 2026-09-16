import Foundation

public struct TaskDraft: Equatable, Sendable {
    public var title: String
    public var taskDescription: String
    public var priority: TaskPriority
    public var projectID: UUID?
    public var scheduledFor: Date?
    public var dueAt: Date?

    public init(
        title: String = "",
        taskDescription: String = "",
        priority: TaskPriority = .none,
        projectID: UUID? = nil,
        scheduledFor: Date? = nil,
        dueAt: Date? = nil
    ) {
        self.title = title
        self.taskDescription = taskDescription
        self.priority = priority
        self.projectID = projectID
        self.scheduledFor = scheduledFor
        self.dueAt = dueAt
    }

    public init(task: ProjectTask) {
        self.init(
            title: task.title,
            taskDescription: task.taskDescription,
            priority: task.priority,
            projectID: task.projectID,
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
            priority: priority,
            projectID: projectID,
            scheduledFor: scheduledFor,
            dueAt: dueAt,
            createdAt: now,
            updatedAt: now
        )
    }

    public func apply(to task: ProjectTask, now: Date = .now) {
        task.title = normalizedTitle
        task.taskDescription = taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        task.priority = priority
        task.projectID = projectID
        task.scheduledFor = scheduledFor
        task.dueAt = dueAt
        task.updatedAt = now
    }
}

