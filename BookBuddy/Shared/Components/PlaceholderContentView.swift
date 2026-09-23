import SwiftUI

struct PlaceholderContentView: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "book.closed",
            description: Text(message)
        )
    }
}
