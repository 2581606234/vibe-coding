import Foundation

public struct WorkbookImportPreview: Equatable, Sendable {
    public let projectCreates: Int
    public let projectUpdates: Int
    public let taskCreates: Int
    public let taskUpdates: Int

    public var projectTotal: Int { projectCreates + projectUpdates }
    public var taskTotal: Int { taskCreates + taskUpdates }

    public init(
        workbook: VibePMExcelWorkbook,
        existingProjects: [Project],
        existingTasks: [ProjectTask]
    ) {
        let projectIDs = Set(existingProjects.map(\.id))
        let taskIDs = Set(existingTasks.map(\.id))
        projectUpdates = workbook.projects.count { projectIDs.contains($0.id) }
        projectCreates = workbook.projects.count - projectUpdates
        taskUpdates = workbook.tasks.count { taskIDs.contains($0.id) }
        taskCreates = workbook.tasks.count - taskUpdates
    }
}

public struct ProjectWorkbookImportPreview: Equatable, Sendable {
    public let creates: Int
    public let updates: Int
    public let skips: Int
    public let conflicts: Int
    public let conflictItems: [ProjectWorkbookConflict]
    let updateIDs: Set<UUID>

    public var canImport: Bool { conflicts == 0 }

    public init(
        workbook: ProjectExcelWorkbook,
        targetProjectID: UUID,
        existingTasks: [ProjectTask]
    ) {
        let existingByID = Dictionary(uniqueKeysWithValues: existingTasks.map { ($0.id, $0) })
        let importedByID = Dictionary(uniqueKeysWithValues: workbook.tasks.map { ($0.id, $0) })
        let importedIDs = Set(importedByID.keys)
        var conflictsByID: [UUID: ProjectWorkbookConflict] = [:]

        for record in workbook.tasks {
            if let existing = existingByID[record.id],
               existing.deletedAt != nil || existing.projectID != targetProjectID {
                conflictsByID[record.id] = ProjectWorkbookConflict(
                    taskID: record.id,
                    taskTitle: record.title,
                    reason: existing.deletedAt == nil ? .identifierOutsideProject : .identifierInTrash
                )
                continue
            }

            guard let parentID = record.parentTaskID else { continue }
            if parentID == record.id {
                conflictsByID[record.id] = ProjectWorkbookConflict(
                    taskID: record.id,
                    taskTitle: record.title,
                    reason: .invalidParent
                )
            } else if !importedIDs.contains(parentID) {
                let parent = existingByID[parentID]
                if parent == nil || parent?.deletedAt != nil || parent?.projectID != targetProjectID {
                    conflictsByID[record.id] = ProjectWorkbookConflict(
                        taskID: record.id,
                        taskTitle: record.title,
                        reason: .parentOutsideProject
                    )
                }
            }
        }

        for id in Self.cycleIDs(in: importedByID) where conflictsByID[id] == nil {
            let record = importedByID[id]!
            conflictsByID[id] = ProjectWorkbookConflict(
                taskID: id,
                taskTitle: record.title,
                reason: .parentCycle
            )
        }

        var createCount = 0
        var updateCount = 0
        var skipCount = 0
        var updates = Set<UUID>()
        for record in workbook.tasks where conflictsByID[record.id] == nil {
            guard let existing = existingByID[record.id] else {
                createCount += 1
                continue
            }
            if Self.matches(record, existing: existing) {
                skipCount += 1
            } else {
                updateCount += 1
                updates.insert(record.id)
            }
        }

        creates = createCount
        self.updates = updateCount
        skips = skipCount
        conflictItems = workbook.tasks.compactMap { conflictsByID[$0.id] }
        conflicts = conflictItems.count
        updateIDs = updates
    }

    private static func matches(_ record: TaskRecord, existing: ProjectTask) -> Bool {
        record.title == existing.title
            && record.taskDescription == existing.taskDescription
            && record.status == existing.status
            && record.priority == existing.priority
            && record.parentTaskID == existing.parentTaskID
            && record.scheduledFor == existing.scheduledFor
            && record.dueAt == existing.dueAt
            && record.completedAt == existing.completedAt
    }

    private static func cycleIDs(in records: [UUID: TaskRecord]) -> Set<UUID> {
        var result = Set<UUID>()
        for start in records.keys {
            var path: [UUID] = []
            var positions: [UUID: Int] = [:]
            var current: UUID? = start
            while let id = current, let record = records[id] {
                if let position = positions[id] {
                    result.formUnion(path[position...])
                    break
                }
                positions[id] = path.count
                path.append(id)
                current = record.parentTaskID
            }
        }
        return result
    }
}

public struct ProjectWorkbookConflict: Equatable, Sendable, Identifiable {
    public enum Reason: Equatable, Sendable {
        case identifierOutsideProject
        case identifierInTrash
        case parentOutsideProject
        case invalidParent
        case parentCycle
    }

    public var id: UUID { taskID }
    public let taskID: UUID
    public let taskTitle: String
    public let reason: Reason
}
