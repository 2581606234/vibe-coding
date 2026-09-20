import Foundation
import SwiftData
import Testing
@testable import VibePMCore

struct VibePMBackupTests {
    @Test
    @MainActor
    func backupRoundTripRestoresProjectsAndTasks() throws {
        let projectID = UUID()
        let parentTaskID = UUID()
        let project = Project(
            id: projectID,
            name: "Launch",
            projectDescription: "Ship the first version",
            accent: .purple
        )
        let parent = ProjectTask(
            id: parentTaskID,
            title: "Prepare release",
            status: .inProgress,
            priority: .high,
            projectID: projectID
        )
        let subtask = ProjectTask(
            title: "Review screenshots",
            projectID: projectID,
            parentTaskID: parentTaskID,
            dueAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let backup = VibePMBackup(
            projects: [project],
            tasks: [parent, subtask],
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let encoded = try backup.encoded()
        let decoded = try VibePMBackup.decoded(from: encoded)
        let container = try makeContainer()
        let context = ModelContext(container)
        try decoded.restore(into: context)

        let projects = try context.fetch(FetchDescriptor<Project>())
        let tasks = try context.fetch(FetchDescriptor<ProjectTask>())
        #expect(projects.count == 1)
        #expect(projects.first?.accent == .purple)
        #expect(tasks.count == 2)
        #expect(tasks.first(where: { $0.id == parentTaskID })?.status == .inProgress)
        #expect(tasks.first(where: { $0.parentTaskID == parentTaskID })?.title == "Review screenshots")
    }

    @Test
    @MainActor
    func restoreMergesRecordsByIdentity() throws {
        let projectID = UUID()
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Project(id: projectID, name: "Old name", accent: .blue))
        try context.save()

        let replacement = Project(id: projectID, name: "New name", accent: .orange)
        let backup = VibePMBackup(projects: [replacement], tasks: [])
        try backup.restore(into: context)

        let projects = try context.fetch(FetchDescriptor<Project>())
        #expect(projects.count == 1)
        #expect(projects.first?.name == "New name")
        #expect(projects.first?.accent == .orange)
    }

    @Test
    @MainActor
    func replacingLocalDataRemovesRecordsOutsideSnapshot() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let kept = Project(name: "Keep")
        let removed = Project(name: "Remove")
        context.insert(kept)
        context.insert(removed)
        context.insert(ProjectTask(title: "Imported extra", projectID: removed.id))
        try context.save()

        let snapshotProject = Project(id: kept.id, name: "Restored")
        let backup = VibePMBackup(projects: [snapshotProject], tasks: [])
        try backup.replaceLocalData(in: context)

        let projects = try context.fetch(FetchDescriptor<Project>())
        let tasks = try context.fetch(FetchDescriptor<ProjectTask>())
        #expect(projects.map(\.name) == ["Restored"])
        #expect(tasks.isEmpty)
    }

    @Test
    func versionOneBackupRemainsReadable() throws {
        let data = Data(
            """
            {
              "schemaVersion": 1,
              "exportedAt": "2026-01-01T00:00:00Z",
              "projects": [],
              "tasks": []
            }
            """.utf8
        )

        let backup = try VibePMBackup.decoded(from: data)
        #expect(backup.schemaVersion == 1)
    }

    @Test
    func unsupportedSchemaIsRejected() throws {
        let data = Data(
            """
            {
              "schemaVersion": 999,
              "exportedAt": "2026-01-01T00:00:00Z",
              "projects": [],
              "tasks": []
            }
            """.utf8
        )

        #expect(throws: BackupError.unsupportedSchemaVersion(999)) {
            try VibePMBackup.decoded(from: data)
        }
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Project.self,
            ProjectTask.self,
            configurations: configuration
        )
    }
}
