import Foundation
import UserNotifications
import VibePMCore

@MainActor
enum TaskReminderService {
    static func enableAndSchedule(tasks: [ProjectTask]) async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else { return false }
        try await schedule(tasks: tasks, center: center)
        return true
    }

    static func schedule(tasks: [ProjectTask]) async throws {
        try await schedule(tasks: tasks, center: .current())
    }

    static func disable() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
    }

    private static func schedule(
        tasks: [ProjectTask],
        center: UNUserNotificationCenter
    ) async throws {
        center.removeAllPendingNotificationRequests()

        let futureTasks = tasks.filter { task in
            task.status != .done && task.dueAt.map { $0 > .now } == true
        }

        for task in futureTasks {
            guard let dueAt = task.dueAt else { continue }

            let content = UNMutableNotificationContent()
            content.title = L10n.text("Task due")
            content.body = task.title
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueAt
            )
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "task-\(task.id.uuidString)",
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }
    }
}
