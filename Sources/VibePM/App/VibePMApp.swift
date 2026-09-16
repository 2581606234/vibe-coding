import SwiftData
import SwiftUI
import VibePMCore

@main
struct VibePMApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 820, minHeight: 560)
        }
        .modelContainer(for: [Project.self, ProjectTask.self])

        Settings {
            SettingsView()
        }
    }
}

