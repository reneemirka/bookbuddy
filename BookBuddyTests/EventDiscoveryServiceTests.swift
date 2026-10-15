import XCTest
import SwiftData
@testable import BookBuddy

final class EventDiscoveryServiceTests: XCTestCase {
    @MainActor
    func testRefreshLinksAndDeduplicatesFollowedAuthorEvent() async throws {
        let context = try makeContext()
        let author = Author(name: "N. K. Jemisin")
        context.insert(author)
        context.insert(FollowedAuthor(author: author))
        let event = DiscoveredLiteraryEvent(title: "N. K. Jemisin in conversation", details: nil, startsAt: Date(timeIntervalSince1970: 2_000_000_000), endsAt: nil, venueName: "Library", address: nil, city: nil, latitude: nil, longitude: nil, type: .authorTalk, source: "Test", sourceURL: nil, externalID: "event-1", authorName: nil, bookTitle: nil, seriesName: nil)

        let first = try await EventDiscoveryService.refresh(provider: StubEventProvider(events: [event]), context: context)
        let second = try await EventDiscoveryService.refresh(provider: StubEventProvider(events: [event]), context: context)

        XCTAssertEqual(first.created, 1)
        XCTAssertEqual(second.updated, 1)
        let stored = try XCTUnwrap(try context.fetch(FetchDescriptor<LiteraryEvent>()).first)
        XCTAssertEqual(stored.author?.id, author.id)
    }

    func testFiltersCoordinatesOutsideAllConfiguredRadii() {
        let event = DiscoveredLiteraryEvent(title: "Event", details: nil, startsAt: .now, endsAt: nil, venueName: nil, address: nil, city: nil, latitude: 40.0, longitude: -74.0, type: .literary, source: "Test", sourceURL: nil, externalID: nil, authorName: nil, bookTitle: nil, seriesName: nil)
        XCTAssertFalse(EventDiscoveryService.isWithinConfiguredLocations(event: event, locations: [EventSearchLocation(name: "Far away", latitude: 34.0, longitude: -118.0, radiusMiles: 10)]))
        XCTAssertTrue(EventDiscoveryService.isWithinConfiguredLocations(event: event, locations: []))
    }

    func testExistingStyleSourceDefaultsToReaderAdded() {
        let source = EventSourcePreference(name: "Neighborhood Library", feedURL: "https://example.com/events.ics")

        XCTAssertEqual(source.kind, .readerAdded)
        XCTAssertEqual(source.kind.label, "Your added source")
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Author.self, Book.self, Series.self, SeriesBook.self, UserBook.self, FollowedBook.self, FollowedAuthor.self, FollowedSeries.self, Release.self, SeriesRecap.self, BookSummary.self, LiteraryEvent.self, EventLocationPreference.self, EventSourcePreference.self])
        return ModelContext(try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
    }
}

private struct StubEventProvider: LiteraryEventProvider {
    let events: [DiscoveredLiteraryEvent]
    func discoverEvents(matching query: EventDiscoveryQuery) async throws -> [DiscoveredLiteraryEvent] { events }
}
