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
        .frame(width: 600, height: 430)
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

    private var workbookFilename: String {
        let date = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "VibePM-Data-\(date)"
    }

    private func exportWorkbook() {
        do {
            let workbook = VibePMExcelWorkbook(projects: projects, tasks: tasks)
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
            try workbook.restore(into: modelContext)
            showStatus(L10n.format(
                "Imported %d Projects and %d Tasks.",
                arguments: [workbook.projects.count, workbook.tasks.count]
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
