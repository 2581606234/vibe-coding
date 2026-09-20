import SwiftUI
import VibePMCore

struct TrashTaskGroup: Identifiable {
    let id: UUID
    let batchID: UUID
    let title: String
    let deletedAt: Date
    let tasks: [ProjectTask]

    static func make(from tasks: [ProjectTask]) -> [TrashTaskGroup] {
        let groups = Dictionary(grouping: tasks) { $0.deletionBatchID ?? $0.id }
        return groups.map { batchID, tasks in
            let ids = Set(tasks.map(\.id))
            let root = tasks.first { task in
                task.parentTaskID.map { !ids.contains($0) } ?? true
            } ?? tasks[0]
            return TrashTaskGroup(
                id: batchID,
                batchID: batchID,
                title: root.title,
                deletedAt: tasks.compactMap(\.deletedAt).max() ?? .now,
                tasks: tasks
            )
        }
        .sorted { $0.deletedAt > $1.deletedAt }
    }
}

struct TrashView: View {
    let projects: [Project]
    let taskGroups: [TrashTaskGroup]
    let taskCount: (Project) -> Int
    let onRestore: (UUID) -> Void
    let onPermanentlyDeleteProject: (Project) -> Void
    let onPermanentlyDeleteTaskGroup: (TrashTaskGroup) -> Void

    @State private var pendingDeletion: PendingDeletion?

    private enum PendingDeletion: Identifiable {
        case project(Project)
        case taskGroup(TrashTaskGroup)

        var id: UUID {
            switch self {
            case let .project(project): project.id
            case let .taskGroup(group): group.id
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if projects.isEmpty && taskGroups.isEmpty {
                ContentUnavailableView(
                    L10n.text("Trash is Empty"),
                    systemImage: "trash",
                    description: Text(L10n.text("Deleted Projects and Tasks stay here for 30 days."))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(projects.sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }) { project in
                            row(
                                title: project.name,
                                subtitle: L10n.format("Project · %d Tasks", arguments: [taskCount(project)]),
                                deletedAt: project.deletedAt,
                                restore: { project.deletionBatchID.map(onRestore) },
                                delete: { pendingDeletion = .project(project) }
                            )
                        }
                        ForEach(taskGroups) { group in
                            row(
                                title: group.title,
                                subtitle: L10n.format("%d Tasks", arguments: [group.tasks.count]),
                                deletedAt: group.deletedAt,
                                restore: { onRestore(group.batchID) },
                                delete: { pendingDeletion = .taskGroup(group) }
                            )
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(VibeTheme.canvas)
        .alert(item: $pendingDeletion) { item in
            Alert(
                title: Text(L10n.text("Delete Permanently?")),
                message: Text(L10n.text("This data will be permanently deleted and cannot be restored.")),
                primaryButton: .destructive(Text(L10n.text("Delete Permanently"))) {
                    switch item {
                    case let .project(project): onPermanentlyDeleteProject(project)
                    case let .taskGroup(group): onPermanentlyDeleteTaskGroup(group)
                    }
                },
                secondaryButton: .cancel(Text(L10n.text("Cancel")))
            )
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.secondary.gradient)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "trash.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("Trash"))
                    .font(.largeTitle.bold())
                Text(L10n.text("Deleted Projects and Tasks stay here for 30 days."))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    private func row(
        title: String,
        subtitle: String,
        deletedAt: Date?,
        restore: @escaping () -> Void,
        delete: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "trash")
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                HStack(spacing: 8) {
                    Text(subtitle)
                    if let deletedAt {
                        Text("·")
                        Text(deletedAt, style: .relative)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button(L10n.text("Restore"), action: restore)
                .buttonStyle(.borderedProminent)
            Button(L10n.text("Delete Permanently"), role: .destructive, action: delete)
                .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.separator.opacity(0.45), lineWidth: 1)
        }
    }
}
