import SwiftUI
import SwiftData

struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var authorName = ""
    @State private var readingStatus: ReadingStatus = .wantToRead
    @State private var rating = 0
    @State private var review = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $authorName)
                }

                Section("Reading") {
                    Picker("Status", selection: $readingStatus) {
                        ForEach(ReadingStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }

                    Picker("Rating", selection: $rating) {
                        Text("Not rated").tag(0)
                        ForEach(1...5, id: \.self) { value in
                            Text("\(value) star\(value == 1 ? "" : "s")").tag(value)
                        }
                    }
                }

                Section("Review") {
                    TextEditor(text: $review)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveBook() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveBook() {
        let trimmedReview = review.trimmingCharacters(in: .whitespacesAndNewlines)
        let book = Book(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            authorName: authorName.trimmingCharacters(in: .whitespacesAndNewlines),
            readingStatus: readingStatus,
            rating: rating == 0 ? nil : rating,
            review: trimmedReview.isEmpty ? nil : trimmedReview
        )

        modelContext.insert(book)
        dismiss()
    }
}
