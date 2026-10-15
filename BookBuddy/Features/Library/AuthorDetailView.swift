import SwiftUI
import SwiftData

struct AuthorDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userBooks: [UserBook]
    let author: Author

    var body: some View {
        List {
            Section {
                Text(author.name).font(.title2.weight(.semibold))
            }

            Section("Following") {
                Button {
                    FollowingService.toggleAuthor(author, context: modelContext)
                } label: {
                    Label(FollowingService.followedAuthor(for: author, context: modelContext) == nil ? "Follow Author" : "Unfollow Author", systemImage: "person.badge.plus")
                }
            }

            Section("Books") {
                ForEach(author.books.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }) { book in
                    if let userBook = userBooks.first(where: { $0.book?.id == book.id }) {
                        NavigationLink(book.title) { BookDetailView(userBook: userBook) }
                    } else {
                        Text(book.title)
                    }
                }
            }
        }
        .navigationTitle("Author")
        .navigationBarTitleDisplayMode(.inline)
    }
}
