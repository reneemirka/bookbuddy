import SwiftUI

struct BookDetailView: View {
    let book: Book

    var body: some View {
        List {
            Section {
                Text(book.title)
                    .font(.title2.weight(.semibold))
                Text(book.authorName)
                    .foregroundStyle(.secondary)
            }

            Section("Reading") {
                LabeledContent("Status", value: book.readingStatus.title)

                if let rating = book.rating {
                    LabeledContent("Rating") {
                        Text(String(repeating: "★", count: rating))
                            .foregroundStyle(.yellow)
                    }
                }

                LabeledContent("Added") {
                    Text(book.addedAt, format: .dateTime.month().day().year())
                }

                if let startedReadingAt = book.startedReadingAt {
                    LabeledContent("Started") {
                        Text(startedReadingAt, format: .dateTime.month().day().year())
                    }
                }

                if let finishedReadingAt = book.finishedReadingAt {
                    LabeledContent("Finished") {
                        Text(finishedReadingAt, format: .dateTime.month().day().year())
                    }
                }
            }

            if let review = book.review, !review.isEmpty {
                Section("Your Review") {
                    Text(review)
                }
            }
        }
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
