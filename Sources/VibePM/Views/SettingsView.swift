import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import VibePMCore

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @Query(sort: \ProjectTask.createdAt) private var tasks: [ProjectTask]

    @AppStorage("remindersEnabled") private var remindersEnabled = false
    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var statusMessage: String?
    @State private var showsStatus = false

    var body: some View {
        TabView {
            dataSettings
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }

            reminderSettings
                .tabItem {
                    Label("Reminders", systemImage: "bell")
                }
        }
        .frame(width: 520, height: 360)
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: backupFilename
        ) { result in
            switch result {
            case .success:
                showStatus("Backup exported successfully.")
            case let .failure(error):
                showStatus("Export failed: \(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importBackup(result)
        }
        .alert("VibePM", isPresented: $showsStatus) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(statusMessage ?? "")
        }
    }

    private var dataSettings: some View {
        Form {
            Section("Your data") {
                LabeledContent("Projects", value: projects.count.formatted())
                LabeledContent("Tasks", value: tasks.count.formatted())
            }

            Section("Backup") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Export JSON backup")
                            .font(.headline)
                        Text("Includes every Project, Task, Subtask, Status, and date.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Export…", action: exportBackup)
                        .buttonStyle(.borderedProminent)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Import JSON backup")
                            .font(.headline)
                        Text("Matching records are updated; other local data is preserved.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Import…") {
                        isImporting = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var reminderSettings: some View {
        Form {
            Section("Due dates") {
                Toggle("Local Task reminders", isOn: reminderBinding)
                Text("VibePM schedules a native notification for incomplete Tasks with a future due date. No Task data leaves this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if remindersEnabled {
                Section {
                    Button("Refresh scheduled reminders") {
                        Task {
                            do {
                                try await TaskReminderService.schedule(tasks: tasks)
                                showStatus("Reminders refreshed.")
                            } catch {
                                showStatus("Unable to schedule reminders: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { remindersEnabled },
            set: { enabled in
                if enabled {
                    Task {
                        do {
                            let granted = try await TaskReminderService.enableAndSchedule(tasks: tasks)
                            remindersEnabled = granted
                            if !granted {
                                showStatus("Notification permission was not granted.")
                            }
                        } catch {
                            remindersEnabled = false
                            showStatus("Unable to enable reminders: \(error.localizedDescription)")
                        }
                    }
                } else {
                    remindersEnabled = false
                    TaskReminderService.disable()
                }
            }
        )
    }

    private var backupFilename: String {
        let date = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "VibePM-Backup-\(date)"
    }

    private func exportBackup() {
        do {
            let backup = VibePMBackup(projects: projects, tasks: tasks)
            exportDocument = BackupDocument(data: try backup.encoded())
            isExporting = true
        } catch {
            showStatus("Export failed: \(error.localizedDescription)")
        }
    }

    private func importBackup(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let backup = try VibePMBackup.decoded(from: Data(contentsOf: url))
            try backup.restore(into: modelContext)
            showStatus("Imported \(backup.projects.count) Projects and \(backup.tasks.count) Tasks.")

            if remindersEnabled {
                Task {
                    try? await TaskReminderService.schedule(tasks: tasks)
                }
            }
        } catch {
            showStatus("Import failed: \(error.localizedDescription)")
        }
    }

    private func showStatus(_ message: String) {
        statusMessage = message
        showsStatus = true
    }
}
