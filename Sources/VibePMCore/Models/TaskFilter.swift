import Foundation

public struct TaskFilter: Equatable, Sendable {
    public var searchText: String
    public var priority: TaskPriority?
    public var status: TaskStatus?

    public init(
        searchText: String = "",
        priority: TaskPriority? = nil,
        status: TaskStatus? = nil
    ) {
        self.searchText = searchText
        self.priority = priority
        self.status = status
    }

    public var isActive: Bool {
        !normalizedSearchText.isEmpty || priority != nil || status != nil
    }

    public func matches(_ task: ProjectTask) -> Bool {
        if let priority, task.priority != priority {
            return false
        }

        if let status, task.status != status {
            return false
        }

        guard !normalizedSearchText.isEmpty else {
            return true
        }

        return task.title.localizedCaseInsensitiveContains(normalizedSearchText)
            || task.taskDescription.localizedCaseInsensitiveContains(normalizedSearchText)
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
