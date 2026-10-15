import Foundation
import SwiftData

struct ReadingSyncResult { var imported = 0; var updated = 0; var preservedLocalRecords = 0 }

enum ReadingSyncService {
    @MainActor
    static func sync(from provider: any ReadingDataProvider, context: ModelContext) async throws -> ReadingSyncResult {
        let records = try await provider.fetchReadingHistory()
        var result = ReadingSyncResult()
        for record in records {
            let userBooks = (try? context.fetch(FetchDescriptor<UserBook>())) ?? []
            let authors = (try? context.fetch(FetchDescriptor<Author>())) ?? []
            let books = (try? context.fetch(FetchDescriptor<Book>())) ?? []
            let author = authors.first { $0.name.caseInsensitiveCompare(record.authorName ?? "Unknown Author") == .orderedSame } ?? Author(name: record.authorName ?? "Unknown Author")
            if author.modelContext == nil { context.insert(author) }
            let book = books.first { book in
                if let isbn = record.isbn, !isbn.isEmpty, book.isbn == isbn { return true }
                return book.title.caseInsensitiveCompare(record.title) == .orderedSame && book.author?.name.caseInsensitiveCompare(author.name) == .orderedSame
            } ?? Book(title: record.title, author: author, subtitle: record.subtitle, isbn: record.isbn)
            if book.modelContext == nil { context.insert(book) }

            if let existing = userBooks.first(where: { $0.source == "hardcover" && $0.sourceID == record.id }) {
                apply(record, to: existing)
                result.updated += 1
            } else if userBooks.contains(where: { $0.book?.id == book.id }) {
                result.preservedLocalRecords += 1
            } else {
                let userBook = UserBook(book: book, readingStatus: record.status, rating: record.rating, review: record.review, startedReadingAt: record.startedReadingAt, finishedReadingAt: record.finishedReadingAt, addedAt: record.addedAt ?? .now, source: "hardcover", sourceID: record.id, lastSynced: .now)
                context.insert(userBook)
                result.imported += 1
            }
        }
        try context.save()
        return result
    }

    private static func apply(_ record: ReadingDataRecord, to userBook: UserBook) {
        userBook.readingStatusRawValue = record.status.rawValue
        userBook.rating = record.rating
        userBook.review = record.review
        userBook.startedReadingAt = record.startedReadingAt
        userBook.finishedReadingAt = record.finishedReadingAt
        userBook.lastSynced = .now
    }
}
