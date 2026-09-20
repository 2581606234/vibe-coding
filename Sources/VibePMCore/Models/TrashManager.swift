import Foundation

public enum TrashManager {
    public static let retentionDays = 30

    @discardableResult
    public static func moveTasks(
        selectedIDs: Set<UUID>,
        in tasks: [ProjectTask],
        batchID: UUID = UUID(),
        at date: Date = .now
    ) -> UUID {
        let activeTasks = tasks.filter { $0.deletedAt == nil }
        let deletionIDs = TaskHierarchy.deletionIDs(selectedIDs: selectedIDs, in: activeTasks)
        for task in activeTasks where deletionIDs.contains(task.id) {
            task.moveToTrash(batchID: batchID, at: date)
        }
        return batchID
    }

    @discardableResult
    public static func moveProject(
        _ project: Project,
        tasks: [ProjectTask],
        batchID: UUID = UUID(),
        at date: Date = .now
    ) -> UUID {
        project.moveToTrash(batchID: batchID, at: date)
        for task in tasks where task.projectID == project.id && task.deletedAt == nil {
            task.moveToTrash(batchID: batchID, at: date)
        }
        return batchID
    }

    public static func restore(
        batchID: UUID,
        projects: [Project],
        tasks: [ProjectTask],
        at date: Date = .now
    ) {
        for project in projects where project.deletionBatchID == batchID {
            project.restoreFromTrash(at: date)
        }

        let restoredProjectIDs = Set(projects.filter { $0.deletedAt == nil }.map(\.id))
        let restoredTaskIDs = Set(tasks.filter {
            $0.deletedAt == nil || $0.deletionBatchID == batchID
        }.map(\.id))

        for task in tasks where task.deletionBatchID == batchID {
            if let projectID = task.projectID, !restoredProjectIDs.contains(projectID) {
                task.projectID = nil
            }
            if let parentTaskID = task.parentTaskID, !restoredTaskIDs.contains(parentTaskID) {
                task.parentTaskID = nil
            }
            task.restoreFromTrash(at: date)
        }
    }

    public static func expiredProjectIDs(
        in projects: [Project],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Set<UUID> {
        let cutoff = calendar.date(byAdding: .day, value: -retentionDays, to: now) ?? now
        return Set(projects.lazy.filter { ($0.deletedAt ?? .distantFuture) <= cutoff }.map(\.id))
    }

    public static func expiredTaskIDs(
        in tasks: [ProjectTask],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Set<UUID> {
        let cutoff = calendar.date(byAdding: .day, value: -retentionDays, to: now) ?? now
        return Set(tasks.lazy.filter { ($0.deletedAt ?? .distantFuture) <= cutoff }.map(\.id))
    }
}
