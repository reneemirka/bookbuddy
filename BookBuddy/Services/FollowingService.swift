import Foundation
import SwiftData

/// Stores the things the reader wants Book Buddy to monitor for future releases.
enum FollowingService {
    static func toggleBook(_ book: Book, context: ModelContext) {
        if let existing = followedBook(for: book, context: context) {
            context.delete(existing)
        } else {
            context.insert(FollowedBook(book: book))
        }
        NotificationCenter.default.post(name: .monitoringPreferencesChanged, object: nil)
    }

    static func followBook(_ book: Book, context: ModelContext) {
        guard followedBook(for: book, context: context) == nil else { return }
        context.insert(FollowedBook(book: book))
        NotificationCenter.default.post(name: .monitoringPreferencesChanged, object: nil)
    }

    static func toggleAuthor(_ author: Author, context: ModelContext) {
        if let existing = followedAuthor(for: author, context: context) {
            context.delete(existing)
        } else {
            context.insert(FollowedAuthor(author: author))
        }
        NotificationCenter.default.post(name: .monitoringPreferencesChanged, object: nil)
    }

    static func toggleSeries(_ series: Series, context: ModelContext) {
        if let existing = followedSeries(for: series, context: context) {
            context.delete(existing)
        } else {
            context.insert(FollowedSeries(series: series))
        }
        NotificationCenter.default.post(name: .monitoringPreferencesChanged, object: nil)
    }

    static func followSeries(_ series: Series, context: ModelContext) {
        guard followedSeries(for: series, context: context) == nil else { return }
        context.insert(FollowedSeries(series: series))
        NotificationCenter.default.post(name: .monitoringPreferencesChanged, object: nil)
    }

    static func followedBook(for book: Book, context: ModelContext) -> FollowedBook? {
        (try? context.fetch(FetchDescriptor<FollowedBook>()))?.first { $0.book?.id == book.id }
    }

    static func followedAuthor(for author: Author, context: ModelContext) -> FollowedAuthor? {
        (try? context.fetch(FetchDescriptor<FollowedAuthor>()))?.first { $0.author?.id == author.id }
    }

    static func followedSeries(for series: Series, context: ModelContext) -> FollowedSeries? {
        (try? context.fetch(FetchDescriptor<FollowedSeries>()))?.first { $0.series?.id == series.id }
    }
}
