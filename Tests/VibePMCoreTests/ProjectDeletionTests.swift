import Foundation
import Testing
@testable import VibePMCore

@Suite("Project deletion")
struct ProjectDeletionTests {
    @Test("Deleting a Project includes all of its Tasks and Subtasks")
    func deletionIncludesEveryProjectTask() {
        let projectID = UUID()
        let parent = ProjectTask(title: "Parent", projectID: projectID)
        let child = ProjectTask(title: "Child", projectID: projectID, parentTaskID: parent.id)
        let otherProjectTask = ProjectTask(title: "Other", projectID: UUID())
        let inboxTask = ProjectTask(title: "Inbox")

        let deletionIDs = ProjectDeletion.taskIDs(
            for: projectID,
            in: [child, otherProjectTask, inboxTask, parent]
        )

        #expect(deletionIDs == Set([parent.id, child.id]))
    }
}
