import Foundation
import SwiftData

enum SeriesLibraryService {
    @discardableResult
    static func addToLibrary(_ book: Book, context: ModelContext) -> UserBook {
        if let existing = existingUserBook(for: book, context: context) { return existing }
        let userBook = UserBook(book: book)
        context.insert(userBook)
        return userBook
    }

    @discardableResult
    static func addAllToLibrary(_ books: [Book], context: ModelContext) -> Int {
        var addedCount = 0
        for book in books where existingUserBook(for: book, context: context) == nil {
            context.insert(UserBook(book: book))
            addedCount += 1
        }
        return addedCount
    }

    private static func existingUserBook(for book: Book, context: ModelContext) -> UserBook? {
        (try? context.fetch(FetchDescriptor<UserBook>()))?.first { $0.book?.id == book.id }
    }
}
