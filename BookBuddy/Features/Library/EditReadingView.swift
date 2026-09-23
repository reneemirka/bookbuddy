import SwiftUI
import SwiftData

struct EditReadingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let userBook: UserBook
    @State private var readingStatus: ReadingStatus
    @State private var rating: Int
    @State private var review: String
    @State private var hasStartedReadingDate: Bool
    @State private var startedReadingAt: Date
    @State private var hasFinishedReadingDate: Bool
    @State private var finishedReadingAt: Date
    @State private var errorMessage: String?

    init(userBook: UserBook) {
        self.userBook = userBook
        _readingStatus = State(initialValue: userBook.readingStatus)
        _rating = State(initialValue: Int(userBook.rating ?? 0))
        _review = State(initialValue: userBook.review ?? "")
        _hasStartedReadingDate = State(initialValue: userBook.startedReadingAt != nil)
        _startedReadingAt = State(initialValue: userBook.startedReadingAt ?? .now)
        _hasFinishedReadingDate = State(initialValue: userBook.finishedReadingAt != nil)
        _finishedReadingAt = State(initialValue: userBook.finishedReadingAt ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
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
                    if hasStartedReadingDate { DatePicker("Date started", selection: $startedReadingAt, displayedComponents: .date) }
                    Toggle("Finished reading", isOn: $hasFinishedReadingDate)
                    if hasFinishedReadingDate { DatePicker("Date finished", selection: $finishedReadingAt, displayedComponents: .date) }
                }
                Section("Your Review") {
                    TextEditor(text: $review).frame(minHeight: 140)
                }
            }
            .navigationTitle("Edit Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .alert("Could Not Save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func save() {
        userBook.readingStatusRawValue = readingStatus.rawValue
        userBook.rating = rating == 0 ? nil : Double(rating)
        let trimmedReview = review.trimmingCharacters(in: .whitespacesAndNewlines)
        userBook.review = trimmedReview.isEmpty ? nil : trimmedReview
        userBook.startedReadingAt = hasStartedReadingDate ? startedReadingAt : nil
        userBook.finishedReadingAt = hasFinishedReadingDate ? finishedReadingAt : nil

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
