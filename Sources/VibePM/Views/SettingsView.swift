import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import VibePMCore

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @Query(sort: \ProjectTask.createdAt) private var tasks: [ProjectTask]

    @AppStorage("remindersEnabled") private var remindersEnabled = false
    @AppStorage(AppLanguage.userDefaultsKey) private var appLanguageRawValue = AppLanguage.system.rawValue
    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var statusMessage: String?
    @State private var showsStatus = false

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label(L10n.text("General"), systemImage: "gearshape")
                }

            dataSettings
                .tabItem {
                    Label(L10n.text("Data"), systemImage: "externaldrive")
                }

            reminderSettings
                .tabItem {
                    Label(L10n.text("Reminders"), systemImage: "bell")
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
                showStatus(L10n.text("Backup exported successfully."))
            case let .failure(error):
                showStatus(L10n.format("Export failed: %@", arguments: [error.localizedDescription]))
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
            Button(L10n.text("OK"), role: .cancel) {}
        } message: {
            Text(statusMessage ?? "")
        }
    }

    private var generalSettings: some View {
        Form {
            Section(L10n.text("Language")) {
                Picker(L10n.text("App language"), selection: $appLanguageRawValue) {
                    Text(L10n.text("Follow System")).tag(AppLanguage.system.rawValue)
                    Text("简体中文").tag(AppLanguage.simplifiedChinese.rawValue)
                    Text("English").tag(AppLanguage.english.rawValue)
                }
                Text(L10n.text("Language changes apply immediately."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var dataSettings: some View {
        Form {
            Section(L10n.text("Your data")) {
                LabeledContent(L10n.text("Projects"), value: projects.count.formatted())
                LabeledContent(L10n.text("Tasks"), value: tasks.count.formatted())
            }

            Section(L10n.text("Backup")) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.text("Export JSON backup"))
                            .font(.headline)
                        Text(L10n.text("Includes every Project, Task, Subtask, Status, and date."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L10n.text("Export…"), action: exportBackup)
                        .buttonStyle(.borderedProminent)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.text("Import JSON backup"))
                            .font(.headline)
                        Text(L10n.text("Matching records are updated; other local data is preserved."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L10n.text("Import…")) {
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
            Section(L10n.text("Due dates")) {
                Toggle(L10n.text("Local Task reminders"), isOn: reminderBinding)
                Text(L10n.text("VibePM schedules a native notification for incomplete Tasks with a future due date. No Task data leaves this Mac."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if remindersEnabled {
                Section {
                    Button(L10n.text("Refresh scheduled reminders")) {
                        Task {
                            do {
                                try await TaskReminderService.schedule(tasks: tasks)
                                showStatus(L10n.text("Reminders refreshed."))
                            } catch {
                                showStatus(L10n.format("Unable to schedule reminders: %@", arguments: [error.localizedDescription]))
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
                                showStatus(L10n.text("Notification permission was not granted."))
                            }
                        } catch {
                            remindersEnabled = false
                            showStatus(L10n.format("Unable to enable reminders: %@", arguments: [error.localizedDescription]))
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
            showStatus(L10n.format("Export failed: %@", arguments: [error.localizedDescription]))
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
            showStatus(L10n.format(
                "Imported %d Projects and %d Tasks.",
                arguments: [backup.projects.count, backup.tasks.count]
            ))

            if remindersEnabled {
                Task {
                    try? await TaskReminderService.schedule(tasks: tasks)
                }
            }
        } catch {
            showStatus(L10n.format("Import failed: %@", arguments: [error.localizedDescription]))
        }
    }

    private func showStatus(_ message: String) {
        statusMessage = message
        showsStatus = true
    }
}
