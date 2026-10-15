import XCTest
import SwiftData
@testable import BookBuddy

final class SearchLibraryServiceTests: XCTestCase {
    func testAddingTheSameSearchResultTwiceReusesTheLocalBook() throws {
        let context = try makeContext()
        let result = BookSearchResult(id: "/works/OL1W", title: "A Search Result", subtitle: nil, authorName: "A. Reader", isbn: "9780123456789", seriesName: "A Series", firstPublishedYear: 2025, coverID: nil)

        let first = SearchLibraryService.add(result, context: context)
        let second = SearchLibraryService.add(result, context: context)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Book>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserBook>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SeriesBook>()).count, 1)
    }

    func testAddingSearchResultEnrichesAnExistingBookWithItsSeries() throws {
        let context = try makeContext()
        let author = Author(name: "Rebecca Yarros")
        let book = Book(title: "Fourth Wing", author: author)
        context.insert(author)
        context.insert(book)
        context.insert(UserBook(book: book))
        let result = BookSearchResult(id: "/works/OL29226517W", title: "Fourth Wing", subtitle: nil, authorName: "Rebecca Yarros", isbn: "9781649374042", seriesName: "The Empyrean", firstPublishedYear: 2023, coverID: nil)

        let enriched = SearchLibraryService.add(result, context: context)

        XCTAssertEqual(enriched.id, book.id)
        XCTAssertEqual(enriched.seriesMemberships.first?.series?.name, "The Empyrean")
    }

    func testExtractsSeriesNameFromOpenLibrarySubject() {
        XCTAssertEqual(OpenLibraryMetadataProvider().seriesName(from: ["Fantasy", "Serie:The_Empyrean"]), "The Empyrean")
    }

    func testExtractsOpenLibraryDescriptionFromTextOrValueObject() throws {
        let provider = OpenLibraryMetadataProvider()

        XCTAssertEqual(try provider.description(from: Data(#"{"description":"A direct description."}"#.utf8)), "A direct description.")
        XCTAssertEqual(try provider.description(from: Data(#"{"description":{"value":"A nested description."}}"#.utf8)), "A nested description.")
    }

    func testSkipsAConfidentlyNonEnglishOpenLibraryDescription() throws {
        let provider = OpenLibraryMetadataProvider()
        let spanishDescription = "Esta novela sigue a una joven que descubre secretos familiares mientras intenta construir una nueva vida lejos de su ciudad natal."

        XCTAssertNil(try provider.description(from: Data("{\"description\":\"\(spanishDescription)\"}".utf8)))
    }

    func testCachingCompanionBookDoesNotAddItToReadingHistory() throws {
        let context = try makeContext()
        let result = BookSearchResult(id: "/works/OL2W", title: "Iron Flame", subtitle: nil, authorName: "Rebecca Yarros", isbn: "9781649374172", seriesName: "The Empyrean", firstPublishedYear: 2023, coverID: nil)

        let book = SearchLibraryService.cache(result, context: context)

        XCTAssertEqual(book.seriesMemberships.first?.series?.name, "The Empyrean")
        XCTAssertTrue(book.userBooks.isEmpty)
        XCTAssertEqual(book.firstPublishedYear, 2023)
    }

    func testAddingAfterSeriesDiscoveryCreatesTheLibraryRecord() throws {
        let context = try makeContext()
        let result = BookSearchResult(id: "/works/OL4W", title: "Series Search Result", subtitle: nil, authorName: "A. Reader", isbn: nil, seriesName: "A Series", firstPublishedYear: 2025, coverID: nil)

        let book = SearchLibraryService.add(result, context: context)
        _ = SeriesLibraryService.addToLibrary(book, context: context)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<UserBook>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserBook>()).first?.book?.id, book.id)
    }

    func testCachingProviderRelatedWorkInKnownSeriesDoesNotAddItToLibrary() throws {
        let context = try makeContext()
        let series = Series(name: "Fae & Alchemy")
        context.insert(series)
        let result = BookSearchResult(id: "/works/OL42445468W", title: "Brimstone", subtitle: nil, authorName: "Callie Hart", isbn: nil, seriesName: nil, firstPublishedYear: 2025, coverID: nil)

        let book = SearchLibraryService.cache(result, in: series, context: context)

        XCTAssertEqual(book.seriesMemberships.first?.series?.id, series.id)
        XCTAssertTrue(book.userBooks.isEmpty)
    }

    func testCachingSearchResultPersistsCoverMetadataForLibraryRows() throws {
        let context = try makeContext()
        let result = BookSearchResult(id: "/works/OL3W", title: "Covered Book", subtitle: nil, authorName: "A. Reader", isbn: nil, seriesName: nil, firstPublishedYear: nil, coverID: 12345)

        let book = SearchLibraryService.add(result, context: context)

        XCTAssertEqual(book.coverID, 12345)
    }

    func testSeriesOrderUsesNumbersThenPublicationYear() {
        let numbered = Book(title: "Later Alphabetically")
        let olderUnnumbered = Book(title: "Zeta", firstPublishedYear: 2019)
        let newerUnnumbered = Book(title: "Alpha", firstPublishedYear: 2021)
        let memberships = [
            SeriesBook(book: newerUnnumbered),
            SeriesBook(book: olderUnnumbered),
            SeriesBook(book: numbered, position: 1)
        ]

        XCTAssertEqual(SeriesReadingOrder.sorted(memberships).compactMap { $0.book?.title }, ["Later Alphabetically", "Zeta", "Alpha"])
    }

    func testAddingAllSeriesBooksCreatesLibraryRecordsOnlyForMissingBooks() throws {
        let context = try makeContext()
        let first = Book(title: "First")
        let second = Book(title: "Second")
        context.insert(first)
        context.insert(second)
        context.insert(UserBook(book: first))

        let addedCount = SeriesLibraryService.addAllToLibrary([first, second], context: context)

        XCTAssertEqual(addedCount, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserBook>()).count, 2)
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
