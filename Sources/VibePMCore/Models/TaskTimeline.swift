import Foundation

public struct TaskTimelineInterval: Equatable, Sendable {
    public let start: Date
    public let end: Date

    public init?(scheduledFor: Date?, dueAt: Date?, calendar: Calendar = .current) {
        guard scheduledFor != nil || dueAt != nil else { return nil }

        let scheduledDay = scheduledFor.map(calendar.startOfDay(for:))
        let dueDay = dueAt.map(calendar.startOfDay(for:))
        let first = scheduledDay ?? dueDay!
        let last = dueDay ?? scheduledDay!

        start = min(first, last)
        end = max(first, last)
    }

    public var isSingleDay: Bool { start == end }
}

public struct TaskTimelineBounds: Equatable, Sendable {
    public let start: Date
    public let end: Date

    public init(
        intervals: [TaskTimelineInterval],
        today: Date = .now,
        minimumDayCount: Int = 14,
        paddingDays: Int = 2,
        calendar: Calendar = .current
    ) {
        let today = calendar.startOfDay(for: today)
        let earliest = intervals.map(\.start).min() ?? today
        let latest = intervals.map(\.end).max() ?? today
        let paddedStart = calendar.date(byAdding: .day, value: -paddingDays, to: earliest) ?? earliest
        let paddedEnd = calendar.date(byAdding: .day, value: paddingDays, to: latest) ?? latest
        let minimumEnd = calendar.date(
            byAdding: .day,
            value: max(minimumDayCount - 1, 0),
            to: paddedStart
        ) ?? paddedStart

        start = paddedStart
        end = max(paddedEnd, minimumEnd)
    }

    public func dayOffset(for date: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents(
            [.day],
            from: start,
            to: calendar.startOfDay(for: date)
        ).day ?? 0
    }

    public func dates(calendar: Calendar = .current) -> [Date] {
        let count = max(dayOffset(for: end, calendar: calendar) + 1, 1)
        return (0..<count).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }
}
