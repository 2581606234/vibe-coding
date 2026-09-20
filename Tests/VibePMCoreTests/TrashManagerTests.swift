import Foundation
import Testing
@testable import VibePMCore

@Suite("Trash lifecycle")
struct TrashManagerTests {
    @Test("Moving a parent Task moves and restores its descendants as one batch")
    func taskBatchRoundTrip() {
        let parent = ProjectTask(title: "Parent")
        let child = ProjectTask(title: "Child", parentTaskID: parent.id)
        let grandchild = ProjectTask(title: "Grandchild", parentTaskID: child.id)
        let unrelated = ProjectTask(title: "Unrelated")
        let batchID = UUID()

        TrashManager.moveTasks(
            selectedIDs: [parent.id],
            in: [grandchild, unrelated, child, parent],
            batchID: batchID
        )

        #expect([parent, child, grandchild].allSatisfy { $0.deletionBatchID == batchID })
        #expect(unrelated.deletedAt == nil)

        TrashManager.restore(
            batchID: batchID,
            projects: [],
            tasks: [parent, child, grandchild, unrelated]
        )

        #expect([parent, child, grandchild].allSatisfy { $0.deletedAt == nil })
        #expect(child.parentTaskID == parent.id)
        #expect(grandchild.parentTaskID == child.id)
    }

    @Test("Restoring a Project does not restore a previously deleted Task")
    func projectRestoreKeepsEarlierTaskInTrash() {
        let project = Project(name: "Launch")
        let earlierDeleted = ProjectTask(title: "Old", projectID: project.id)
        let active = ProjectTask(title: "Active", projectID: project.id)
        let earlierBatch = UUID()
        let projectBatch = UUID()

        TrashManager.moveTasks(selectedIDs: [earlierDeleted.id], in: [earlierDeleted, active], batchID: earlierBatch)
        TrashManager.moveProject(project, tasks: [earlierDeleted, active], batchID: projectBatch)
        TrashManager.restore(batchID: projectBatch, projects: [project], tasks: [earlierDeleted, active])

        #expect(project.deletedAt == nil)
        #expect(active.deletedAt == nil)
        #expect(earlierDeleted.deletionBatchID == earlierBatch)
        #expect(earlierDeleted.deletedAt != nil)
    }

    @Test("Orphaned restored Tasks return to Inbox as top-level Tasks")
    func orphanedRestoreNormalizesRelationships() {
        let missingProjectID = UUID()
        let missingParentID = UUID()
        let task = ProjectTask(
            title: "Orphan",
            projectID: missingProjectID,
            parentTaskID: missingParentID
        )
        let batchID = UUID()
        task.moveToTrash(batchID: batchID)

        TrashManager.restore(batchID: batchID, projects: [], tasks: [task])

        #expect(task.deletedAt == nil)
        #expect(task.projectID == nil)
        #expect(task.parentTaskID == nil)
    }

    @Test("Trash expiration begins at thirty days")
    func expirationPolicy() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let old = ProjectTask(title: "Old")
        let recent = ProjectTask(title: "Recent")
        old.moveToTrash(batchID: UUID(), at: calendar.date(byAdding: .day, value: -31, to: now)!)
        recent.moveToTrash(batchID: UUID(), at: calendar.date(byAdding: .day, value: -29, to: now)!)

        #expect(TrashManager.expiredTaskIDs(in: [old, recent], now: now, calendar: calendar) == [old.id])
    }
}
