import Foundation
import SwiftData

@Model final class Series {
    @Attribute(.unique) var id: UUID
    var name: String
    var authors: [Author] = []
    @Relationship(inverse: \SeriesBook.series) var books: [SeriesBook] = []
    @Relationship(inverse: \SeriesRecap.series) var recaps: [SeriesRecap] = []
    init(id: UUID = UUID(), name: String) { self.id = id; self.name = name }
}
