import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationStack {
            PlaceholderContentView(
                title: "Library",
                message: "Your reading history will live here."
            )
            .navigationTitle("Library")
        }
    }
}
