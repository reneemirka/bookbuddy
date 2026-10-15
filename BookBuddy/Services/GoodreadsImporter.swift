import Foundation
import SwiftData

struct ImportResult { var imported = 0; var updated = 0; var skipped = 0 }

/// A cutoff applies only to records that have a Goodreads reading or added date.
/// Undated records remain eligible so an export never silently loses older history.
struct GoodreadsImportFilter: Equatable {
    var earliestActivityDate: Date?

    func includes(_ row: GoodreadsRow) -> Bool {
        guard let earliestActivityDate else { return true }
        guard let latestActivityDate = [row.dateRead, row.dateAdded].compactMap({ $0 }).max() else { return true }
        return latestActivityDate >= Calendar.current.startOfDay(for: earliestActivityDate)
    }
}

struct GoodreadsImporter {
    func preview(_ data: Data, filter: GoodreadsImportFilter = GoodreadsImportFilter()) throws -> (eligible: Int, skipped: Int) {
        let rows = try GoodreadsCSV.parse(data)
        let eligible = rows.filter(filter.includes).count
        return (eligible, rows.count - eligible)
    }

    func `import`(_ data: Data, context: ModelContext, filter: GoodreadsImportFilter = GoodreadsImportFilter()) throws -> ImportResult {
        var result = ImportResult()
        for row in try GoodreadsCSV.parse(data) {
            guard filter.includes(row) else { result.skipped += 1; continue }
            let existing = try context.fetch(FetchDescriptor<UserBook>()).first { $0.source == "goodreads" && $0.sourceID == row.id }
            let status: ReadingStatus = row.shelf == "read" ? .read : row.shelf == "currently-reading" ? .currentlyReading : .wantToRead
            if let existing { existing.readingStatusRawValue = status.rawValue; existing.rating = row.rating; existing.review = row.review.isEmpty ? nil : row.review; existing.finishedReadingAt = row.dateRead; result.updated += 1; continue }
            let author = try context.fetch(FetchDescriptor<Author>()).first { $0.name.caseInsensitiveCompare(row.author) == .orderedSame } ?? Author(name: row.author.isEmpty ? "Unknown Author" : row.author)
            if author.modelContext == nil { context.insert(author) }
            let book = try context.fetch(FetchDescriptor<Book>()).first { $0.title.caseInsensitiveCompare(row.title) == .orderedSame && $0.author?.name.caseInsensitiveCompare(author.name) == .orderedSame } ?? Book(title: row.title, author: author, isbn: row.isbn.isEmpty ? nil : row.isbn)
            if book.modelContext == nil { context.insert(book) }
            context.insert(UserBook(book: book, readingStatus: status, rating: row.rating, review: row.review.isEmpty ? nil : row.review, finishedReadingAt: row.dateRead, addedAt: row.dateAdded ?? .now, source: "goodreads", sourceID: row.id.isEmpty ? nil : row.id)); result.imported += 1
        }; try context.save(); return result
    }
}
