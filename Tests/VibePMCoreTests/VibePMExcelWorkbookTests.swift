import Foundation
import SwiftData
import Testing
@testable import VibePMCore

@Suite("VibePM Excel workbook")
struct VibePMExcelWorkbookTests {
    @Test("Excel export and import preserves Projects, Tasks, dates, and hierarchy")
    func workbookRoundTrip() throws {
        let project = Project(
            name: "Website launch",
            projectDescription: "Ship the new website",
            accent: .purple
        )
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let due = Date(timeIntervalSince1970: 1_800_604_800)
        let parent = ProjectTask(
            title: "Launch website",
            status: .inProgress,
            priority: .high,
            projectID: project.id,
            scheduledFor: start,
            dueAt: due
        )
        let child = ProjectTask(
            title: "Review copy",
            projectID: project.id,
            parentTaskID: parent.id,
            dueAt: due
        )

        let data = try VibePMExcelWorkbook(
            projects: [project],
            tasks: [child, parent]
        ).encoded()
        let decoded = try VibePMExcelWorkbook.decoded(from: data)

        #expect(data.starts(with: [0x50, 0x4B]))
        #expect(decoded.projects.count == 1)
        #expect(decoded.tasks.count == 2)
        #expect(decoded.projects[0].id == project.id)
        #expect(decoded.projects[0].accent == .purple)
        #expect(abs(decoded.projects[0].createdAt.timeIntervalSince(project.createdAt)) < 1)
        #expect(decoded.tasks.first(where: { $0.id == child.id })?.parentTaskID == parent.id)
        #expect(abs((decoded.tasks.first(where: { $0.id == parent.id })?.scheduledFor?.timeIntervalSince(start)) ?? 99) < 1)
        #expect(abs((decoded.tasks.first(where: { $0.id == parent.id })?.updatedAt.timeIntervalSince(parent.updatedAt)) ?? 99) < 1)
    }

    @Test("Downloadable template contains examples with valid relationships")
    func templateIsImportable() throws {
        let templateData = try VibePMExcelWorkbook.templateData()
        if let outputPath = ProcessInfo.processInfo.environment["VIBEPM_TEMPLATE_OUTPUT"] {
            try templateData.write(to: URL(fileURLWithPath: outputPath))
        }
        let first = try VibePMExcelWorkbook.decoded(from: templateData)
        let second = try VibePMExcelWorkbook.decoded(from: VibePMExcelWorkbook.templateData())

        #expect(first.projects.count == 1)
        #expect(first.tasks.count == 2)
        #expect(first.tasks.contains { $0.parentTaskID != nil })
        #expect(first.projects.map(\.id) == second.projects.map(\.id))
        #expect(first.tasks.map(\.id) == second.tasks.map(\.id))
    }

    @MainActor
    @Test("Excel import merges matching records without removing local data")
    func restoreMergesByKey() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Project.self,
            ProjectTask.self,
            configurations: configuration
        )
        let context = container.mainContext
        let existing = Project(name: "Existing")
        let unrelated = Project(name: "Keep me")
        context.insert(existing)
        context.insert(unrelated)

        existing.name = "Updated"
        let data = try VibePMExcelWorkbook(projects: [existing], tasks: []).encoded()
        existing.name = "Old local value"

        let workbook = try VibePMExcelWorkbook.decoded(from: data)
        try workbook.restore(into: context)
        let projects = try context.fetch(FetchDescriptor<Project>())

        #expect(projects.first(where: { $0.id == existing.id })?.name == "Updated")
        #expect(projects.contains(where: { $0.id == unrelated.id }))
    }
}
