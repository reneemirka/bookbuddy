import XCTest
import SwiftData
@testable import BookBuddy

final class ReadingSyncServiceTests: XCTestCase {
    @MainActor
    func testSyncImportsHardcoverReadingData() async throws {
        let context = try makeContext()
        let record = ReadingDataRecord(
            id: "42",
            title: "Fourth Wing",
            subtitle: nil,
            authorName: "Rebecca Yarros",
            isbn: "9781649374042",
            status: .read,
            rating: 5,
            review: "Could not put it down.",
            startedReadingAt: Date(timeIntervalSince1970: 10),
            finishedReadingAt: Date(timeIntervalSince1970: 20),
            addedAt: Date(timeIntervalSince1970: 5)
        )

        let result = try await ReadingSyncService.sync(from: StubProvider(records: [record]), context: context)

        let userBook = try XCTUnwrap(try context.fetch(FetchDescriptor<UserBook>()).first)
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(userBook.source, "hardcover")
        XCTAssertEqual(userBook.sourceID, "42")
        XCTAssertEqual(userBook.readingStatus, .read)
        XCTAssertEqual(userBook.rating, 5)
        XCTAssertEqual(userBook.review, "Could not put it down.")
        XCTAssertEqual(userBook.book?.author?.name, "Rebecca Yarros")
    }

    @MainActor
    func testSyncPreservesExistingBookBuddyReadingRecord() async throws {
        let context = try makeContext()
        let author = Author(name: "Rebecca Yarros")
        let book = Book(title: "Fourth Wing", author: author)
        let localRecord = UserBook(book: book, readingStatus: .currentlyReading, rating: 4, review: "My local review")
        context.insert(author)
        context.insert(book)
        context.insert(localRecord)

        let imported = ReadingDataRecord(id: "42", title: "Fourth Wing", subtitle: nil, authorName: "Rebecca Yarros", isbn: nil, status: .read, rating: 5, review: "Remote review", startedReadingAt: nil, finishedReadingAt: .now, addedAt: .now)
        let result = try await ReadingSyncService.sync(from: StubProvider(records: [imported]), context: context)

        XCTAssertEqual(result.preservedLocalRecords, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserBook>()).count, 1)
        XCTAssertEqual(localRecord.readingStatus, .currentlyReading)
        XCTAssertEqual(localRecord.review, "My local review")
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Author.self, Book.self, Series.self, SeriesBook.self, UserBook.self, FollowedBook.self, FollowedAuthor.self, FollowedSeries.self, Release.self, SeriesRecap.self, BookSummary.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [configuration]))
    }
}

private struct StubProvider: ReadingDataProvider {
    let name = "Stub"
    let records: [ReadingDataRecord]
    func fetchReadingHistory() async throws -> [ReadingDataRecord] { records }
}
