import Foundation
import SwiftData
import Testing
import ZIPFoundation
@testable import VibePMCore

@Suite("Project-scoped Excel workbook")
struct ProjectExcelWorkbookTests {
    @Test("Project export preserves only the selected Project Tasks and hierarchy")
    func roundTripIsProjectScoped() throws {
        let project = Project(name: "Apollo", projectDescription: "Ship Apollo", accent: .mint)
        let otherProject = Project(name: "Other")
        let parent = ProjectTask(
            title: "Plan launch",
            taskDescription: "Coordinate the launch",
            status: .inProgress,
            priority: .high,
            projectID: project.id,
            scheduledFor: Date(timeIntervalSince1970: 1_800_000_000),
            dueAt: Date(timeIntervalSince1970: 1_800_086_400)
        )
        let child = ProjectTask(title: "Write brief", projectID: project.id, parentTaskID: parent.id)
        let unrelated = ProjectTask(title: "Unrelated", projectID: otherProject.id)

        let data = try ProjectExcelWorkbook(project: project, tasks: [child, unrelated, parent])
            .encoded(project: project)
        if let outputPath = ProcessInfo.processInfo.environment["VIBEPM_PROJECT_EXPORT_OUTPUT"] {
            try data.write(to: URL(fileURLWithPath: outputPath))
        }
        let decoded = try ProjectExcelWorkbook.decoded(from: data)

        #expect(decoded.sourceProjectID == project.id)
        #expect(decoded.sourceProjectName == project.name)
        #expect(decoded.tasks.count == 2)
        #expect(decoded.tasks.contains { $0.id == child.id && $0.parentTaskID == parent.id })
        #expect(decoded.tasks.contains { $0.id == parent.id && $0.priority == .high })
        #expect(!decoded.tasks.contains { $0.id == unrelated.id })
    }

    @Test("Localized Project template omits Project and audit fields from Tasks")
    func localizedTemplateUsesImplicitProject() throws {
        let project = Project(name: "药明津石", projectDescription: "项目描述", accent: .purple)
        let data = try ProjectExcelWorkbook.templateData(project: project, language: .simplifiedChinese)
        if let outputPath = ProcessInfo.processInfo.environment["VIBEPM_PROJECT_TEMPLATE_OUTPUT_ZH"] {
            try data.write(to: URL(fileURLWithPath: outputPath))
        }
        let workbook = try ProjectExcelWorkbook.decoded(from: data)
        let taskXML = try entryText("xl/worksheets/sheet2.xml", in: data)
        let guideXML = try entryText("xl/worksheets/sheet3.xml", in: data)

        #expect(workbook.tasks.count == 2)
        #expect(workbook.tasks.contains { $0.parentTaskID != nil })
        #expect(taskXML.contains("任务编号（新建可留空）"))
        #expect(!taskXML.contains("所属项目"))
        #expect(!taskXML.contains("创建时间") && !taskXML.contains("更新时间"))
        #expect(taskXML.contains("sqref=\"F2:F2001\""))
        #expect(guideXML.contains("只导入到打开导入操作的当前项目"))
    }

    @Test("Unchanged exports are skipped and changed rows update")
    func previewDistinguishesSkipAndUpdate() throws {
        let project = Project(name: "Apollo")
        let unchanged = ProjectTask(title: "Unchanged", projectID: project.id)
        let changed = ProjectTask(title: "Edited in Excel", projectID: project.id)
        let workbook = try ProjectExcelWorkbook.decoded(
            from: ProjectExcelWorkbook(project: project, tasks: [unchanged, changed]).encoded(project: project)
        )
        changed.title = "Old local title"

        let preview = ProjectWorkbookImportPreview(
            workbook: workbook,
            targetProjectID: project.id,
            existingTasks: [unchanged, changed]
        )

        #expect(preview.creates == 0)
        #expect(preview.updates == 1)
        #expect(preview.skips == 1)
        #expect(preview.conflicts == 0)
        #expect(preview.canImport)
    }

    @Test("IDs and Parent Tasks outside the target Project are conflicts")
    func crossProjectReferencesAreBlocked() throws {
        let target = Project(name: "Target")
        let other = Project(name: "Other")
        let occupied = ProjectTask(title: "Occupied", projectID: other.id)
        let externalParent = ProjectTask(title: "External parent", projectID: other.id)
        let importedOccupied = ProjectTask(id: occupied.id, title: "Overwrite", projectID: target.id)
        let importedChild = ProjectTask(
            title: "Child",
            projectID: target.id,
            parentTaskID: externalParent.id
        )
        let workbook = try ProjectExcelWorkbook.decoded(
            from: ProjectExcelWorkbook(project: target, tasks: [importedOccupied, importedChild]).encoded(project: target)
        )

        let preview = ProjectWorkbookImportPreview(
            workbook: workbook,
            targetProjectID: target.id,
            existingTasks: [occupied, externalParent]
        )

        #expect(preview.conflicts == 2)
        #expect(!preview.canImport)
        #expect(preview.conflictItems.contains { $0.reason == .identifierOutsideProject })
        #expect(preview.conflictItems.contains { $0.reason == .parentOutsideProject })
    }

    @Test("Global workbooks are rejected by the Project importer")
    func globalWorkbookCannotBeCollapsedIntoOneProject() throws {
        let project = Project(name: "Global")
        let task = ProjectTask(title: "Global Task", projectID: project.id)
        let data = try VibePMExcelWorkbook(projects: [project], tasks: [task]).encoded()

        #expect(throws: ExcelWorkbookError.projectScopedWorkbookRequired) {
            try ProjectExcelWorkbook.decoded(from: data)
        }
    }

    @MainActor
    @Test("Project import creates and updates Tasks only in the target Project")
    func restoreAppliesSafeRows() throws {
        let target = Project(name: "Target")
        let existing = ProjectTask(title: "Old title", projectID: target.id)
        let exported = ProjectTask(id: existing.id, title: "New title", projectID: target.id)
        let created = ProjectTask(title: "New Task", projectID: target.id)
        let workbook = try ProjectExcelWorkbook.decoded(
            from: ProjectExcelWorkbook(project: target, tasks: [exported, created]).encoded(project: target)
        )
        let container = try ModelContainer(
            for: Project.self,
            ProjectTask.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        context.insert(target)
        context.insert(existing)

        try workbook.restore(into: context, targetProjectID: target.id, existingTasks: [existing])
        let restored = try context.fetch(FetchDescriptor<ProjectTask>())

        #expect(restored.count == 2)
        #expect(restored.first { $0.id == existing.id }?.title == "New title")
        #expect(restored.allSatisfy { $0.projectID == target.id })
    }

    private func entryText(_ path: String, in data: Data) throws -> String {
        let archive = try Archive(data: data, accessMode: .read)
        guard let entry = archive[path] else { throw ExcelWorkbookError.malformedWorkbook }
        var contents = Data()
        _ = try archive.extract(entry) { contents.append($0) }
        return try #require(String(data: contents, encoding: .utf8))
    }
}
