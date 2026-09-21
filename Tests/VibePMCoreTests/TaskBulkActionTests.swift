import Foundation
import Testing
@testable import VibePMCore

@Suite("Bulk Task actions")
struct TaskBulkActionTests {
    @Test("Status and Priority affect only selected Tasks")
    func selectedFieldsOnly() {
        let project = UUID()
        let parent = ProjectTask(title: "Parent", projectID: project)
        let child = ProjectTask(title: "Child", projectID: project, parentTaskID: parent.id)
        let other = ProjectTask(title: "Other", projectID: project)
        let action = TaskBulkAction(status: .done, priority: .high)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let preview = action.apply(selectedIDs: [parent.id], tasks: [parent, child, other], now: now)

        #expect(preview.selectedCount == 1)
        #expect(preview.changedCount == 1)
        #expect(parent.status == .done && parent.priority == .high)
        #expect(parent.completedAt == now && parent.updatedAt == now)
        #expect(child.status == .todo && child.priority == .none)
        #expect(other.status == .todo && other.priority == .none)
    }

    @Test("Moving a parent moves descendants once and keeps hierarchy")
    func parentMove() {
        let source = UUID()
        let target = UUID()
        let parent = ProjectTask(title: "Parent", projectID: source)
        let child = ProjectTask(title: "Child", projectID: source, parentTaskID: parent.id)
        let grandchild = ProjectTask(title: "Grandchild", projectID: source, parentTaskID: child.id)
        let unrelated = ProjectTask(title: "Unrelated", projectID: source)
        let action = TaskBulkAction(destination: .project(target))

        let preview = action.apply(
            selectedIDs: [parent.id, child.id],
            tasks: [parent, child, grandchild, unrelated]
        )

        #expect(preview.selectedCount == 2)
        #expect(preview.movedCount == 3)
        #expect(preview.additionallyMovedCount == 1)
        #expect(parent.projectID == target)
        #expect(child.projectID == target && child.parentTaskID == parent.id)
        #expect(grandchild.projectID == target && grandchild.parentTaskID == child.id)
        #expect(unrelated.projectID == source)
    }

    @Test("Moving a Subtask alone detaches it from an external parent")
    func childMoveDetaches() {
        let source = UUID()
        let target = UUID()
        let parent = ProjectTask(title: "Parent", projectID: source)
        let child = ProjectTask(title: "Child", projectID: source, parentTaskID: parent.id)
        let grandchild = ProjectTask(title: "Grandchild", projectID: source, parentTaskID: child.id)

        TaskBulkAction(destination: .project(target))
            .apply(selectedIDs: [child.id], tasks: [parent, child, grandchild])

        #expect(parent.projectID == source)
        #expect(child.projectID == target && child.parentTaskID == nil)
        #expect(grandchild.projectID == target && grandchild.parentTaskID == child.id)
    }

    @Test("Inbox is a destination; Trash is excluded")
    func inboxAndTrash() {
        let source = UUID()
        let active = ProjectTask(title: "Active", projectID: source)
        let trashed = ProjectTask(title: "Trashed", projectID: source, deletedAt: .now)
        let action = TaskBulkAction(destination: .inbox)
        let preview = action.apply(selectedIDs: [active.id, trashed.id], tasks: [active, trashed])

        #expect(preview.selectedCount == 1)
        #expect(preview.movedCount == 1)
        #expect(active.projectID == nil)
        #expect(trashed.projectID == source)
    }

    @Test("Keep current and same destination are no-ops")
    func noOp() {
        let project = UUID()
        let task = ProjectTask(title: "Task", priority: .high, projectID: project)
        let originalUpdatedAt = task.updatedAt
        let action = TaskBulkAction(priority: .high, destination: .project(project))
        let preview = action.apply(selectedIDs: [task.id], tasks: [task])

        #expect(!preview.canApply)
        #expect(task.updatedAt == originalUpdatedAt)
    }
}
