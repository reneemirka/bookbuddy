import Foundation
import SwiftData

@Model final class Book {
    @Attribute(.unique) var id: UUID
    var title: String
    var subtitle: String?
    var isbn: String?
    var author: Author?
    var lastUpdated: Date
    @Relationship(inverse: \SeriesBook.book) var seriesMemberships: [SeriesBook] = []
    @Relationship(inverse: \UserBook.book) var userBooks: [UserBook] = []
    init(id: UUID = UUID(), title: String, author: Author? = nil, subtitle: String? = nil, isbn: String? = nil, lastUpdated: Date = .now) { self.id = id; self.title = title; self.author = author; self.subtitle = subtitle; self.isbn = isbn; self.lastUpdated = lastUpdated }
}
