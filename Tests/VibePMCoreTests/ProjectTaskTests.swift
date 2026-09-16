import Foundation
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
}

