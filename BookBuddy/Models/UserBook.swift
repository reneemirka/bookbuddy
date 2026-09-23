import Foundation
import SwiftData

@Model final class UserBook {
    @Attribute(.unique) var id: UUID
    var readingStatusRawValue: String
    var rating: Double?
    var review: String?
    var startedReadingAt: Date?
    var finishedReadingAt: Date?
    var addedAt: Date
    var source: String
    var sourceID: String?
    var lastSynced: Date?
    var book: Book?
    init(id: UUID = UUID(), book: Book? = nil, readingStatus: ReadingStatus = .wantToRead, rating: Double? = nil, review: String? = nil, startedReadingAt: Date? = nil, finishedReadingAt: Date? = nil, addedAt: Date = .now, source: String = "bookBuddy", sourceID: String? = nil, lastSynced: Date? = nil) { self.id = id; self.book = book; self.readingStatusRawValue = readingStatus.rawValue; self.rating = rating; self.review = review; self.startedReadingAt = startedReadingAt; self.finishedReadingAt = finishedReadingAt; self.addedAt = addedAt; self.source = source; self.sourceID = sourceID; self.lastSynced = lastSynced }
    var readingStatus: ReadingStatus { ReadingStatus(rawValue: readingStatusRawValue) ?? .wantToRead }
}
