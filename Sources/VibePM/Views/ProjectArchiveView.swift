import SwiftUI
import VibePMCore

struct ProjectArchiveView: View {
    let projects: [Project]
    let taskCount: (Project) -> Int
    let onRestore: (Project) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.text("Archive"))
                    .font(.largeTitle.bold())
                Text(L10n.text("Projects stay here with their Tasks until you restore them."))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 18)

            if projects.isEmpty {
                ContentUnavailableView(
                    L10n.text("No Archived Projects"),
                    systemImage: "archivebox",
                    description: Text(L10n.text("Projects you archive will appear here."))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(projects) { project in
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(project.accent.color.gradient)
                                    .frame(width: 38, height: 38)
                                    .overlay {
                                        Image(systemName: "folder.fill")
                                            .foregroundStyle(.white)
                                    }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(project.name)
                                        .font(.headline)
                                    Text(L10n.format("%d Tasks", arguments: [taskCount(project)]))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button(L10n.text("Restore")) {
                                    onRestore(project)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(14)
                            .vibeCard()
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(VibeTheme.canvas)
    }
}
