import SwiftUI
import VibePMCore

enum TaskViewMode: String, CaseIterable {
    case list
    case board

    var title: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .list: "list.bullet"
        case .board: "rectangle.split.3x1"
        }
    }
}

struct TaskBoardView: View {
    let tasks: [ProjectTask]
    let accent: Color
    let onEdit: (ProjectTask) -> Void
    let onMove: (ProjectTask, TaskStatus) -> Void

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(TaskStatus.allCases, id: \.self) { status in
                    BoardColumn(
                        status: status,
                        tasks: tasks.filter { $0.status == status },
                        accent: accent,
                        onEdit: onEdit,
                        onMove: onMove
                    )
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
    }
}

private struct BoardColumn: View {
    let status: TaskStatus
    let tasks: [ProjectTask]
    let accent: Color
    let onEdit: (ProjectTask) -> Void
    let onMove: (ProjectTask, TaskStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(status.title)
                    .font(.headline)
                Spacer()
                CountBadge(count: tasks.count)
            }
            .padding(.horizontal, 3)

            if tasks.isEmpty {
                Text("No Tasks")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 76)
                    .background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(tasks) { task in
                    BoardTaskCard(
                        task: task,
                        accent: accent,
                        onEdit: { onEdit(task) },
                        onMove: { onMove(task, $0) }
                    )
                }
            }
        }
        .frame(width: 250)
    }

    private var statusColor: Color {
        switch status {
        case .todo: .secondary
        case .inProgress: accent
        case .done: .green
        }
    }
}

private struct BoardTaskCard: View {
    let task: ProjectTask
    let accent: Color
    let onEdit: () -> Void
    let onMove: (TaskStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                Text(task.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Spacer(minLength: 8)
                Menu {
                    ForEach(TaskStatus.allCases, id: \.self) { status in
                        Button(status.title) {
                            onMove(status)
                        }
                        .disabled(status == task.status)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            if !task.taskDescription.isEmpty {
                Text(task.taskDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                if task.parentTaskID != nil {
                    Image(systemName: "arrow.turn.down.right")
                        .accessibilityLabel("Subtask")
                }
                if task.priority != .none {
                    Label(task.priority.title, systemImage: "flag.fill")
                        .foregroundStyle(task.priority.color)
                }
                Spacer()
                if let dueAt = task.dueAt {
                    Label(dueAt.formatted(date: .numeric, time: .omitted), systemImage: "clock")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .vibeCard()
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}
