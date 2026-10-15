import Foundation
import SwiftData

@Model final class Book {
    @Attribute(.unique) var id: UUID
    var title: String
    var subtitle: String?
    var isbn: String?
    var firstPublishedYear: Int?
    /// Open Library cover identifier. Kept locally so Library rendering does not need metadata requests.
    var coverID: Int?
    var openLibraryWorkID: String?
    var metadataDescription: String?
    var author: Author?
    var lastUpdated: Date
    @Relationship(inverse: \SeriesBook.book) var seriesMemberships: [SeriesBook] = []
    @Relationship(inverse: \UserBook.book) var userBooks: [UserBook] = []
    @Relationship(inverse: \Release.book) var releases: [Release] = []
    @Relationship(inverse: \BookSummary.book) var summaries: [BookSummary] = []
    init(id: UUID = UUID(), title: String, author: Author? = nil, subtitle: String? = nil, isbn: String? = nil, firstPublishedYear: Int? = nil, coverID: Int? = nil, openLibraryWorkID: String? = nil, metadataDescription: String? = nil, lastUpdated: Date = .now) { self.id = id; self.title = title; self.author = author; self.subtitle = subtitle; self.isbn = isbn; self.firstPublishedYear = firstPublishedYear; self.coverID = coverID; self.openLibraryWorkID = openLibraryWorkID; self.metadataDescription = metadataDescription; self.lastUpdated = lastUpdated }
}
