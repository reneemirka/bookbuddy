import XCTest
import SwiftData
@testable import BookBuddy

final class SeriesAnnouncementServiceTests: XCTestCase {
    @MainActor
    func testConfirmedAnnouncementAddsSeriesBookAndReleaseWithoutAddingToLibrary() async throws {
        let context = try makeContext()
        let series = Series(name: "A Court of Thorns and Roses")
        context.insert(series)
        context.insert(FollowedSeries(series: series))
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-01-12T00:00:00Z"))
        let provider = StubAnnouncementProvider(values: [
            SeriesAnnouncement(seriesName: series.name, title: "A Court of Forgotten Melody", authorName: "Sarah J. Maas", position: 7, releaseDate: date, source: "Publisher", sourceURL: "https://example.com", confidence: .confirmed)
        ])

        let added = try await SeriesAnnouncementService.refresh(provider: provider, context: context)

        XCTAssertEqual(added, 1)
        XCTAssertEqual(series.books.first?.book?.title, "A Court of Forgotten Melody")
        XCTAssertEqual(series.books.first?.position, 7)
        XCTAssertTrue(series.books.first?.book?.userBooks.isEmpty ?? false)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Release>()).first?.releaseDate, date)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Author.self, Book.self, Series.self, SeriesBook.self, UserBook.self,
            FollowedBook.self, FollowedAuthor.self, FollowedSeries.self, Release.self,
            SeriesRecap.self, BookSummary.self
        ])
        return ModelContext(try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
    }
}

private struct StubAnnouncementProvider: SeriesAnnouncementProvider {
    let values: [SeriesAnnouncement]
    func announcements() async throws -> [SeriesAnnouncement] { values }
}
