import XCTest
import SwiftData
@testable import BookBuddy

final class FollowingServiceTests: XCTestCase {
    func testFollowingABookDoesNotAutomaticallyFollowItsSeries() throws {
        let context = try makeContext()
        let book = Book(title: "Book One")
        let series = Series(name: "A Series")
        context.insert(book)
        context.insert(series)
        context.insert(SeriesBook(series: series, book: book))

        FollowingService.followBook(book, context: context)
        XCTAssertNotNil(FollowingService.followedBook(for: book, context: context))
        XCTAssertNil(FollowingService.followedSeries(for: series, context: context))
    }

    func testUnfollowingABookKeepsAnIndependentlyFollowedSeries() throws {
        let context = try makeContext()
        let book = Book(title: "Book One")
        let series = Series(name: "A Series")
        context.insert(book)
        context.insert(series)
        context.insert(SeriesBook(series: series, book: book))

        FollowingService.followBook(book, context: context)
        FollowingService.followSeries(series, context: context)
        FollowingService.toggleBook(book, context: context)
        XCTAssertNil(FollowingService.followedBook(for: book, context: context))
        XCTAssertNotNil(FollowingService.followedSeries(for: series, context: context))
    }

    func testFollowingASeriesIsIdempotent() throws {
        let context = try makeContext()
        let series = Series(name: "A Series")
        context.insert(series)

        FollowingService.followSeries(series, context: context)
        FollowingService.followSeries(series, context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<FollowedSeries>()).count, 1)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Author.self, Book.self, Series.self, SeriesBook.self, UserBook.self,
            FollowedBook.self, FollowedAuthor.self, FollowedSeries.self, Release.self, SeriesRecap.self, BookSummary.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [configuration]))
    }
}
