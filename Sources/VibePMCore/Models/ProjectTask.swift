import Foundation
import SwiftData

public enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case todo
    case inProgress
    case done

    public var title: String {
        switch self {
        case .todo: "To Do"
        case .inProgress: "In Progress"
        case .done: "Done"
        }
    }
}

public enum TaskPriority: Int, Codable, CaseIterable, Sendable {
    case none
    case low
    case medium
    case high

    public var title: String {
        switch self {
        case .none: "None"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

@Model
public final class ProjectTask {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var taskDescription: String
    public var statusRawValue: String
    public var priorityRawValue: Int
    public var projectID: UUID?
    public var parentTaskID: UUID?
    public var scheduledFor: Date?
    public var dueAt: Date?
    public var completedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public var status: TaskStatus {
        get { TaskStatus(rawValue: statusRawValue) ?? .todo }
        set { statusRawValue = newValue.rawValue }
    }

    public var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRawValue) ?? .none }
        set { priorityRawValue = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        taskDescription: String = "",
        status: TaskStatus = .todo,
        priority: TaskPriority = .none,
        projectID: UUID? = nil,
        parentTaskID: UUID? = nil,
        scheduledFor: Date? = nil,
        dueAt: Date? = nil,
        completedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.taskDescription = taskDescription
        self.statusRawValue = status.rawValue
        self.priorityRawValue = priority.rawValue
        self.projectID = projectID
        self.parentTaskID = parentTaskID
        self.scheduledFor = scheduledFor
        self.dueAt = dueAt
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func markDone(at date: Date = .now) {
        status = .done
        completedAt = date
        updatedAt = date
    }

    public func reopen(at date: Date = .now) {
        status = .todo
        completedAt = nil
        updatedAt = date
    }
}

