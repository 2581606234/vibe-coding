import Foundation
import SwiftData
import Testing
@testable import VibePMCore

struct ProjectTaskTests {
    @Test
    func completingATaskRecordsCompletionTime() {
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let task = ProjectTask(title: "Ship the MVP")

        task.markDone(at: completedAt)

        #expect(task.status == .done)
        #expect(task.completedAt == completedAt)
        #expect(task.updatedAt == completedAt)
    }

    @Test
    func reopeningATaskClearsCompletionTime() {
        let reopenedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let task = ProjectTask(title: "Review feedback", status: .done)
        task.completedAt = .now

        task.reopen(at: reopenedAt)

        #expect(task.status == .todo)
        #expect(task.completedAt == nil)
        #expect(task.updatedAt == reopenedAt)
    }

    @Test
    func blankTaskDraftCannotBeSaved() {
        let draft = TaskDraft(title: "  \n ")

        #expect(!draft.canSave)
    }

    @Test
    func taskDraftCreatesNormalizedTask() {
        let now = Date(timeIntervalSince1970: 1_700_001_000)
        let projectID = UUID()
        let dueAt = Date(timeIntervalSince1970: 1_700_010_000)
        let draft = TaskDraft(
            title: "  Prepare release  ",
            taskDescription: "  Verify the package  ",
            priority: .high,
            projectID: projectID,
            dueAt: dueAt
        )

        let task = draft.makeTask(now: now)

        #expect(task.title == "Prepare release")
        #expect(task.taskDescription == "Verify the package")
        #expect(task.priority == .high)
        #expect(task.projectID == projectID)
        #expect(task.dueAt == dueAt)
        #expect(task.createdAt == now)
        #expect(task.updatedAt == now)
    }

    @Test
    func taskDraftAppliesEditsAndUpdatesTimestamp() {
        let updatedAt = Date(timeIntervalSince1970: 1_700_002_000)
        let task = ProjectTask(title: "Old title", priority: .low)
        let draft = TaskDraft(
            title: "New title",
            taskDescription: "New description",
            priority: .medium,
            scheduledFor: updatedAt
        )

        draft.apply(to: task, now: updatedAt)

        #expect(task.title == "New title")
        #expect(task.taskDescription == "New description")
        #expect(task.priority == .medium)
        #expect(task.scheduledFor == updatedAt)
        #expect(task.updatedAt == updatedAt)
    }

    @Test
    @MainActor
    func taskPersistsThroughSwiftData() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ProjectTask.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let task = TaskDraft(
            title: "Persist me",
            priority: .high
        ).makeTask()

        context.insert(task)
        try context.save()

        let persistedTasks = try context.fetch(FetchDescriptor<ProjectTask>())
        #expect(persistedTasks.count == 1)
        #expect(persistedTasks.first?.title == "Persist me")
        #expect(persistedTasks.first?.priority == .high)
    }
}
