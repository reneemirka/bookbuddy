import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            PlaceholderContentView(
                title: "Settings",
                message: "Preferences and connections will be available here."
            )
            .navigationTitle("Settings")
        }
    }
}
