import CryptoKit
import Foundation
import SwiftData

struct RecapSourceBook: Sendable, Equatable {
    let title: String
    let position: Double?
    let rating: Double?
    let review: String?
    let finishedReadingAt: Date?
}

struct SeriesRecapRequest: Sendable, Equatable {
    let seriesName: String
    let readBooks: [RecapSourceBook]
    let sourceFingerprint: String
}

protocol SeriesRecapProvider: Sendable {
    func generateRecap(for request: SeriesRecapRequest) async throws -> String
}

struct BookSummaryRequest: Sendable, Equatable {
    let bookTitle: String
    let sourceBook: RecapSourceBook
    let sourceFingerprint: String
}

protocol BookSummaryProvider: Sendable {
    func generateBookSummary(for request: BookSummaryRequest) async throws -> String
}

enum RecapGenerationError: LocalizedError {
    case noReadBooks
    case bookNotRead
    case providerNotConfigured
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noReadBooks: "Mark at least one book in this series as Read before generating a recap."
        case .bookNotRead: "Mark this book as Read before generating its summary."
        case .providerNotConfigured: "AI recaps need a secure recap provider. Book Buddy does not store API keys in the app."
        case .invalidResponse: "The recap provider returned an empty response."
        }
    }
}

/// Deliberately fails until the app has a server-side provider. OpenAI's API
/// documentation prohibits exposing API keys in client-side apps.
struct UnconfiguredSeriesRecapProvider: SeriesRecapProvider {
    func generateRecap(for request: SeriesRecapRequest) async throws -> String {
        throw RecapGenerationError.providerNotConfigured
    }
}

extension UnconfiguredSeriesRecapProvider: BookSummaryProvider {
    func generateBookSummary(for request: BookSummaryRequest) async throws -> String {
        throw RecapGenerationError.providerNotConfigured
    }
}

enum RecapGenerationService {
    @MainActor
    static func request(for series: Series, context: ModelContext) throws -> SeriesRecapRequest {
        let readBooks = SeriesReadingOrder.sorted(series.books)
            .compactMap { membership -> RecapSourceBook? in
                guard let userBook = membership.book?.userBooks.first(where: { $0.readingStatus == .read }),
                      let title = membership.book?.title
                else { return nil }
                return RecapSourceBook(
                    title: title,
                    position: membership.position,
                    rating: userBook.rating,
                    review: userBook.review,
                    finishedReadingAt: userBook.finishedReadingAt
                )
            }
        guard !readBooks.isEmpty else { throw RecapGenerationError.noReadBooks }
        // Update this value when the server-side recap instructions materially change,
        // so an older cached recap is regenerated with the new behavior.
        var inputLines = ["recap-v5", series.name]
        for book in readBooks {
            let position = book.position.map { String($0) } ?? ""
            let rating = book.rating.map { String($0) } ?? ""
            let finishedAt = book.finishedReadingAt.map { String($0.timeIntervalSince1970) } ?? ""
            inputLines.append([book.title, position, rating, book.review ?? "", finishedAt].joined(separator: "|"))
        }
        let canonicalInput = inputLines.joined(separator: "\n")
        let fingerprint = SHA256.hash(data: Data(canonicalInput.utf8)).map { String(format: "%02x", $0) }.joined()
        return SeriesRecapRequest(seriesName: series.name, readBooks: readBooks, sourceFingerprint: fingerprint)
    }

    @MainActor
    static func cachedRecap(for series: Series, context: ModelContext) -> SeriesRecap? {
        (try? context.fetch(FetchDescriptor<SeriesRecap>()))?.first { $0.series?.id == series.id }
    }

    @MainActor
    static func generate(
        for series: Series,
        provider: any SeriesRecapProvider,
        context: ModelContext,
        forceRefresh: Bool = false
    ) async throws -> SeriesRecap {
        let request = try request(for: series, context: context)
        if !forceRefresh,
           let cached = cachedRecap(for: series, context: context),
           cached.sourceFingerprint == request.sourceFingerprint {
            return cached
        }
        let content = try await provider.generateRecap(for: request).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { throw RecapGenerationError.invalidResponse }
        if let existing = cachedRecap(for: series, context: context) {
            existing.content = content
            existing.sourceFingerprint = request.sourceFingerprint
            existing.generatedAt = .now
            try context.save()
            return existing
        }
        let recap = SeriesRecap(series: series, content: content, sourceFingerprint: request.sourceFingerprint)
        context.insert(recap)
        try context.save()
        return recap
    }
}

enum BookSummaryGenerationService {
    @MainActor
    static func request(for userBook: UserBook) throws -> BookSummaryRequest {
        guard userBook.readingStatus == .read, let book = userBook.book else {
            throw RecapGenerationError.bookNotRead
        }
        let sourceBook = RecapSourceBook(
            title: book.title,
            position: nil,
            rating: userBook.rating,
            review: userBook.review,
            finishedReadingAt: userBook.finishedReadingAt
        )
        let finishedAt = sourceBook.finishedReadingAt.map { String($0.timeIntervalSince1970) } ?? ""
        let rating = sourceBook.rating.map { String($0) } ?? ""
        let canonicalInput = ["book-summary-v1", sourceBook.title, rating, sourceBook.review ?? "", finishedAt].joined(separator: "|")
        let fingerprint = SHA256.hash(data: Data(canonicalInput.utf8)).map { String(format: "%02x", $0) }.joined()
        return BookSummaryRequest(bookTitle: book.title, sourceBook: sourceBook, sourceFingerprint: fingerprint)
    }

    @MainActor
    static func cachedSummary(for book: Book, context: ModelContext) -> BookSummary? {
        (try? context.fetch(FetchDescriptor<BookSummary>()))?.first { $0.book?.id == book.id }
    }

    @MainActor
    static func generate(for userBook: UserBook, provider: any BookSummaryProvider, context: ModelContext) async throws -> BookSummary {
        let request = try request(for: userBook)
        guard let book = userBook.book else { throw RecapGenerationError.bookNotRead }
        if let cached = cachedSummary(for: book, context: context), cached.sourceFingerprint == request.sourceFingerprint {
            return cached
        }
        let content = try await provider.generateBookSummary(for: request).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { throw RecapGenerationError.invalidResponse }
        if let existing = cachedSummary(for: book, context: context) {
            existing.content = content
            existing.sourceFingerprint = request.sourceFingerprint
            existing.generatedAt = .now
            try context.save()
            return existing
        }
        let summary = BookSummary(book: book, content: content, sourceFingerprint: request.sourceFingerprint)
        context.insert(summary)
        try context.save()
        return summary
    }
}
