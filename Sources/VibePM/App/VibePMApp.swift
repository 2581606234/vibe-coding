import SwiftData
import SwiftUI
import VibePMCore

@main
struct VibePMApp: App {
    private let modelContainer: ModelContainer
    @AppStorage(AppLanguage.userDefaultsKey) private var appLanguageRawValue = AppLanguage.system.rawValue

    init() {
        do {
            modelContainer = try ModelContainer(for: Project.self, ProjectTask.self)
        } catch {
            fatalError("Unable to initialize VibePM data: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(appLanguageRawValue)
                .environment(\.locale, appLanguage.locale())
                .frame(minWidth: 820, minHeight: 560)
        }
        .modelContainer(modelContainer)

        Settings {
            SettingsView()
                .id(appLanguageRawValue)
                .environment(\.locale, appLanguage.locale())
        }
        .modelContainer(modelContainer)
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .system
    }
}
