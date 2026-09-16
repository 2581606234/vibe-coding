import Foundation
import SwiftData

public struct VibePMBackup: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let exportedAt: Date
    public let projects: [ProjectRecord]
    public let tasks: [TaskRecord]

    public init(
        projects: [Project],
        tasks: [ProjectTask],
        exportedAt: Date = .now
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.exportedAt = exportedAt
        self.projects = projects.map(ProjectRecord.init)
        self.tasks = tasks.map(TaskRecord.init)
    }

    init(
        schemaVersion: Int,
        exportedAt: Date,
        projects: [ProjectRecord],
        tasks: [TaskRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.projects = projects
        self.tasks = tasks
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decoded(from data: Data) throws -> VibePMBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Self.self, from: data)
        guard backup.schemaVersion == currentSchemaVersion else {
            throw BackupError.unsupportedSchemaVersion(backup.schemaVersion)
        }
        return backup
    }

    @MainActor
    public func restore(into context: ModelContext) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw BackupError.unsupportedSchemaVersion(schemaVersion)
        }

        let storedProjects = try context.fetch(FetchDescriptor<Project>())
        var projectsByID = Dictionary(uniqueKeysWithValues: storedProjects.map { ($0.id, $0) })

        for record in projects {
            if let project = projectsByID[record.id] {
                record.apply(to: project)
            } else {
                let project = record.makeProject()
                context.insert(project)
                projectsByID[record.id] = project
            }
        }

        let storedTasks = try context.fetch(FetchDescriptor<ProjectTask>())
        var tasksByID = Dictionary(uniqueKeysWithValues: storedTasks.map { ($0.id, $0) })

        for record in tasks {
            if let task = tasksByID[record.id] {
                record.apply(to: task)
            } else {
                let task = record.makeTask()
                context.insert(task)
                tasksByID[record.id] = task
            }
        }

        try context.save()
    }
}

public struct ProjectRecord: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let projectDescription: String
    public let createdAt: Date
    public let updatedAt: Date
    public let isArchived: Bool
    public let accent: ProjectAccent

    init(
        id: UUID,
        name: String,
        projectDescription: String,
        createdAt: Date,
        updatedAt: Date,
        isArchived: Bool,
        accent: ProjectAccent
    ) {
        self.id = id
        self.name = name
        self.projectDescription = projectDescription
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.accent = accent
    }

    init(project: Project) {
        id = project.id
        name = project.name
        projectDescription = project.projectDescription
        createdAt = project.createdAt
        updatedAt = project.updatedAt
        isArchived = project.isArchived
        accent = project.accent
    }

    func makeProject() -> Project {
        Project(
            id: id,
            name: name,
            projectDescription: projectDescription,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isArchived: isArchived,
            accent: accent
        )
    }

    func apply(to project: Project) {
        project.name = name
        project.projectDescription = projectDescription
        project.createdAt = createdAt
        project.updatedAt = updatedAt
        project.isArchived = isArchived
        project.accent = accent
    }
}

public struct TaskRecord: Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let taskDescription: String
    public let status: TaskStatus
    public let priority: TaskPriority
    public let projectID: UUID?
    public let parentTaskID: UUID?
    public let scheduledFor: Date?
    public let dueAt: Date?
    public let completedAt: Date?
    public let createdAt: Date
    public let updatedAt: Date

    init(
        id: UUID,
        title: String,
        taskDescription: String,
        status: TaskStatus,
        priority: TaskPriority,
        projectID: UUID?,
        parentTaskID: UUID?,
        scheduledFor: Date?,
        dueAt: Date?,
        completedAt: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.taskDescription = taskDescription
        self.status = status
        self.priority = priority
        self.projectID = projectID
        self.parentTaskID = parentTaskID
        self.scheduledFor = scheduledFor
        self.dueAt = dueAt
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(task: ProjectTask) {
        id = task.id
        title = task.title
        taskDescription = task.taskDescription
        status = task.status
        priority = task.priority
        projectID = task.projectID
        parentTaskID = task.parentTaskID
        scheduledFor = task.scheduledFor
        dueAt = task.dueAt
        completedAt = task.completedAt
        createdAt = task.createdAt
        updatedAt = task.updatedAt
    }

    func makeTask() -> ProjectTask {
        ProjectTask(
            id: id,
            title: title,
            taskDescription: taskDescription,
            status: status,
            priority: priority,
            projectID: projectID,
            parentTaskID: parentTaskID,
            scheduledFor: scheduledFor,
            dueAt: dueAt,
            completedAt: completedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(to task: ProjectTask) {
        task.title = title
        task.taskDescription = taskDescription
        task.status = status
        task.priority = priority
        task.projectID = projectID
        task.parentTaskID = parentTaskID
        task.scheduledFor = scheduledFor
        task.dueAt = dueAt
        task.completedAt = completedAt
        task.createdAt = createdAt
        task.updatedAt = updatedAt
    }
}

public enum BackupError: LocalizedError, Equatable {
    case unsupportedSchemaVersion(Int)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedSchemaVersion(version):
            "This backup uses unsupported schema version \(version)."
        }
    }
}
