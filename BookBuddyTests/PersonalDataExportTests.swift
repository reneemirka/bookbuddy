import XCTest
import SwiftData
@testable import BookBuddy

final class PersonalDataExportTests: XCTestCase {
    @MainActor
    func testExportIncludesPersonalReadingAndFollowingData() throws {
        let context = try makeContext()
        let author = Author(name: "Ursula K. Le Guin")
        let book = Book(title: "A Wizard of Earthsea", author: author, isbn: "9780547773742")
        let userBook = UserBook(book: book, readingStatus: .read, rating: 5, review: "A favorite.")
        context.insert(author); context.insert(book); context.insert(userBook)
        context.insert(FollowedAuthor(author: author))
        context.insert(EventLocationPreference(name: "Home", latitude: 42.36, longitude: -71.06, radiusMiles: 15))

        let document = try PersonalDataExportService.makeExport(context: context)
        let value = try JSONSerialization.jsonObject(with: document.data) as? [String: Any]
        let books = try XCTUnwrap(value?["books"] as? [[String: Any]])
        let following = try XCTUnwrap(value?["following"] as? [String: [String]])

        XCTAssertEqual(books.first?["title"] as? String, "A Wizard of Earthsea")
        XCTAssertEqual(books.first?["status"] as? String, "read")
        XCTAssertEqual(following["authors"], ["Ursula K. Le Guin"])
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Author.self, Book.self, Series.self, SeriesBook.self, UserBook.self, FollowedBook.self, FollowedAuthor.self, FollowedSeries.self, Release.self, SeriesRecap.self, BookSummary.self, LiteraryEvent.self, EventLocationPreference.self, EventSourcePreference.self])
        return ModelContext(try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
    }
}
