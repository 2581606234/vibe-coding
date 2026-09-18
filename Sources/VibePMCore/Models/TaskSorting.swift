import Foundation

public enum TaskSortOption: String, CaseIterable, Sendable {
    public static let userDefaultsKey = "taskSortOption"

    case createdNewest
    case createdOldest
    case priorityHighToLow
    case priorityLowToHigh
    case scheduleEarliest
    case scheduleLatest
    case dueEarliest
    case dueLatest

    public var title: String {
        switch self {
        case .createdNewest: "Created: Newest First"
        case .createdOldest: "Created: Oldest First"
        case .priorityHighToLow: "Priority: High to Low"
        case .priorityLowToHigh: "Priority: Low to High"
        case .scheduleEarliest: "Schedule: Earliest First"
        case .scheduleLatest: "Schedule: Latest First"
        case .dueEarliest: "Due: Earliest First"
        case .dueLatest: "Due: Latest First"
        }
    }
}

public enum TaskSorter {
    public static func parentFirst(
        _ tasks: [ProjectTask],
        by option: TaskSortOption
    ) -> [ProjectTask] {
        TaskHierarchy.parentFirst(tasks.sorted { precedes($0, $1, by: option) })
    }

    private static func precedes(
        _ lhs: ProjectTask,
        _ rhs: ProjectTask,
        by option: TaskSortOption
    ) -> Bool {
        switch option {
        case .createdNewest:
            return compare(lhs.createdAt, rhs.createdAt, ascending: false, lhs: lhs, rhs: rhs)
        case .createdOldest:
            return compare(lhs.createdAt, rhs.createdAt, ascending: true, lhs: lhs, rhs: rhs)
        case .priorityHighToLow:
            return comparePriority(lhs, rhs, ascending: false)
        case .priorityLowToHigh:
            return comparePriority(lhs, rhs, ascending: true)
        case .scheduleEarliest:
            return compareOptionalDate(lhs.scheduledFor, rhs.scheduledFor, ascending: true, lhs: lhs, rhs: rhs)
        case .scheduleLatest:
            return compareOptionalDate(lhs.scheduledFor, rhs.scheduledFor, ascending: false, lhs: lhs, rhs: rhs)
        case .dueEarliest:
            return compareOptionalDate(lhs.dueAt, rhs.dueAt, ascending: true, lhs: lhs, rhs: rhs)
        case .dueLatest:
            return compareOptionalDate(lhs.dueAt, rhs.dueAt, ascending: false, lhs: lhs, rhs: rhs)
        }
    }

    private static func comparePriority(
        _ lhs: ProjectTask,
        _ rhs: ProjectTask,
        ascending: Bool
    ) -> Bool {
        let lhsRank = lhs.priority == .none ? nil : lhs.priority.rawValue
        let rhsRank = rhs.priority == .none ? nil : rhs.priority.rawValue

        switch (lhsRank, rhsRank) {
        case let (lhsRank?, rhsRank?) where lhsRank != rhsRank:
            return ascending ? lhsRank < rhsRank : lhsRank > rhsRank
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return tieBreak(lhs, rhs)
        }
    }

    private static func compareOptionalDate(
        _ lhsDate: Date?,
        _ rhsDate: Date?,
        ascending: Bool,
        lhs: ProjectTask,
        rhs: ProjectTask
    ) -> Bool {
        switch (lhsDate, rhsDate) {
        case let (lhsDate?, rhsDate?):
            return compare(lhsDate, rhsDate, ascending: ascending, lhs: lhs, rhs: rhs)
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return tieBreak(lhs, rhs)
        }
    }

    private static func compare(
        _ lhsValue: Date,
        _ rhsValue: Date,
        ascending: Bool,
        lhs: ProjectTask,
        rhs: ProjectTask
    ) -> Bool {
        guard lhsValue != rhsValue else { return tieBreak(lhs, rhs) }
        return ascending ? lhsValue < rhsValue : lhsValue > rhsValue
    }

    private static func tieBreak(_ lhs: ProjectTask, _ rhs: ProjectTask) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
