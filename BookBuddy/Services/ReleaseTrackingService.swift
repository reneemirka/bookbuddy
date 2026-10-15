import Foundation
import SwiftData

struct ReleaseLookup: Sendable {
    let title: String
    let authorName: String?
    let isbn: String?
}

struct ReleaseMetadata: Sendable {
    let releaseDate: Date?
    let status: ReleaseStatus
    let source: String
    let sourceURL: String?
    let confidence: ReleaseConfidence
}

protocol ReleaseMetadataProvider: Sendable {
    func releaseMetadata(for lookup: ReleaseLookup) async throws -> ReleaseMetadata?
}

enum ReleaseTrackingError: LocalizedError {
    case invalidResponse

    var errorDescription: String? { "Release information returned an unexpected response." }
}

/// Looks up the best available publication date in Open Library. The value is
/// cached locally, so the app remains useful without a network connection.
struct OpenLibraryReleaseProvider: ReleaseMetadataProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func releaseMetadata(for lookup: ReleaseLookup) async throws -> ReleaseMetadata? {
        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        let isbn = lookup.isbn?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let isbn, !isbn.isEmpty {
            components.queryItems = [
                URLQueryItem(name: "isbn", value: isbn),
                URLQueryItem(name: "limit", value: "1"),
                URLQueryItem(name: "fields", value: "key,publish_date,publish_year,first_publish_year")
            ]
        } else {
            var queryItems = [
                URLQueryItem(name: "title", value: lookup.title),
                URLQueryItem(name: "limit", value: "1"),
                URLQueryItem(name: "fields", value: "key,publish_date,publish_year,first_publish_year")
            ]
            if let authorName = lookup.authorName, !authorName.isEmpty {
                queryItems.append(URLQueryItem(name: "author", value: authorName))
            }
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw ReleaseTrackingError.invalidResponse }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw ReleaseTrackingError.invalidResponse
        }
        guard let document = try JSONDecoder().decode(Response.self, from: data).docs.first else { return nil }
        guard let date = bestDate(from: document) else { return nil }
        let status: ReleaseStatus = date < Calendar.current.startOfDay(for: .now) ? .released : .upcoming
        return ReleaseMetadata(
            releaseDate: date,
            status: status,
            source: "Open Library",
            sourceURL: URL(string: "https://openlibrary.org\(document.key)")?.absoluteString,
            confidence: .likely
        )
    }

    private func bestDate(from document: Document) -> Date? {
        let values = (document.publishDates ?? []) + (document.publishYears ?? []).map(String.init)
            + (document.firstPublishedYear.map { [String($0)] } ?? [])
        let dates = values.compactMap(parseDate).sorted()
        let today = Calendar.current.startOfDay(for: .now)
        return dates.first(where: { $0 >= today }) ?? dates.first
    }

    private func parseDate(_ value: String) -> Date? {
        let formats = ["yyyy-MM-dd", "MMMM d, yyyy", "d MMMM yyyy", "yyyy"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    private struct Response: Decodable { let docs: [Document] }
    private struct Document: Decodable {
        let key: String
        let publishDates: [String]?
        let publishYears: [Int]?
        let firstPublishedYear: Int?

        enum CodingKeys: String, CodingKey {
            case key
            case publishDates = "publish_date"
            case publishYears = "publish_year"
            case firstPublishedYear = "first_publish_year"
        }
    }
}

struct ReleaseRefreshResult {
    var checked = 0
    var created = 0
    var updated = 0
    var dateChanges = 0
}

enum ReleaseTrackingService {
    @MainActor
    static func refresh(
        provider: any ReleaseMetadataProvider,
        context: ModelContext
    ) async throws -> ReleaseRefreshResult {
        let books = relevantBooks(context: context)
        var result = ReleaseRefreshResult()

        for book in books {
            let metadata = try await provider.releaseMetadata(for: ReleaseLookup(
                title: book.title,
                authorName: book.author?.name,
                isbn: book.isbn
            ))
            result.checked += 1
            guard let metadata else { continue }

            if let release = release(for: book, context: context) {
                // A publisher-confirmed announcement is more authoritative than
                // a best-match catalog lookup. The announcement refresh remains
                // responsible for updating it if the publisher changes the date.
                guard release.confidence != .confirmed else { continue }
                if release.releaseDate != metadata.releaseDate {
                    release.previousReleaseDate = release.releaseDate
                    result.dateChanges += 1
                }
                release.releaseDate = metadata.releaseDate
                release.statusRawValue = metadata.status.rawValue
                release.source = metadata.source
                release.sourceURL = metadata.sourceURL
                release.confidenceRawValue = metadata.confidence.rawValue
                release.lastChecked = .now
                result.updated += 1
            } else {
                context.insert(Release(
                    book: book,
                    releaseDate: metadata.releaseDate,
                    status: metadata.status,
                    source: metadata.source,
                    sourceURL: metadata.sourceURL,
                    confidence: metadata.confidence
                ))
                result.created += 1
            }
        }
        try context.save()
        return result
    }

    @MainActor
    static func relevantBooks(context: ModelContext) -> [Book] {
        let followedBooks = (try? context.fetch(FetchDescriptor<FollowedBook>())) ?? []
        let followedAuthors = (try? context.fetch(FetchDescriptor<FollowedAuthor>())) ?? []
        let followedSeries = (try? context.fetch(FetchDescriptor<FollowedSeries>())) ?? []

        var booksByID = Dictionary(uniqueKeysWithValues: followedBooks.compactMap { followed in
            followed.book.map { ($0.id, $0) }
        })
        for followed in followedAuthors {
            for book in followed.author?.books ?? [] { booksByID[book.id] = book }
        }
        for followed in followedSeries {
            for membership in followed.series?.books ?? [] {
                if let book = membership.book { booksByID[book.id] = book }
            }
        }
        return booksByID.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    @MainActor
    static func release(for book: Book, context: ModelContext) -> Release? {
        (try? context.fetch(FetchDescriptor<Release>()))?.first { $0.book?.id == book.id }
    }
}
