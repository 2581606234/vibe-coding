import Foundation
import Testing
@testable import VibePMCore

@Suite("Recovery Points")
struct RecoveryPointStoreTests {
    @Test("Automatic Recovery Points are limited to one per day")
    func automaticCadence() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RecoveryPointStore(directoryURL: directory)
        let backup = VibePMBackup(projects: [], tasks: [])
        let now = Date(timeIntervalSince1970: 2_000_000_000)

        #expect(try store.createAutomaticIfNeeded(backup: backup, now: now) != nil)
        #expect(try store.createAutomaticIfNeeded(backup: backup, now: now.addingTimeInterval(3_600)) == nil)
        #expect(try store.createAutomaticIfNeeded(backup: backup, now: now.addingTimeInterval(86_401)) != nil)
    }

    @Test("Only the newest fourteen automatic Recovery Points are retained")
    func automaticRetention() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RecoveryPointStore(directoryURL: directory)
        let backup = VibePMBackup(projects: [], tasks: [])
        let start = Date(timeIntervalSince1970: 2_000_000_000)

        for day in 0..<18 {
            _ = try store.create(
                backup: backup,
                kind: .automatic,
                now: start.addingTimeInterval(Double(day) * 86_400)
            )
        }

        #expect(try store.descriptors().filter { $0.kind == .automatic }.count == 14)
    }

    @Test("Pre-bulk Recovery Points can be listed and restored")
    func preBulkSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RecoveryPointStore(directoryURL: directory)
        let project = Project(name: "Before bulk edit")
        let task = ProjectTask(title: "Original", projectID: project.id)
        let backup = VibePMBackup(projects: [project], tasks: [task])

        let descriptor = try store.create(backup: backup, kind: .preBulk)
        task.title = "Changed"
        let restored = try VibePMBackup.decoded(from: Data(contentsOf: descriptor.url))

        #expect(try store.descriptors().contains { $0.kind == .preBulk })
        #expect(restored.tasks.first?.title == "Original")
    }
}
