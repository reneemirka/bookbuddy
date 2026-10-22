import XCTest
import SwiftData
@testable import BookBuddy

final class RecapGenerationServiceTests: XCTestCase {
    @MainActor
    func testRequestIncludesOnlyBooksMarkedRead() throws {
        let context = try makeContext()
        let series = Series(name: "The Sequence")
        let readBook = Book(title: "Read Book")
        let unreadBook = Book(title: "Unread Book")
        context.insert(series)
        context.insert(readBook)
        context.insert(unreadBook)
        context.insert(SeriesBook(series: series, book: readBook, position: 1))
        context.insert(SeriesBook(series: series, book: unreadBook, position: 2))
        context.insert(UserBook(book: readBook, readingStatus: .read, rating: 5, review: "Remember this."))
        context.insert(UserBook(book: unreadBook, readingStatus: .wantToRead))

        let request = try RecapGenerationService.request(for: series, context: context)

        XCTAssertEqual(request.readBooks.map(\.title), ["Read Book"])
        XCTAssertFalse(request.sourceFingerprint.isEmpty)
    }

    @MainActor
    func testGenerationReusesUnchangedCachedRecap() async throws {
        let context = try makeContext()
        let series = Series(name: "The Sequence")
        let book = Book(title: "Read Book")
        context.insert(series)
        context.insert(book)
        context.insert(SeriesBook(series: series, book: book, position: 1))
        context.insert(UserBook(book: book, readingStatus: .read))
        let request = try RecapGenerationService.request(for: series, context: context)
        let cached = SeriesRecap(series: series, content: "Cached recap", sourceFingerprint: request.sourceFingerprint)
        context.insert(cached)

        let result = try await RecapGenerationService.generate(for: series, provider: FailingProvider(), context: context)

        XCTAssertEqual(result.id, cached.id)
        XCTAssertEqual(result.content, "Cached recap")
    }

    func testGatewayConfigurationRequiresSecureRecapEndpoint() throws {
        let configuration = try RecapGatewayConfiguration(
            endpointString: "https://bookbuddy-recap-gateway.example.workers.dev/v1/recaps",
            token: "client-token"
        )

        XCTAssertEqual(configuration.endpoint.path, "/v1/recaps")
        XCTAssertThrowsError(try RecapGatewayConfiguration(endpointString: "http://example.com/v1/recaps", token: "token"))
        XCTAssertThrowsError(try RecapGatewayConfiguration(endpointString: "https://example.com", token: "token"))
    }

    func testLocalBookstoreSearchUsesTheConnectedGateway() throws {
        let configuration = try RecapGatewayConfiguration(
            endpointString: "https://bookbuddy-recap-gateway.example.workers.dev/v1/recaps",
            token: "token"
        )

        XCTAssertEqual(
            LocalBookstoreGatewayProvider.endpoint(for: configuration).absoluteString,
            "https://bookbuddy-recap-gateway.example.workers.dev/v1/local-bookstores"
        )
    }

    func testLocalBookstoreResultDistinguishesAConfirmedPreorder() throws {
        let data = """
        {
          "name": "Example Books",
          "availability": "preorder_available",
          "detail": "Preorder listed for the hardcover edition.",
          "sourceURL": "https://example.com/preorders/book"
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(LocalBookstoreSearchResult.self, from: data)

        XCTAssertEqual(result.availability, .preorderAvailable)
        XCTAssertEqual(result.availability.title, "Preorder available")
    }

    @MainActor
    func testBookSummaryRequiresReadBook() throws {
        let context = try makeContext()
        let book = Book(title: "Unread Book")
        let userBook = UserBook(book: book, readingStatus: .wantToRead)
        context.insert(book)
        context.insert(userBook)

        XCTAssertThrowsError(try BookSummaryGenerationService.request(for: userBook)) { error in
            XCTAssertEqual((error as? RecapGenerationError)?.errorDescription, RecapGenerationError.bookNotRead.errorDescription)
        }
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Author.self, Book.self, Series.self, SeriesBook.self, UserBook.self, FollowedBook.self, FollowedAuthor.self, FollowedSeries.self, Release.self, SeriesRecap.self, BookSummary.self])
        return ModelContext(try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
    }
}

private struct FailingProvider: SeriesRecapProvider {
    func generateRecap(for request: SeriesRecapRequest) async throws -> String {
        XCTFail("A matching cached recap should avoid another provider call.")
        return ""
    }
}
