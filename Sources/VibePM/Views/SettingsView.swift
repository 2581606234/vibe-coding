import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Text("VibePM stores project data locally on this Mac.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 420)
    }
}

