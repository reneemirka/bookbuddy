import SwiftUI

struct RadarView: View {
    var body: some View {
        NavigationStack {
            PlaceholderContentView(
                title: "Radar",
                message: "Books, series, and authors you choose to follow will appear here."
            )
            .navigationTitle("Radar")
        }
    }
}
