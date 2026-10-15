import Foundation
import SwiftData

/// A locally cached, spoiler-bounded summary for one completed book.
@Model final class BookSummary {
    @Attribute(.unique) var id: UUID
    var content: String
    var sourceFingerprint: String
    var generatedAt: Date
    var book: Book?

    init(id: UUID = UUID(), book: Book? = nil, content: String, sourceFingerprint: String, generatedAt: Date = .now) {
        self.id = id
        self.book = book
        self.content = content
        self.sourceFingerprint = sourceFingerprint
        self.generatedAt = generatedAt
    }
}
