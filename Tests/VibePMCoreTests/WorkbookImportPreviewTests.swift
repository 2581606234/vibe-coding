import Testing
@testable import VibePMCore

@Suite("Workbook Import Preview")
struct WorkbookImportPreviewTests {
    @Test("Preview distinguishes creates from updates")
    func countsChanges() throws {
        let existingProject = Project(name: "Existing")
        let newProject = Project(name: "New")
        let existingTask = ProjectTask(title: "Existing task", projectID: existingProject.id)
        let newTask = ProjectTask(title: "New task", projectID: newProject.id)
        let data = try VibePMExcelWorkbook(
            projects: [existingProject, newProject],
            tasks: [existingTask, newTask]
        ).encoded()
        let workbook = try VibePMExcelWorkbook.decoded(from: data)

        let preview = WorkbookImportPreview(
            workbook: workbook,
            existingProjects: [existingProject],
            existingTasks: [existingTask]
        )

        #expect(preview.projectCreates == 1)
        #expect(preview.projectUpdates == 1)
        #expect(preview.taskCreates == 1)
        #expect(preview.taskUpdates == 1)
    }
}
