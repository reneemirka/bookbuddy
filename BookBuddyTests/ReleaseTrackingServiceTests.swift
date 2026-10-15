import XCTest
import SwiftData
@testable import BookBuddy

final class ReleaseTrackingServiceTests: XCTestCase {
    @MainActor
    func testRefreshCreatesReleasesForBooksReachedThroughEveryFollowingType() async throws {
        let context = try makeContext()
        let author = Author(name: "Ada Author")
        let directlyFollowed = Book(title: "Direct", author: author)
        let authorBook = Book(title: "Author Book", author: author)
        let series = Series(name: "Series")
        let seriesBook = Book(title: "Series Book")
        context.insert(author)
        context.insert(directlyFollowed)
        context.insert(authorBook)
        context.insert(series)
        context.insert(seriesBook)
        context.insert(SeriesBook(series: series, book: seriesBook))
        context.insert(FollowedBook(book: directlyFollowed))
        context.insert(FollowedAuthor(author: author))
        context.insert(FollowedSeries(series: series))

        let result = try await ReleaseTrackingService.refresh(provider: StubReleaseProvider(), context: context)

        XCTAssertEqual(result.checked, 3)
        XCTAssertEqual(result.created, 3)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Release>()).count, 3)
    }

    @MainActor
    func testRefreshPreservesPriorDateWhenMetadataChanges() async throws {
        let context = try makeContext()
        let book = Book(title: "Next Book")
        context.insert(book)
        context.insert(FollowedBook(book: book))
        let initialDate = Date(timeIntervalSince1970: 100)
        let changedDate = Date(timeIntervalSince1970: 200)

        _ = try await ReleaseTrackingService.refresh(provider: StubReleaseProvider(date: initialDate), context: context)
        let result = try await ReleaseTrackingService.refresh(provider: StubReleaseProvider(date: changedDate), context: context)

        let release = try XCTUnwrap(try context.fetch(FetchDescriptor<Release>()).first)
        XCTAssertEqual(result.dateChanges, 1)
        XCTAssertEqual(release.releaseDate, changedDate)
        XCTAssertEqual(release.previousReleaseDate, initialDate)
    }

    @MainActor
    func testRefreshDoesNotOverwritePublisherConfirmedRelease() async throws {
        let context = try makeContext()
        let book = Book(title: "Announced Book")
        let confirmedDate = Date(timeIntervalSince1970: 100)
        let catalogDate = Date(timeIntervalSince1970: 200)
        context.insert(book)
        context.insert(FollowedBook(book: book))
        context.insert(Release(
            book: book,
            releaseDate: confirmedDate,
            status: .upcoming,
            source: "Publisher",
            confidence: .confirmed
        ))

        let result = try await ReleaseTrackingService.refresh(provider: StubReleaseProvider(date: catalogDate), context: context)

        let release = try XCTUnwrap(try context.fetch(FetchDescriptor<Release>()).first)
        XCTAssertEqual(result.updated, 0)
        XCTAssertEqual(release.releaseDate, confirmedDate)
        XCTAssertEqual(release.source, "Publisher")
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Author.self, Book.self, Series.self, SeriesBook.self, UserBook.self, FollowedBook.self, FollowedAuthor.self, FollowedSeries.self, Release.self, SeriesRecap.self, BookSummary.self])
        return ModelContext(try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
    }
}

private struct StubReleaseProvider: ReleaseMetadataProvider {
    let date: Date
    init(date: Date = .now) { self.date = date }
    func releaseMetadata(for lookup: ReleaseLookup) async throws -> ReleaseMetadata? {
        ReleaseMetadata(releaseDate: date, status: .upcoming, source: "Test", sourceURL: nil, confidence: .confirmed)
    }
}
