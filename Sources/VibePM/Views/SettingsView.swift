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
    @State private var exportDocument: SpreadsheetDocument?
    @State private var exportFilename = "VibePM"
    @State private var exportSuccessMessage = ""
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var backupDocument: JSONBackupDocument?
    @State private var backupFilename = "VibePM-Recovery-Point"
    @State private var isExportingBackup = false
    @State private var isRestoringBackup = false
    @State private var pendingWorkbookImport: PendingWorkbookImport?
    @State private var statusMessage: String?
    @State private var showsStatus = false
    @AppStorage("lastAutomaticRecoveryPointAt") private var lastAutomaticRecoveryPointAt = 0.0

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
        .frame(width: 640, height: 560)
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .vibePMExcel,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                showStatus(exportSuccessMessage)
            case let .failure(error):
                showStatus(L10n.format("Export failed: %@", arguments: [error.localizedDescription]))
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.vibePMExcel],
            allowsMultipleSelection: false
        ) { result in
            importBackup(result)
        }
        .fileExporter(
            isPresented: $isExportingBackup,
            document: backupDocument,
            contentType: .json,
            defaultFilename: backupFilename
        ) { result in
            switch result {
            case .success:
                showStatus(L10n.text("Recovery point exported successfully."))
            case let .failure(error):
                showStatus(L10n.format("Export failed: %@", arguments: [error.localizedDescription]))
            }
        }
        .fileImporter(
            isPresented: $isRestoringBackup,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            restoreRecoveryPoint(result)
        }
        .sheet(item: $pendingWorkbookImport) { pending in
            ImportPreviewView(
                preview: pending.preview,
                onCancel: { pendingWorkbookImport = nil },
                onImport: { confirmWorkbookImport(pending) }
            )
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
                LabeledContent(L10n.text("Projects"), value: projects.count { $0.deletedAt == nil }.formatted())
                LabeledContent(L10n.text("Tasks"), value: tasks.count { $0.deletedAt == nil }.formatted())
            }

            Section(L10n.text("Excel import and export")) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.text("Export Excel workbook"))
                            .font(.headline)
                        Text(L10n.text("Exports Projects and Tasks as editable Excel worksheets."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: exportWorkbook) {
                        Label(L10n.text("Export…"), systemImage: "square.and.arrow.up")
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.text("Import Excel workbook"))
                            .font(.headline)
                        Text(L10n.text("Use the template for field names, allowed values, and examples."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: exportTemplate) {
                            Label(L10n.text("Template…"), systemImage: "arrow.down.doc")
                        }
                        .controlSize(.large)

                        Button {
                            isImporting = true
                        } label: {
                            Label(L10n.text("Import…"), systemImage: "square.and.arrow.down")
                        }
                        .controlSize(.large)
                    }
                }
            }

            Section(L10n.text("Recovery points")) {
                LabeledContent(L10n.text("Last automatic recovery point")) {
                    if lastAutomaticRecoveryPointAt > 0 {
                        Text(Date(timeIntervalSince1970: lastAutomaticRecoveryPointAt), style: .relative)
                    } else {
                        Text(L10n.text("Not yet created"))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.text("Protect and restore local data"))
                            .font(.headline)
                        Text(L10n.text("VibePM creates one local recovery point per day and keeps the latest 14."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L10n.text("Create Now"), action: createManualRecoveryPoint)
                    Button(L10n.text("Export…"), action: exportRecoveryPoint)
                    Button(L10n.text("Restore…")) { isRestoringBackup = true }
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
                                try await TaskReminderService.schedule(tasks: tasks.filter { $0.deletedAt == nil })
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
                            let granted = try await TaskReminderService.enableAndSchedule(tasks: tasks.filter { $0.deletedAt == nil })
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

    private var workbookFilename: String {
        let date = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "VibePM-Data-\(date)"
    }

    private func exportWorkbook() {
        do {
            let workbook = VibePMExcelWorkbook(
                projects: projects.filter { $0.deletedAt == nil },
                tasks: tasks.filter { $0.deletedAt == nil }
            )
            exportDocument = SpreadsheetDocument(data: try workbook.encoded())
            exportFilename = workbookFilename
            exportSuccessMessage = L10n.text("Excel workbook exported successfully.")
            isExporting = true
        } catch {
            showStatus(L10n.format("Export failed: %@", arguments: [error.localizedDescription]))
        }
    }

    private func exportTemplate() {
        do {
            let language = AppLanguage(rawValue: appLanguageRawValue) ?? .system
            exportDocument = SpreadsheetDocument(data: try VibePMExcelWorkbook.templateData(language: language))
            exportFilename = language.resolved() == .simplifiedChinese
                ? "VibePM-导入模板"
                : "VibePM-Import-Template"
            exportSuccessMessage = L10n.text("Excel import template saved successfully.")
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

            let workbook = try VibePMExcelWorkbook.decoded(from: Data(contentsOf: url))
            pendingWorkbookImport = PendingWorkbookImport(
                workbook: workbook,
                preview: WorkbookImportPreview(
                    workbook: workbook,
                    existingProjects: projects,
                    existingTasks: tasks
                )
            )
        } catch {
            showStatus(L10n.format("Import failed: %@", arguments: [error.localizedDescription]))
        }
    }

    private func confirmWorkbookImport(_ pending: PendingWorkbookImport) {
        do {
            let store = try RecoveryPointStore.applicationSupport()
            _ = try store.create(
                backup: VibePMBackup(projects: projects, tasks: tasks),
                kind: .preImport
            )
            try pending.workbook.restore(into: modelContext)
            pendingWorkbookImport = nil
            showStatus(L10n.format(
                "Imported %d Projects and %d Tasks.",
                arguments: [pending.preview.projectTotal, pending.preview.taskTotal]
            ))
            refreshReminders()
        } catch {
            modelContext.rollback()
            pendingWorkbookImport = nil
            showStatus(L10n.format("Import failed: %@", arguments: [error.localizedDescription]))
        }
    }

    private func createManualRecoveryPoint() {
        do {
            let store = try RecoveryPointStore.applicationSupport()
            _ = try store.create(
                backup: VibePMBackup(projects: projects, tasks: tasks),
                kind: .manual
            )
            showStatus(L10n.text("Recovery point created successfully."))
        } catch {
            showStatus(L10n.format("Unable to create a recovery point: %@", arguments: [error.localizedDescription]))
        }
    }

    private func exportRecoveryPoint() {
        do {
            backupDocument = JSONBackupDocument(data: try VibePMBackup(projects: projects, tasks: tasks).encoded())
            let date = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
            backupFilename = "VibePM-Recovery-Point-\(date)"
            isExportingBackup = true
        } catch {
            showStatus(L10n.format("Export failed: %@", arguments: [error.localizedDescription]))
        }
    }

    private func restoreRecoveryPoint(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            let backup = try VibePMBackup.decoded(from: Data(contentsOf: url))
            try backup.replaceLocalData(in: modelContext)
            showStatus(L10n.text("Recovery point restored successfully."))
            refreshReminders()
        } catch {
            modelContext.rollback()
            showStatus(L10n.format("Restore failed: %@", arguments: [error.localizedDescription]))
        }
    }

    private func refreshReminders() {
        guard remindersEnabled else { return }
        let activeTasks = tasks.filter { $0.deletedAt == nil }
        Task { try? await TaskReminderService.schedule(tasks: activeTasks) }
    }

    private func showStatus(_ message: String) {
        statusMessage = message
        showsStatus = true
    }
}

private struct PendingWorkbookImport: Identifiable {
    let id = UUID()
    let workbook: VibePMExcelWorkbook
    let preview: WorkbookImportPreview
}

private struct ImportPreviewView: View {
    let preview: WorkbookImportPreview
    let onCancel: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "tablecells")
                    .font(.title2)
                    .foregroundStyle(VibeTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("Import Preview"))
                        .font(.title2.bold())
                    Text(L10n.text("Review changes before writing them to VibePM."))
                        .foregroundStyle(.secondary)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 36, verticalSpacing: 12) {
                GridRow {
                    Text("")
                    Text(L10n.text("Create")).font(.headline)
                    Text(L10n.text("Update")).font(.headline)
                }
                GridRow {
                    Text(L10n.text("Projects")).font(.headline)
                    Text(preview.projectCreates.formatted())
                    Text(preview.projectUpdates.formatted())
                }
                GridRow {
                    Text(L10n.text("Tasks")).font(.headline)
                    Text(preview.taskCreates.formatted())
                    Text(preview.taskUpdates.formatted())
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))

            Text(L10n.text("A recovery point will be created automatically before import."))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button(L10n.text("Cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(L10n.text("Import"), action: onImport)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
