import Foundation
import SwiftData

enum ReadingStatus: String, CaseIterable, Identifiable {
    case wantToRead
    case currentlyReading
    case read
    case didNotFinish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wantToRead: "Want to Read"
        case .currentlyReading: "Currently Reading"
        case .read: "Read"
        case .didNotFinish: "Did Not Finish"
        }
    }
}

@Model
final class Book {
    var title: String
    var authorName: String
    var readingStatusRawValue: String
    var rating: Int?
    var review: String?
    var startedReadingAt: Date?
    var finishedReadingAt: Date?
    var addedAt: Date

    init(title: String, authorName: String, readingStatus: ReadingStatus = .wantToRead, rating: Int? = nil, review: String? = nil, startedReadingAt: Date? = nil, finishedReadingAt: Date? = nil, addedAt: Date = .now) {
        self.title = title
        self.authorName = authorName
        self.readingStatusRawValue = readingStatus.rawValue
        self.rating = rating
        self.review = review
        self.startedReadingAt = startedReadingAt
        self.finishedReadingAt = finishedReadingAt
        self.addedAt = addedAt
    }

    var readingStatus: ReadingStatus {
        ReadingStatus(rawValue: readingStatusRawValue) ?? .wantToRead
    }
}
