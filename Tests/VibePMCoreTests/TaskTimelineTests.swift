import Foundation
import Testing
@testable import VibePMCore

@Suite("Task timeline")
struct TaskTimelineTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("Schedule and due date form a normalized interval")
    func intervalNormalizesDates() {
        let interval = TaskTimelineInterval(
            scheduledFor: date(2026, 9, 20),
            dueAt: date(2026, 9, 16),
            calendar: calendar
        )

        #expect(interval?.start == date(2026, 9, 16))
        #expect(interval?.end == date(2026, 9, 20))
    }

    @Test("A single provided date creates a one-day interval")
    func singleDateInterval() {
        let interval = TaskTimelineInterval(
            scheduledFor: nil,
            dueAt: date(2026, 9, 16),
            calendar: calendar
        )

        #expect(interval?.start == interval?.end)
        #expect(interval?.isSingleDay == true)
    }

    @Test("Tasks without dates remain unscheduled")
    func missingDatesHaveNoInterval() {
        #expect(TaskTimelineInterval(scheduledFor: nil, dueAt: nil, calendar: calendar) == nil)
    }

    @Test("Bounds include padding and a minimum two-week window")
    func boundsIncludeMinimumWindow() {
        let interval = TaskTimelineInterval(
            scheduledFor: date(2026, 9, 16),
            dueAt: date(2026, 9, 18),
            calendar: calendar
        )!
        let bounds = TaskTimelineBounds(
            intervals: [interval],
            today: date(2026, 9, 16),
            calendar: calendar
        )

        #expect(bounds.start == date(2026, 9, 14))
        #expect(bounds.dates(calendar: calendar).count == 14)
        #expect(bounds.dayOffset(for: date(2026, 9, 16), calendar: calendar) == 2)
    }
}
