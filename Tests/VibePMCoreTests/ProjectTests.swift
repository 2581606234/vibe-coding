import Foundation
import Testing
@testable import VibePMCore

struct ProjectTests {
    @Test
    func blankProjectDraftCannotBeSaved() {
        let draft = ProjectDraft(name: "  \n ")

        #expect(!draft.canSave)
    }

    @Test
    func projectDraftCreatesNormalizedProject() {
        let now = Date(timeIntervalSince1970: 1_700_003_000)
        let draft = ProjectDraft(
            name: "  Launch VibePM  ",
            projectDescription: "  Prepare the first release  ",
            accent: .mint
        )

        let project = draft.makeProject(now: now)

        #expect(project.name == "Launch VibePM")
        #expect(project.projectDescription == "Prepare the first release")
        #expect(project.accent == .mint)
        #expect(project.createdAt == now)
        #expect(project.updatedAt == now)
    }

    @Test
    func projectCanBeArchivedAndRestored() {
        let archivedAt = Date(timeIntervalSince1970: 1_700_004_000)
        let restoredAt = Date(timeIntervalSince1970: 1_700_005_000)
        let project = Project(name: "Release")

        project.archive(at: archivedAt)
        #expect(project.isArchived)
        #expect(project.updatedAt == archivedAt)

        project.restore(at: restoredAt)
        #expect(!project.isArchived)
        #expect(project.updatedAt == restoredAt)
    }

    @Test
    func projectDraftAppliesEdits() {
        let updatedAt = Date(timeIntervalSince1970: 1_700_006_000)
        let project = Project(name: "Old name", accent: .blue)
        let draft = ProjectDraft(
            name: "New name",
            projectDescription: "A clearer outcome",
            accent: .rose
        )

        draft.apply(to: project, now: updatedAt)

        #expect(project.name == "New name")
        #expect(project.projectDescription == "A clearer outcome")
        #expect(project.accent == .rose)
        #expect(project.updatedAt == updatedAt)
    }
}
