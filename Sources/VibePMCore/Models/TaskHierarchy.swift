import Foundation

public enum TaskHierarchy {
    public static func parentFirst(_ tasks: [ProjectTask]) -> [ProjectTask] {
        guard tasks.count > 1 else { return tasks }

        let visibleIDs = Set(tasks.map(\.id))
        var childrenByParent: [UUID: [ProjectTask]] = [:]

        for task in tasks {
            guard let parentTaskID = task.parentTaskID,
                  visibleIDs.contains(parentTaskID) else { continue }
            childrenByParent[parentTaskID, default: []].append(task)
        }

        let roots = tasks.filter { $0.parentTaskID == nil }
        let orphans = tasks.filter { task in
            guard let parentTaskID = task.parentTaskID else { return false }
            return !visibleIDs.contains(parentTaskID)
        }

        var ordered: [ProjectTask] = []
        var visited: Set<UUID> = []

        func appendHierarchy(from task: ProjectTask) {
            guard visited.insert(task.id).inserted else { return }
            ordered.append(task)

            for child in childrenByParent[task.id, default: []] {
                appendHierarchy(from: child)
            }
        }

        for task in roots {
            appendHierarchy(from: task)
        }

        for task in orphans {
            appendHierarchy(from: task)
        }

        // Invalid cycles cannot be represented as a hierarchy, but no Task should disappear.
        for task in tasks where !visited.contains(task.id) {
            appendHierarchy(from: task)
        }

        return ordered
    }
}
