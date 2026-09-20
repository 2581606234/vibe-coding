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
