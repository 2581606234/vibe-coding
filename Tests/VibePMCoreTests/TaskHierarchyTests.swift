import Foundation
import Testing
@testable import VibePMCore

@Suite("Task hierarchy ordering")
struct TaskHierarchyTests {
    @Test("Parents precede their children even when query order is reversed")
    func parentsComeFirst() {
        let parent = ProjectTask(title: "Parent")
        let firstChild = ProjectTask(title: "First child", parentTaskID: parent.id)
        let secondChild = ProjectTask(title: "Second child", parentTaskID: parent.id)

        let ordered = TaskHierarchy.parentFirst([firstChild, secondChild, parent])

        #expect(ordered.map(\.title) == ["Parent", "First child", "Second child"])
    }

    @Test("Root and sibling order remains stable")
    func rootAndSiblingOrderIsStable() {
        let firstParent = ProjectTask(title: "First parent")
        let secondParent = ProjectTask(title: "Second parent")
        let secondChild = ProjectTask(title: "Second child", parentTaskID: firstParent.id)
        let firstChild = ProjectTask(title: "First child", parentTaskID: firstParent.id)

        let ordered = TaskHierarchy.parentFirst([
            secondChild,
            secondParent,
            firstChild,
            firstParent
        ])

        #expect(ordered.map(\.title) == [
            "Second parent",
            "First parent",
            "Second child",
            "First child"
        ])
    }

    @Test("Orphaned Subtasks are retained after valid hierarchies")
    func orphansComeLast() {
        let missingParentID = UUID()
        let orphan = ProjectTask(title: "Orphan", parentTaskID: missingParentID)
        let parent = ProjectTask(title: "Parent")
        let child = ProjectTask(title: "Child", parentTaskID: parent.id)

        let ordered = TaskHierarchy.parentFirst([orphan, child, parent])

        #expect(ordered.map(\.title) == ["Parent", "Child", "Orphan"])
    }

    @Test("Nested descendants remain directly below their ancestors")
    func nestedHierarchyIsDepthFirst() {
        let root = ProjectTask(title: "Root")
        let child = ProjectTask(title: "Child", parentTaskID: root.id)
        let grandchild = ProjectTask(title: "Grandchild", parentTaskID: child.id)

        let ordered = TaskHierarchy.parentFirst([grandchild, child, root])

        #expect(ordered.map(\.title) == ["Root", "Child", "Grandchild"])
    }

    @Test("Deletion expands selected parents to all descendants")
    func deletionIncludesDescendants() {
        let root = ProjectTask(title: "Root")
        let child = ProjectTask(title: "Child", parentTaskID: root.id)
        let grandchild = ProjectTask(title: "Grandchild", parentTaskID: child.id)
        let unrelated = ProjectTask(title: "Unrelated")

        let deletionIDs = TaskHierarchy.deletionIDs(
            selectedIDs: [root.id],
            in: [grandchild, unrelated, child, root]
        )

        #expect(deletionIDs == [root.id, child.id, grandchild.id])
        #expect(!deletionIDs.contains(unrelated.id))
    }

    @Test("Bulk deletion de-duplicates overlapping parent and child selections")
    func bulkDeletionDeDuplicatesHierarchy() {
        let parent = ProjectTask(title: "Parent")
        let child = ProjectTask(title: "Child", parentTaskID: parent.id)

        let deletionIDs = TaskHierarchy.deletionIDs(
            selectedIDs: [parent.id, child.id],
            in: [child, parent]
        )

        #expect(deletionIDs == [parent.id, child.id])
    }
}
