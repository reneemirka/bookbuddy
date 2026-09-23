import SwiftUI

struct BookDetailView: View {
    let userBook: UserBook
    @State private var isPresentingEditor = false

    var body: some View {
        List {
            Section {
                Text(userBook.book?.title ?? "Unknown Book")
                    .font(.title2.weight(.semibold))
                Text(userBook.book?.author?.name ?? "Unknown Author")
                    .foregroundStyle(.secondary)
            }

            Section("Reading") {
                LabeledContent("Status", value: userBook.readingStatus.title)

                if let rating = userBook.rating {
                    LabeledContent("Rating") {
                        Text(String(repeating: "★", count: Int(rating)))
                            .foregroundStyle(.yellow)
                    }
                }

                LabeledContent("Added") {
                    Text(userBook.addedAt, format: .dateTime.month().day().year())
                }

                if let startedReadingAt = userBook.startedReadingAt {
                    LabeledContent("Started") {
                        Text(startedReadingAt, format: .dateTime.month().day().year())
                    }
                }

                if let finishedReadingAt = userBook.finishedReadingAt {
                    LabeledContent("Finished") {
                        Text(finishedReadingAt, format: .dateTime.month().day().year())
                    }
                }
            }

            if let review = userBook.review, !review.isEmpty {
                Section("Your Review") {
                    Text(review)
                }
            }
        }
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") {
                isPresentingEditor = true
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            EditReadingView(userBook: userBook)
        }
    }
}
