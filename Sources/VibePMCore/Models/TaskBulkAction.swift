import Foundation

public enum BulkProjectDestination: Hashable, Sendable {
    case keepCurrent
    case inbox
    case project(UUID)

    public var projectID: UUID? {
        switch self {
        case .keepCurrent, .inbox: nil
        case let .project(id): id
        }
    }
}

public struct TaskBulkAction: Equatable, Sendable {
    public var status: TaskStatus?
    public var priority: TaskPriority?
    public var destination: BulkProjectDestination

    public init(
        status: TaskStatus? = nil,
        priority: TaskPriority? = nil,
        destination: BulkProjectDestination = .keepCurrent
    ) {
        self.status = status
        self.priority = priority
        self.destination = destination
    }

    public var hasRequestedChanges: Bool {
        status != nil || priority != nil || destination != .keepCurrent
    }

    public func preview(
        selectedIDs: Set<UUID>,
        tasks: [ProjectTask]
    ) -> TaskBulkPreview {
        let active = tasks.filter { $0.deletedAt == nil }
        let selected = active.filter { selectedIDs.contains($0.id) }
        let selectedSet = Set(selected.map(\.id))
        let movingIDs: Set<UUID>
        if destination == .keepCurrent {
            movingIDs = []
        } else {
            movingIDs = TaskHierarchy.deletionIDs(selectedIDs: selectedSet, in: active)
        }

        let moved = active.count { task in
            movingIDs.contains(task.id) && task.projectID != destination.projectID
        }
        let changedSelected = selected.count { task in
            (status.map { $0 != task.status } ?? false)
                || (priority.map { $0 != task.priority } ?? false)
        }
        return TaskBulkPreview(
            selectedCount: selected.count,
            movedCount: moved,
            changedCount: active.count { task in
                (selectedSet.contains(task.id) &&
                    ((status.map { $0 != task.status } ?? false) ||
                     (priority.map { $0 != task.priority } ?? false)))
                    || (movingIDs.contains(task.id) && task.projectID != destination.projectID)
            },
            additionallyMovedCount: active.count { task in
                movingIDs.contains(task.id) && !selectedSet.contains(task.id)
                    && task.projectID != destination.projectID
            },
            changedSelectedCount: changedSelected
        )
    }

    @discardableResult
    public func apply(
        selectedIDs: Set<UUID>,
        tasks: [ProjectTask],
        now: Date = .now
    ) -> TaskBulkPreview {
        let active = tasks.filter { $0.deletedAt == nil }
        let preview = preview(selectedIDs: selectedIDs, tasks: active)
        let selectedSet = Set(active.filter { selectedIDs.contains($0.id) }.map(\.id))
        let movingIDs = destination == .keepCurrent
            ? Set<UUID>()
            : TaskHierarchy.deletionIDs(selectedIDs: selectedSet, in: active)
        let tasksByID = Dictionary(uniqueKeysWithValues: active.map { ($0.id, $0) })

        for task in active {
            var changed = false
            if selectedSet.contains(task.id) {
                if let status, task.status != status {
                    task.move(to: status, at: now)
                    changed = true
                }
                if let priority, task.priority != priority {
                    task.priority = priority
                    changed = true
                }
            }

            if movingIDs.contains(task.id), task.projectID != destination.projectID {
                task.projectID = destination.projectID
                if let parentID = task.parentTaskID,
                   !movingIDs.contains(parentID),
                   tasksByID[parentID]?.projectID != destination.projectID {
                    task.parentTaskID = nil
                }
                changed = true
            }

            if changed { task.updatedAt = now }
        }
        return preview
    }
}

public struct TaskBulkPreview: Equatable, Sendable {
    public let selectedCount: Int
    public let movedCount: Int
    public let changedCount: Int
    public let additionallyMovedCount: Int
    public let changedSelectedCount: Int

    public var canApply: Bool { changedCount > 0 }
}
