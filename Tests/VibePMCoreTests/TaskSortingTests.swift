import Foundation
import Testing
@testable import VibePMCore

@Suite("Task sorting")
struct TaskSortingTests {
    @Test("Priority sorting keeps parents before children and sorts roots")
    func prioritySortingPreservesHierarchy() {
        let parent = ProjectTask(title: "Parent", priority: .low)
        let child = ProjectTask(title: "Child", priority: .high, parentTaskID: parent.id)
        let mediumRoot = ProjectTask(title: "Medium", priority: .medium)
        let noneRoot = ProjectTask(title: "None", priority: .none)

        let result = TaskSorter.parentFirst(
            [child, noneRoot, parent, mediumRoot],
            by: .priorityHighToLow
        )

        #expect(result.map(\.title) == ["Medium", "Parent", "Child", "None"])
    }

    @Test("Undated Tasks remain last in both schedule directions")
    func undatedTasksRemainLast() {
        let early = ProjectTask(
            title: "Early",
            scheduledFor: Date(timeIntervalSince1970: 100)
        )
        let late = ProjectTask(
            title: "Late",
            scheduledFor: Date(timeIntervalSince1970: 200)
        )
        let undated = ProjectTask(title: "Undated")

        #expect(
            TaskSorter.parentFirst([undated, late, early], by: .scheduleEarliest).map(\.title)
                == ["Early", "Late", "Undated"]
        )
        #expect(
            TaskSorter.parentFirst([undated, early, late], by: .scheduleLatest).map(\.title)
                == ["Late", "Early", "Undated"]
        )
    }

    @Test("Creation time supports newest and oldest ordering")
    func creationTimeSorting() {
        let old = ProjectTask(
            title: "Old",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let new = ProjectTask(
            title: "New",
            createdAt: Date(timeIntervalSince1970: 200)
        )

        #expect(TaskSorter.parentFirst([old, new], by: .createdNewest).map(\.title) == ["New", "Old"])
        #expect(TaskSorter.parentFirst([new, old], by: .createdOldest).map(\.title) == ["Old", "New"])
    }
}
