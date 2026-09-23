import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.title) private var books: [Book]
    @State private var isPresentingAddBook = false

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView(
                        "Your Library Is Empty",
                        systemImage: "books.vertical",
                        description: Text("Add a book to begin building your reading history.")
                    )
                } else {
                    List {
                        ForEach(books) { book in
                            NavigationLink {
                                BookDetailView(book: book)
                            } label: {
                                BookRow(book: book)
                            }
                        }
                        .onDelete(perform: deleteBooks)
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Book", systemImage: "plus") {
                        isPresentingAddBook = true
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddBook) {
                AddBookView()
            }
        }
    }

    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(books[index])
        }
    }
}

private struct BookRow: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.title)
                .font(.headline)
            Text(book.authorName)
                .foregroundStyle(.secondary)
            Text(book.readingStatus.title)
                .font(.caption)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 4)
    }
}
