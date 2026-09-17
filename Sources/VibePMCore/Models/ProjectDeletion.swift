import Foundation

public enum ProjectDeletion {
    public static func taskIDs(for projectID: UUID, in tasks: [ProjectTask]) -> Set<UUID> {
        Set(tasks.lazy.filter { $0.projectID == projectID }.map(\.id))
    }
}
