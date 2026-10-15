import Foundation
import SwiftData

enum SearchLibraryService {
    @discardableResult
    static func add(_ result: BookSearchResult, context: ModelContext) -> Book {
        upsert(result, addToLibrary: true, context: context)
    }

    /// Stores discovered companion books as canonical local metadata without adding them to reading history.
    @discardableResult
    static func cache(_ result: BookSearchResult, context: ModelContext) -> Book {
        upsert(result, addToLibrary: false, context: context)
    }

    /// Stores a discovered companion when the metadata provider confirms it is
    /// related but omits the series relationship on that individual work.
    @discardableResult
    static func cache(_ result: BookSearchResult, in series: Series, context: ModelContext) -> Book {
        let book = upsert(result, addToLibrary: false, context: context)
        if !book.seriesMemberships.contains(where: { $0.series?.id == series.id }) {
            context.insert(SeriesBook(series: series, book: book))
        }
        return book
    }

    @discardableResult
    private static func upsert(_ result: BookSearchResult, addToLibrary: Bool, context: ModelContext) -> Book {
        let authorName = result.authorName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Author"
        let author = fetchAuthors(context: context).first {
            $0.name.caseInsensitiveCompare(authorName) == .orderedSame
        } ?? Author(name: authorName)
        if author.modelContext == nil { context.insert(author) }

        let book: Book
        if let existing = existingBook(for: result, context: context) {
            book = existing
            book.author = book.author ?? author
            book.subtitle = book.subtitle ?? result.subtitle
            book.isbn = book.isbn ?? result.isbn
            book.firstPublishedYear = book.firstPublishedYear ?? result.firstPublishedYear
            book.coverID = book.coverID ?? result.coverID
            if result.id.hasPrefix("/works/") {
                book.openLibraryWorkID = book.openLibraryWorkID ?? result.id
            }
            book.lastUpdated = .now
        } else {
            book = Book(title: result.title, author: author, subtitle: result.subtitle, isbn: result.isbn, firstPublishedYear: result.firstPublishedYear, coverID: result.coverID, openLibraryWorkID: result.id.hasPrefix("/works/") ? result.id : nil)
            context.insert(book)
        }
        if addToLibrary, book.userBooks.isEmpty { context.insert(UserBook(book: book)) }

        if let seriesName = result.seriesName?.trimmingCharacters(in: .whitespacesAndNewlines), !seriesName.isEmpty {
            let series = fetchSeries(context: context).first {
                $0.name.caseInsensitiveCompare(seriesName) == .orderedSame
            } ?? Series(name: seriesName)
            if series.modelContext == nil { context.insert(series) }
            if !book.seriesMemberships.contains(where: { $0.series?.id == series.id }) {
                context.insert(SeriesBook(series: series, book: book))
            }
        }
        return book
    }

    private static func existingBook(for result: BookSearchResult, context: ModelContext) -> Book? {
        fetchBooks(context: context).first { book in
            if let isbn = result.isbn, !isbn.isEmpty, book.isbn == isbn { return true }
            return book.title.caseInsensitiveCompare(result.title) == .orderedSame
                && book.author?.name.caseInsensitiveCompare(result.authorName ?? "Unknown Author") == .orderedSame
        }
    }

    private static func fetchBooks(context: ModelContext) -> [Book] { (try? context.fetch(FetchDescriptor<Book>())) ?? [] }
    private static func fetchAuthors(context: ModelContext) -> [Author] { (try? context.fetch(FetchDescriptor<Author>())) ?? [] }
    private static func fetchSeries(context: ModelContext) -> [Series] { (try? context.fetch(FetchDescriptor<Series>())) ?? [] }
}
