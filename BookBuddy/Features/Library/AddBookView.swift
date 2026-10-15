import SwiftUI
import SwiftData

struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var authors: [Author]
    @Query private var series: [Series]

    @State private var title = ""
    @State private var authorName = ""
    @State private var seriesName = ""
    @State private var seriesPosition = ""
    @State private var seriesType = "Novel"
    @State private var readingStatus: ReadingStatus = .wantToRead
    @State private var rating = 0
    @State private var review = ""
    @State private var hasStartedReadingDate = false
    @State private var startedReadingAt = Date()
    @State private var hasFinishedReadingDate = false
    @State private var finishedReadingAt = Date()
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $authorName)
                }

                Section("Series (optional)") {
                    TextField("Series name", text: $seriesName)
                    TextField("Number", text: $seriesPosition)
                        .keyboardType(.decimalPad)
                    TextField("Type (for example, novella)", text: $seriesType)
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

                    Toggle("Started reading", isOn: $hasStartedReadingDate)
                    if hasStartedReadingDate {
                        DatePicker("Date started", selection: $startedReadingAt, displayedComponents: .date)
                    }

                    Toggle("Finished reading", isOn: $hasFinishedReadingDate)
                    if hasFinishedReadingDate {
                        DatePicker("Date finished", selection: $finishedReadingAt, displayedComponents: .date)
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
            .alert("Couldn't Save Book", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private func saveBook() {
        let trimmedReview = review.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = authors.first { $0.name.compare(trimmedAuthor, options: .caseInsensitive) == .orderedSame } ?? Author(name: trimmedAuthor)
        if author.modelContext == nil { modelContext.insert(author) }
        let book = Book(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: author
        )
        let userBook = UserBook(book: book, readingStatus: readingStatus, rating: rating == 0 ? nil : Double(rating), review: trimmedReview.isEmpty ? nil : trimmedReview, startedReadingAt: hasStartedReadingDate ? startedReadingAt : nil, finishedReadingAt: hasFinishedReadingDate ? finishedReadingAt : nil)

        modelContext.insert(book)
        modelContext.insert(userBook)
        let trimmedSeries = seriesName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSeries.isEmpty {
            let matchedSeries = series.first { $0.name.compare(trimmedSeries, options: .caseInsensitive) == .orderedSame }
            let bookSeries = matchedSeries ?? Series(name: trimmedSeries)
            if bookSeries.modelContext == nil { modelContext.insert(bookSeries) }
            let position = Double(seriesPosition.trimmingCharacters(in: .whitespacesAndNewlines))
            modelContext.insert(SeriesBook(series: bookSeries, book: book, position: position, type: seriesType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Novel" : seriesType.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = "Book Buddy couldn't save this book. Please try again."
        }
    }
}
