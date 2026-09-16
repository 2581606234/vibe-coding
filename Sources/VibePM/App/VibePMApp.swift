import SwiftData
import SwiftUI
import VibePMCore

@main
struct VibePMApp: App {
    private let modelContainer: ModelContainer

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
                .frame(minWidth: 820, minHeight: 560)
        }
        .modelContainer(modelContainer)

        Settings {
            SettingsView()
        }
        .modelContainer(modelContainer)
    }
}
