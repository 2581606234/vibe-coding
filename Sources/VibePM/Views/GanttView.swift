import SwiftUI
import VibePMCore

struct GanttView: View {
    let tasks: [ProjectTask]
    let accent: Color
    let isSelecting: Bool
    let selectedTaskIDs: Set<UUID>
    let onToggleSelection: (ProjectTask) -> Void
    let onEdit: (ProjectTask) -> Void
    let onDelete: (ProjectTask) -> Void

    private let calendar = Calendar.current
    private let taskColumnWidth: CGFloat = 236
    private let dayWidth: CGFloat = 46
    private let rowHeight: CGFloat = 54

    private var orderedTasks: [ProjectTask] {
        TaskHierarchy.parentFirst(tasks)
    }

    private var intervals: [TaskTimelineInterval] {
        tasks.compactMap {
            TaskTimelineInterval(
                scheduledFor: $0.scheduledFor,
                dueAt: $0.dueAt,
                calendar: calendar
            )
        }
    }

    private var bounds: TaskTimelineBounds {
        TaskTimelineBounds(intervals: intervals, calendar: calendar)
    }

    private var dates: [Date] {
        bounds.dates(calendar: calendar)
    }

    private var timelineWidth: CGFloat {
        CGFloat(dates.count) * dayWidth
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                timelineHeader

                ForEach(orderedTasks.indices, id: \.self) { index in
                    taskRow(orderedTasks[index], index: index)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(VibeTheme.subtleBorder, lineWidth: 1)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
    }

    private var timelineHeader: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(accent)
                Text(L10n.text("Task"))
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(width: taskColumnWidth, height: 58)
            .background(VibeTheme.elevatedSurface)

            HStack(spacing: 0) {
                ForEach(dates, id: \.self) { date in
                    VStack(spacing: 3) {
                        Text(monthLabel(for: date))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        HStack(spacing: 3) {
                            Text(weekdayLabel(for: date))
                                .foregroundStyle(.secondary)
                            Text(dayNumberLabel(for: date))
                                .foregroundStyle(isToday(date) ? accent : .primary)
                        }
                        .font(.caption.weight(isToday(date) ? .bold : .medium))
                    }
                    .frame(width: dayWidth, height: 58)
                    .background(dayBackground(for: date))
                    .overlay(alignment: .trailing) {
                        Divider()
                    }
                }
            }
            .frame(width: timelineWidth)
        }
        .overlay(alignment: .bottom) { Divider() }
    }

    private func taskRow(_ task: ProjectTask, index: Int) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 9) {
                if task.parentTaskID != nil {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if isSelecting {
                    Image(systemName: selectedTaskIDs.contains(task.id) ? "checkmark.circle.fill" : "circle")
                        .font(.callout)
                        .foregroundStyle(selectedTaskIDs.contains(task.id) ? accent : .secondary)
                        .accessibilityLabel(
                            L10n.text(selectedTaskIDs.contains(task.id) ? "Deselect Task" : "Select Task")
                        )
                } else {
                    Circle()
                        .fill(statusColor(for: task.status))
                        .frame(width: 7, height: 7)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(L10n.text(task.status.title))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 14)
            .frame(width: taskColumnWidth, height: rowHeight)
            .background(rowBackground(index: index))

            timelineCells(for: task, index: index)
        }
        .overlay(alignment: .bottom) { Divider().opacity(0.7) }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelecting {
                onToggleSelection(task)
            } else {
                onEdit(task)
            }
        }
        .contextMenu {
            Button(L10n.text("Edit Task"), systemImage: "pencil") { onEdit(task) }
            Divider()
            Button(L10n.text("Delete Task"), systemImage: "trash", role: .destructive) { onDelete(task) }
        }
    }

    private func timelineCells(for task: ProjectTask, index: Int) -> some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                ForEach(dates, id: \.self) { date in
                    Rectangle()
                        .fill(cellBackground(for: date, rowIndex: index))
                        .frame(width: dayWidth, height: rowHeight)
                        .overlay(alignment: .trailing) { Divider().opacity(0.65) }
                }
            }

            if let interval = TaskTimelineInterval(
                scheduledFor: task.scheduledFor,
                dueAt: task.dueAt,
                calendar: calendar
            ) {
                let startOffset = bounds.dayOffset(for: interval.start, calendar: calendar)
                let endOffset = bounds.dayOffset(for: interval.end, calendar: calendar)
                let width = CGFloat(endOffset - startOffset + 1) * dayWidth - 8

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(statusColor(for: task.status).gradient)
                    .frame(width: max(width, dayWidth - 8), height: 24)
                    .overlay(alignment: .leading) {
                        if width > 88 {
                            Text(task.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                        }
                    }
                    .shadow(color: statusColor(for: task.status).opacity(0.18), radius: 4, y: 2)
                    .offset(x: CGFloat(startOffset) * dayWidth + 4)
            } else {
                Text(L10n.text("No dates"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 12)
            }

            if let todayOffset = todayOffset {
                Rectangle()
                    .fill(accent.opacity(0.65))
                    .frame(width: 2, height: rowHeight)
                    .offset(x: CGFloat(todayOffset) * dayWidth + dayWidth / 2)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: timelineWidth, height: rowHeight)
    }

    private var todayOffset: Int? {
        let offset = bounds.dayOffset(for: .now, calendar: calendar)
        return dates.indices.contains(offset) ? offset : nil
    }

    private func monthLabel(for date: Date) -> String {
        let day = calendar.component(.day, from: date)
        guard date == dates.first || day == 1 else { return "" }
        return date.formatted(
            Date.FormatStyle()
                .month(.abbreviated)
                .locale(L10n.selectedLanguage().locale())
        )
    }

    private func weekdayLabel(for date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .weekday(.narrow)
                .locale(L10n.selectedLanguage().locale())
        )
    }

    private func dayNumberLabel(for date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .day()
                .locale(L10n.selectedLanguage().locale())
        )
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func isWeekend(_ date: Date) -> Bool {
        calendar.isDateInWeekend(date)
    }

    private func dayBackground(for date: Date) -> Color {
        if isToday(date) { return accent.opacity(0.10) }
        return isWeekend(date) ? Color.primary.opacity(0.035) : VibeTheme.elevatedSurface
    }

    private func cellBackground(for date: Date, rowIndex: Int) -> Color {
        if isToday(date) { return accent.opacity(0.055) }
        if isWeekend(date) { return Color.primary.opacity(0.025) }
        return rowBackground(index: rowIndex)
    }

    private func rowBackground(index: Int) -> Color {
        index.isMultiple(of: 2) ? VibeTheme.elevatedSurface : Color.primary.opacity(0.018)
    }

    private func statusColor(for status: TaskStatus) -> Color {
        switch status {
        case .todo: accent.opacity(0.72)
        case .inProgress: accent
        case .done: .green
        }
    }
}
