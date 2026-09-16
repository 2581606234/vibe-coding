import SwiftUI
import VibePMCore

struct ProjectArchiveView: View {
    let projects: [Project]
    let taskCount: (Project) -> Int
    let onRestore: (Project) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Archive")
                    .font(.largeTitle.bold())
                Text("Projects stay here with their Tasks until you restore them.")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 18)

            if projects.isEmpty {
                ContentUnavailableView(
                    "No Archived Projects",
                    systemImage: "archivebox",
                    description: Text("Projects you archive will appear here.")
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
                                    Text("\(taskCount(project)) Tasks")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button("Restore") {
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
